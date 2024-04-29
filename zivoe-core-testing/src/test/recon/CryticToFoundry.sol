// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {TargetFunctions} from "./TargetFunctions.sol";
import {FoundryAsserts} from "@chimera/FoundryAsserts.sol";
import {ZivoeGlobals} from "../../../lib/zivoe-core-foundry/src/ZivoeGlobals.sol";

// fork testing with foundry: forge test --mt test_zivoeITO_depositSenior --fork-url https:// --fork-block-number 19712713
contract CryticToFoundry is Test, TargetFunctions, FoundryAsserts {
    function setUp() public {
        setup();
    }

    function test_zivoeITO_depositJunior() public {
        vm.prank(ZivoeGlobals(ITO.GBL()).ZVL());
        ITO.commence();

        zivoeITO_depositJunior(10900000, 25000000000000000000000001, 18299999);
    }

    function test_zivoeITO_depositSenior() public {
        vm.prank(ZivoeGlobals(ITO.GBL()).ZVL());
        ITO.commence();

        zivoeITO_depositSenior(
            73900160710983669925942477279448927243570503213555515888704095591758482231158,
            19999,
            353073666
        );
    }

    function test_ZTO_02() public {
        zivoeITO_depositSenior(
            15557058185092,
            38368949624871655874694595110534589931355144807531108,
            70436852268073678714075553155087345714840085665878
        );
        // *wait* Time delay: 235976 seconds Block delay: 40541
        vm.warp(235976);
        vm.roll(40541);
        // *wait* Time delay: 203127 seconds Block delay: 19856
        vm.warp(203127);
        vm.roll(19856);
        zivoeITO_depositJunior(
            13376907592048147922309039336064123294530339720875493067821365,
            1,
            34791411016057858833621346
        );
        // Time delay: 171922 seconds Block delay: 816
        vm.warp(171922);
        vm.roll(816);
        // *wait* Time delay: 345582 seconds Block delay: 88
        vm.warp(345582);
        vm.roll(88);
        zivoeITO_migrateDeposits();
        // Time delay: 518389 seconds Block delay: 58560
        vm.warp(518389);
        vm.roll(58560);
        // *wait* Time delay: 579559 seconds Block delay: 4933
        vm.warp(579559);
        vm.roll(4933);
        // *wait* Time delay: 537598 seconds Block delay: 35266
        vm.warp(537598);
        vm.roll(35266);
        zivoeITO_claimAirdrop(
            6701531729166028421714162396132906122713456701970563748699266137708265494
        );
    }
}
