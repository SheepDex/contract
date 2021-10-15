// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;
pragma abicoder v2;

import './interfaces/IPositionReward.sol';
import './PositionReward.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/EnumerableSet.sol';
import '@sheepdex/router/contracts/interfaces/INFTPositionManager.sol';
import '@sheepdex/core/contracts/interfaces/ISpePool.sol';
import '@uniswap/v3-core/contracts/interfaces/IERC20Minimal.sol';
import '@sheepdex/core/contracts/interfaces/ISpeFactory.sol';
import '@sheepdex/router/contracts/lib/PoolAddress.sol';
import '@sheepdex/router/contracts/lib/NFTPositionInfo.sol';
import './lib/PoolId.sol';

contract TestCall {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    PositionReward public immutable positionReward;
    INFTPositionManager public immutable nonfungiblePositionManager;
    ISpeFactory public immutable factory;

    constructor(
        ISpeFactory _factory,
        PositionReward _reward,
        INFTPositionManager _nonfungiblePositionManager
    ) public {
        factory = _factory;
        positionReward = _reward;
        nonfungiblePositionManager = _nonfungiblePositionManager;
    }

    struct Positions {
        // address operator;
        // address token0;
        // address token1;
        // uint24 fee;
        uint256 tokenId;
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        ISpePool pool;
        uint256 reward;
        uint128 totalLiquidty;
    }

    function getTokens(address account, IPositionReward.IncentiveKey memory key)
    public
    view
    returns (Positions[] memory returnData)
    {
        require(account != address(0), 'balance query for the zero address');
        uint256 len = positionReward.depositOf(account);
        returnData = new Positions[](len);
        for (uint256 index = 0; index < returnData.length; index++) {
            returnData[index] = getPool(account, key, index);
        }
    }

    function getPool(
        address account,
        IPositionReward.IncentiveKey memory key,
        uint256 index
    ) public view returns (Positions memory returnData) {
        uint256 tokenId = positionReward.tokenOfOwnerByIndex(account, index);

        (,
        ,
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        ,
        ,
        ,) = nonfungiblePositionManager.positions(tokenId);
        ISpePool pool = ISpePool(
            PoolAddress.computeAddress(
                address(factory),
                PoolAddress.PoolKey({token0 : token0, token1 : token1, fee : fee})
            )
        );
        bytes32 incentiveId = PoolId.compute(key);
        (, uint128 stakesLiquidity) = positionReward.stakes(tokenId, incentiveId);
        uint256 reward;
        if (stakesLiquidity > 0) {
            (reward,) = positionReward.getRewardInfo(key, tokenId);
        }

        uint128 totalLiquidty = pool.liquidity();
        return Positions(tokenId, token0, token1, fee, tickLower, tickUpper, liquidity, pool, reward, totalLiquidty);
    }
}
