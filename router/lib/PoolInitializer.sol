pragma solidity =0.7.6;

import '../interfaces/IPoolInitializer.sol';
import '@sheepdex/core/contracts/interfaces/ISpePool.sol';
import '@sheepdex/core/contracts/interfaces/ISpeFactory.sol';
import './PeripheryImmutableState.sol';

abstract contract PoolInitializer is IPoolInitializer, PeripheryImmutableState {
    function createAndInitializePoolIfNecessary(
        address token0,
        address token1,
        uint24 fee,
        uint160 sqrtPriceX96
    ) external payable override returns (address pool) {
        require(token0 < token1, "!sort");
        require(sqrtPriceX96 != 0, "!0");
        pool = ISpeFactory(factory).getPool(token0, token1, fee);

        if (pool == address(0)) {
            pool = ISpeFactory(factory).createPool(token0, token1, fee);
            ISpePool(pool).initialize(sqrtPriceX96);
        } else {
            (uint160 sqrtPriceX96Existing, , , , , ,) = ISpePool(pool).slot0();
            if (sqrtPriceX96Existing == 0) {
                ISpePool(pool).initialize(sqrtPriceX96);
            }
        }
    }
}
