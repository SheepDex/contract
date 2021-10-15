pragma solidity =0.7.6;
pragma abicoder v2;

import '@sheepdex/router/contracts/lib/NFTPositionInfo.sol';
import '@sheepdex/core/contracts/interfaces/ISpePool.sol';

contract TestNFTPositionInfo {
    function getPositionInfo(
        ISpeFactory factory,
        INFTPositionManager nonfungiblePositionManager,
        uint256 tokenId
    ) external
    view
    returns (
        ISpePool pool,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ){
        return NFTPositionInfo.getPositionInfo(factory, nonfungiblePositionManager, tokenId);
    }
}