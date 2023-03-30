// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "lib/zivoe-core-foundry/src/ZivoeYDL.sol";

// First the idea is to test for multiple values of input parameters and it's effect on returned value.

// Then in a separate test function we will also perform fuzz testing

contract Test_ZivoeYDL_seniorRateBase is Utility {

    uint256 sSTT = 30_000_000 ether;
    uint256 sJTT = 6_000_000 ether;

    function setUp() public {
        deployCore(false);
    }

    function test_ZivoeYDL_seniorRateBase_chosenValues() public {

        uint256 yT = YDL.yieldTarget(
            sSTT, sJTT, YDL.targetAPYBIPS(), YDL.targetRatioBIPS(), 30
        );

        emit log_named_uint("yT", yT);
        emit log_named_uint("yT / 10**18", yT / 10**18);

        uint256 seniorRateBase = YDL.seniorRateBase(
            yT,
            sSTT,
            YDL.targetAPYBIPS(),
            30
        );
        
        emit log_named_uint("seniorRateBase", seniorRateBase);
        emit log_named_uint("seniorRateBase / (RAY/10**4)", seniorRateBase / (RAY/10**4));

        seniorRateBase = YDL.seniorRateBase(
            1_000_000 ether,
            sSTT,
            YDL.targetAPYBIPS(),
            30
        );
        
        emit log_named_uint("seniorRateBase", seniorRateBase);
        emit log_named_uint("seniorRateBase / (RAY/10**4)", seniorRateBase / (RAY/10**4));

        seniorRateBase = YDL.seniorRateBase(
            2_000_000 ether,
            sSTT,
            YDL.targetAPYBIPS(),
            30
        );
        
        emit log_named_uint("seniorRateBase", seniorRateBase);
        emit log_named_uint("seniorRateBase / (RAY/10**4)", seniorRateBase / (RAY/10**4));

    }

    function test_ZivoeYDL_seniorRateBase_fuzzTesting(
        uint88 yD,
        uint96 eSTT,
        uint16 Y,
        uint8 T

    ) public {

        // We can assume that yield distributed is greater than 0,
        // otherwise no need of distributing yield.
        hevm.assume(yD > 0);
        hevm.assume(Y > 1);
        hevm.assume(T >= 1);
        hevm.assume(eSTT > 1 ether);

        assert (YDL.seniorRateBase(yD, eSTT, Y, T) > 0);
    }

}