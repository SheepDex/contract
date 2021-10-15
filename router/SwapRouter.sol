pragma solidity =0.7.6;
pragma abicoder v2;

import '@sheepdex/core/contracts/lib/SafeCast.sol';
import '@sheepdex/core/contracts/lib/SwapMath.sol';
import '@sheepdex/core/contracts/lib/TransferHelper.sol';
import '@sheepdex/core/contracts/lib/CheckOper.sol';

import './interfaces/ISwapRouter.sol';
import './interfaces/ISwapMining.sol';
import './lib/PeripheryImmutableState.sol';
import './lib/PeripheryValidation.sol';
import './lib/PeripheryPaymentsWithFee.sol';
import './lib/Multicall.sol';
import './lib/SelfPermit.sol';
import './lib/Path.sol';
import './lib/PoolAddress.sol';
import './lib/CallbackValidation.sol';
import './interfaces/IWBNB.sol';

contract SwapRouter is
ISwapRouter,
PeripheryImmutableState,
PeripheryValidation,
PeripheryPaymentsWithFee,
Multicall,
SelfPermit,
CheckOper
{
    using Path for bytes;
    using SafeCast for uint256;


    event ChangeSwapMining(address indexed oldSwapMining, address indexed newSwapMining);

    uint256 private constant DEFAULT_AMOUNT_IN_CACHED = type(uint256).max;

    uint256 private amountInCached = DEFAULT_AMOUNT_IN_CACHED;

    address public swapMining;

    constructor(
        address _operCon,
        address _factory,
        address _WBNB
    ) PeripheryImmutableState(_factory, _WBNB) CheckOper(_operCon) {}

    // address(0) means no swap mining
    function setSwapMining(address addr) public onlyOperator {
        address oldSwapMining = swapMining;
        swapMining = addr;
        emit ChangeSwapMining(oldSwapMining, swapMining);
    }

    function salvageToken(address _asset) onlyOperator external returns (uint256 balance) {
        balance = IERC20(_asset).balanceOf(address(this));
        TransferHelper.safeTransfer(_asset, operator(), balance);
    }

    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) public override view returns (ISpePool) {
        return ISpePool(PoolAddress.computeAddress(factory, PoolAddress.getPoolKey(tokenA, tokenB, fee)));
    }

    struct SwapCallbackData {
        bytes path;
        address payer;
    }

    function swapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata _data
    ) external override {
        require(amount0Delta > 0 || amount1Delta > 0);
        // swaps entirely within 0-liquidity regions are not supported
        SwapCallbackData memory data = abi.decode(_data, (SwapCallbackData));
        (address tokenIn, address tokenOut, uint24 fee) = data.path.decodeFirstPool();
        CallbackValidation.verifyCallback(factory, tokenIn, tokenOut, fee);

        (bool isExactInput, uint256 amountToPay) =
        amount0Delta > 0
        ? (tokenIn < tokenOut, uint256(amount0Delta))
        : (tokenOut < tokenIn, uint256(amount1Delta));
        if (isExactInput) {
            pay(tokenIn, data.payer, msg.sender, amountToPay);
        } else {
            // either initiate the next swap or pay
            if (data.path.hasMultiplePools()) {
                data.path = data.path.skipToken();
                exactOutputInternal(amountToPay, msg.sender, 0, data);
            } else {
                amountInCached = amountToPay;
                tokenIn = tokenOut;
                // swap in/out because exact output swaps are reversed
                pay(tokenIn, data.payer, msg.sender, amountToPay);
            }
        }
    }

    function exactInputInternal(
        uint256 amountIn,
        address recipient,
        uint160 sqrtPriceLimitX96,
        SwapCallbackData memory data
    ) private returns (uint256 amountOut) {
        // allow swapping to the router address with address 0
        if (recipient == address(0)) recipient = address(this);

        (address tokenIn, address tokenOut, uint24 fee) = data.path.decodeFirstPool();

        bool zeroForOne = tokenIn < tokenOut;
        (int256 amount0, int256 amount1) =
        getPool(tokenIn, tokenOut, fee).swap(
            recipient,
            zeroForOne,
            amountIn.toInt256(),
            sqrtPriceLimitX96 == 0
            ? (zeroForOne ? SwapMath.MIN_SQRT_RATIO + 1 : SwapMath.MAX_SQRT_RATIO - 1)
            : sqrtPriceLimitX96,
            abi.encode(data)
        );
        amountOut = uint256(- (zeroForOne ? amount1 : amount0));
        callSwapMining(msg.sender,
            address(getPool(tokenIn, tokenOut, fee)),
            tokenIn,
            tokenOut,
            amountIn,
            amountOut);
        return amountOut;
    }

    function callSwapMining(address account,
        address pair,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut) private {
        if (swapMining != address(0)) {
            ISwapMining(swapMining).swap(
                account,
                pair,
                tokenIn,
                tokenOut,
                amountIn,
                amountOut
            );
        }
    }

    function exactInputSingle(ExactInputSingleParams calldata params)
    external
    payable
    override
    checkDeadline(params.deadline)
    returns (uint256 amountOut)
    {
        amountOut = exactInputInternal(
            params.amountIn,
            params.recipient,
            params.sqrtPriceLimitX96,
            SwapCallbackData({path : abi.encodePacked(params.tokenIn, params.fee, params.tokenOut), payer : msg.sender})
        );
        require(amountOut >= params.amountOutMinimum, 'Too little received');
    }

    function exactInput(ExactInputParams memory params)
    external
    payable
    override
    checkDeadline(params.deadline)
    returns (uint256 amountOut)
    {
        address payer = msg.sender;
        // msg.sender pays for the first hop

        while (true) {
            bool hasMultiplePools = params.path.hasMultiplePools();

            // the outputs of prior swaps become the inputs to subsequent ones
            params.amountIn = exactInputInternal(
                params.amountIn,
                hasMultiplePools ? address(this) : params.recipient, // for intermediate swaps, this contract custodies
                0,
                SwapCallbackData({
            path : params.path.getFirstPool(), // only the first pool in the path is necessary
            payer : payer
            })
            );

            // decide whether to continue or terminate
            if (hasMultiplePools) {
                payer = address(this);
                // at this point, the caller has paid
                params.path = params.path.skipToken();
            } else {
                amountOut = params.amountIn;
                break;
            }
        }

        require(amountOut >= params.amountOutMinimum, 'Too little received');
    }

    function exactOutputInternal(
        uint256 amountOut,
        address recipient,
        uint160 sqrtPriceLimitX96,
        SwapCallbackData memory data
    ) private returns (uint256 amountIn) {
        if (recipient == address(0)) recipient = address(this);

        (address tokenOut, address tokenIn, uint24 fee) = data.path.decodeFirstPool();

        bool zeroForOne = tokenIn < tokenOut;

        (int256 amount0Delta, int256 amount1Delta) =
        getPool(tokenIn, tokenOut, fee).swap(
            recipient,
            zeroForOne,
            - amountOut.toInt256(),
            sqrtPriceLimitX96 == 0
            ? (zeroForOne ? SwapMath.MIN_SQRT_RATIO + 1 : SwapMath.MAX_SQRT_RATIO - 1)
            : sqrtPriceLimitX96,
            abi.encode(data)
        );

        uint256 amountOutReceived;
        (amountIn, amountOutReceived) = zeroForOne
        ? (uint256(amount0Delta), uint256(- amount1Delta))
        : (uint256(amount1Delta), uint256(- amount0Delta));
        callSwapMining(msg.sender, address(getPool(tokenIn, tokenOut, fee)),
            tokenIn,
            tokenOut,
            amountIn,
            amountOutReceived);

        if (sqrtPriceLimitX96 == 0) require(amountOutReceived == amountOut);
    }

    function exactOutputSingle(ExactOutputSingleParams calldata params)
    external
    payable
    override
    checkDeadline(params.deadline)
    returns (uint256 amountIn)
    {
        // avoid an SLOAD by using the swap return data
        amountIn = exactOutputInternal(
            params.amountOut,
            params.recipient,
            params.sqrtPriceLimitX96,
            SwapCallbackData({path : abi.encodePacked(params.tokenOut, params.fee, params.tokenIn), payer : msg.sender})
        );

        require(amountIn <= params.amountInMaximum, 'Too much requested');
        // has to be reset even though we don't use it in the single hop case
        amountInCached = DEFAULT_AMOUNT_IN_CACHED;
    }

    function exactOutput(ExactOutputParams calldata params)
    external
    payable
    override
    checkDeadline(params.deadline)
    returns (uint256 amountIn)
    {
        // it's okay that the payer is fixed to msg.sender here, as they're only paying for the "final" exact output
        // swap, which happens first, and subsequent swaps are paid for within nested callback frames
        exactOutputInternal(
            params.amountOut,
            params.recipient,
            0,
            SwapCallbackData({path : params.path, payer : msg.sender})
        );

        amountIn = amountInCached;
        require(amountIn <= params.amountInMaximum, 'Too much requested');
        amountInCached = DEFAULT_AMOUNT_IN_CACHED;
    }
}
