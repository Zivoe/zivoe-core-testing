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

contract Test_ZivoeYDL_seniorProportionShortfall is Utility {

    uint256 sSTT = 30_000_000 ether;
    uint256 sJTT = 6_000_000 ether;

    function setUp() public {
        deployCore(false);
    }

    function test_ZivoeYDL_seniorProportionShortfall_chosenValues() public {

        // State 0
        uint256 seniorRate = YDL.seniorProportionShortfall(
            sSTT,
            sJTT,
            YDL.targetRatioBIPS()
        );

        withinDiff(seniorRate, 754716981 ether, 100 ether);
        emit log_named_uint("seniorRate", seniorRate);

        // state 1
        uint256 seniorRate1 = YDL.seniorProportionShortfall(
            (sSTT * 10) / 100,
            sJTT,
            YDL.targetRatioBIPS()
        );

        assert (seniorRate1 < seniorRate);
        withinDiff(seniorRate1, 235294117 ether, 100 ether);
        emit log_named_uint("seniorRate1", seniorRate1);

        // state 2
        uint256 seniorRate2 = YDL.seniorProportionShortfall(
            sSTT,
            (sJTT * 10) / 100,
            YDL.targetRatioBIPS()
        );

        assert (seniorRate2 > seniorRate);
        withinDiff(seniorRate2, 968523002 ether, 100 ether);
        emit log_named_uint("seniorRate2", seniorRate2);

        // state 3
        uint256 seniorRate3 = YDL.seniorProportionShortfall(
            sSTT,
            sJTT,
            5000
        );

        assert (seniorRate3 > seniorRate);
        withinDiff(seniorRate3, 909090909 ether, 100 ether);
        emit log_named_uint("seniorRate3", seniorRate3);

        // state 4
        uint256 seniorRate4 = YDL.seniorProportionShortfall(
            sSTT,
            sJTT,
            100000
        );

        assert (seniorRate4 < seniorRate);
        withinDiff(seniorRate4, 333333333 ether, 100 ether);
        emit log_named_uint("seniorRate4", seniorRate4);

    }

    function test_ZivoeYDL_seniorProportionShortfall_fuzzTesting(
        uint96 seniorSupply,
        uint96 juniorSupply,
        uint32 targetRatio
    ) 
    public
    {
        hevm.assume(seniorSupply > 1 ether);
        hevm.assume(targetRatio > 0);
        uint256 seniorRate = YDL.seniorProportionShortfall(
            uint256(seniorSupply),
            uint256(juniorSupply),
            uint256(targetRatio)
        );

        assert(seniorRate > 0);
    }

}