// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/EnumerableSet.sol';
import '@sheepdex/core/contracts/lib/CheckOper.sol';
import '@sheepdex/core/contracts/lib/TransferHelper.sol';
import './interfaces/ISwap.sol';

abstract contract TokenReward is CheckOper {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event SetPool(address indexed pool, uint256 point);
    event AddPool(address indexed pool, uint256 point);

    ISwap public swapToken;

    uint256 public tokenPerBlock;
    uint256 public immutable startBlock;
    uint256 public periodEndBlock;
    // How many blocks (90 days) are halved 2592000
    uint256 public period;

    uint256 public mintPeriod;

    uint256 public minTokenReward = 1.75e17;

    constructor(
        address _operatorMsg,
        ISwap _swapToken,
        uint256 _tokenPerBlock,
        uint256 _startBlock,
        uint256 _period
    ) CheckOper(_operatorMsg) {
        require(address(_swapToken) != address(0), "swapToken is 0");
        swapToken = _swapToken;
        tokenPerBlock = _tokenPerBlock;
        startBlock = _startBlock;
        period = _period;
        periodEndBlock = _startBlock.add(_period);
        mintPeriod = 28800;
    }

    modifier reduceBlockReward() {
        if (block.number > startBlock && block.number >= periodEndBlock) {
            if (tokenPerBlock > minTokenReward) {
                tokenPerBlock = tokenPerBlock.mul(80).div(100);
            }
            if (tokenPerBlock < minTokenReward) {
                tokenPerBlock = minTokenReward;
            }
            periodEndBlock = block.number.add(period);
        }
        _;
    }

    function setHalvingPeriod(uint256 _block) public onlyOperator {
        period = _block;
    }

    function setMintPeriod(uint256 _block) public onlyOperator {
        mintPeriod = _block;
    }

    function setMinTokenReward(uint256 _reward) public onlyOperator {
        minTokenReward = _reward;
    }

    // Set the number of swap produced by each block
    function setTokenPerBlock(uint256 _newPerBlock, bool _withUpdate) public onlyOperator {
        if (_withUpdate) {
            massUpdatePools();
        }
        tokenPerBlock = _newPerBlock;
    }

    // Safe swap token transfer function, just in case if rounding error causes pool to not have enough swaps.
    function _safeTokenTransfer(address _to, uint256 _amount) internal {
        _mintRewardToken(_amount);
        uint256 bal = swapToken.balanceOf(address(this));
        if (_amount > bal) {
            _amount = bal;
        }
        TransferHelper.safeTransfer(address(swapToken), _to, _amount);
    }

    function _mintRewardToken(uint256 _amount) private {
        uint256 bal = swapToken.balanceOf(address(this));
        if (bal < _amount) {
            swapToken.mint(address(this), _amount.mul(mintPeriod));
        }
    }

    function massUpdatePools() public virtual;
}
