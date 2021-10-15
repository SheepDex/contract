// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/EnumerableSet.sol';

import '@sheepdex/core/contracts/lib/SwapMath.sol';
import '@sheepdex/core/contracts/interfaces/ISpePool.sol';

import './interfaces/ISwap.sol';
import "./interfaces/ISwapMining.sol";

import './lib/OracleLibrary.sol';
import './TokenReward.sol';


contract SwapMining is TokenReward, ISwapMining {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    event SwapMining(
        address indexed account,
        address indexed pair,
        address input,
        address output,
        uint256 amountIn,
        uint256 amountOut
    );

    event ChangeRouter(address indexed oldRouter, address indexed newRouter);

    struct UserInfo {
        uint256 quantity; // How many LP tokens the user has provided
        uint256 blockNumber; // Last transaction block
    }

    struct PoolInfo {
        address pair; // Trading pairs that can be mined
        uint256 quantity; // Current amount of LPs
        uint256 totalQuantity; // All quantity
        uint256 allocPoint; // How many allocation points assigned to this pool
        uint256 allocSwapTokenAmount; // How many token
        uint256 lastRewardBlock; // Last transaction block
    }

    // Total allocation points
    uint256 public totalAllocPoint = 0;
    // router address
    address public router;
    // factory address
    address public factory;

    address public targetToken;
    // pair corresponding pid
    mapping(address => uint256) public pairOfPid;

    PoolInfo[] public poolInfo;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    constructor(
        address _operatorMsg,
        ISwap _swapToken,
        address _factory,
        address _router,
        uint256 _swapPerBlock,
        uint256 _startBlock,
        uint256 _period
    ) TokenReward(_operatorMsg, _swapToken, _swapPerBlock, _startBlock, _period) {
        require(_factory != address(0), "!0");
        require(_router != address(0), "!0");
        factory = _factory;
        router = _router;
        emit ChangeRouter(address(0), router);
    }

    modifier onlyRouter() {
        require(msg.sender == router, 'SwapMining: caller is not the router');
        _;
    }

    // Get rewards from users in the current pool
    function pending(uint256 _pid, address _user) public view returns (uint256, uint256) {
        require(_pid < poolInfo.length, 'SwapMining: Not find this pool');
        uint256 userSub;
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo memory user = userInfo[_pid][_user];
        if (user.quantity > 0) {
            uint256 mul = block.number.sub(pool.lastRewardBlock);
            uint256 tokenReward = tokenPerBlock.mul(mul).mul(pool.allocPoint).div(totalAllocPoint);
            userSub = userSub.add((pool.allocSwapTokenAmount.add(tokenReward)).mul(user.quantity).div(pool.quantity));
        }
        //swap available to users, User transaction amount
        return (userSub, user.quantity);
    }

    // Get details of the pool
    function getPoolInfo(uint256 _pid)
    public
    view
    returns (
        address,
        address,
        uint256,
        uint256,
        uint256,
        uint256
    )
    {
        require(_pid <= poolInfo.length - 1, 'SwapMining: Not find this pool');
        PoolInfo memory pool = poolInfo[_pid];
        address token0 = ISpePool(pool.pair).token0();
        address token1 = ISpePool(pool.pair).token1();
        uint256 tokenAmount = pool.allocSwapTokenAmount;
        uint256 mul = block.number.sub(pool.lastRewardBlock);
        uint256 tokenReward = tokenPerBlock.mul(mul).mul(pool.allocPoint).div(totalAllocPoint);
        tokenAmount = tokenAmount.add(tokenReward);
        //token0,token1,Pool remaining reward,Total /Current transaction volume of the pool
        return (token0, token1, tokenAmount, pool.totalQuantity, pool.quantity, pool.allocPoint);
    }

    function getQuantity(
        address pair,
        address input,
        address /** output **/,
        uint256 amountIn,
        uint256 amountOut) public view returns (uint256) {
        address token0 = ISpePool(pair).token0();
        if (input == token0) {
            return amountIn;
        }
        return amountOut;
    }

    function poolLength() public view returns (uint256) {
        return poolInfo.length;
    }

    function addPair(
        uint256 _allocPoint,
        address _pool,
        bool _withUpdate
    ) public onlyOperator {
        require(_pool != address(0), '_pair is the zero address');
        if (poolLength() > 0) {
            require((pairOfPid[_pool] == 0)&&(address(poolInfo[0].pair) != _pool), "only one pair");

        }
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
        pair : _pool,
        quantity : 0,
        totalQuantity : 0,
        allocPoint : _allocPoint,
        allocSwapTokenAmount : 0,
        lastRewardBlock : lastRewardBlock
        })
        );
        pairOfPid[_pool] = poolLength() - 1;
        emit AddPool(_pool, _allocPoint);
    }

    // Update the allocPoint of the pool
    function setPair(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOperator {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
        emit SetPool(poolInfo[_pid].pair, _allocPoint);
    }

    function setRouter(address newRouter) public onlyOperator {
        require(newRouter != address(0), 'SwapMining: new router is the zero address');
        address oldRouter = router;
        router = newRouter;
        emit ChangeRouter(oldRouter, router);
    }

    // swapMining only router
    function swap(
        address account,
        address pair,
        address input,
        address output,
        uint256 amountIn,
        uint256 amountOut
    ) public override onlyRouter returns (bool) {
        require(account != address(0), 'SwapMining: taker swap account is the zero address');
        require(input != address(0), 'SwapMining: taker swap input is the zero address');
        require(output != address(0), 'SwapMining: taker swap output is the zero address');
        require(pair != address(0), 'SwapMining: taker swap pair is the zero address');

        if (poolLength() == 0) {
            return false;
        }
        uint256 _pid = pairOfPid[pair];
        PoolInfo storage pool = poolInfo[_pid];
        // If it does not exist or the allocPoint is 0 then return
        if (pool.pair != pair || pool.allocPoint <= 0) {
            return false;
        }

        updatePool(_pid);
        uint256 quantity = getQuantity(pair, input, output, amountIn, amountOut);
        if (quantity == 0) {
            return false;
        }

        pool.quantity = pool.quantity.add(quantity);
        pool.totalQuantity = pool.totalQuantity.add(quantity);
        UserInfo storage user = userInfo[pairOfPid[pair]][account];
        user.quantity = user.quantity.add(quantity);
        user.blockNumber = block.number;
        emit SwapMining(account, pair, input, output, amountIn, amountOut);
        return true;
    }

    // Update all pools Called when updating allocPoint and setting new blocks
    function massUpdatePools() public override {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    function updatePool(uint256 _pid) public reduceBlockReward returns (bool) {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return false;
        }
        if (tokenPerBlock <= 0) {
            return false;
        }
        // Calculate the rewards obtained by the pool based on the allocPoint
        uint256 mul = block.number.sub(pool.lastRewardBlock);
        uint256 tokenReward = tokenPerBlock.mul(mul).mul(pool.allocPoint).div(totalAllocPoint);
        // Increase the number of tokens in the current pool
        pool.allocSwapTokenAmount = pool.allocSwapTokenAmount.add(tokenReward);
        pool.lastRewardBlock = block.number;
        return true;
    }

    // The user withdraws all the transaction rewards of the pool
    function getReward() override public {
        uint256 userSub;
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            PoolInfo storage pool = poolInfo[pid];
            UserInfo storage user = userInfo[pid][msg.sender];
            if (user.quantity > 0) {
                updatePool(pid);
                // The reward held by the user in this pool
                uint256 userReward = pool.allocSwapTokenAmount.mul(user.quantity).div(pool.quantity);
                pool.quantity = pool.quantity.sub(user.quantity);
                pool.allocSwapTokenAmount = pool.allocSwapTokenAmount.sub(userReward);
                user.quantity = 0;
                user.blockNumber = block.number;
                userSub = userSub.add(userReward);
            }
        }
        if (userSub <= 0) {
            return;
        }
        _safeTokenTransfer(msg.sender, userSub);
    }

    function rewardInfo(address account) public view returns (uint256) {
        uint256 userSub;
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            PoolInfo storage pool = poolInfo[pid];
            UserInfo storage user = userInfo[pid][account];
            if (user.quantity > 0) {
                uint256 userReward = pool.allocSwapTokenAmount.mul(user.quantity).div(pool.quantity);
                userSub = userSub.add(userReward);
            }
        }
        return userSub;
    }

    // The user withdraws all the transaction rewards of one pool
    function getReward(uint256 pid) public override {
        uint256 userSub;
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][msg.sender];
        if (user.quantity > 0) {
            updatePool(pid);
            // The reward held by the user in this pool
            uint256 userReward = pool.allocSwapTokenAmount.mul(user.quantity).div(pool.quantity);
            pool.quantity = pool.quantity.sub(user.quantity);
            pool.allocSwapTokenAmount = pool.allocSwapTokenAmount.sub(userReward);
            user.quantity = 0;
            user.blockNumber = block.number;
            userSub = userSub.add(userReward);
        }
        if (userSub <= 0) {
            return;
        }
        _safeTokenTransfer(msg.sender, userSub);
    }

}
