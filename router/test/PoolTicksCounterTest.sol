pragma solidity >=0.6.0;

import '@sheepdex/core/contracts/interfaces/ISpeSwapCallback.sol';

import '../lib/PoolTicksCounter.sol';

contract PoolTicksCounterTest {
    using PoolTicksCounter for ISpePool;

    function countInitializedTicksCrossed(
        ISpePool pool,
        int24 tickBefore,
        int24 tickAfter
    ) external view returns (uint32 initializedTicksCrossed) {
        return pool.countInitializedTicksCrossed(tickBefore, tickAfter);
    }
}
