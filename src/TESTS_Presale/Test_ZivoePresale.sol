// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../Utility/Utility.sol";

import "../../lib/zivoe-core-foundry/src/misc/Presale.sol";

contract Test_Presale is Utility {

    using FloorMath for uint256;

    Presale ZPS;

    // Test-cases implemented for Ethereum mainnet RPC.

    function setUp() public { 

        // Stablecoin whitelist setup.
        address[] memory stablecoins = new address[](4);
        stablecoins[0] = DAI;
        stablecoins[1] = FRAX;
        stablecoins[2] = USDC;
        stablecoins[3] = USDT;

        // Initialize pre-sale contract.
        ZPS = new Presale(stablecoins, CHAINLINK_ETH, address(this));

    }

    // Test presale initial settings.

    function test_Presale_initialSettings() public {
        
    }

    // Test presale view function endpoints:
    //  - oraclePrice()
    //  - pointsAwardedStablecoin()
    //  - pointsAwardedETH()
    //  - standardize()

    function test_Presale_oraclePrice() public {
        
    }

    function test_Presale_pointsAwardedStablecoin() public {
        
    }

    function test_Presale_pointsAwardedETH() public {
        
    }

    function test_Presale_standardize() public {
        
    }

    // Test presale function depositStablecoin():
    //  - Restrictions (whitelist stablecoin)
    //  - Restrictions (amount > 0) ? (not implemented)
    //  - State changes

    function test_Presale_depositStablecoin_require() public {

    }

    function test_Presale_depositStablecoin_state() public {

    }

    // Test presale function depositETH():
    //  - Restrictions (msg.value > 0.1 ether)
    //  - State changes

    function test_Presale_depositETH_require() public {

    }

    function test_Presale_depositETH_state() public {

    }


}