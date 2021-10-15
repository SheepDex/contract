pragma solidity =0.7.6;


import '@sheepdex/core/contracts/interfaces/ISpePool.sol';

import './PoolAddress.sol';

library CallbackValidation {
    function verifyCallback(
        address factory,
        address tokenA,
        address tokenB,
        uint24 fee
    ) internal view returns (ISpePool pool) {
        return verifyCallback(factory, PoolAddress.getPoolKey(tokenA, tokenB, fee));
    }

    function verifyCallback(address factory, PoolAddress.PoolKey memory poolKey) internal view returns (ISpePool pool) {
        pool = ISpePool(PoolAddress.computeAddress(factory, poolKey));
        require(msg.sender == address(pool));
    }
}
