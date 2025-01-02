// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

interface IDCAExtension {
    error DCAExtension__ZeroInput();
    error DCAExtension__ExceedSlippageBP(uint256 actualDiffInBP);
    error DCAExtension__InvalidTotalPayAmount(uint256 totalPayAmount);
    error DCAExtension__InvalidTaskIndex();
    error DCAExtension__NotTimeToDCAYet();
    error DCAExtension__InsufficientFunds();
    error DCAExtension__IntervalTooLong();

    struct DCATask {
        address token;
        address paymentToken;
        uint128 payAmount;
        uint128 totalPayAmount;
        uint64 slippageBP;
        uint64 interval;
        uint64 lastExecution;
    }

    struct SwapParams {
        address feeReceiver;
        uint256 amountOutMin;
        uint160 sqrtPriceLimitX96;
        uint24 fee;
    }

    function subscribeDCA(
        address token,
        address paymentToken,
        uint128 payAmount,
        uint128 totalPayAmount,
        uint64 slippageBP,
        uint64 interval
    ) external returns (uint256);
    function unsubscribeDCA(uint256 index) external;
    function executeDCA(uint256 taskIdx, SwapParams calldata swapParams) external returns (uint256 amountOut);
}
