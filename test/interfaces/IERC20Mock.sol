// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

interface IERC20Mock {
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);

    function approve(address spender, uint256 amount) external returns (bool);

    function mint(address account, uint256 amount) external;
    function burn(address account, uint256 amount) external;
}
