// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../Utility/Utility.sol";

contract Test_ZivoeMath_seniorProportionBase is Utility {

    function setUp() public {
        deployCore(false);
    }

    function test_ZivoeMath_seniorProportionBase_static() public {

        uint256 yD = 66_666 ether;
        uint256 eSTT = 8_000_000 ether;

        uint256 sPB1 = MATH.seniorProportionBase(
            yD,     
            eSTT,   
            YDL.targetAPYBIPS(), // Y
            YDL.daysBetweenDistributions() // T       
        );

        withinDiff(sPB1, 986311233 ether, 100 ether);

        uint256 sPB2 = MATH.seniorProportionBase(
            yD * 50 / 100,     
            eSTT,   
            YDL.targetAPYBIPS(), // Y
            YDL.daysBetweenDistributions() // T       
        );

        assert(sPB1 < sPB2);
        assert(sPB2 == RAY);

        uint256 sPB3 = MATH.seniorProportionBase(
            yD,     
            eSTT * 10 / 100,   
            YDL.targetAPYBIPS(), // Y
            YDL.daysBetweenDistributions() // T       
        );

        assert(sPB3 < sPB1);
        withinDiff(sPB3, 98631123 ether, 100 ether);

        uint256 sPB4 = MATH.seniorProportionBase(
            yD,     
            eSTT,   
            YDL.targetAPYBIPS() + 200, // Y
            YDL.daysBetweenDistributions() // T       
        );

        assert(sPB4 > sPB1);
        withinDiff(sPB4, 1000000000 ether, 100 ether);

    }

    function test_ZivoeMath_seniorProportionBase_fuzzTesting(
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

        uint256 sPB = MATH.seniorProportionBase(yD, eSTT, Y, T);
        
        assert(sPB > 0 && sPB <= RAY);
    }

}