// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "lib/zivoe-core-foundry/src/ZivoeYDL.sol";

contract Test_ZivoeYDL_seniorProportion is Utility {

    function setUp() public {
        deployCore(false);
    }

    function test_ZivoeYDL_seniorProportion_shortFallScenario() public {
        // testing for yT > yD (shortfall)
        uint256 yD = 66_000 ether;
        uint256 yT = 66_666 ether;
        uint256 yA = 65_000 ether;
        uint256 eSTT = 8_000_000 ether;
        uint256 eJTT = 2_000_000 ether;

        uint256 seniorProportion = YDL.seniorProportion(
            yD, 
            yT, 
            yA, 
            eSTT, 
            eJTT, 
            YDL.targetAPYBIPS(), // Y
            YDL.targetRatioBIPS(), // Q
            YDL.daysBetweenDistributions(), // T
            YDL.retrospectiveDistributions() // R
        );

        uint256 seniorProportionShortfall = YDL.seniorProportionShortfall(
            eSTT, 
            eJTT, 
            16250 // Q
        );

        uint256 seniorProportionCatchup = YDL.seniorProportionCatchup(
            yD,
            yT,
            yA,
            eSTT,
            eJTT,
            YDL.retrospectiveDistributions(), // R
            YDL.targetRatioBIPS() // Q
        );

        uint256 seniorProportionBase = YDL.seniorProportionBase(
            yD,
            eSTT,
            YDL.targetAPYBIPS(), // Y
            YDL.daysBetweenDistributions() // T
        );

        assert(seniorProportion == seniorProportionShortfall);
        assert(seniorProportion != seniorProportionCatchup);
        assert(seniorProportion != seniorProportionBase);
    }

    function test_ZivoeYDL_seniorProportion_catchupScenario() public {
        // testing for yD > yT && yT >= yA (excess + catchup) here
        uint256 yD = 67_000 ether;
        uint256 yT = 66_666 ether;
        uint256 yA = 65_000 ether;
        uint256 eSTT = 8_000_000 ether;
        uint256 eJTT = 2_000_000 ether;

        uint256 seniorProportion = YDL.seniorProportion(
            yD, 
            yT, 
            yA, 
            eSTT, 
            eJTT, 
            YDL.targetAPYBIPS(), // Y
            YDL.targetRatioBIPS(), // Q
            YDL.daysBetweenDistributions(), // T
            YDL.retrospectiveDistributions() // R
        );

        uint256 seniorProportionShortfall = YDL.seniorProportionShortfall(
            eSTT, 
            eJTT, 
            16250 // Q
        );

        uint256 seniorProportionCatchup = YDL.seniorProportionCatchup(
            yD,
            yT,
            yA,
            eSTT,
            eJTT,
            YDL.retrospectiveDistributions(), // R
            YDL.targetRatioBIPS() // Q
        );

        uint256 seniorProportionBase = YDL.seniorProportionBase(
            yD,
            eSTT,
            YDL.targetAPYBIPS(), // Y
            YDL.daysBetweenDistributions() // T
        );

        assert(seniorProportion != seniorProportionShortfall);
        assert(seniorProportion == seniorProportionCatchup);
        assert(seniorProportion != seniorProportionBase);
    }   

    function test_ZivoeYDL_seniorProportion_baseScenario() public {
        // testing for yD > yT && yT < yA (excess + base) here
        uint256 yD = 66_000 ether;
        uint256 yT = 66_666 ether;
        uint256 yA = 67_000 ether;
        uint256 eSTT = 8_000_000 ether;
        uint256 eJTT = 2_000_000 ether;

        uint256 seniorProportion = YDL.seniorProportion(
            yD, 
            yT, 
            yA, 
            eSTT, 
            eJTT, 
            YDL.targetAPYBIPS(), // Y
            YDL.targetRatioBIPS(), // Q
            YDL.daysBetweenDistributions(), // T
            YDL.retrospectiveDistributions() // R
        );

        uint256 seniorProportionShortfall = YDL.seniorProportionShortfall(
            eSTT, 
            eJTT, 
            16250 // Q
        );

        uint256 seniorProportionCatchup = YDL.seniorProportionCatchup(
            yD,
            yT,
            yA,
            eSTT,
            eJTT,
            YDL.retrospectiveDistributions(), // R
            YDL.targetRatioBIPS() // Q
        );

        uint256 seniorProportionBase = YDL.seniorProportionBase(
            yD,
            eSTT,
            YDL.targetAPYBIPS(), // Y
            YDL.daysBetweenDistributions() // R
        );

        assert(seniorProportion != seniorProportionShortfall);
        assert(seniorProportion != seniorProportionCatchup);
        assert(seniorProportion == seniorProportionBase);
    } 

}