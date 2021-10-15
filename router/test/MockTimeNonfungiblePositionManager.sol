//
pragma solidity =0.7.6;
pragma abicoder v2;

import '../NFTPositionManager.sol';

contract MockTimeNonfungiblePositionManager is NFTPositionManager {
    uint256 time;

    constructor(
        address _factory,
        address _WBNB,
        address _tokenDescriptor
    ) NFTPositionManager(_factory, _WBNB, _tokenDescriptor) {}

    function _blockTimestamp() internal view override returns (uint256) {
        return time;
    }

    function setTime(uint256 _time) external {
        time = _time;
    }
}
