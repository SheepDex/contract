pragma solidity =0.7.6;

import '@uniswap/v3-core/contracts/libraries/FullMath.sol';
import '@openzeppelin/contracts/math/Math.sol';


library RewardMath {
    function computeRewardAmount(
        uint256 totalRewardUnclaimed,
        uint160 totalSecondsClaimedX128,
        uint256 startTime,
        uint128 liquidity,
        uint160 secondsPerLiquidityInsideInitialX128,
        uint160 secondsPerLiquidityInsideX128,
        uint256 currentTime
    ) internal pure returns (uint256 reward, uint160 secondsInsideX128) {
        require(currentTime >= startTime, "no start");
        secondsInsideX128 = (secondsPerLiquidityInsideX128 - secondsPerLiquidityInsideInitialX128) * liquidity;
        uint256 totalSecondsUnclaimedX128 =
        ((currentTime - startTime) << 128) - totalSecondsClaimedX128;
        reward = FullMath.mulDiv(totalRewardUnclaimed, secondsInsideX128, totalSecondsUnclaimedX128);
    }
}
