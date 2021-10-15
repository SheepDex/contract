pragma solidity =0.7.6;

import '../interfaces/INFTPositionManager.sol';
import './PoolAddress.sol';
import '@sheepdex/core/contracts/interfaces/ISpePool.sol';
import '@sheepdex/core/contracts/interfaces/ISpeFactory.sol';

library NFTPositionInfo {
    function getPositionInfo(
        ISpeFactory factory,
        INFTPositionManager nonfungiblePositionManager,
        uint256 tokenId
    )
        internal
        view
        returns (
            ISpePool pool,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity
        )
    {
        address token0;
        address token1;
        uint24 fee;
        (, , token0, token1, fee, tickLower, tickUpper, liquidity, , , , ) = nonfungiblePositionManager.positions(
            tokenId
        );

        pool = ISpePool(
            PoolAddress.computeAddress(
                address(factory),
                PoolAddress.PoolKey({token0: token0, token1: token1, fee: fee})
            )
        );
    }
}
