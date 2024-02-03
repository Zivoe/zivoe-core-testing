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

        assert(ZPS.stablecoinWhitelist(DAI));
        assert(ZPS.stablecoinWhitelist(FRAX));
        assert(ZPS.stablecoinWhitelist(USDC));
        assert(ZPS.stablecoinWhitelist(USDT));

        assertEq(ZPS.oracle(), CHAINLINK_ETH);
        assertEq(ZPS.treasury(), address(this));
        assertEq(ZPS.pointsFloor(), 250);
        assertEq(ZPS.pointsCeiling(), 5000);
        assertEq(ZPS.presaleStart(), block.timestamp + 1 days);
        assertEq(ZPS.presaleDays(), 21);

    }

    // Test presale view function endpoints:
    //  - oraclePrice()
    //  - pointsAwardedStablecoin()
    //  - pointsAwardedETH()
    //  - standardize()

    function test_Presale_oraclePrice() public {

        // Test-case ensure:
        //  - 10**8 precision
        //  - Range between 1500 and 3500 (subject to change)
        assertGt(ZPS.oraclePrice() / (10**8), 1500);
        assertLt(ZPS.oraclePrice() / (10**8), 3500);

    }

    function test_Presale_pointsAwardedStablecoin_static() public {
        
    }

    function test_Presale_pointsAwardedETH_static() public {
        
    }

    function test_Presale_pointsAwardedStablecoin_fuzz() public {
        
    }

    function test_Presale_pointsAwardedETH_fuzz() public {
        
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