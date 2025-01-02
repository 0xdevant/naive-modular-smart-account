// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {PackedUserOperation} from "@eth-infinitism/account-abstraction/interfaces/PackedUserOperation.sol";

import {IExtension} from "../../extensions/IExtension.sol";

interface IValidateHookExtension is IExtension {
    function beforeValidate(address sender, PackedUserOperation calldata userOp, bytes32 userOpHash)
        external
        returns (bytes4);
    function afterValidate(PackedUserOperation calldata userOp, bytes32 userOpHash) external returns (bytes4);

    function extensionId() external view returns (bytes32);
}
