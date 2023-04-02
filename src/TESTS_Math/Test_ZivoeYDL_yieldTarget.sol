// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "lib/zivoe-core-foundry/src/ZivoeYDL.sol";

// 1) First the idea is to test for multiple values of input parameters and it's effect on returned value.

// Test 1
// eSTT = 10% of initial amount

// Test 2
// eJTT = 10% of initial amount

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

contract Test_ZivoeYDL_yieldTarget is Utility {

    uint256 eSTT = 8_000_000 ether;
    uint256 eJTT = 2_000_000 ether;

    function setUp() public {
        deployCore(false);
    }

    function test_ZivoeYDL_yieldTarget_chosenValues() public {

        // State 0
        uint256 yieldTarget0 = YDL.yieldTarget(
            eSTT, 
            eJTT, 
            YDL.targetAPYBIPS(), 
            YDL.targetRatioBIPS(), 
            YDL.daysBetweenDistributions()
        );

        withinDiff(yieldTarget0, 261_300 ether, 100 ether);
        emit log_named_uint("yieldTarget0", yieldTarget0);

        // Test 1
        uint256 yieldTarget1 = YDL.yieldTarget(
            (eSTT * 10) / 100, 
            eJTT, 
            YDL.targetAPYBIPS(), 
            YDL.targetRatioBIPS(), 
            YDL.daysBetweenDistributions()
        );

        assert(yieldTarget1 < yieldTarget0);
        withinDiff(yieldTarget1, 83_800 ether, 100 ether);
        emit log_named_uint("yieldTarget1", yieldTarget1);

        // Test 2
        uint256 yieldTarget2 = YDL.yieldTarget(
            eSTT, 
            (eJTT * 10) / 100, 
            YDL.targetAPYBIPS(), 
            YDL.targetRatioBIPS(), 
            YDL.daysBetweenDistributions()
        );

        assert(yieldTarget2 < yieldTarget0);
        withinDiff(yieldTarget2, 203_600 ether, 100 ether);
        emit log_named_uint("yieldTarget2", yieldTarget2);

        // Test 3
        uint256 yieldTarget3 = YDL.yieldTarget(
            eSTT, 
            eJTT, 
            100, 
            YDL.targetRatioBIPS(), 
            YDL.daysBetweenDistributions()
        );

        assert(yieldTarget3 < yieldTarget0);
        withinDiff(yieldTarget3, 32_600 ether, 100 ether);
        emit log_named_uint("yieldTarget3", yieldTarget3);

        // Test 4
        uint256 yieldTarget4 = YDL.yieldTarget(
            eSTT, 
            eJTT, 
            2000,
            YDL.targetRatioBIPS(), 
            YDL.daysBetweenDistributions()
        );

        assert(yieldTarget4 > yieldTarget0 && yieldTarget4 > yieldTarget3);
        withinDiff(yieldTarget4, 653_400 ether, 100 ether);
        emit log_named_uint("yieldTarget4", yieldTarget4);

        // Test 5
        uint256 yieldTarget5 = YDL.yieldTarget(
            eSTT, 
            eJTT, 
            YDL.targetAPYBIPS(), 
            5000, 
            YDL.daysBetweenDistributions()
        );

        assert(yieldTarget5 < yieldTarget0);
        withinDiff(yieldTarget5, 216_900 ether, 100 ether);
        emit log_named_uint("yieldTarget5", yieldTarget5);

        // Test 6
        uint256 yieldTarget6 = YDL.yieldTarget(
            eSTT, 
            eJTT, 
            YDL.targetAPYBIPS(), 
            100000, 
            YDL.daysBetweenDistributions()
        );

        assert(yieldTarget6 > yieldTarget0 && yieldTarget6 > yieldTarget5);
        withinDiff(yieldTarget6, 591_700 ether, 100 ether);
        emit log_named_uint("yieldTarget6", yieldTarget6);

        // Test 7
        uint256 yieldTarget7 = YDL.yieldTarget(
            eSTT, 
            eJTT, 
            YDL.targetAPYBIPS(), 
            YDL.targetRatioBIPS(), 
            1
        );

        assert(yieldTarget7 < yieldTarget0);
        withinDiff(yieldTarget7, 8_700 ether, 100 ether);
        emit log_named_uint("yieldTarget7", yieldTarget7);
    }

    function test_ZivoeYDL_yieldTarget_fuzzTesting(
        uint96 eSTT,
        uint96 eJTT,
        uint16 Y,
        uint32 Q,
        uint16 T
    ) public {
        hevm.assume(Y < 10000 && Y > 100);
        hevm.assume(Q > 0);
        hevm.assume(T > 0);
        hevm.assume(eSTT > 1 ether);

        uint256 yieldTarget = YDL.yieldTarget(
            uint256(eSTT), 
            uint256(eJTT), 
            uint256(Y), 
            uint256(Q), 
            T
        );

        assert(yieldTarget > 0);
    }

}