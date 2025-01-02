// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Script, console} from "forge-std/Script.sol";

import {OwnershipManagementHookExtension} from "src/extensions/OwnershipManagementHookExtension.sol";
import {DCAExtension} from "src/extensions/DCAExtension.sol";

contract DeployExtensions is Script {
    function run() public {
        address omExtension = address(new OwnershipManagementHookExtension());
        address dcaExtension = address(new DCAExtension());

        console.log("OwnershipManagementHookExtension deployed at: ", omExtension);
        console.log("DCAExtension deployed at: ", dcaExtension);
    }
}
