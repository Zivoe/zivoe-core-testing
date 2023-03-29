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

contract Test_ZivoeYDL_seniorProportionCatchup is Utility {

    uint256 sSTT = 30_000_000 ether;
    uint256 sJTT = 6_000_000 ether;

    function setUp() public {
        deployCore(false);

    }

    function test_ZivoeYDL_seniorProportionCatchup_chosenValues() public {

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
        uint256 emaYield = YDL.emaYield();
        uint256 yT = 260_000 ether;

        uint256 seniorProportionCatchup0 = YDL.seniorProportionCatchup(
            postFeeYield,
            emaYield,
            yT,
            supplyZSTT,
            supplyZJTT,
            YDL.retrospectiveDistributions(),
            YDL.targetRatioBIPS()
        );

        withinDiff(seniorProportionCatchup0, 908843537 ether, 100 ether);
        emit log_named_uint("seniorProportionCatchup0", seniorProportionCatchup0);
        emit log_named_uint("emaYield", emaYield);

        // Test 1
        uint256 seniorProportionCatchup1 = YDL.seniorProportionCatchup(
            postFeeYield,
            emaYield,
            yT,
            (supplyZSTT * 10) / 100,
            supplyZJTT,
            YDL.retrospectiveDistributions(),
            YDL.targetRatioBIPS()
        );

        assert(seniorProportionCatchup1 < seniorProportionCatchup0);
        withinDiff(seniorProportionCatchup1, 138302277 ether, 100 ether);
        emit log_named_uint("seniorProportionCatchup1", seniorProportionCatchup1);

        // Test 2
        uint256 seniorProportionCatchup2 = YDL.seniorProportionCatchup(
            postFeeYield,
            emaYield,
            yT,
            supplyZSTT,
            (supplyZJTT * 10) / 100,
            YDL.retrospectiveDistributions(),
            YDL.targetRatioBIPS()
        );

        assert(seniorProportionCatchup2 > seniorProportionCatchup0);
        withinDiff(seniorProportionCatchup2, 1000000000 ether, 100 ether);
        emit log_named_uint("seniorProportionCatchup2", seniorProportionCatchup2);

        // Test 3
        uint256 seniorProportionCatchup3 = YDL.seniorProportionCatchup(
            postFeeYield,
            emaYield,
            yT,
            supplyZSTT,
            supplyZJTT,
            YDL.retrospectiveDistributions(),
            5000
        );

        assert(seniorProportionCatchup3 > seniorProportionCatchup0);
        withinDiff(seniorProportionCatchup3, 1000000000 ether, 100 ether);
        emit log_named_uint("seniorProportionCatchup3", seniorProportionCatchup3);

        // Test 4
        uint256 seniorProportionCatchup4 = YDL.seniorProportionCatchup(
            postFeeYield,
            emaYield,
            yT,
            supplyZSTT,
            supplyZJTT,
            YDL.retrospectiveDistributions(),
            100000
        );

        assert(seniorProportionCatchup4 < seniorProportionCatchup0);
        withinDiff(seniorProportionCatchup4, 216883116 ether, 100 ether);
        emit log_named_uint("seniorProportionCatchup4", seniorProportionCatchup4);
    }

    function test_ZivoeYDL_seniorProportionCatchup_fuzzTesting(
        uint88 postFeeYield,
        uint88 yT,
        uint96 depositITO,
        uint88 initialYield,
        uint16 targetRatio

    ) 
    public
    {
        
        hevm.assume(initialYield < yT && initialYield > 0);
        hevm.assume(postFeeYield > yT);
        hevm.assume(yT > initialYield);

        uint256 targetRatioBIPS = uint256(targetRatio) + 1;
        uint256 ITOAmount = uint256(depositITO) + 1_000 ether;

        simulateITO(ITOAmount, ITOAmount, ITOAmount/10**12, ITOAmount/10**12); 
        claimITO_and_approveTokens_and_stakeTokens(true);

        (uint256 supplyZSTT, uint256 supplyZJTT) = GBL.adjustedSupplies();

        emit log_named_uint("zSTT", supplyZSTT);
        emit log_named_uint("zJTT", supplyZJTT);

        // As a first step we will distributeYield() in order to set initial variable "ema" needed 
        deal(DAI, address(YDL), initialYield); 
        hevm.warp(block.timestamp + 31 days);
        YDL.distributeYield();

        emit log_named_uint("postFeeYield", postFeeYield);
        emit log_named_uint("yT", yT);
        emit log_named_uint("ITOAmount", ITOAmount);
        emit log_named_uint("initialYield", initialYield);
        emit log_named_uint("targetRatio", targetRatio);

        uint256 seniorProportionCatchup = YDL.seniorProportionCatchup(
            postFeeYield,
            YDL.emaYield(),
            yT,
            supplyZSTT,
            supplyZJTT,
            YDL.retrospectiveDistributions(),
            targetRatioBIPS
        );

        assert(seniorProportionCatchup > 0);

    }

}