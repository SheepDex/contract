pragma solidity =0.7.6;

import '@openzeppelin/contracts/utils/EnumerableSet.sol';
import "@sheepdex/core/contracts/lib/Operatable.sol";
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract TestERC20 is IERC20, Operatable {
    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;

    EnumerableSet.AddressSet private _minters;
    uint256 private _totalSupply;

    constructor(uint256 amountToMint) Operatable() public {
        _mint(msg.sender, amountToMint);
        _totalSupply = _totalSupply + amountToMint;
    }

    modifier onlyMinter() {
        require(isMinter(msg.sender), 'caller is not the minter');
        _;
    }

    function mint(address _to, uint256 _amount) public onlyMinter returns (bool) {
        _mint(msg.sender, _amount);
        return true;

    }

    function _mint(address to, uint256 amount) private {
        uint256 balanceNext = balanceOf[to] + amount;
        require(balanceNext >= amount, 'overflow balance');
        balanceOf[to] = balanceNext;
        _totalSupply = _totalSupply + amount;
    }

    function addMinter(address _addMinter) public onlyOperator returns (bool) {
        require(_addMinter != address(0), ': _addMinter is the zero address');
        return EnumerableSet.add(_minters, _addMinter);
    }

    function delMinter(address _delMinter) public onlyOperator returns (bool) {
        require(_delMinter != address(0), ': _delMinter is the zero address');
        return EnumerableSet.remove(_minters, _delMinter);
    }

    function isMinter(address account) public view returns (bool) {
        return EnumerableSet.contains(_minters, account);
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        uint256 balanceBefore = balanceOf[msg.sender];
        require(balanceBefore >= amount, 'insufficient balance');
        balanceOf[msg.sender] = balanceBefore - amount;

        uint256 balanceRecipient = balanceOf[recipient];
        require(balanceRecipient + amount >= balanceRecipient, 'recipient balance overflow');
        balanceOf[recipient] = balanceRecipient + amount;

        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        uint256 allowanceBefore = allowance[sender][msg.sender];
        require(allowanceBefore >= amount, 'allowance insufficient');

        allowance[sender][msg.sender] = allowanceBefore - amount;

        uint256 balanceRecipient = balanceOf[recipient];
        require(balanceRecipient + amount >= balanceRecipient, 'overflow balance recipient');
        balanceOf[recipient] = balanceRecipient + amount;
        uint256 balanceSender = balanceOf[sender];
        require(balanceSender >= amount, 'underflow balance sender');
        balanceOf[sender] = balanceSender - amount;

        emit Transfer(sender, recipient, amount);
        return true;
    }

    function totalSupply() external override view returns (uint256){
        return _totalSupply;
    }
}
