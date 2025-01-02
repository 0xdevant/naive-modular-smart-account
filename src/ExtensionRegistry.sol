// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import {IExtensionRegistry} from "./interfaces/IExtensionRegistry.sol";
import {IExtension} from "./interfaces/extensions/IExtension.sol";
import {IValidateHookExtension} from "./interfaces/extensions/hooks/IValidateHookExtension.sol";
import {IExecuteHookExtension} from "./interfaces/extensions/hooks/IExecuteHookExtension.sol";
import {FuncSelectorsCheckLib} from "./libraries/FuncSelectorsCheckLib.sol";

contract ExtensionRegistry is IExtensionRegistry {
    using FuncSelectorsCheckLib for bytes4;

    mapping(bytes32 extensionId => ExtensionConfig config) public extensions;
    mapping(bytes32 extensionId => HookExtensionConfig config) public hookExtensions;

    /// @inheritdoc IExtensionRegistry
    function registerExtension(bytes32 extensionId, ExtensionConfig calldata config) external {
        require(config.extension != address(0) || config.funcSelectors.length > 0, ExtensionRegistry__ZeroInput());
        // checkings to avoid duplication of function selectors within extensions and AA-related(e.g. EntryPoint, MSA etc) contracts
        for (uint256 i; i < config.funcSelectors.length; i++) {
            require(
                ERC165Checker.supportsInterface(config.extension, type(IExtension).interfaceId),
                ExtensionRegistry__ExtensionNotSupported(config.extension)
            );
            require(
                config.funcSelectors[i].isValidFuncSelector(),
                ExtensionRegistry__InvalidFuncSelector(config.funcSelectors[i])
            );
        }
        extensions[extensionId] = config;
    }

    /// @inheritdoc IExtensionRegistry
    function registerHookExtension(bytes32 extensionId, HookExtensionConfig calldata config) external {
        require(config.extension != address(0), ExtensionRegistry__ZeroInput());
        require(config.isValidateHook || config.isExecuteHook, ExtensionRegistry__InvalidConfig());
        require(
            ERC165Checker.supportsInterface(config.extension, type(IExtension).interfaceId),
            ExtensionRegistry__ExtensionNotSupported(config.extension)
        );
        if (config.isValidateHook) {
            require(
                ERC165Checker.supportsInterface(config.extension, type(IValidateHookExtension).interfaceId),
                ExtensionRegistry__ExtensionNotSupported(config.extension)
            );
        }
        if (config.isExecuteHook) {
            require(
                ERC165Checker.supportsInterface(config.extension, type(IExecuteHookExtension).interfaceId),
                ExtensionRegistry__ExtensionNotSupported(config.extension)
            );
        }
        hookExtensions[extensionId] = config;
    }

    /// @inheritdoc IExtensionRegistry
    function getExtension(bytes32 extensionId) external view returns (ExtensionConfig memory) {
        return extensions[extensionId];
    }

    /// @inheritdoc IExtensionRegistry
    function getHookExtension(bytes32 extensionId) external view returns (HookExtensionConfig memory) {
        return hookExtensions[extensionId];
    }
}
