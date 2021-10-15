
pragma solidity =0.7.6;
pragma abicoder v2;

import '../interfaces/IPositionReward.sol';

import '../lib/PoolId.sol';

/// @dev Test contract for IncentiveId
contract TestIncentiveId {
    function compute(IPositionReward.IncentiveKey memory key) public pure returns (bytes32) {
        return PoolId.compute(key);
    }
}
