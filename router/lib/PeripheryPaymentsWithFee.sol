pragma solidity >=0.7.5;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@sheepdex/core/contracts/lib/SwapMath.sol';

import './PeripheryPayments.sol';
import '../interfaces/IPeripheryPaymentsWithFee.sol';

import '../interfaces/IWBNB.sol';
import '@sheepdex/core/contracts/lib/TransferHelper.sol';

abstract contract PeripheryPaymentsWithFee is PeripheryPayments, IPeripheryPaymentsWithFee {
    using SwapMath for uint256;
    using SafeMath for uint256;

    function unwrapWETH9WithFee(
        uint256 amountMinimum,
        address recipient,
        uint256 feeBips,
        address feeRecipient
    ) public payable override {
        require(feeBips > 0 && feeBips <= 100);

        uint256 balanceWETH9 = IWBNB(WBNB).balanceOf(address(this));
        require(balanceWETH9 >= amountMinimum, 'Insufficient WBNB');

        if (balanceWETH9 > 0) {
            IWBNB(WBNB).withdraw(balanceWETH9);
            uint256 feeAmount = balanceWETH9.mul(feeBips) / 10_000;
            if (feeAmount > 0) TransferHelper.safeTransferETH(feeRecipient, feeAmount);
            TransferHelper.safeTransferETH(recipient, balanceWETH9 - feeAmount);
        }
    }

    function sweepTokenWithFee(
        address token,
        uint256 amountMinimum,
        address recipient,
        uint256 feeBips,
        address feeRecipient
    ) public payable override {
        require(feeBips > 0 && feeBips <= 100);

        uint256 balanceToken = IERC20(token).balanceOf(address(this));
        require(balanceToken >= amountMinimum, 'Insufficient token');

        if (balanceToken > 0) {
            uint256 feeAmount = balanceToken.mul(feeBips) / 10_000;
            if (feeAmount > 0) TransferHelper.safeTransfer(token, feeRecipient, feeAmount);
            TransferHelper.safeTransfer(token, recipient, balanceToken - feeAmount);
        }
    }
}
