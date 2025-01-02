// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

interface IExtensionRegistry {
    error ExtensionRegistry__ZeroInput();
    error ExtensionRegistry__ExtensionNotSupported(address extension);
    error ExtensionRegistry__InvalidFuncSelector(bytes4 funcSelector);
    error ExtensionRegistry__InvalidConfig();

    struct ExtensionConfig {
        address extension;
        bytes4[] funcSelectors;
        bytes4[] interfaceIds;
    }

    struct HookExtensionConfig {
        address extension;
        bool isValidateHook;
        bool isExecuteHook;
        bytes4[] interfaceIds;
    }

    function registerExtension(bytes32 extensionId, ExtensionConfig calldata config) external;
    function registerHookExtension(bytes32 extensionId, HookExtensionConfig calldata config) external;

    function getExtension(bytes32 extensionId) external view returns (ExtensionConfig memory);
    function getHookExtension(bytes32 extensionId) external view returns (HookExtensionConfig memory);
}
