// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "lib/zivoe-core-foundry/src/ZivoeYDL.sol";

// Note: We should replace all postFeeYield by preFeeYield in YDL accounting
// Note: rateSenior is a rate (in %) and not an amount (just for info)


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

    function test_ZivoeYDL_seniorRateNominal_chosenValues() public {

        uint256 yT = YDL.yieldTarget(
            sSTT, sJTT, YDL.targetAPYBIPS(), YDL.targetRatioBIPS(), 30
        );

        emit log_named_uint("yT", yT);
        emit log_named_uint("yT / 10**18", yT / 10**18);

        uint256 seniorRateNominal = YDL.seniorRateBase(
            yT,
            sSTT,
            YDL.targetAPYBIPS(),
            30
        );
        
        emit log_named_uint("seniorRateNominal", seniorRateNominal);
        emit log_named_uint("seniorRateNominal / (RAY/10**4)", seniorRateNominal / (RAY/10**4));

        seniorRateNominal = YDL.seniorRateBase(
            1_000_000 ether,
            sSTT,
            YDL.targetAPYBIPS(),
            30
        );
        
        emit log_named_uint("seniorRateNominal", seniorRateNominal);
        emit log_named_uint("seniorRateNominal / (RAY/10**4)", seniorRateNominal / (RAY/10**4));

        seniorRateNominal = YDL.seniorRateBase(
            2_000_000 ether,
            sSTT,
            YDL.targetAPYBIPS(),
            30
        );
        
        emit log_named_uint("seniorRateNominal", seniorRateNominal);
        emit log_named_uint("seniorRateNominal / (RAY/10**4)", seniorRateNominal / (RAY/10**4));

    }

}