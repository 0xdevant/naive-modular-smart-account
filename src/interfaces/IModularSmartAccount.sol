// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

interface IModularSmartAccount {
    error ModularSmartAccount__CallFailed(bytes result);
    error ModularSmartAccount__NoExtensionFound(bytes4 funcSelector);
    error ModularSmartAccount__OnlyFromEntryPointOrPermissionedCaller();
    error ModularSmartAccount__OnlyFromEntryPoint();

    /// @notice A wrapper struct used for Passkey signature validation so that callers
    ///         can identify the owner that signed.
    struct PasskeySignatureWrapper {
        /// @dev The x coordinate of the public key.
        uint256 x;
        /// @dev The y coordinate of the public key.
        uint256 y;
        /// @dev Should be abi.encode(WebAuthnAuth).
        bytes signatureData;
    }

    function execute(address target, uint256 value, bytes calldata data) external returns (bytes memory);
}
