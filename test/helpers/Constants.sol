// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

address constant MAINNET_SWAP_ROUTER_02 = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
address constant MAINNET_WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant MAINNET_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
uint256 constant DEFAULT_AMOUNT = 10_000 ether;
uint256 constant DEFAULT_FEE_BP = 100;
uint256 constant BASIS_POINTS = 10_000;

address constant MAINNET_ENTRY_POINT = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
address constant BUNDLER = address(uint160(uint256(keccak256(abi.encodePacked("bundler")))));

bytes4 constant EIP1271_MAGIC_VALUE = 0x1626ba7e;
bytes constant PASSKEY_OWNER =
    hex"1c05286fe694493eae33312f2d2e0d0abeda8db76238b7a204be1fb87f54ce4228fef61ef4ac300f631657635c28e59bfb2fe71bce1634c81c65642042f6dc4d";
uint256 constant PASSKEY_PRIVATE_KEY = uint256(0x03d99692017473e2d631945a812607b23269d85721e0f370b8d3e7d29a874fd2);
