// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {ModularSmartAccount} from "src/ModularSmartAccount.sol";
import {ExtensionRegistry} from "src/ExtensionRegistry.sol";

import {MAINNET_ENTRY_POINT} from "test/helpers/Constants.sol";

contract DeployRegistryAndMSA is Script {
    function run() public {
        // deploy ExtensionRegistry
        address extensionRegistry = address(new ExtensionRegistry());

        // deploy ModularSmartAccount implementation
        address msaImpl = address(new ModularSmartAccount(MAINNET_ENTRY_POINT));
        bytes memory initData = abi.encodeCall(ModularSmartAccount.initialize, extensionRegistry);
        address msa = address(new ERC1967Proxy(address(msaImpl), initData));

        console.log("ExtensionRegistry deployed at: ", extensionRegistry);
        console.log("ModularSmartAccount implementation deployed at: ", msaImpl);
        console.log("ModularSmartAccount deployed at: ", msa);
    }
}
