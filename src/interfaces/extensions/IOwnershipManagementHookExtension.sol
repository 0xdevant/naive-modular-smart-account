// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

interface IOwnershipManagementHookExtension {
    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnershipManagementHookExtension__UnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnershipManagementHookExtension__InvalidOwner(address owner);

    function transferOwnership(address newOwner) external;
    function owner(address msa) external view returns (address);
}
