// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/EnumerableSet.sol';

import './interfaces/ISwap.sol';
import './interfaces/IMasterChef.sol';

import './TokenReward.sol';

contract RewardPool is TokenReward {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    event Paused(address indexed user, bool paused);
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. swapToken to distribute per block.
        uint256 lastRewardBlock; // Last block number that swap token distribution occurs.
        uint256 accTokenPerShare; // Accumulated swap token per share, times 1e12.
        uint256 totalAmount; // Total amount of current pool deposit.
    }
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // pid corresponding address
    mapping(address => uint256) public LpOfPid;
    // Control mining
    bool public paused = false;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;

    constructor(
        address _operatorMsg,
        ISwap _swapToken,
        uint256 _ftpPerBlock,
        uint256 _startBlock,
        uint256 _period
    ) TokenReward(_operatorMsg, _swapToken, _ftpPerBlock, _startBlock, _period) {}


    // View function to see pending swap token on frontend.
    function pending(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accTokenPerShare = pool.accTokenPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (user.amount > 0) {
            if (block.number > pool.lastRewardBlock) {
                uint256 mul = block.number.sub(pool.lastRewardBlock);
                uint256 tokenReward = tokenPerBlock.mul(mul).mul(pool.allocPoint).div(totalAllocPoint);
                accTokenPerShare = accTokenPerShare.add(tokenReward.mul(1e12).div(lpSupply));
                return user.amount.mul(accTokenPerShare).div(1e12).sub(user.rewardDebt);
            }
            if (block.number == pool.lastRewardBlock) {
                return user.amount.mul(accTokenPerShare).div(1e12).sub(user.rewardDebt);
            }
        }
        return 0;
    }

    function poolLength() public view returns (uint256) {
        return poolInfo.length;
    }

    modifier notPause() {
        require(paused == false, 'Mining has been suspended');
        _;
    }


    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public override {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public reduceBlockReward {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        if (tokenPerBlock <= 0) {
            return;
        }
        uint256 mul = block.number.sub(pool.lastRewardBlock);
        uint256 tokenReward = tokenPerBlock.mul(mul).mul(pool.allocPoint).div(totalAllocPoint);
        pool.accTokenPerShare = pool.accTokenPerShare.add(tokenReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to Pool for swap token allocation.
    function deposit(uint256 _pid, uint256 _amount) public notPause {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pendingAmount = user.amount.mul(pool.accTokenPerShare).div(1e12).sub(user.rewardDebt);
            if (pendingAmount > 0) {
                _safeTokenTransfer(msg.sender, pendingAmount);
            }
        }
        if (_amount > 0) {
            TransferHelper.safeTransferFrom(address(pool.lpToken), msg.sender, address(this), _amount);
            user.amount = user.amount.add(_amount);
            pool.totalAmount = pool.totalAmount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accTokenPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from pool.
    function withdraw(uint256 _pid, uint256 _amount) public notPause {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, 'withdrawSwap: not good');
        updatePool(_pid);
        uint256 pendingAmount = user.amount.mul(pool.accTokenPerShare).div(1e12).sub(user.rewardDebt);
        if (pendingAmount > 0) {
            _safeTokenTransfer(msg.sender, pendingAmount);
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.totalAmount = pool.totalAmount.sub(_amount);
            TransferHelper.safeTransfer(address(pool.lpToken), msg.sender, _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accTokenPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public notPause {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        TransferHelper.safeTransfer(address(pool.lpToken), msg.sender, amount);
        pool.totalAmount = pool.totalAmount.sub(amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    function setPause() public onlyOperator {
        paused = !paused;
        emit Paused(msg.sender, paused);
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        address _lpToken,
        bool _withUpdate
    ) public onlyOperator {
        require(_lpToken != address(0), 'lpToken is the zero address');
        if (poolLength() > 0) {
            require((LpOfPid[_lpToken] == 0) && (address(poolInfo[0].lpToken) != _lpToken), "only one pool");
        }
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
        lpToken : IERC20(_lpToken),
        allocPoint : _allocPoint,
        lastRewardBlock : lastRewardBlock,
        accTokenPerShare : 0,
        totalAmount : 0
        })
        );
        LpOfPid[_lpToken] = poolLength() - 1;
        emit AddPool(_lpToken, _allocPoint);
    }

    // Update the given pool's swapToken allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOperator {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
        emit SetPool(address(poolInfo[_pid].lpToken), _allocPoint);
    }


}
