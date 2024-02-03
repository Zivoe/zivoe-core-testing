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

        // Test-case ensures:
        //  - 10**8 precision
        //  - Range between 1500 and 3500 (subject to change)
        assertGt(ZPS.oraclePrice() / (10**8), 1500);
        assertLt(ZPS.oraclePrice() / (10**8), 3500);

    }

    function test_Presale_pointsAwardedStablecoin_static() public {
        
        // Warp to 1 day later, exact start of presale
        hevm.warp(block.timestamp + 1 days);

        // Expected amount per any stablecoin is maximum: 5000 * Stablecoins, wei precision
        // NOTE: DAI/FRAX = 18 decimal precision, USDC/USDT = 6 decimal precision
        assertEq(ZPS.pointsAwardedStablecoin(DAI, 1000 ether), 1000 ether * ZPS.pointsCeiling());
        assertEq(ZPS.pointsAwardedStablecoin(FRAX, 1000 ether), 1000 ether * ZPS.pointsCeiling());
        assertEq(ZPS.pointsAwardedStablecoin(USDC, 1000 * 10**6), 1000 ether * ZPS.pointsCeiling());
        assertEq(ZPS.pointsAwardedStablecoin(USDT, 1000 * 10**6), 1000 ether * ZPS.pointsCeiling());
        
        // Warp to 7 days later, 1 week into presale (7/21)
        hevm.warp(block.timestamp + 7 days);

        // Expected amount per any stablecoin is: Floor + (Ceiling - Floor) * 14/21 * Stablecoins, wei precision
        assertEq(ZPS.pointsAwardedStablecoin(DAI, 1000 ether), 1000 ether * (ZPS.pointsFloor() + (ZPS.pointsCeiling() - ZPS.pointsFloor()) * 14 / 21));
        assertEq(ZPS.pointsAwardedStablecoin(FRAX, 1000 ether), 1000 ether * (ZPS.pointsFloor() + (ZPS.pointsCeiling() - ZPS.pointsFloor()) * 14 / 21));
        assertEq(ZPS.pointsAwardedStablecoin(USDC, 1000 * 10**6), 1000 ether * (ZPS.pointsFloor() + (ZPS.pointsCeiling() - ZPS.pointsFloor()) * 14 / 21));
        assertEq(ZPS.pointsAwardedStablecoin(USDT, 1000 * 10**6), 1000 ether * (ZPS.pointsFloor() + (ZPS.pointsCeiling() - ZPS.pointsFloor()) * 14 / 21));
        
        // Warp to end of presale, 14 days more, 21 days in
        hevm.warp(block.timestamp + 14 days);

        // Expected amount per any stablecoin is: Floor * Stablecoins, wei precision
        assertEq(ZPS.pointsAwardedStablecoin(DAI, 1000 ether), 1000 ether * ZPS.pointsFloor());
        assertEq(ZPS.pointsAwardedStablecoin(FRAX, 1000 ether), 1000 ether * ZPS.pointsFloor());
        assertEq(ZPS.pointsAwardedStablecoin(USDC, 1000 * 10**6), 1000 ether * ZPS.pointsFloor());
        assertEq(ZPS.pointsAwardedStablecoin(USDT, 1000 * 10**6), 1000 ether * ZPS.pointsFloor());

    }

    function test_Presale_pointsAwardedETH_static() public {
        
        // Warp to 1 day later, exact start of presale
        hevm.warp(block.timestamp + 1 days);

        // Expected amount per 1 ETH is maximum: 5000 * 1 ETH ($ Value), wei precision
        (uint pointsAwarded, uint priceEth) = ZPS.pointsAwardedETH(1 ether);
        assertEq(pointsAwarded, 1 ether * priceEth / (10**8) * ZPS.pointsCeiling());

        // Warp to 7 days later, early-mid of presale
        hevm.warp(block.timestamp + 7 days);

        // Expect amount per 1 ETH is: Floor + (Ceiling - Floor) * 14/21 * 1 ETH ($ Value), wei precision
        (pointsAwarded, priceEth) = ZPS.pointsAwardedETH(1 ether);
        assertEq(pointsAwarded, 1 ether * priceEth / (10**8) * (ZPS.pointsFloor() + (ZPS.pointsCeiling() - ZPS.pointsFloor()) * 14 / 21));

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