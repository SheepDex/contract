
pragma solidity =0.7.6;

import "../interfaces/IPositionReward.sol";
pragma abicoder v2;


library PoolId {
    function compute(IPositionReward.IncentiveKey memory key) internal pure returns (bytes32 incentiveId) {
        return keccak256(abi.encode(key));
    }
}
