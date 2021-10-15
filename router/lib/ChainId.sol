pragma solidity >=0.7.0;

library ChainId {
    function get() internal pure returns (uint256 chainId) {
        assembly {
            chainId := chainid()
        }
    }
}
