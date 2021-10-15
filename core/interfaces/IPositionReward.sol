pragma solidity =0.7.6;
pragma abicoder v2;

import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';

import '@uniswap/v3-core/contracts/interfaces/IERC20Minimal.sol';

import "@sheepdex/router/contracts/interfaces/IMulticall.sol";
import "@sheepdex/router/contracts/interfaces/INFTPositionManager.sol";
import '@sheepdex/core/contracts/interfaces/ISpePool.sol';
import '@sheepdex/core/contracts/interfaces/ISpeFactory.sol';


interface IPositionReward is IERC721Receiver, IMulticall {
    struct IncentiveKey {
        IERC20Minimal rewardToken;
        ISpePool pool;
        uint256 startTime;
    }

    event IncentiveCreated(
        IERC20Minimal indexed rewardToken,
        ISpePool indexed pool,
        uint256 startTime,
        uint256 reward
    );

    event IncentiveEnded(bytes32 indexed incentiveId, uint256 refund);
    event DepositTransferred(uint256 indexed tokenId, address indexed oldOwner, address indexed newOwner);

    event TokenStaked(uint256 indexed tokenId, bytes32 indexed incentiveId, uint128 liquidity);

    event TokenUnstaked(uint256 indexed tokenId, bytes32 indexed incentiveId);
    event RewardClaimed(address indexed to, uint256 reward);
}
