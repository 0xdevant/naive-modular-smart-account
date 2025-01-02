// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IExtension} from "../../extensions/IExtension.sol";

interface IExecuteHookExtension is IExtension {
    function beforeExecute(address sender, bytes calldata data) external returns (bytes4);
    function afterExecute(address sender, bytes calldata data) external returns (bytes4);

    function extensionId() external view returns (bytes32);
}
