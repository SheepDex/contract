pragma solidity >=0.7.5;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import '../interfaces/IPeripheryPayments.sol';
import '../interfaces/IWBNB.sol';

import '@sheepdex/core/contracts/lib/TransferHelper.sol';

import './PeripheryImmutableState.sol';

abstract contract PeripheryPayments is IPeripheryPayments, PeripheryImmutableState {
    receive() external payable {
        require(msg.sender == WBNB, 'Not WBNB');
    }

    function unwrapWBNB(uint256 amountMinimum, address recipient) external payable override {
        uint256 balanceWETH9 = IWBNB(WBNB).balanceOf(address(this));
        require(balanceWETH9 >= amountMinimum, 'Insufficient WBNB');

        if (balanceWETH9 > 0) {
            IWBNB(WBNB).withdraw(balanceWETH9);
            TransferHelper.safeTransferETH(recipient, balanceWETH9);
        }
    }

    function sweepToken(
        address token,
        uint256 amountMinimum,
        address recipient
    ) external payable override {
        uint256 balanceToken = IERC20(token).balanceOf(address(this));
        require(balanceToken >= amountMinimum, 'Insufficient token');

        if (balanceToken > 0) {
            TransferHelper.safeTransfer(token, recipient, balanceToken);
        }
    }

    function refundETH() external payable override {
        if (address(this).balance > 0) TransferHelper.safeTransferETH(msg.sender, address(this).balance);
    }

    function pay(
        address token,
        address payer,
        address recipient,
        uint256 value
    ) internal {
        if (token == WBNB && address(this).balance >= value) {
            IWBNB(WBNB).deposit{value: value}(); // wrap only what is needed to pay
            IWBNB(WBNB).transfer(recipient, value);
        } else if (payer == address(this)) {
            // pay with tokens already in the contract (for the exact input multihop case)
            TransferHelper.safeTransfer(token, recipient, value);
        } else {
            // pull payment
            TransferHelper.safeTransferFrom(token, payer, recipient, value);
        }
    }
}
