// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {BaseAccount} from "@eth-infinitism/account-abstraction/core/BaseAccount.sol";
import {IAccountExecute} from "@eth-infinitism/account-abstraction/interfaces/IAccountExecute.sol";
import {IEntryPoint} from "@eth-infinitism/account-abstraction/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "@eth-infinitism/account-abstraction/interfaces/PackedUserOperation.sol";

import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {WebAuthn} from "@webauthn-sol/WebAuthn.sol";

import {ExtensionManager} from "./ExtensionManager.sol";
import {IModularSmartAccount} from "./interfaces/IModularSmartAccount.sol";

contract ModularSmartAccount is
    UUPSUpgradeable,
    BaseAccount,
    ExtensionManager,
    IModularSmartAccount,
    IERC165,
    IERC1271,
    IAccountExecute
{
    IEntryPoint private immutable _ENTRY_POINT;

    // As per the EIP-165 spec, no interface should ever match 0xffffffff
    bytes4 internal constant _INTERFACE_ID_INVALID = 0xffffffff;
    bytes4 internal constant _IERC165_INTERFACE_ID = 0x01ffc9a7;

    // bytes4(keccak256("isValidSignature(bytes32,bytes)"))
    bytes4 internal constant _1271_MAGIC_VALUE = 0x1626ba7e;
    bytes4 internal constant _1271_INVALID = 0xffffffff;

    constructor(address _entryPoint) {
        _ENTRY_POINT = IEntryPoint(_entryPoint);
        _disableInitializers();
    }

    function initialize(address extensionRegistry_) external initializer {
        __ExtensionManager_init(extensionRegistry_);
    }

    receive() external payable {}

    /// @notice Function signature that doesn't exist in the MSA will be directed to fallback and find non-hook extension based on msg.sig
    /// @dev Only non-hook extension functions will be called here
    fallback(bytes calldata) external payable returns (bytes memory) {
        _beforeExecuteHook(msg.sender, msg.data);
        address extension = installedExtensions[msg.sig];
        require(extension != address(0), ModularSmartAccount__NoExtensionFound(msg.sig));

        (bool success, bytes memory result) = installedExtensions[msg.sig].call(msg.data);
        require(success, ModularSmartAccount__CallFailed(result));
        _afterExecuteHook(msg.sender, msg.data);

        return result;
    }

    /*//////////////////////////////////////////////////////////////
                               EXTERNALS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IAccountExecute
    function executeUserOp(PackedUserOperation calldata userOp, bytes32) external override {
        require(msg.sender == address(_ENTRY_POINT), ModularSmartAccount__OnlyFromEntryPoint());

        (bool success, bytes memory result) = address(this).call(userOp.callData[4:]);
        require(success, ModularSmartAccount__CallFailed(result));
    }

    function execute(address target, uint256 value, bytes calldata data) external returns (bytes memory) {
        _beforeExecuteHook(msg.sender, data);
        (bool success, bytes memory result) = target.call{value: value}(data);
        require(success, ModularSmartAccount__CallFailed(result));
        _afterExecuteHook(msg.sender, data);

        return result;
    }

    /// @inheritdoc IERC1271
    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4 magicValue) {
        if (_isValidSignature(hash, signature)) {
            return _1271_MAGIC_VALUE;
        } else {
            return _1271_INVALID;
        }
    }

    /// @notice ERC165 introspection
    /// @dev returns true for `IERC165.interfaceId` and false for `0xFFFFFFFF`
    /// @param interfaceId interface id to check against
    /// @return bool support for specific interface
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        if (interfaceId == _INTERFACE_ID_INVALID) {
            return false;
        }
        if (interfaceId == _IERC165_INTERFACE_ID) {
            return true;
        }

        return interfaceId == type(IModularSmartAccount).interfaceId;
    }

    /*//////////////////////////////////////////////////////////////
                               INTERNALS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc BaseAccount
    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
        internal
        override
        returns (uint256 validationData)
    {
        _beforeValidateHook(msg.sender, userOp, userOpHash);
        if (_isValidSignature(userOpHash, userOp.signature)) {
            validationData = 0;
        } else {
            validationData = 1;
        }
        _afterValidateHook(userOp, userOpHash);
    }

    // validate passkey signature
    function _isValidSignature(bytes32 hash, bytes memory signature) internal view returns (bool) {
        PasskeySignatureWrapper memory sigWrapper = abi.decode(signature, (PasskeySignatureWrapper));

        WebAuthn.WebAuthnAuth memory auth = abi.decode(sigWrapper.signatureData, (WebAuthn.WebAuthnAuth));

        return WebAuthn.verify({
            challenge: abi.encode(hash),
            requireUV: false,
            webAuthnAuth: auth,
            x: sigWrapper.x,
            y: sigWrapper.y
        });
    }

    function _beforeExecuteHook(address sender, bytes calldata data) internal {
        // to be added whitelist feature for view functions
        if (address(executeHookExtension) != address(0)) {
            try executeHookExtension.beforeExecute(sender, data) {}
            // fallback to check if the caller is EntryPoint as well
            catch {
                require(sender == address(_ENTRY_POINT), ModularSmartAccount__OnlyFromEntryPointOrPermissionedCaller());
            }
        } else {
            require(sender == address(_ENTRY_POINT), ModularSmartAccount__OnlyFromEntryPoint());
        }
    }

    function _afterExecuteHook(address sender, bytes calldata data) internal {
        if (address(executeHookExtension) != address(0)) executeHookExtension.afterExecute(sender, data);
    }

    function _beforeValidateHook(address sender, PackedUserOperation calldata userOp, bytes32 userOpHash) internal {
        if (address(validateHookExtension) != address(0)) {
            validateHookExtension.beforeValidate(sender, userOp, userOpHash);
        }
    }

    function _afterValidateHook(PackedUserOperation calldata userOp, bytes32 userOpHash) internal {
        if (address(validateHookExtension) != address(0)) validateHookExtension.afterValidate(userOp, userOpHash);
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal override {}

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/
    function entryPoint() public view override returns (IEntryPoint) {
        return _ENTRY_POINT;
    }
}
