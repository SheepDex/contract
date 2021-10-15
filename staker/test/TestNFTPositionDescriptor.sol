pragma solidity =0.7.6;


import "@sheepdex/router/contracts/NFTPositionDescriptor.sol";

contract TestNFTPositionDescriptor is NFTPositionDescriptor {
    constructor(address _wbnb) NFTPositionDescriptor(_wbnb) {
    }
}