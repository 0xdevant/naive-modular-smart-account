// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface IExtension is IERC165 {
    function installCallBack(bytes calldata data) external;
    function uninstallCallBack(bytes calldata data) external;

    function extensionId() external view returns (bytes32);
}
