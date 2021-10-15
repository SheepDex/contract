pragma solidity >=0.5.0;
pragma abicoder v2;

import '../lib/TickLens.sol';

contract TickLensTest is TickLens {
    function getGasCostOfGetPopulatedTicksInWord(address pool, int16 tickBitmapIndex) external view returns (uint256) {
        uint256 gasBefore = gasleft();
        getPopulatedTicksInWord(pool, tickBitmapIndex);
        return gasBefore - gasleft();
    }
}
