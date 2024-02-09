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

        // Create actors for interactions here (spoofing), initialize mainnet tokens (enables minting via hevm)
        createActors();
        setUpTokens();

    }

    // Events for expecting emits

    event StablecoinDeposited(
        address indexed depositor,
        address indexed stablecoin,
        uint256 amount,
        uint256 pointsAwarded
    );

    event ETHDeposited(
        address indexed depositor,
        uint256 amount,
        uint256 oraclePrice,
        uint256 pointsAwarded
    );

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
        assertEq(ZPS.presaleDuration(), 21);

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

        // Warp to end of pre-sale
        hevm.warp(block.timestamp + 14 days);

        // Expect amount per 1 ETH is: Floor * 1 ETH ($ Value), wei precision
        (pointsAwarded, priceEth) = ZPS.pointsAwardedETH(1 ether);
        assertEq(pointsAwarded, 1 ether * priceEth / (10**8) * ZPS.pointsFloor());

    }

    function test_Presale_pointsAwardedStablecoin_fuzz(uint256 amount, uint256 timePassed) public {
        
        hevm.assume(timePassed <= 21 days);
        hevm.assume(amount < 1_000_000_000 ether);

        // Warp to start of pre-sale
        hevm.warp(block.timestamp + 1 days);

        // Warp amount of time passed
        hevm.warp(block.timestamp + timePassed);

        // DAI Case
        assertEq(
            ZPS.pointsAwardedStablecoin(DAI, amount), 
            ZPS.standardize(DAI, amount) * (ZPS.pointsFloor() + (ZPS.pointsCeiling() - ZPS.pointsFloor()) * 
            (21 days - (block.timestamp - ZPS.presaleStart())) / 21 days)
        );
        
        // FRAX Case
        assertEq(
            ZPS.pointsAwardedStablecoin(FRAX, amount), 
            ZPS.standardize(FRAX, amount) * (ZPS.pointsFloor() + (ZPS.pointsCeiling() - ZPS.pointsFloor()) * 
            (21 days - (block.timestamp - ZPS.presaleStart())) / 21 days)
        );

        // USDC Case
        assertEq(
            ZPS.pointsAwardedStablecoin(USDC, amount), 
            ZPS.standardize(USDC, amount) * (ZPS.pointsFloor() + (ZPS.pointsCeiling() - ZPS.pointsFloor()) * 
            (21 days - (block.timestamp - ZPS.presaleStart())) / 21 days)
        );

        // USDT Case
        assertEq(
            ZPS.pointsAwardedStablecoin(USDT, amount), 
            ZPS.standardize(USDT, amount) * (ZPS.pointsFloor() + (ZPS.pointsCeiling() - ZPS.pointsFloor()) * 
            (21 days - (block.timestamp - ZPS.presaleStart())) / 21 days)
        );
        
    }

    function test_Presale_pointsAwardedETH_fuzz(uint256 amount, uint256 timePassed) public {
        
        hevm.assume(timePassed <= 21 days);
        hevm.assume(amount < 1_000_000_000 ether);

        // Warp to start of pre-sale
        hevm.warp(block.timestamp + 1 days);

        // Warp amount of time passed
        hevm.warp(block.timestamp + timePassed);

        (uint256 pointsAwarded, uint256 ethPrice) = ZPS.pointsAwardedETH(amount);

        assertEq(
            pointsAwarded, 
            ((ethPrice * amount) / (10**8)) * (ZPS.pointsFloor() + (ZPS.pointsCeiling() - ZPS.pointsFloor()) * 
            (21 days - (block.timestamp - ZPS.presaleStart())) / 21 days)
        );

        assertEq(
            pointsAwarded, 
            ((ZPS.oraclePrice() * amount) / (10**8)) * (ZPS.pointsFloor() + (ZPS.pointsCeiling() - ZPS.pointsFloor()) * 
            (21 days - (block.timestamp - ZPS.presaleStart())) / 21 days)
        );

    }

    function test_Presale_standardize(uint96 amount) public {

        // Test presale function standardize() for:
        //  - 6 Decimal tokens (USDC, USDT)
        //  - 18 Decimal tokens (DAI, FRAX)

        uint256 conversionAmount = uint256(amount);

        // USDC 6 Decimals -> 18 Decimals
        // USDT 6 Decimals -> 18 Decimals
        (uint256 standardizedAmountUSDC) = ZPS.standardize(USDC, conversionAmount);
        (uint256 standardizedAmountUSDT) = ZPS.standardize(USDT, conversionAmount);

        // Note: The conversion amount should be 10**12 greater than provided 10**6 amount for 10**18 standardization
        assertEq(standardizedAmountUSDC, conversionAmount * 10**12);
        assertEq(standardizedAmountUSDT, conversionAmount * 10**12);

        // DAI 18 Decimals -> 18 Decimals
        // FRAX 18 Decimals -> 18 Decimals
        (uint256 standardizedAmountDAI) = ZPS.standardize(DAI, conversionAmount);
        (uint256 standardizedAmountFRAX) = ZPS.standardize(FRAX, conversionAmount);

        // Note: No change should occur (it should skip over if-else statements) given initial 10**18 precision
        assertEq(standardizedAmountDAI, conversionAmount);
        assertEq(standardizedAmountFRAX, conversionAmount);

    }

    // Test presale function depositStablecoin():
    //  - Restrictions (whitelist stablecoin)
    //  - Restrictions (amount > 0) ? (not implemented)
    //  - Restrictions (presale not started)
    //  - Restrictions (presale ended)
    //  - State changes, event logs

    function test_Presale_depositStablecoin_require_whitelist() public {

        // Reverts if stablecoin is not on whitelist
        hevm.startPrank(address(bob));
        mint("WETH", address(bob), 1 ether);
        hevm.expectRevert("Presale::depositStablecoin() !stablecoinWhitelist[stablecoin]");

        // Revert on depositStablecoin()
        ZPS.depositStablecoin(WETH, 1 ether);
        hevm.stopPrank();

    }

    function test_Presale_depositStablecoin_require_amount_18() public {

        // Warp past start of presale (otherwise will trigger another reversion error)
        hevm.warp(block.timestamp + 1 days + 1 hours);

        // Reverts if amount is less than 10 (standardized)
        hevm.startPrank(address(bob));

        mint("DAI", address(bob), 9.9 ether);
        assert(bob.try_approveToken(DAI, address(ZPS), 9.9 ether));

        hevm.expectRevert("Presale::depositStablecoin() checkAmount < 10 ether");

        ZPS.depositStablecoin(DAI, 9.9 ether);

        // Function call
        hevm.stopPrank();

    }

    function test_Presale_depositStablecoin_require_amount_6() public {

        // Warp past start of presale (otherwise will trigger another reversion error)
        hevm.warp(block.timestamp + 1 days + 1 hours);

        // Reverts if amount is less than 10 (standardized)
        hevm.startPrank(address(bob));

        mint("USDT", address(bob), 9.9 * 10**6);
        assert(bob.try_approveToken(USDT, address(ZPS), 9.9 * 10**6));

        hevm.expectRevert("Presale::depositStablecoin() checkAmount < 10 ether");

        ZPS.depositStablecoin(USDT, 9.9 * 10**6);

        // Function call
        hevm.stopPrank();

    }

    function test_Presale_depositStablecoin_require_notStarted() public {

        // Warp to edge-case of presale (1 second before start)
        hevm.warp(block.timestamp + 1 days);

        // Revert if presale hasn't started (note no tokens/approvals are needed to trigger)
        hevm.startPrank(address(bob));
        hevm.expectRevert("Presale::depositStablecoin() block.timestamp <= presaleStart");
        ZPS.depositStablecoin(USDT, 9.9 * 10**6);

        hevm.stopPrank();

    }

    function test_Presale_depositStablecoin_require_ended() public {

        // Warp to edge-case of presale (1 second after end)
        hevm.warp(block.timestamp + 1 days + ZPS.presaleDuration());

        // Revert if presale has ended (note no tokens/approvals are needed to trigger)
        hevm.startPrank(address(bob));
        hevm.expectRevert("Presale::depositStablecoin() block.timestamp >= presaleStart + presaleDuration");
        ZPS.depositStablecoin(USDT, 9.9 * 10**6);

        hevm.stopPrank();

    }

    function test_Presale_depositStablecoin_state(uint256 warpSpeed, uint256 amount) public {

        hevm.assume(warpSpeed > 1 seconds);
        hevm.assume(warpSpeed < 21 days);
        hevm.assume(amount >= 10 ether);
        hevm.assume(amount < 20_000_000 ether);

        // Warp to start of presale
        hevm.warp(block.timestamp + 1 days + warpSpeed);

        // Pre-state
        assertEq(IERC20(DAI).balanceOf(ZPS.treasury()), 0);
        assertEq(ZPS.points(address(bob)), 0);

        // Mint tokens, approve
        hevm.startPrank(address(bob));
        mint("DAI", address(bob), amount);
        assert(bob.try_approveToken(DAI, address(ZPS), amount));

        // Deposit, confirm event log
        hevm.expectEmit(true, true, false, false, address(ZPS));
        emit StablecoinDeposited(address(bob), DAI, amount, ZPS.pointsAwardedStablecoin(DAI, amount));
        ZPS.depositStablecoin(DAI, amount);

        // Post-state
        assertEq(IERC20(DAI).balanceOf(ZPS.treasury()), amount);
        assertEq(ZPS.points(address(bob)), ZPS.pointsAwardedStablecoin(DAI, amount));

    }

    // Test presale function depositETH():
    //  - Restrictions (msg.value > 0.1 ether)
    //  - Restrictions (presale not started)
    //  - Restrictions (presale ended)
    //  - State changes, event logs

    function test_Presale_depositETH_require_amount() public {

        // Warp past start of presale
        hevm.warp(block.timestamp + 1 days + 1 hours);

        // Reverts if amount of ETH is less than 0.01
        hevm.expectRevert("Presale::depositETH() msg.value < 0.01 ether");
        ZPS.depositETH{value: 0.009 ether}();

    }

    function test_Presale_depositETH_require_notStarted() public {

        // Warp to edge-case of presale (1 second before start)
        hevm.warp(block.timestamp + 1 days);

        // Revert if presale hasn't started (note no tokens/approvals are needed to trigger)
        hevm.expectRevert("Presale::depositETH() block.timestamp <= presaleStart");
        ZPS.depositETH{value: 0.01 ether}();

    }

    function test_Presale_depositETH_require_ended() public {

        // Warp to edge-case of presale (1 second after end)
        hevm.warp(block.timestamp + 1 days + ZPS.presaleDuration());
        
        // Revert if presale has ended (note no tokens/approvals are needed to trigger)
        hevm.expectRevert("Presale::depositETH() block.timestamp >= presaleStart + presaleDuration");
        ZPS.depositETH{value: 0.01 ether}();

    }

    function test_Presale_depositETH_state(uint256 warpSpeed, uint256 amount) public {

        hevm.assume(warpSpeed > 1 seconds);
        hevm.assume(warpSpeed < 21 days);
        hevm.assume(amount >= 0.01 ether);
        hevm.assume(amount < 1000 ether);

        // Warp to start of presale
        hevm.warp(block.timestamp + 1 days + warpSpeed);

        // Pre-state
        assertEq(ZPS.treasury().balance, 0);
        assertEq(ZPS.points(address(this)), 0);

        (uint points, uint price) = ZPS.pointsAwardedETH(amount);

        // Deposit, confirm event log
        hevm.expectEmit(true, false, false, false, address(ZPS));
        emit ETHDeposited(address(this), amount, price, points);

        // Post-state
        assertEq(ZPS.treasury().balance, amount);
        assertEq(ZPS.points(address(this)), points);

    }


}