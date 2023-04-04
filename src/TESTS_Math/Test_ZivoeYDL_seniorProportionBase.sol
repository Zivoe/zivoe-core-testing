// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "lib/zivoe-core-foundry/src/ZivoeYDL.sol";

contract Test_ZivoeYDL_seniorProportionBase is Utility {

    function setUp() public {
        deployCore(false);
    }

    function test_ZivoeYDL_seniorProportionBase_static() public {

        uint256 yD = 66_666 ether;
        uint256 eSTT = 8_000_000 ether;

        uint256 sPB1 = YDL.seniorProportionBase(
            yD,     
            eSTT,   
            YDL.targetAPYBIPS(), // Y
            YDL.daysBetweenDistributions() // T       
        );

        withinDiff(sPB1, 789048986 ether, 100 ether);

        uint256 sPB2 = YDL.seniorProportionBase(
            yD * 50 / 100,     
            eSTT,   
            YDL.targetAPYBIPS(), // Y
            YDL.daysBetweenDistributions() // T       
        );

        assert(sPB1 < sPB2);
        assert(sPB2 == RAY);

        uint256 sPB3 = YDL.seniorProportionBase(
            yD,     
            eSTT * 10 / 100,   
            YDL.targetAPYBIPS(), // Y
            YDL.daysBetweenDistributions() // T       
        );

        assert(sPB3 < sPB1);
        withinDiff(sPB3, 78904899 ether, 100 ether);

        uint256 sPB4 = YDL.seniorProportionBase(
            yD,     
            eSTT,   
            YDL.targetAPYBIPS() + 200, // Y
            YDL.daysBetweenDistributions() // T       
        );

        assert(sPB4 > sPB1);
        withinDiff(sPB4, 986311233 ether, 100 ether);

    }

    function test_ZivoeYDL_seniorProportionBase_fuzzTesting(
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

        assert(YDL.seniorProportionBase(yD, eSTT, Y, T) > 0);
    }

}