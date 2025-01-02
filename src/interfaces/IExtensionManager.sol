// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

interface IExtensionManager {
    error ExtensionManager__ExtensionAlreadyInstalled();
    error ExtensionManager__ExtensionNotInstalled(address extension);
    error ExtensionManager__ExtensionNotRegistered();

    function installExtension(bytes32 extensionId, bytes calldata installData) external;
    function uninstallExtension(bytes32 extensionId, bytes calldata uninstallData) external;
    function installHookExtension(bytes32 extensionId, bytes calldata installData) external;
    function uninstallHookExtension(bytes32 extensionId, bytes calldata uninstallData) external;
}
