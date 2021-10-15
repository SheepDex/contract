pragma solidity ^0.7.0;

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';

import '@sheepdex/core/contracts/lib/TransferHelper.sol';
import '@sheepdex/core/contracts/lib/CheckOper.sol';


contract SPCTimeLock is CheckOper {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    IERC20 public token;
    uint public period = 864000;
    uint public cycleTimes = 48;
    uint public fixedQuantity;
    uint public startBlock;
    uint public cycle;
    uint public rewarded;

    event WithDraw(address indexed operator, address indexed to, uint amount);

    constructor(
        address _operatorMsg,
        address _token,
        uint _startBlock,
        uint _period,
        uint _cycleTimes
    ) public CheckOper(_operatorMsg){
        require(_token != address(0), "TimeLock: zero address");
        require(_startBlock.sub(block.number) < 50000 && _startBlock.sub(block.number) > 0, "TimeLock: startBlock");
        token = IERC20(_token);
        startBlock = _startBlock;
        period = _period;
        cycleTimes = _cycleTimes;
    }


    function getBalance() public view returns (uint) {
        return token.balanceOf(address(this));
    }

    function getReward() public view returns (uint) {
        if (block.number <= startBlock) {
            return 0;
        }
        uint pCycle = currentCycle();
        if (pCycle >= cycleTimes) {
            return token.balanceOf(address(this));
        }
        return pCycle.sub(cycle).mul(fixedQuantity);
    }

    function currentCycle() public view returns (uint){
        return (block.number.sub(startBlock)).div(period);
    }

    function reset() onlyOperator external {
        fixedQuantity = token.balanceOf(address(this)).div(period);
    }

    function release() onlyOperator external {
        uint reward = getReward();
        uint pCycle = currentCycle();
        cycle = pCycle >= cycleTimes ? cycleTimes : pCycle;
        rewarded = rewarded.add(reward);
        token.safeTransfer(operator(), reward);
        emit WithDraw(msg.sender, operator(), reward);
    }

    function salvageToken(address _asset) onlyOperator external returns (uint256 balance) {
        require(_asset != address(token), 'no token');
        balance = IERC20(_asset).balanceOf(address(this));
        TransferHelper.safeTransfer(_asset, operator(), balance);
    }
}
