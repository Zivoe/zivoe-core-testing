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

        (uint256 targetSenior, uint256 targetJunior) = YDL.yieldTargetDual(
            sSTT, sJTT, YDL.targetAPYBIPS(), YDL.targetRatioBIPS(), 30
        );

        emit log_named_uint("targetSenior", targetSenior);
        emit log_named_uint("targetJunior", targetJunior);
        emit log_named_uint("targetSenior / 10**18", targetSenior / 10**18);
        emit log_named_uint("targetJunior / 10**18", targetJunior / 10**18);

        uint256 seniorRateNominal = YDL.seniorRateNominal_RAY(
            targetSenior + targetJunior,
            sSTT,
            YDL.targetAPYBIPS(),
            30
        );
        
        emit log_named_uint("seniorRateNominal", seniorRateNominal);
        emit log_named_uint("seniorRateNominal / (RAY/10**4)", seniorRateNominal / (RAY/10**4));

        seniorRateNominal = YDL.seniorRateNominal_RAY(
            targetSenior,
            sSTT,
            YDL.targetAPYBIPS(),
            30
        );
        
        emit log_named_uint("seniorRateNominal", seniorRateNominal);
        emit log_named_uint("seniorRateNominal / (RAY/10**4)", seniorRateNominal / (RAY/10**4));

        seniorRateNominal = YDL.seniorRateNominal_RAY(
            1_000_000 ether,
            sSTT,
            YDL.targetAPYBIPS(),
            30
        );
        
        emit log_named_uint("seniorRateNominal", seniorRateNominal);
        emit log_named_uint("seniorRateNominal / (RAY/10**4)", seniorRateNominal / (RAY/10**4));

        seniorRateNominal = YDL.seniorRateNominal_RAY(
            2_000_000 ether,
            sSTT,
            YDL.targetAPYBIPS(),
            30
        );
        
        emit log_named_uint("seniorRateNominal", seniorRateNominal);
        emit log_named_uint("seniorRateNominal / (RAY/10**4)", seniorRateNominal / (RAY/10**4));

    }

}