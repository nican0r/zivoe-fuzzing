// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseSetup} from "@chimera/BaseSetup.sol";
import "../../../lib/zivoe-core-foundry/src/ZivoeITO.sol";
import "../../Utility/Utility.sol";

abstract contract Setup is BaseSetup, Utility {
    uint256 ITOstart;
    bool migrated; // ghost for tracking migration to not trust the one in the contract

    function setup() internal virtual override {
        deployCore(false);
    }
}
