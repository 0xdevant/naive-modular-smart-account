// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract BaseSetup is Test {
    address[] public users;
    ERC20Mock public erc20Mock;

    function setUp() public virtual {
        setUpUsers();
        deployMockERC20();
    }

    function setUpUsers() public {
        string[] memory names = new string[](5);
        names[0] = "alice";
        names[1] = "bob";
        names[2] = "charlie";
        names[3] = "david";
        names[4] = "eve";

        for (uint256 i = 0; i < names.length; i++) {
            users.push(makeAddr(names[i]));
        }
    }

    function deployMockERC20() public {
        erc20Mock = new ERC20Mock();
    }
}
