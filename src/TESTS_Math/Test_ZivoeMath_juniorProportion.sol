// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../Utility/Utility.sol";

import "../../lib/zivoe-core-foundry/src/libraries/FloorMath.sol";

// First the idea is to test for multiple values of input parameters and it's effect on returned value.

// Test 1
// eSTT = 10% of initial amount

// Test 2
// eJTT = 10% of initial amount

// Test 3
// targetRatioBIPS = 5000

// Test 4
// targetRatioBIPS = 100000

// Test5
// sP = 10% of initial amount


// Then in a separate test function we will also perform fuzz testing

contract Test_ZivoeMath_juniorProportion is Utility {

    function setUp() public {
        deployCore(false);
    }

    // Here we will test for specific cases
    function test_ZivoeMath_juniorProportion_static() public {
        uint256 eSTT = 8_000_000 ether;
        uint256 eJTT = 2_000_000 ether;
        uint256 sP = 600000000 ether; // 60%
        uint256 Q = 16250;

        uint256 jP = MATH.juniorProportion(
            eSTT,
            eJTT,
            sP,
            Q
        );

        withinDiff(jP, 243750000 ether, 100 ether);
        
        // Test 1
        jP = MATH.juniorProportion(
            eSTT * 10 / 100,
            eJTT,
            sP,
            Q
        );

        assert(jP == (RAY - sP));

        // Test 2
        jP = MATH.juniorProportion(
            eSTT,
            eJTT * 10 / 100,
            sP,
            Q
        );

        withinDiff(jP, 24375000 ether, 100 ether);

        // Test 3
        jP = MATH.juniorProportion(
            eSTT,
            eJTT,
            sP,
            5000 // Q
        );

        withinDiff(jP, 75000000 ether, 100 ether);

        // Test 4
        jP = MATH.juniorProportion(
            eSTT,
            eJTT,
            sP,
            100_000 // Q
        );

        assert(jP == (RAY - sP));

        // Test 5
        jP = MATH.juniorProportion(
            eSTT,
            eJTT,
            sP * 10 / 100,
            Q
        );

        withinDiff(jP, 24375000 ether, 100 ether);

    }

    function test_ZivoeMath_juniorProportion_fuzzInvariant(uint128 eSTT, uint128 eJTT, uint256 sP) public {
        // We can assume the input value for "sP" will never exceed RAY (10**27).
        hevm.assume(sP <= RAY);

        uint256 jP = MATH.juniorProportion(
            eSTT, 
            eJTT, 
            sP, 
            YDL.targetRatioBIPS() // Q
        );

        // The invariant for juniorProportion() is that return value never exceeds RAY (10**27).
        assert(jP <= RAY);
    }

}