// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "lib/zivoe-core-foundry/src/ZivoeYDL.sol";

// 1) First the idea is to test for multiple values of input parameters and it's effect on returned value.

// Test 1
// sSTT = 10% of initial amount

// Test 2
// sJTT = 10% of initial amount

// Test 3
// Target annual yield for senior tranche (Y) = 1%

// Test 4
// Target annual yield for senior tranche (Y) = 20%

// Test 5
// Multiplication factor = 0.5

// Test 6
// Multiplication factor = 10

// Test 7
// Number of days (T) = 1

// 2) Then in a separate test function we will also perform fuzz testing

contract Test_ZivoeYDL_targetYield is Utility {

    uint256 sSTT = 30_000_000 ether;
    uint256 sJTT = 6_000_000 ether;

    function setUp() public {
        deployCore(false);
        //simulateITO(1_000_000 ether, 1_000_000 ether, 1_000_000 * 10**6, 1_000_000 * 10**6);
        //claimITO_and_approveTokens_and_stakeTokens(true);
    }

    function test_ZivoeYDL_yieldTargetDual_chosenValues() public {

        // State 0
        uint256 yieldTarget0 = YDL.yieldTarget(
            sSTT, 
            sJTT, 
            YDL.targetAPYBIPS(), 
            YDL.targetRatioBIPS(), 
            YDL.daysBetweenDistributions()
        );

        withinDiff(yieldTarget0, 261369863013698630136986, 2);

        (uint256 seniorYieldTarget0, uint256 juniorYieldTarget0) = YDL.yieldTargetDual(
            sSTT, 
            sJTT, 
            YDL.targetAPYBIPS(), 
            YDL.targetRatioBIPS(), 
            YDL.daysBetweenDistributions()
        );

        withinDiff(yieldTarget0, seniorYieldTarget0 + juniorYieldTarget0, 2);
        

        emit log_named_uint("yieldTarget0", yieldTarget0);
        emit log_named_uint("seniorYieldTarget0", seniorYieldTarget0);
        emit log_named_uint("juniorYieldTarget0", juniorYieldTarget0);
    }
    
}