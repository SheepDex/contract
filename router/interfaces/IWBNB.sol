pragma solidity =0.7.6;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IWBNB is IERC20 {
    function deposit() external payable;

    function withdraw(uint256) external;
}
