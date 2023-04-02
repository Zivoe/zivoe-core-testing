// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "lib/zivoe-core-foundry/src/ZivoeYDL.sol";

contract Test_ZivoeYDL_seniorProportion is Utility {

    uint256 sSTT = 30_000_000 ether;
    uint256 sJTT = 6_000_000 ether;

    function setUp() public {
        deployCore(false);
    }

    function test_ZivoeYDL_seniorProportion_shortFallScenario() public {
        // testing for yT > yD (shortfall) here

        uint256 yD = 200_000 ether;
        uint256 yT = 250_000 ether;
        uint256 yA = 230_000 ether;
        uint256 eSTT = 30_000_000 ether;
        uint256 eJTT = 6_000_000 ether;

        uint256 seniorProportion = YDL.seniorProportion(
            yD, // yD
            yT, // yT
            yA, // yA
            eSTT, // eSTT
            eJTT, // eJTT
            YDL.targetAPYBIPS(), // Y
            YDL.targetRatioBIPS(), // Q
            YDL.daysBetweenDistributions(), // T
            YDL.retrospectiveDistributions() // R
        );

        uint256 seniorProportionShortfall = YDL.seniorProportionShortfall(
            eSTT, // eSTT
            eJTT, // eJTT
            16250 // Q
        );

        uint256 seniorProportionCatchup = YDL.seniorProportionCatchup(
            yD,
            yA,
            yT,
            eSTT,
            eJTT,
            YDL.retrospectiveDistributions(),
            YDL.targetRatioBIPS()
        );

        uint256 seniorRateBase = YDL.seniorRateBase(
            yD,
            eSTT,
            YDL.targetAPYBIPS(),
            YDL.daysBetweenDistributions()
        );

        assert(seniorProportion == seniorProportionShortfall);
        assert(seniorProportion != seniorProportionCatchup);
        assert(seniorProportion != seniorRateBase);

    }

    function test_ZivoeYDL_seniorProportion_catchupScenario() public {
        // testing for yD > yT && yT >= yA (excess + catchup) here

        uint256 yD = 251_000 ether;
        uint256 yT = 250_000 ether;
        uint256 yA = 230_000 ether;
        uint256 eSTT = 30_000_000 ether;
        uint256 eJTT = 6_000_000 ether;

        uint256 seniorProportion = YDL.seniorProportion(
            yD, // yD
            yT, // yT
            yA, // yA
            eSTT, // eSTT
            eJTT, // eJTT
            YDL.targetAPYBIPS(), // Y
            YDL.targetRatioBIPS(), // Q
            YDL.daysBetweenDistributions(), // T
            YDL.retrospectiveDistributions() // R
        );

        uint256 seniorProportionShortfall = YDL.seniorProportionShortfall(
            eSTT, // eSTT
            eJTT, // eJTT
            16250 // Q
        );

        uint256 seniorProportionCatchup = YDL.seniorProportionCatchup(
            yD,
            yA,
            yT,
            eSTT,
            eJTT,
            YDL.retrospectiveDistributions(),
            YDL.targetRatioBIPS()
        );

        uint256 seniorRateBase = YDL.seniorRateBase(
            yD,
            eSTT,
            YDL.targetAPYBIPS(),
            YDL.daysBetweenDistributions()
        );

        assert(seniorProportion != seniorProportionShortfall);
        assert(seniorProportion == seniorProportionCatchup);
        assert(seniorProportion != seniorRateBase);

    }   

    function test_ZivoeYDL_seniorProportion_baseScenario() public {
        // testing for yD > yT && yT < yA (excess + base) here

        uint256 yD = 251_000 ether;
        uint256 yT = 210_000 ether;
        uint256 yA = 230_000 ether;
        uint256 eSTT = 30_000_000 ether;
        uint256 eJTT = 6_000_000 ether;

        uint256 seniorProportion = YDL.seniorProportion(
            yD, // yD
            yT, // yT
            yA, // yA
            eSTT, // eSTT
            eJTT, // eJTT
            YDL.targetAPYBIPS(), // Y
            YDL.targetRatioBIPS(), // Q
            YDL.daysBetweenDistributions(), // T
            YDL.retrospectiveDistributions() // R
        );

        uint256 seniorProportionShortfall = YDL.seniorProportionShortfall(
            eSTT, // eSTT
            eJTT, // eJTT
            16250 // Q
        );

        uint256 seniorProportionCatchup = YDL.seniorProportionCatchup(
            yD,
            yA,
            yT,
            eSTT,
            eJTT,
            YDL.retrospectiveDistributions(),
            YDL.targetRatioBIPS()
        );

        uint256 seniorRateBase = YDL.seniorRateBase(
            yD,
            eSTT,
            YDL.targetAPYBIPS(),
            YDL.daysBetweenDistributions()
        );

        assert(seniorProportion != seniorProportionShortfall);
        assert(seniorProportion != seniorProportionCatchup);
        assert(seniorProportion == seniorRateBase);

    } 

}