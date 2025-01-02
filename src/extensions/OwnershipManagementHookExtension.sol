// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {BaseExtension} from "./BaseExtension.sol";
import {IExtension} from "../interfaces/extensions/IExtension.sol";
import {IExecuteHookExtension} from "../interfaces/extensions/hooks/IExecuteHookExtension.sol";
import {IOwnershipManagementHookExtension} from "../interfaces/extensions/IOwnershipManagementHookExtension.sol";

/**
 * OwnershipManagementHookExtension is an extension that allows MSA owners to transfer ownership of their MSA to another address.
 */
contract OwnershipManagementHookExtension is IOwnershipManagementHookExtension, IExecuteHookExtension, BaseExtension {
    mapping(address modularSmartAccount => address owner) public msaOwners;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @notice Transfer ownership of the MSA to a new address
    /// @param newOwner The address of the new owner
    function transferOwnership(address newOwner) external {
        require(newOwner != address(0), OwnershipManagementHookExtension__InvalidOwner(address(0)));

        address oldOwner = msaOwners[msg.sender];
        msaOwners[msg.sender] = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /// @notice Get the owner of the MSA
    /// @param msa The address of the MSA
    function owner(address msa) public view returns (address) {
        return msaOwners[msa];
    }

    /*//////////////////////////////////////////////////////////////
                               EXTENSIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IExecuteHookExtension
    function beforeExecute(address msaOwner, bytes calldata) external view override returns (bytes4) {
        require(owner(msg.sender) == msaOwner, OwnershipManagementHookExtension__UnauthorizedAccount(msg.sender));

        return (this.beforeExecute.selector);
    }

    /// @inheritdoc IExecuteHookExtension
    function afterExecute(address, bytes calldata) external pure override returns (bytes4) {
        return (this.afterExecute.selector);
    }

    /// @inheritdoc IExtension
    function installCallBack(bytes calldata data) external override {
        (address msa, address initialOwner) = abi.decode(data, (address, address));
        msaOwners[msa] = initialOwner;
    }

    /// @inheritdoc IExtension
    function uninstallCallBack(bytes calldata data) external override {
        (address msa) = abi.decode(data, (address));
        delete msaOwners[msa];
    }

    /// @inheritdoc IExtension
    function extensionId() external pure override(IExecuteHookExtension, IExtension) returns (bytes32) {
        return keccak256(abi.encodePacked("MCA", "Access", "OwnershipManagementHook", "0.0.1"));
    }

    /// @inheritdoc BaseExtension
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(BaseExtension, IERC165)
        returns (bool)
    {
        return interfaceId == type(IExecuteHookExtension).interfaceId || super.supportsInterface(interfaceId);
    }
}
