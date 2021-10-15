// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;
pragma abicoder v2;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/EnumerableSet.sol';

import '@sheepdex/core/contracts/lib/TransferHelper.sol';
import '@sheepdex/core/contracts/lib/CheckOper.sol';

// Each block produces 3.5 coins
contract SPCToken is ERC20, CheckOper {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    event AddMinter(address indexed minter);
    event DelMinter(address indexed minter);

    uint256 constant public MAX_SUPPLY = 9e7 * 1e18; // the total supply

    EnumerableSet.AddressSet private _minters;

    constructor(address _operCon) ERC20('Sheep Swap Token', 'SPC') CheckOper(_operCon) {
        _mint(msg.sender, MAX_SUPPLY.mul(3).div(10));
    }


    function getMinterLength() public view returns (uint256) {
        return EnumerableSet.length(_minters);
    }

    function isMinter(address account) public view returns (bool) {
        return EnumerableSet.contains(_minters, account);
    }

    modifier onlyMinter() {
        require(isMinter(msg.sender), 'caller is not the minter');
        _;
    }

    function getMinter(uint256 _index) public view onlyOperator returns (address) {
        require(_index < getMinterLength(), ': index out of bounds');
        return EnumerableSet.at(_minters, _index);
    }

    function addMinter(address _minter) public onlyOperator returns (bool) {
        require(_minter != address(0), ': _addMinter is the zero address');
        emit AddMinter(_minter);
        return EnumerableSet.add(_minters, _minter);
    }

    function delMinter(address _minter) public onlyOperator returns (bool) {
        require(_minter != address(0), ': _delMinter is the zero address');
        emit DelMinter(_minter);
        return EnumerableSet.remove(_minters, _minter);
    }

    function salvageToken(address reserve) external onlyOperator {
        uint256 amount = IERC20(reserve).balanceOf(address(this));
        TransferHelper.safeTransfer(reserve, operator(), amount);
    }

    function mint(address _to, uint256 _amount) public onlyMinter returns (bool) {
        if (_amount.add(totalSupply()) > MAX_SUPPLY) {
            return false;
        }
        _mint(_to, _amount);
        return true;
    }

    function burn(uint256 _amount) public {
        _burn(msg.sender, _amount);
    }

}
