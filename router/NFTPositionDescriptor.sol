pragma solidity =0.7.6;
pragma abicoder v2;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import '@sheepdex/core/contracts/interfaces/ISpePool.sol';

import './interfaces/INFTPositionManager.sol';
import './interfaces/INFTPositionDescriptor.sol';

import './lib/SafeERC20Namer.sol';
import './lib/ChainId.sol';
import './lib/PoolAddress.sol';
import './lib/NFTDescriptor.sol';

contract NFTPositionDescriptor is INFTPositionDescriptor {
    int256 constant NUMERATOR_MOST = 300;
    int256 constant NUMERATOR_MORE = 200;
    int256 constant NUMERATOR = 100;

    int256 constant DENOMINATOR_MOST = - 300;
    int256 constant DENOMINATOR_MORE = - 200;
    int256 constant DENOMINATOR = - 100;

    address private constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address private constant USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
    address private constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address private constant ETH = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;
    address private constant BTC = 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c;

    address public immutable WBNB;

    constructor(address _wbnb) {
        WBNB = _wbnb;
    }

    function tokenURI(INFTPositionManager positionManager, uint256 tokenId)
    external
    view
    override
    returns (string memory)
    {
        (, , address token0, address token1, uint24 fee, int24 tickLower, int24 tickUpper, , , , ,) =
        positionManager.positions(tokenId);

        ISpePool pool =
        ISpePool(
            PoolAddress.computeAddress(
                positionManager.factory(),
                PoolAddress.PoolKey({token0 : token0, token1 : token1, fee : fee})
            )
        );

        bool _flipRatio = flipRatio(token0, token1);
        address quoteTokenAddress = !_flipRatio ? token1 : token0;
        address baseTokenAddress = !_flipRatio ? token0 : token1;
        (, int24 tick, , , , ,) = pool.slot0();

        return
        NFTDescriptor.constructTokenURI(
            NFTDescriptor.ConstructTokenURIParams({
        tokenId : tokenId,
        quoteTokenAddress : quoteTokenAddress,
        baseTokenAddress : baseTokenAddress,
        quoteTokenSymbol : quoteTokenAddress == WBNB ? 'BNB' : SafeERC20Namer.tokenSymbol(quoteTokenAddress),
        baseTokenSymbol : baseTokenAddress == WBNB ? 'BNB' : SafeERC20Namer.tokenSymbol(baseTokenAddress),
        quoteTokenDecimals : ERC20(quoteTokenAddress).decimals(),
        baseTokenDecimals : ERC20(baseTokenAddress).decimals(),
        flipRatio : _flipRatio,
        tickLower : tickLower,
        tickUpper : tickUpper,
        tickCurrent : tick,
        tickSpacing : pool.tickSpacing(),
        fee : fee,
        poolAddress : address(pool)
        })
        );
    }

    function flipRatio(address token0, address token1) public view returns (bool) {
        return tokenRatioPriority(token0) > tokenRatioPriority(token1);
    }

    function tokenRatioPriority(address token) public view returns (int256) {
        if (token == WBNB) {
            return DENOMINATOR;
        }
        if (token == USDC) {
            return NUMERATOR_MOST;
        } else if (token == USDT) {
            return NUMERATOR_MORE;
        } else if (token == BUSD) {
            return NUMERATOR;
        } else if (token == ETH) {
            return DENOMINATOR_MORE;
        } else if (token == BTC) {
            return DENOMINATOR_MOST;
        } else {
            return 0;
        }
    }
}
