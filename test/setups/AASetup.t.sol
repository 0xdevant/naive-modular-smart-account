// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {ExtensionRegistry} from "src/ExtensionRegistry.sol";
import {OwnershipManagementHookExtension} from "src/extensions/OwnershipManagementHookExtension.sol";
import {DCAExtension} from "src/extensions/DCAExtension.sol";
import {ModularSmartAccount} from "src/ModularSmartAccount.sol";

import {BaseSetup} from "./BaseSetup.t.sol";
import {MAINNET_SWAP_ROUTER_02, MAINNET_WETH, MAINNET_USDC, MAINNET_ENTRY_POINT} from "../helpers/Constants.sol";

contract AASetup is BaseSetup {
    ExtensionRegistry public extensionRegistry;
    OwnershipManagementHookExtension public omExtension;
    DCAExtension public dcaExtension;
    ModularSmartAccount public msaImpl;
    ModularSmartAccount public msa;

    function setUp() public virtual override {
        BaseSetup.setUp();
        deployExtensionContracts();
        deployMSA();
        labelContracts();
        makeContractsPersistent();
    }

    function deployMSA() public {
        msaImpl = new ModularSmartAccount(MAINNET_ENTRY_POINT);
        bytes memory initData = abi.encodeCall(ModularSmartAccount.initialize, address(extensionRegistry));
        msa = ModularSmartAccount(payable(address(new ERC1967Proxy(address(msaImpl), initData))));
    }

    function deployExtensionContracts() public {
        extensionRegistry = new ExtensionRegistry();
        // deploy all extensions
        omExtension = new OwnershipManagementHookExtension();
        dcaExtension = new DCAExtension();
    }

    function makeContractsPersistent() public {
        vm.makePersistent(address(omExtension), address(dcaExtension), address(msaImpl));
        vm.makePersistent(address(msa), address(erc20Mock), address(users[0]));
        vm.makePersistent(address(users[1]), address(users[2]), address(users[3]));
    }

    function labelContracts() internal {
        vm.label({account: address(this), newLabel: "TestContract"});
        vm.label({account: address(erc20Mock), newLabel: "ERC20Mock"});
        vm.label({account: address(omExtension), newLabel: "OwnershipManagementHookExtension"});
        vm.label({account: address(dcaExtension), newLabel: "DCAExtension"});
        vm.label({account: address(extensionRegistry), newLabel: "ExtensionRegistry"});
        vm.label({account: address(msa), newLabel: "ModularSmartAccount"});
        vm.label({account: address(msaImpl), newLabel: "ModularSmartAccountImplementation"});
        vm.label({account: MAINNET_SWAP_ROUTER_02, newLabel: "Mainnet_SwapRouter02"});
        vm.label({account: MAINNET_WETH, newLabel: "Mainnet_WETH"});
        vm.label({account: MAINNET_USDC, newLabel: "Mainnet_USDC"});
        vm.label({account: MAINNET_ENTRY_POINT, newLabel: "Mainnet_EntryPoint"});
    }
}
