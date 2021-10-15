pragma solidity =0.7.6;
pragma abicoder v2;


import "@sheepdex/router/contracts/SPCToken.sol";


contract TestSPCToken is SPCToken {

    constructor(address _operCon) SPCToken(_operCon) {

    }

}