pragma solidity =0.7.6;
pragma abicoder v2;

import "@sheepdex/router/contracts/NFTPositionManager.sol";

contract TestNFTPositionManager is NFTPositionManager {
    constructor(
        address _factory,
        address _WETH9,
        address _tokenDescriptor_
    ) NFTPositionManager(_factory, _WETH9, _tokenDescriptor_){
    }
}