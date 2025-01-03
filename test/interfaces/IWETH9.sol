// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

interface IWETH9 {
    /// @notice Deposit ether to get wrapped ether
    function deposit() external payable;
    /// @notice Withdraw wrapped ether to get ether
    function withdraw(uint256) external;

    function balanceOf(address account) external view returns (uint256);
}
