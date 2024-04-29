// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {vm} from "@chimera/Hevm.sol";
import {Properties} from "./Properties.sol";
import {ZivoeGlobals} from "../../../lib/zivoe-core-foundry/src/ZivoeGlobals.sol";
import {IERC20Mintable_ITO, IZivoeGlobals_ITO} from "../../../lib/zivoe-core-foundry/src/ZivoeITO.sol";
import {IERC20} from "../../../lib/zivoe-core-foundry/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../../Utility/Utility.sol";
import "forge-std/console2.sol";

interface IActor {
    function try_approveToken(
        address token,
        address to,
        uint256 amount
    ) external returns (bool ok);
}

// @audit target function callers are pranked to be system users by fuzzing an index to select from the actors array
abstract contract TargetFunctions is BaseTargetFunctions, Properties {
    function zivoeITO_claimAirdrop(uint256 depositorIndex) public {
        depositorIndex = bound(depositorIndex, 0, actors.length - 1);
        // @audit may be useful to also include calls where the sender isn't the depositor
        address depositor = actors[depositorIndex];

        uint256 seniorCreditsOwned = ITO.seniorCredits(depositor);
        uint256 juniorCreditsOwned = ITO.juniorCredits(depositor);

        // @audit checking senior/junior credits is still always reverting
        // could be because msg.sender isn't preserved so when deposits are made it's never for addresses in the system
        // this means the possible callers need to be pranked here
        vm.prank(depositor);
        try ITO.claimAirdrop(depositor) {
            // created a ghost variable to not trust state variable value
            // ZTO-01: claimAirdrop can only be called after ITO concludes
            t(
                block.timestamp >= ITOstart + 30 days,
                "airdrop claimed before ITO end"
            );

            // ZTO-02: $ZVE only gets vested once $zJTT and $zSTT are claimed
            // this uses same conditionals from the function to verify vesting only when executed
            uint256 upper = seniorCreditsOwned + juniorCreditsOwned;
            uint256 middle = IERC20(GBL.ZVE()).totalSupply() / 20;
            uint256 lower = IERC20(GBL.zSTT()).totalSupply() *
                3 +
                (IERC20(address((GBL).zJTT())).totalSupply());

            if ((upper * middle) / lower > 0) {
                t(
                    vestZVE.vestingScheduleSet(depositor),
                    "$ZVE not vested after claiming airdrop"
                );
            }
        } catch {
            // t(false, "claimAirdrop reverts");
        }
    }

    function zivoeITO_commence() public {
        // need to prank as ZVL here because it's the only one that can call it
        vm.prank(ZivoeGlobals(ITO.GBL()).ZVL());
        try ITO.commence() {
            // ghost variable to track start of ITO on deployment used in checking end time
            ITOstart = block.timestamp;
        } catch {}
    }

    function zivoeITO_depositBoth(
        uint256 depositorIndex,
        uint256 amountSenior,
        uint256 assetSeniorIndex,
        uint256 amountJunior,
        uint256 assetJuniorIndex
    ) public {
        depositorIndex = bound(depositorIndex, 0, actors.length - 1);
        address depositor = actors[depositorIndex];

        // bounding the asset addresses to be ones actually accepted by ITO
        assetSeniorIndex = bound(assetSeniorIndex, 0, 3);
        assetJuniorIndex = bound(assetJuniorIndex, 0, 3);
        address assetSenior = ITO.stables(assetSeniorIndex);
        address assetJunior = ITO.stables(assetJuniorIndex);

        // minting and approving stables to the depositor
        bool juniorApprovalSuccess = _mintAndApproveStablesToDepositor(
            assetJunior,
            depositor,
            amountJunior
        );
        bool seniorApprovalSuccess = _mintAndApproveStablesToDepositor(
            assetSenior,
            depositor,
            amountSenior
        );

        // fetching initial asset and tranche token values
        uint256 depositorJuniorAssetBalanceInitial = IERC20(assetJunior)
            .balanceOf(depositor);
        uint256 ITOzJTTBalanceBefore = IERC20(GBL.zJTT()).balanceOf(
            address(ITO)
        );
        uint256 depositorSeniorAssetBalanceInitial = IERC20(assetSenior)
            .balanceOf(depositor);
        uint256 ITOzSTTBalanceBefore = IERC20(GBL.zSTT()).balanceOf(
            address(ITO)
        );

        vm.prank(depositor);
        try
            ITO.depositBoth(
                amountSenior,
                assetSenior,
                amountJunior,
                assetJunior
            )
        {
            // ZTO-08: depositJunior and depositSenior can’t be called after migration
            t(!migrated, "deposit made after migration");

            if (amountJunior != 0 || amountSenior != 0) {
                uint256 standardizedJuniorAmount = GBL.standardize(
                    amountJunior,
                    assetJunior
                );
                uint256 standardizedSeniorAmount = GBL.standardize(
                    amountSenior,
                    assetSenior
                );

                uint256 ITOzJTTBalanceAfter = IERC20(GBL.zJTT()).balanceOf(
                    address(ITO)
                );
                uint256 ITOzSTTBalanceAfter = IERC20(GBL.zSTT()).balanceOf(
                    address(ITO)
                );
                uint256 ITOzJTTBalanceDelta = ITOzJTTBalanceAfter -
                    ITOzJTTBalanceBefore;
                uint256 ITOzSTTBalanceDelta = ITOzSTTBalanceAfter -
                    ITOzSTTBalanceBefore;

                // ZTO-04: $zJTT and $zSTT are always minted after making a nonzero deposit
                // @audit this rounds in the protocol's favor to ensure no more than the standardizedAmount is minted to the user
                t(
                    ITOzJTTBalanceDelta <= standardizedJuniorAmount,
                    "ZTO-04: junior tranche tokens aren't minted for nonzero amount"
                );
                t(
                    ITOzSTTBalanceDelta <= standardizedSeniorAmount,
                    "ZTO-04: senior tranche tokens aren't minted for nonzero amount"
                );

                uint256 depositorJuniorAssetBalanceAfter = IERC20(assetJunior)
                    .balanceOf(depositor);
                uint256 depositorSeniorAssetBalanceAfter = IERC20(assetSenior)
                    .balanceOf(depositor);
                uint256 depositorJuniorAssetBalanceDelta = depositorJuniorAssetBalanceInitial -
                        depositorJuniorAssetBalanceAfter;
                uint256 depositorSeniorAssetBalanceDelta = depositorSeniorAssetBalanceInitial -
                        depositorSeniorAssetBalanceAfter;

                // ZTO-05: $zJTT and $zSTT can’t be minted for free
                t(
                    depositorJuniorAssetBalanceDelta > 0,
                    "ZTO-05: tranche tokens get minted for free"
                );
                t(
                    depositorSeniorAssetBalanceDelta > 0,
                    "ZTO-05: tranche tokens get minted for free"
                );

                // ZTO-06: depositJunior and depositSenior can only be called during the ITO
                t(
                    block.timestamp <= ITOstart + 30 days,
                    "deposit made after ITO ended"
                );
            }
        } catch {
            // t(false, "depositBoth reverts");

            // ZTO-02: $ZVE only gets vested once $zJTT and $zSTT are claimed
            // since airdrop can only be claimed when ITO has ended, include this here because deposit would fail in this case
            if (ITO.airdropClaimed(depositor)) {
                t(
                    vestZVE.vestingScheduleSet(depositor),
                    "$ZVE not vested after claiming aridrop"
                );
            }
        }
    }

    function zivoeITO_depositJunior(
        uint256 depositorIndex,
        uint256 amount,
        uint256 assetIndex
    ) public {
        depositorIndex = bound(depositorIndex, 0, actors.length - 1);
        address depositor = actors[depositorIndex];

        assetIndex = bound(assetIndex, 0, 3);
        address asset = ITO.stables(assetIndex);

        // mints stablecoins to the depositor by modifying storage of mainnet ERC20
        // @audit might run into issues with amount overflows
        // could potentially clamp amount to a large value that a whale might hold
        bool approvalSuccess = _mintAndApproveStablesToDepositor(
            asset,
            depositor,
            amount
        );
        if (!approvalSuccess) {
            return;
        }

        uint256 depositorAssetBalanceInitial = IERC20(asset).balanceOf(
            depositor
        );
        uint256 ITOzJTTBalanceBefore = IERC20(GBL.zJTT()).balanceOf(
            address(ITO)
        );

        vm.prank(depositor);
        try ITO.depositJunior(amount, asset) {
            // ZTO-08: depositJunior and depositSenior can’t be called after migration
            t(!migrated, "deposit made after migration");

            if (amount != 0) {
                // ITO's balance of $zJTT should increase
                uint256 standardizedAmount = GBL.standardize(amount, asset);
                uint256 ITOzJTTBalanceAfter = IERC20(GBL.zJTT()).balanceOf(
                    address(ITO)
                );
                uint256 ITOzJTTBalanceDelta = ITOzJTTBalanceAfter -
                    ITOzJTTBalanceBefore;

                // ZTO-04: $zJTT and $zSTT are always minted after making a nonzero deposit
                // @audit this rounds in the protocol's favor to ensure no more than the standardizedAmount is minted to the user
                t(
                    ITOzJTTBalanceDelta <= standardizedAmount,
                    "ZTO-04: tranche tokens aren't minted for nonzero amount"
                );
                uint256 depositorAssetBalanceAfter = IERC20(asset).balanceOf(
                    depositor
                );
                uint256 depositorBalanceDelta = depositorAssetBalanceInitial;

                // ZTO-05: $zJTT and $zSTT can’t be minted for free
                t(
                    depositorBalanceDelta > 0,
                    "ZTO-05: tranche tokens get minted for free"
                );
            }
            // ZTO-06: depositJunior and depositSenior can only be called during the ITO
            t(
                block.timestamp <= ITOstart + 30 days,
                "deposit made after ITO ended"
            );
        } catch {
            // t(false, "depositJunior reverts");

            // ZTO-02: $ZVE only gets vested once $zJTT and $zSTT are claimed
            // since airdrop can only be claimed when ITO has ended, include this here because deposit would fail in this case
            if (ITO.airdropClaimed(depositor)) {
                t(
                    vestZVE.vestingScheduleSet(depositor),
                    "$ZVE not vested after claiming aridrop"
                );
            }
        }
    }

    function zivoeITO_depositSenior(
        uint256 depositorIndex,
        uint256 amount,
        uint256 assetIndex
    ) public {
        // if the ITO hasn't started yet start it, or else the majority of calls will end up reverting
        if (ITO.end() == 0) {
            zivoeITO_commence();
        }

        depositorIndex = bound(depositorIndex, 0, actors.length - 1);
        address depositor = actors[depositorIndex];

        assetIndex = bound(assetIndex, 0, 3);
        address asset = ITO.stables(assetIndex);

        bool approvalSuccess = _mintAndApproveStablesToDepositor(
            asset,
            depositor,
            amount
        );
        // breaks if the call to try_approveToken fails
        // @audit might not be needed since the function call would revert later on anyways
        if (!approvalSuccess) {
            return;
        }

        uint256 depositorAssetBalanceInitial = IERC20(asset).balanceOf(
            depositor
        );
        uint256 ITOzSTTBalanceBefore = IERC20(GBL.zSTT()).balanceOf(
            address(ITO)
        );

        vm.prank(depositor);
        try ITO.depositSenior(amount, asset) {
            // ZTO-08: depositJunior and depositSenior can’t be called after migration
            t(!migrated, "deposit made after migration");

            if (amount != 0) {
                uint256 standardizedAmount = GBL.standardize(amount, asset);
                uint256 ITOzSTTBalanceAfter = IERC20(GBL.zSTT()).balanceOf(
                    address(ITO)
                );
                uint256 ITOzSTTBalanceDelta = ITOzSTTBalanceAfter -
                    ITOzSTTBalanceBefore;

                // ZTO-04: $zJTT and $zSTT are always minted after making a nonzero deposit
                // @audit this rounds in the protocol's favor to ensure no more than the standardizedAmount is minted to the user
                t(
                    ITOzSTTBalanceDelta <= standardizedAmount,
                    "ZTO-04: tranche tokens aren't minted for nonzero amount"
                );
                uint256 depositorAssetBalanceAfter = IERC20(asset).balanceOf(
                    depositor
                );
                uint256 depositorBalanceDelta = depositorAssetBalanceInitial;

                // ZTO-05: $zJTT and $zSTT can’t be minted for free
                t(
                    depositorBalanceDelta > 0,
                    "ZTO-05: tranche tokens get minted for free"
                );
            }

            // ZTO-06: depositJunior and depositSenior can only be called during the ITO
            t(
                block.timestamp <= ITOstart + 30 days,
                "deposit made after ITO ended"
            );
        } catch {
            // t(false, "depositSenior reverts");

            // ZTO-02: $ZVE only gets vested once $zJTT and $zSTT are claimed
            // since airdrop can only be claimed when ITO has ended, include this here because deposit would fail in this case
            if (ITO.airdropClaimed(depositor)) {
                t(
                    vestZVE.vestingScheduleSet(depositor),
                    "$ZVE not vested after claiming aridrop"
                );
            }
        }
    }

    function zivoeITO_migrateDeposits() public {
        uint256 daiBalanceITO = IERC20(ITO.stables(0)).balanceOf(address(ITO));
        uint256 fraxBalanceITO = IERC20(ITO.stables(1)).balanceOf(address(ITO));
        uint256 usdcBalanceITO = IERC20(ITO.stables(2)).balanceOf(address(ITO));
        uint256 usdtBalanceITO = IERC20(ITO.stables(3)).balanceOf(address(ITO));

        try ITO.migrateDeposits() {
            migrated = true;

            // ZTO-03: Deposits are always transferred to ZivoeDAO when migrateDeposits is called
            // balance of ZivoDAO should increase by the balance of the assets in this contract
            // there are four stables that can be deposited, so each needs to be checked or can normalize and use their sum
            uint256 daiBalanceDAO = IERC20(ITO.stables(0)).balanceOf(
                address(DAO)
            );
            uint256 fraxBalanceDAO = IERC20(ITO.stables(1)).balanceOf(
                address(DAO)
            );
            uint256 usdcBalanceDAO = IERC20(ITO.stables(2)).balanceOf(
                address(DAO)
            );
            uint256 usdtBalanceDAO = IERC20(ITO.stables(3)).balanceOf(
                address(DAO)
            );

            // assertions
            t(
                daiBalanceDAO == daiBalanceITO,
                "DAO doesn't receive DAI on migration"
            );
            t(
                fraxBalanceDAO == fraxBalanceITO,
                "DAO doesn't receive FRAX on migration"
            );
            t(
                usdcBalanceDAO == usdcBalanceITO,
                "DAO doesn't receive USDC on migration"
            );
            t(
                usdtBalanceDAO == usdtBalanceITO,
                "DAO doesn't receive USDT on migration"
            );
        } catch {}
    }

    function _mintAndApproveStablesToDepositor(
        address asset,
        address depositor,
        uint256 amount
    ) public returns (bool approvalSuccess) {
        if (asset == DAI) {
            mint("DAI", address(depositor), amount);
        } else if (asset == FRAX) {
            mint("FRAX", address(depositor), amount);
        } else if (asset == USDC) {
            mint("USDC", address(depositor), amount);
        } else if (asset == USDT) {
            mint("USDT", address(depositor), amount);
        }

        (approvalSuccess) = IActor(depositor).try_approveToken(
            asset,
            address(ITO),
            amount
        );

        require(approvalSuccess, "approval call failed");
    }
}
