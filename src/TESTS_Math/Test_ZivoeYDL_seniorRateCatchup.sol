// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "lib/zivoe-core-foundry/src/ZivoeYDL.sol";

// First the idea is to test for multiple values of input parameters and it's effect on returned value.

// Test 1
// sSTT = 10% of initial amount

// Test 2
// sJTT = 10% of initial amount

// Test 3
// Multiplication factor = 0.5

// Test 4
// Multiplication factor = 10

// Then in a separate test function we will also perform fuzz testing

contract Test_ZivoeYDL_seniorRateShortfall is Utility {

    uint256 sSTT = 30_000_000 ether;
    uint256 sJTT = 6_000_000 ether;

    function setUp() public {
        deployCore(false);

    }

    function test_ZivoeYDL_seniorRateCatchup_chosenValues() public {

        simulateITO(1_000_000 ether, 1_000_000 ether, 1_000_000 * 10**6, 1_000_000 * 10**6);
        claimITO_and_approveTokens_and_stakeTokens(true);

        (uint256 supplyZSTT, uint256 supplyZJTT) = GBL.adjustedSupplies();

        emit log_named_uint("zSTT", supplyZSTT);
        emit log_named_uint("zJTT", supplyZJTT);

        // State 0
        // As a first step we will distributeYield() in order to set initial variable "ema" needed 
        deal(DAI, address(YDL), 240_000 ether);
        hevm.warp(block.timestamp + 31 days);
        YDL.distributeYield();

        uint256 postFeeYield = 280_000 ether;
        uint256 yT = 260_000 ether;

        uint256 seniorRateCatchup0 = YDL.seniorRateCatchup_RAY(
            postFeeYield,
            yT,
            supplyZSTT,
            supplyZJTT,
            YDL.retrospectiveDistributions(),
            YDL.targetRatioBIPS()
        );

        //withinDiff(seniorRate, 754716981 ether, 100 ether);
        emit log_named_uint("seniorRateCatchup0", seniorRateCatchup0);
        emit log_named_uint("emaYield", YDL.emaYield());
    }

}