pragma solidity =0.7.6;

import '../interfaces/IPeripheryImmutableState.sol';

/// @title Immutable state
/// @notice Immutable state used by periphery contracts
abstract contract PeripheryImmutableState is IPeripheryImmutableState {
    /// @inheritdoc IPeripheryImmutableState
    address public immutable override factory;
    /// @inheritdoc IPeripheryImmutableState
    address public immutable override WBNB;

    constructor(address _factory, address _WBNB) {
        require(_factory != address(0), "!0");
        require(_WBNB != address(0), "!0");
        factory = _factory;
        WBNB = _WBNB;
    }
}
