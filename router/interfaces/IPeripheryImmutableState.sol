pragma solidity >=0.5.0;

interface IPeripheryImmutableState {
    function factory() external view returns (address);

    function WBNB() external view returns (address);
}
