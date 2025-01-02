// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {IExtensionRegistry} from "./interfaces/IExtensionRegistry.sol";
import {IExtensionManager} from "./interfaces/IExtensionManager.sol";
import {IExtension} from "./interfaces/extensions/IExtension.sol";
import {IValidateHookExtension} from "./interfaces/extensions/hooks/IValidateHookExtension.sol";
import {IExecuteHookExtension} from "./interfaces/extensions/hooks/IExecuteHookExtension.sol";

abstract contract ExtensionManager is Initializable, IExtensionManager {
    mapping(bytes4 funcSelector => address extension) public installedExtensions;
    IExtensionRegistry public extensionRegistry;
    IValidateHookExtension public validateHookExtension;
    IExecuteHookExtension public executeHookExtension;

    function __ExtensionManager_init(address extensionRegistry_) internal onlyInitializing {
        extensionRegistry = IExtensionRegistry(extensionRegistry_);
    }

    /// @inheritdoc IExtensionManager
    function installExtension(bytes32 extensionId, bytes calldata installData) external {
        IExtensionRegistry.ExtensionConfig memory config = extensionRegistry.getExtension(extensionId);
        require(config.extension != address(0), ExtensionManager__ExtensionNotRegistered());

        for (uint256 i; i < config.funcSelectors.length; i++) {
            require(
                installedExtensions[config.funcSelectors[i]] == address(0),
                ExtensionManager__ExtensionAlreadyInstalled()
            );
            installedExtensions[config.funcSelectors[i]] = config.extension;
        }
        IExtension(config.extension).installCallBack(installData);
    }

    /// @inheritdoc IExtensionManager
    function uninstallExtension(bytes32 extensionId, bytes calldata uninstallData) external {
        IExtensionRegistry.ExtensionConfig memory config = extensionRegistry.getExtension(extensionId);
        require(config.extension != address(0), ExtensionManager__ExtensionNotRegistered());

        for (uint256 i; i < config.funcSelectors.length; i++) {
            require(
                installedExtensions[config.funcSelectors[i]] == config.extension,
                ExtensionManager__ExtensionNotInstalled(config.extension)
            );
            installedExtensions[config.funcSelectors[i]] = address(0);
        }
        IExtension(config.extension).uninstallCallBack(uninstallData);
    }

    /// @inheritdoc IExtensionManager
    function installHookExtension(bytes32 extensionId, bytes calldata installData) external {
        IExtensionRegistry.HookExtensionConfig memory config = extensionRegistry.getHookExtension(extensionId);
        require(config.extension != address(0), ExtensionManager__ExtensionNotRegistered());

        // a hook extension can be both validate and execute hook
        if (config.isValidateHook) {
            require(address(validateHookExtension) == address(0), ExtensionManager__ExtensionAlreadyInstalled());
            validateHookExtension = IValidateHookExtension(config.extension);
            IExtension(config.extension).installCallBack(installData);
        }
        if (config.isExecuteHook) {
            require(address(executeHookExtension) == address(0), ExtensionManager__ExtensionAlreadyInstalled());
            executeHookExtension = IExecuteHookExtension(config.extension);
            IExtension(config.extension).installCallBack(installData);
        }
    }

    /// @inheritdoc IExtensionManager
    function uninstallHookExtension(bytes32 extensionId, bytes calldata uninstallData) external {
        IExtensionRegistry.HookExtensionConfig memory config = extensionRegistry.getHookExtension(extensionId);
        require(config.extension != address(0), ExtensionManager__ExtensionNotRegistered());

        if (config.isValidateHook) {
            require(
                address(validateHookExtension) != address(0), ExtensionManager__ExtensionNotInstalled(config.extension)
            );
            validateHookExtension = IValidateHookExtension(address(0));
            IExtension(config.extension).uninstallCallBack(uninstallData);
        }
        if (config.isExecuteHook) {
            require(
                address(executeHookExtension) != address(0), ExtensionManager__ExtensionNotInstalled(config.extension)
            );
            executeHookExtension = IExecuteHookExtension(address(0));
            IExtension(config.extension).uninstallCallBack(uninstallData);
        }
    }
}
