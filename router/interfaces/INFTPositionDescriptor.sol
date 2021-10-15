pragma solidity >=0.5.0;

import './INFTPositionManager.sol';

interface INFTPositionDescriptor {
    function tokenURI(INFTPositionManager positionManager, uint256 tokenId) external view returns (string memory);
}
