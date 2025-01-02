// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {BaseExtension} from "./BaseExtension.sol";
import {IExtension} from "../interfaces/extensions/IExtension.sol";
import {IDCAExtension} from "../interfaces/extensions/IDCAExtension.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface ISwapRouter02 {
    // there is no deadline in the swap params for SwapRouter02
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams memory params) external returns (uint256 amountOut);
}

interface IWETH9 {
    /// @notice Deposit ether to get wrapped ether
    function deposit() external payable;
    /// @notice Withdraw wrapped ether to get ether
    function withdraw(uint256) external;
}

/**
 * DCAExtension is an extension that allows MSA users to subscribe to a Dollar Cost Averaging plan on any ERC20s
 * by specifying information like which token to purchase, what paymentToken to purchase with, amount of token to purchase and the interval.
 * Other parties will then execute the DCA plan on behalf of the user in exchange for a fee.
 */
contract DCAExtension is IExtension, IDCAExtension, BaseExtension {
    uint256 private constant _YEARLY_INTERVAL = 365 days;
    uint256 private constant _BASIS_POINTS = 10_000;
    uint256 private constant _BP_PRECISION = 1e18;
    uint24 private constant _DEFAULT_POOL_FEE = 3000;

    mapping(address modularSmartAccount => DCATask[]) public msaDCATasks;

    uint24 public executeFeeBP;
    ISwapRouter02 private _swapRouter;

    function subscribeDCA(
        address token,
        address paymentToken,
        uint128 payAmount,
        uint128 totalPayAmount,
        uint64 slippageBP,
        uint64 interval
    ) external returns (uint256 taskIdx) {
        require(
            token != address(0) && paymentToken != address(0) && payAmount != 0 && totalPayAmount != 0 && interval != 0,
            DCAExtension__ZeroInput()
        );
        require(interval <= _YEARLY_INTERVAL, DCAExtension__IntervalTooLong());
        // make sure the totalPayAmount is a multiple of payAmount
        require(totalPayAmount % payAmount == 0, DCAExtension__InvalidTotalPayAmount(totalPayAmount));
        uint256 totalFeeNeeded = totalPayAmount * executeFeeBP / _BASIS_POINTS;

        IERC20(paymentToken).transferFrom(msg.sender, address(this), totalPayAmount + totalFeeNeeded);
        msaDCATasks[msg.sender].push(
            DCATask({
                token: token,
                paymentToken: paymentToken,
                payAmount: payAmount,
                totalPayAmount: totalPayAmount,
                slippageBP: slippageBP,
                interval: interval,
                lastExecution: 0
            })
        );

        taskIdx = msaDCATasks[msg.sender].length - 1;
    }

    function unsubscribeDCA(uint256 taskIdx) external {
        require(taskIdx < msaDCATasks[msg.sender].length, DCAExtension__InvalidTaskIndex());
        DCATask memory task = msaDCATasks[msg.sender][taskIdx];
        uint256 totalFeeNeeded = task.totalPayAmount * executeFeeBP / _BASIS_POINTS;
        // refund the user with totalPayAmount and fee
        IERC20(task.paymentToken).transfer(msg.sender, task.totalPayAmount + totalFeeNeeded);
        delete msaDCATasks[msg.sender][taskIdx];
    }

    function executeDCA(uint256 taskIdx, SwapParams calldata swapParams) external returns (uint256 amountOut) {
        DCATask memory task = msaDCATasks[msg.sender][taskIdx];
        // no timestamp checking needed for the first time of DCA
        if (task.lastExecution != 0) {
            require(block.timestamp >= task.lastExecution + task.interval, DCAExtension__NotTimeToDCAYet());
        }
        uint256 fee = task.payAmount * executeFeeBP / _BASIS_POINTS;
        require(
            IERC20(task.paymentToken).balanceOf(address(this)) >= task.payAmount + fee,
            DCAExtension__InsufficientFunds()
        );

        msaDCATasks[msg.sender][taskIdx].lastExecution = uint64(block.timestamp);

        amountOut = _payFeeAndSwap(msg.sender, task, swapParams, fee);
        _checkSlippage(task.slippageBP, swapParams, amountOut);
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/
    function _payFeeAndSwap(address msa, DCATask memory task, SwapParams calldata swapParams, uint256 fee)
        internal
        returns (uint256 amountOut)
    {
        IERC20 paymentToken = IERC20(task.paymentToken);
        paymentToken.transfer(swapParams.feeReceiver, fee);

        paymentToken.approve(address(_swapRouter), task.payAmount);
        amountOut = _swapRouter.exactInputSingle(
            ISwapRouter02.ExactInputSingleParams({
                tokenIn: task.paymentToken,
                tokenOut: task.token,
                fee: swapParams.fee == 0 ? _DEFAULT_POOL_FEE : swapParams.fee,
                recipient: msa,
                amountIn: task.payAmount,
                amountOutMinimum: swapParams.amountOutMin,
                sqrtPriceLimitX96: swapParams.sqrtPriceLimitX96
            })
        );
    }

    /// @dev Ideally the amountOutMin should be calculated by quoting from Quoter contract off-chain or from a price oracle on-chain to make this check effective
    function _checkSlippage(uint64 slippageBP, SwapParams calldata swapParams, uint256 amountOut) private pure {
        if (swapParams.amountOutMin == 0) return;
        uint256 diffOnActualAndExpectedOutWithPrecision =
            (amountOut - swapParams.amountOutMin) * _BP_PRECISION / swapParams.amountOutMin;
        require(
            diffOnActualAndExpectedOutWithPrecision < (slippageBP * _BP_PRECISION),
            DCAExtension__ExceedSlippageBP(diffOnActualAndExpectedOutWithPrecision)
        );
    }

    /*//////////////////////////////////////////////////////////////
                               EXTENSIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IExtension
    function installCallBack(bytes calldata data) external override {
        // verify if msaInstalled[msg.sender] is false
        (uint24 feeBP, address swapRouter) = abi.decode(data, (uint24, address));

        executeFeeBP = feeBP;
        _swapRouter = ISwapRouter02(swapRouter);
    }

    /// @inheritdoc IExtension
    function uninstallCallBack(bytes calldata data) external override {
        (address msa) = abi.decode(data, (address));
        delete msaDCATasks[msa];
    }

    /// @inheritdoc IExtension
    function extensionId() external pure returns (bytes32) {
        return keccak256(abi.encodePacked("MCA", "Finance", "DCA", "0.0.1"));
    }
}
