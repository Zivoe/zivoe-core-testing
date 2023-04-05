// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "lib/zivoe-core-foundry/src/ZivoeYDL.sol";

// First the idea is to test for multiple values of input parameters and it's effect on returned value.

// Test 1
// eSTT = 10% of initial amount

// Test 2
// eJTT = 10% of initial amount

// Test 3
// targetRatioBIPS = 5000

// Test 4
// targetRatioBIPS = 100000


// Then in a separate test function we will also perform fuzz testing

contract Test_ZivoeYDL_seniorProportionCatchup is Utility {

    function setUp() public {
        deployCore(false);
    }

    function test_ZivoeYDL_seniorProportionCatchup_static() public {

        uint256 eSTT = 8_000_000 ether;
        uint256 eJTT = 2_000_000 ether;
        uint256 yD = 68_000 ether;
        uint256 yT = 66_666 ether;
        uint256 yA = 64_000 ether;

        uint256 seniorProportionCatchup0 = YDL.seniorProportionCatchup(
            yD,
            yT,
            yA,
            eSTT,
            eJTT,
            YDL.retrospectiveDistributions(),
            YDL.targetRatioBIPS()
        );

        withinDiff(seniorProportionCatchup0, 864439215 ether, 100 ether);
        emit log_named_uint("seniorProportionCatchup0", seniorProportionCatchup0);
        emit log_named_uint("yA", yA);

        // Test 1
        uint256 seniorProportionCatchup1 = YDL.seniorProportionCatchup(
            yD,
            yT,
            yA,
            (eSTT * 10) / 100,
            eJTT,
            YDL.retrospectiveDistributions(),
            YDL.targetRatioBIPS()
        );

        assert(seniorProportionCatchup1 < seniorProportionCatchup0);
        withinDiff(seniorProportionCatchup1, 240122004 ether, 100 ether);
        emit log_named_uint("seniorProportionCatchup1", seniorProportionCatchup1);

        // Test 2
        uint256 seniorProportionCatchup2 = YDL.seniorProportionCatchup(
            yD,
            yT,
            yA,
            eSTT,
            (eJTT * 10) / 100,
            YDL.retrospectiveDistributions(),
            YDL.targetRatioBIPS()
        );

        assert(seniorProportionCatchup2 > seniorProportionCatchup0);
        withinDiff(seniorProportionCatchup2, 1000000000 ether, 100 ether);
        emit log_named_uint("seniorProportionCatchup2", seniorProportionCatchup2);

        // Test 3
        uint256 seniorProportionCatchup3 = YDL.seniorProportionCatchup(
            yD,
            yT,
            yA,
            eSTT,
            eJTT,
            YDL.retrospectiveDistributions(),
            5000
        );

        assert(seniorProportionCatchup3 > seniorProportionCatchup0);
        withinDiff(seniorProportionCatchup3, 1000000000 ether, 100 ether);
        emit log_named_uint("seniorProportionCatchup3", seniorProportionCatchup3);

        // Test 4
        uint256 seniorProportionCatchup4 = YDL.seniorProportionCatchup(
            yD,
            yT,
            yA,
            eSTT,
            eJTT,
            YDL.retrospectiveDistributions(),
            100000
        );

        assert(seniorProportionCatchup4 < seniorProportionCatchup0);
        withinDiff(seniorProportionCatchup4, 347319327 ether, 100 ether);
        emit log_named_uint("seniorProportionCatchup4", seniorProportionCatchup4);
    }

    function test_ZivoeYDL_seniorProportionCatchup_fuzzTesting(
        uint88 yD,
        uint88 yT,
        uint88 yA,
        uint96 eSTT,
        uint96 eJTT,
        uint16 targetRatio
    ) public {
        hevm.assume(yA < yT && yA > 0);
        hevm.assume(yD > yT);
        // We can assume that target yield for senior tranche is at least 1%.
        hevm.assume(yT >= 100);

        uint256 targetRatioBIPS = uint256(targetRatio) + 1;
        uint256 eJTT = uint256(eJTT) + 1 ether;
        uint256 eSTT = uint256(eSTT) + 1 ether;
        // here we'll assume that the senior tranche cover will not be less than 10% of junior,
        // otherwise we could obtain 0 as result
        eSTT < ((eJTT * 10) / 100) ? eSTT = ((eJTT * 10) / 100) : eSTT;

        emit log_named_uint("yD", yD);
        emit log_named_uint("yT", yT);
        emit log_named_uint("yA", yA);
        emit log_named_uint("targetRatio", targetRatio);

        uint256 seniorProportionCatchup = YDL.seniorProportionCatchup(
            yD,
            yT,
            yA,
            eSTT,
            eJTT,
            YDL.retrospectiveDistributions(),
            targetRatioBIPS
        );

        assert(seniorProportionCatchup > 0 && seniorProportionCatchup <= RAY);
    }


    function test_seniorProportionCatchup_static_0() public {

        uint256 yD = 66_675 ether;
        uint256 yA = 65_000 ether;
        uint256 yT = 66_666 ether;
        uint256 eSTT = 8_000_000 ether;
        uint256 eJTT = 2_000_000 ether;
        uint256 R = 6;
        uint256 Q = 16250;

        uint256 sPC = YDL.seniorProportionCatchup(yD, yT, yA, eSTT, eJTT, R, Q);

        emit log_named_uint("sPC", sPC);

    }

}