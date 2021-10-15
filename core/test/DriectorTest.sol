// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;


import '@sheepdex/core/contracts/SwapDirector.sol';

contract DriectorTest is SwapDirector {
    constructor(address _operatorMsg) SwapDirector(_operatorMsg) public {
    }
}
