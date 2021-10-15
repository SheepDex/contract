pragma solidity >=0.5.0 <0.8.0;

import '@sheepdex/core/contracts/lib/SwapMath.sol';

import '@sheepdex/core/contracts/interfaces/ISpePool.sol';
import '../lib/PoolAddress.sol';

library OracleLibrary {
    function consult(address pool, uint32 period) internal view returns (int24 timeWeightedAverageTick) {
        require(period != 0, 'BP');

        uint32[] memory secondAgos = new uint32[](2);
        secondAgos[0] = period;
        secondAgos[1] = 0;

        (int56[] memory tickCumulatives, ) = ISpePool(pool).observe(secondAgos);
        int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];

        timeWeightedAverageTick = int24(tickCumulativesDelta / period);

        // Always round to negative infinity
        if (tickCumulativesDelta < 0 && (tickCumulativesDelta % period != 0)) timeWeightedAverageTick--;
    }

    function getQuoteAtTick(
        int24 tick,
        uint128 baseAmount,
        address baseToken,
        address quoteToken
    ) internal pure returns (uint256 quoteAmount) {
        uint160 sqrtRatioX96 = SwapMath.getSqrtRatioAtTick(tick);

        // Calculate quoteAmount with better precision if it doesn't overflow when multiplied by itself
        if (sqrtRatioX96 <= type(uint128).max) {
            uint256 ratioX192 = uint256(sqrtRatioX96) * sqrtRatioX96;
            quoteAmount = baseToken < quoteToken
                ? SwapMath.mulDiv(ratioX192, baseAmount, 1 << 192)
                : SwapMath.mulDiv(1 << 192, baseAmount, ratioX192);
        } else {
            uint256 ratioX128 = SwapMath.mulDiv(sqrtRatioX96, sqrtRatioX96, 1 << 64);
            quoteAmount = baseToken < quoteToken
                ? SwapMath.mulDiv(ratioX128, baseAmount, 1 << 128)
                : SwapMath.mulDiv(1 << 128, baseAmount, ratioX128);
        }
    }
}
