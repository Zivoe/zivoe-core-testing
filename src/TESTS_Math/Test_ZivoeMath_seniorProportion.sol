// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../Utility/Utility.sol";

contract Test_ZivoeMath_seniorProportion is Utility {

    function setUp() public {
        deployCore(false);
    }

    function test_ZivoeMath_seniorProportion_shortFallScenario() public {
        // testing for yT > yD (shortfall)
        uint256 yD = 66_000 ether;
        uint256 yT = 66_666 ether;
        uint256 yA = 65_000 ether;
        uint256 eSTT = 8_000_000 ether;
        uint256 eJTT = 2_000_000 ether;

        uint256 seniorProportion = MATH.seniorProportion(
            yD, 
            yT, 
            eSTT, 
            eJTT, 
            YDL.targetAPYBIPS(), // Y
            YDL.targetRatioBIPS(), // Q
            YDL.daysBetweenDistributions() // T
        );

        uint256 seniorProportionShortfall = MATH.seniorProportionShortfall(
            eSTT, 
            eJTT, 
            22000 // Q
        );

        uint256 seniorProportionBase = MATH.seniorProportionBase(
            yD,
            eSTT,
            YDL.targetAPYBIPS(), // Y
            YDL.daysBetweenDistributions() // T
        );

        assert(seniorProportion == seniorProportionShortfall);
        assert(seniorProportion != seniorProportionBase);
    }

    function test_ZivoeMath_seniorProportion_baseScenario() public {
        // testing for yD > yT && yT < yA (excess + base) here
        uint256 yD = 66_700 ether;
        uint256 yT = 66_666 ether;
        uint256 yA = 67_000 ether;
        uint256 eSTT = 8_000_000 ether;
        uint256 eJTT = 2_000_000 ether;

        uint256 seniorProportion = MATH.seniorProportion(
            yD, 
            yT, 
            eSTT, 
            eJTT, 
            YDL.targetAPYBIPS(), // Y
            YDL.targetRatioBIPS(), // Q
            YDL.daysBetweenDistributions() // T
        );

        uint256 seniorProportionShortfall = MATH.seniorProportionShortfall(
            eSTT, 
            eJTT, 
            22000 // Q
        );

        uint256 seniorProportionBase = MATH.seniorProportionBase(
            yD,
            eSTT,
            YDL.targetAPYBIPS(), // Y
            YDL.daysBetweenDistributions() // R
        );

        assert(seniorProportion != seniorProportionShortfall);
        assert(seniorProportion == seniorProportionBase);
    } 

}