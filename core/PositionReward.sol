pragma solidity =0.7.6;
pragma abicoder v2;

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/EnumerableSet.sol';
import '@sheepdex/router/contracts/lib/NFTPositionInfo.sol';

import "@sheepdex/router/contracts/TokenReward.sol";
import "@sheepdex/router/contracts/lib/Multicall.sol";

import './interfaces/IPositionReward.sol';
import './lib/PoolId.sol';
import './lib/RewardMath.sol';


contract PositionReward is IPositionReward, Multicall, TokenReward {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;


    struct Pool {
        uint256 totalRewardUnclaimed;
        uint160 totalSecondsClaimedX128;
        uint96 numberOfStakes;
        uint256 allocPoint;
        uint256 lastRewardBlock;
    }

    struct Deposit {
        address owner;
        uint48 numberOfStakes;
        int24 tickLower;
        int24 tickUpper;
    }

    struct Stake {
        uint160 secondsPerLiquidityInsideInitialX128;
        uint96 liquidityNoOverflow;
        uint128 liquidityIfOverflow;
    }

    uint128 public constant MAX_128 = 2 ** 128 - 1;

    ISpeFactory public immutable  factory;
    INFTPositionManager public immutable  nonfungiblePositionManager;
    mapping(address => EnumerableSet.UintSet) private _holderTokens;
    mapping(bytes32 => Pool) public incentives;
    mapping(uint256 => Deposit) public deposits;
    mapping(uint256 => mapping(bytes32 => Stake)) private _stakes;
    mapping(address => uint256) public  rewards;
    uint256 public totalAllocPoint = 0;
    IncentiveKey[] public incentiveKeys;

    constructor(
        ISpeFactory _factory,
        INFTPositionManager _nonfungiblePositionManager,
        address _operatorMsg,
        ISwap _swapToken,
        uint256 _ftpPerBlock,
        uint256 _startBlock,
        uint256 _period
    ) TokenReward(_operatorMsg, _swapToken, _ftpPerBlock, _startBlock, _period){
        require(address(_factory) != address(0), "!0");
        factory = _factory;
        nonfungiblePositionManager = _nonfungiblePositionManager;
    }

    function tokenOfOwnerByIndex(address owner, uint256 index) public view returns (uint256) {
        return _holderTokens[owner].at(index);
    }

    function depositOf(address owner) public view returns (uint256) {
        require(owner != address(0), "balance query for the zero address");
        return _holderTokens[owner].length();
    }

    function stakes(uint256 tokenId, bytes32 incentiveId) public view
    returns (uint160 secondsPerLiquidityInsideInitialX128, uint128 liquidity)
    {
        Stake storage stake = _stakes[tokenId][incentiveId];
        secondsPerLiquidityInsideInitialX128 = stake.secondsPerLiquidityInsideInitialX128;
        liquidity = stake.liquidityNoOverflow;
        if (liquidity == type(uint96).max) {
            liquidity = stake.liquidityIfOverflow;
        }
    }

    function createIncentive(IncentiveKey memory key, uint256 point) external onlyOperator {
        require(
            block.timestamp <= key.startTime,
            'PositionReward::createIncentive: start time must be now or in the future'
        );
        bytes32 incentiveId = PoolId.compute(key);
        totalAllocPoint = totalAllocPoint.add(point);
        incentives[incentiveId].allocPoint = point;
        incentives[incentiveId].lastRewardBlock = block.number;
        incentiveKeys.push(key);
        emit IncentiveCreated(key.rewardToken, key.pool, key.startTime, point);
    }

    function set(
        IncentiveKey memory key,
        uint256 point,
        bool updateAll
    ) public onlyOperator {
        if (updateAll) {
            massUpdatePools();
        }
        bytes32 incentiveId = PoolId.compute(key);
        totalAllocPoint = totalAllocPoint.sub(incentives[incentiveId].allocPoint).add(point);
        incentives[incentiveId].allocPoint = point;
    }

    function onERC721Received(
        address,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        require(
            msg.sender == address(nonfungiblePositionManager),
            'PositionReward::onERC721Received: not a univ3 nft'
        );

        (,,,,, int24 tickLower, int24 tickUpper,,,,,) = nonfungiblePositionManager.positions(tokenId);

        deposits[tokenId] = Deposit({owner : from, numberOfStakes : 0, tickLower : tickLower, tickUpper : tickUpper});
        emit DepositTransferred(tokenId, address(0), from);

        if (data.length > 0) {
            if (data.length == 160) {
                _stakeToken(abi.decode(data, (IncentiveKey)), tokenId);
            } else {
                IncentiveKey[] memory keys = abi.decode(data, (IncentiveKey[]));
                for (uint256 i = 0; i < keys.length; i++) {
                    _stakeToken(keys[i], tokenId);
                }
            }
        }
        return this.onERC721Received.selector;
    }

    function transferDeposit(uint256 tokenId, address to) external {
        require(to != address(0), 'PositionReward::transferDeposit: invalid transfer recipient');
        address owner = deposits[tokenId].owner;
        require(owner == msg.sender, 'PositionReward::transferDeposit: can only be called by deposit owner');
        _holderTokens[owner].remove(tokenId);
        _holderTokens[to].add(tokenId);
        deposits[tokenId].owner = to;
        emit DepositTransferred(tokenId, owner, to);
    }

    function withdrawToken(
        uint256 tokenId,
        bytes memory data
    ) external {
        require(msg.sender != address(this), 'PositionReward::withdrawToken: cannot withdraw to staker');
        Deposit memory deposit = deposits[tokenId];
        require(deposit.numberOfStakes == 0, 'PositionReward::withdrawToken: cannot withdraw token while staked');
        require(deposit.owner == msg.sender, 'PositionReward::withdrawToken: only owner can withdraw token');

        delete deposits[tokenId];
        emit DepositTransferred(tokenId, deposit.owner, address(0));

        nonfungiblePositionManager.safeTransferFrom(address(this), msg.sender, tokenId, data);
    }

    function stakeToken(IncentiveKey memory key, uint256 tokenId) external {
        require(deposits[tokenId].owner == msg.sender, 'PositionReward::stakeToken: only owner can stake token');

        _stakeToken(key, tokenId);
    }

    function unstakeToken(IncentiveKey memory key, uint256 tokenId) external {
        Deposit memory deposit = deposits[tokenId];
        require(
            deposit.owner == msg.sender,
            'PositionReward::unstakeToken: only owner can withdraw token'
        );
        bytes32 incentiveId = PoolId.compute(key);
        updatePool(incentiveId);
        (uint160 secondsPerLiquidityInsideInitialX128, uint128 liquidity) = stakes(tokenId, incentiveId);

        require(liquidity != 0, 'PositionReward::unstakeToken: stake does not exist');

        Pool storage incentive = incentives[incentiveId];

        deposits[tokenId].numberOfStakes--;
        incentive.numberOfStakes--;
        _holderTokens[deposit.owner].remove(tokenId);

        (, uint160 secondsPerLiquidityInsideX128,) =
        key.pool.snapshotCumulativesInside(deposit.tickLower, deposit.tickUpper);
        (uint256 reward, uint160 secondsInsideX128) =
        RewardMath.computeRewardAmount(
            incentive.totalRewardUnclaimed,
            incentive.totalSecondsClaimedX128,
            key.startTime,
            liquidity,
            secondsPerLiquidityInsideInitialX128,
            secondsPerLiquidityInsideX128,
            block.timestamp
        );
        incentive.totalSecondsClaimedX128 += secondsInsideX128;
        incentive.totalRewardUnclaimed = incentive.totalRewardUnclaimed.sub(reward);
        rewards[deposit.owner] = rewards[deposit.owner].add(reward);

        Stake storage stake = _stakes[tokenId][incentiveId];
        delete stake.secondsPerLiquidityInsideInitialX128;
        delete stake.liquidityNoOverflow;
        if (liquidity >= type(uint96).max) delete stake.liquidityIfOverflow;
        emit TokenUnstaked(tokenId, incentiveId);
    }

    function claimReward(
        uint256 amountRequested
    ) external returns (uint256 reward) {
        reward = rewards[msg.sender];
        if (amountRequested != 0 && amountRequested < reward) {
            reward = amountRequested;
        }

        rewards[msg.sender] = rewards[msg.sender].sub(reward);
        _safeTokenTransfer(msg.sender, reward);

        emit RewardClaimed(msg.sender, reward);
    }

    function getRewardInfo(IncentiveKey memory key, uint256 tokenId)
    external
    view
    returns (uint256 reward, uint160 secondsInsideX128)
    {
        bytes32 incentiveId = PoolId.compute(key);

        (uint160 secondsPerLiquidityInsideInitialX128, uint128 liquidity) = stakes(tokenId, incentiveId);
        require(liquidity > 0, 'PositionReward::getRewardInfo: stake does not exist');

        Deposit memory deposit = deposits[tokenId];
        Pool memory incentive = incentives[incentiveId];

        (, uint160 secondsPerLiquidityInsideX128,) =
        key.pool.snapshotCumulativesInside(deposit.tickLower, deposit.tickUpper);

        (reward, secondsInsideX128) = RewardMath.computeRewardAmount(
            incentive.totalRewardUnclaimed,
            incentive.totalSecondsClaimedX128,
            key.startTime,
            liquidity,
            secondsPerLiquidityInsideInitialX128,
            secondsPerLiquidityInsideX128,
            block.timestamp
        );
    }

    function _stakeToken(IncentiveKey memory key, uint256 tokenId) private {
        require(block.timestamp >= key.startTime, 'PositionReward::stakeToken: incentive not started');

        bytes32 incentiveId = PoolId.compute(key);
        updatePool(incentiveId);

        require(
            incentives[incentiveId].totalRewardUnclaimed > 0,
            'PositionReward::stakeToken: non-existent incentive'
        );
        require(
            _stakes[tokenId][incentiveId].liquidityNoOverflow == 0,
            'PositionReward::stakeToken: token already staked'
        );

        (ISpePool pool, int24 tickLower, int24 tickUpper, uint128 liquidity) =
        NFTPositionInfo.getPositionInfo(factory, nonfungiblePositionManager, tokenId);

        require(pool == key.pool, 'PositionReward::stakeToken: token pool is not the incentive pool');
        require(liquidity > 0, 'PositionReward::stakeToken: cannot stake token with 0 liquidity');

        _holderTokens[deposits[tokenId].owner].add(tokenId);
        deposits[tokenId].numberOfStakes++;
        incentives[incentiveId].numberOfStakes++;

        (, uint160 secondsPerLiquidityInsideX128,) = pool.snapshotCumulativesInside(tickLower, tickUpper);

        if (liquidity >= type(uint96).max) {
            _stakes[tokenId][incentiveId] = Stake({
            secondsPerLiquidityInsideInitialX128 : secondsPerLiquidityInsideX128,
            liquidityNoOverflow : type(uint96).max,
            liquidityIfOverflow : liquidity
            });
        } else {
            Stake storage stake = _stakes[tokenId][incentiveId];
            stake.secondsPerLiquidityInsideInitialX128 = secondsPerLiquidityInsideX128;
            stake.liquidityNoOverflow = uint96(liquidity);
        }

        emit TokenStaked(tokenId, incentiveId, liquidity);
    }

    function collect(uint256 tokenId) external {
        require(deposits[tokenId].owner == msg.sender, 'PositionReward::stakeToken: only owner can collect token');
        nonfungiblePositionManager.collect(INFTPositionManager.CollectParams({
        tokenId : tokenId,
        recipient : msg.sender,
        amount0Max : MAX_128,
        amount1Max : MAX_128
        })
        );
    }


    // Update reward variables of the given pool to be up-to-date.
    function updatePool(bytes32 incentiveId) public reduceBlockReward {
        Pool storage pool = incentives[incentiveId];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        if (tokenPerBlock <= 0) {
            return;
        }
        uint256 mul = block.number.sub(pool.lastRewardBlock);
        uint256 tokenReward = tokenPerBlock.mul(mul).mul(pool.allocPoint).div(totalAllocPoint);
        pool.totalRewardUnclaimed = pool.totalRewardUnclaimed.add(tokenReward);
        pool.lastRewardBlock = block.number;
    }

    function massUpdatePools() public override {
        uint256 length = incentiveKeys.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(PoolId.compute(incentiveKeys[pid]));
        }
    }
}
