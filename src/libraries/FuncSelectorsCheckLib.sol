// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IAccount} from "@eth-infinitism/account-abstraction/interfaces/IAccount.sol";
import {IAccountExecute} from "@eth-infinitism/account-abstraction/interfaces/IAccountExecute.sol";
import {IAggregator} from "@eth-infinitism/account-abstraction/interfaces/IAggregator.sol";
import {IPaymaster} from "@eth-infinitism/account-abstraction/interfaces/IPaymaster.sol";
import {IEntryPoint} from "@eth-infinitism/account-abstraction/interfaces/IEntryPoint.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IExtensionManager} from "../interfaces/IExtensionManager.sol";
import {IExtension} from "../interfaces/extensions/IExtension.sol";
import {IModularSmartAccount} from "../interfaces/IModularSmartAccount.sol";

library FuncSelectorsCheckLib {
    function isValidFuncSelector(bytes4 selector) internal pure returns (bool) {
        return !isERC4337Function(selector) && !isMSAFunction(selector) && !isExtensionFunction(selector);
    }

    function isERC4337Function(bytes4 selector) internal pure returns (bool) {
        return selector == IAccount.validateUserOp.selector || selector == IAccountExecute.executeUserOp.selector
            || selector == IEntryPoint.handleOps.selector || selector == IEntryPoint.handleAggregatedOps.selector
            || selector == IEntryPoint.getUserOpHash.selector || selector == IEntryPoint.getSenderAddress.selector
            || selector == IEntryPoint.delegateAndRevert.selector || selector == IAggregator.validateSignatures.selector
            || selector == IAggregator.validateUserOpSignature.selector
            || selector == IAggregator.aggregateSignatures.selector
            || selector == IPaymaster.validatePaymasterUserOp.selector || selector == IPaymaster.postOp.selector;
    }

    function isMSAFunction(bytes4 selector) internal pure returns (bool) {
        return selector == IModularSmartAccount.execute.selector || selector == IERC165.supportsInterface.selector
            || selector == UUPSUpgradeable.proxiableUUID.selector || selector == UUPSUpgradeable.upgradeToAndCall.selector;
    }

    function isExtensionFunction(bytes4 selector) internal pure returns (bool) {
        return selector == IExtensionManager.installExtension.selector
            || selector == IExtensionManager.uninstallExtension.selector
            || selector == IExtensionManager.installHookExtension.selector
            || selector == IExtensionManager.uninstallHookExtension.selector || selector == IExtension.extensionId.selector
            || selector == IExtension.installCallBack.selector || selector == IExtension.uninstallCallBack.selector;
    }
}
