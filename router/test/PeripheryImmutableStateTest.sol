pragma solidity =0.7.6;

import '../lib/PeripheryImmutableState.sol';

contract PeripheryImmutableStateTest is PeripheryImmutableState {
    constructor(address _factory, address _WBNB) PeripheryImmutableState(_factory, _WBNB) {}
}
