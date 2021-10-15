
pragma solidity =0.7.6;


import '@sheepdex/core/contracts/SpeFactory.sol';

contract FactoryTest is SpeFactory {
    constructor(address driectorAddress) SpeFactory(driectorAddress) public {
    }
}
