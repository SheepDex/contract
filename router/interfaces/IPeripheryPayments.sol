pragma solidity >=0.7.5;

interface IPeripheryPayments {
    function unwrapWBNB(uint256 amountMinimum, address recipient) external payable;

    function refundETH() external payable;

    function sweepToken(
        address token,
        uint256 amountMinimum,
        address recipient
    ) external payable;
}
