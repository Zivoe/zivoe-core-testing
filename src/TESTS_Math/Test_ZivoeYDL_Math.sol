// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "lib/zivoe-core-foundry/src/ZivoeYDL.sol";

contract Test_ZivoeYDL_Math is Utility {
    
    function setUp() public {
        deployCore(false);
    }

    function test_ZivoeYDL_Math_yieldTarget_0() public {

        (uint256 sSTT, uint256 sJTT) = GBL.adjustedSupplies();

        sSTT = 10_000_000 ether;
        sJTT = 1_000_000 ether;

        uint256 yieldTarget = YDL.yieldTarget(
            sSTT, 
            sJTT, 
            YDL.targetAPYBIPS(), 
            YDL.targetRatioBIPS(), 
            YDL.daysBetweenDistributions()
        );

        emit Debug('yieldTarget', yieldTarget);
    }

    function test_ZivoeYDL_Math_yieldTarget_1() public {

        (uint256 sSTT, uint256 sJTT) = GBL.adjustedSupplies();

        // sSTT = 10,000,000
        // sJTT = 2,000,000
        // defaults = 500,000
        // --------------------
        // sSTT = 10,000,000
        // sJTT = 1,500,000

        sSTT = 10_000_000 ether;
        sJTT = 1_000_000 ether; // 25% discount ... [75-100] ... .75 DAI = 1 zJTT ... 

        // sSTT = 8_000_000 ether;
        // sJTT = 2_000_000 ether;

        uint256 yieldTarget = YDL.yieldTarget(
            sSTT, 
            sJTT, 
            YDL.targetAPYBIPS(), 
            YDL.targetRatioBIPS(), 
            YDL.daysBetweenDistributions()
        );

        emit Debug('yieldTarget', yieldTarget);
    }

    function test_ZivoeYDL_Math_yieldTarget_fuzz(
        uint96 _sSTT, uint96 _sJTT, uint24 _Y, uint24 _Q
    ) public {

        uint sSTT = uint(_sSTT);
        uint sJTT = uint(_sJTT);
        uint Y = uint(_Y + 1);
        uint Q = uint(_Q + 1);
        uint BIPS = 10000;
        uint T = 30;

        // 0, 0, 0, 79228162514264337593543950335

        /**
            @notice     Calculates amount of annual yield required to meet target rate for both tranches.
            @param      sSTT = total supply of senior tranche token     (units = WEI)
            @param      sJTT = total supply of junior tranche token     (units = WEI)
            @param      Y    = target annual yield for senior tranche   (units = BIPS)
            @param      Q    = multiple of Y                            (units = BIPS)
            @param      T    = # of days between distributions          (units = integer)
            @dev        (Y * T * (sSTT + sJTT * Q / BIPS) / BIPS) / 365
            @dev        Precision of the return value is in WEI.
        */

        emit Debug('a', (sSTT + sJTT * Q));
        emit Debug('b', Y * T);
        emit Debug('c', Y * T * (sSTT + sJTT * Q / BIPS));

        uint256 yieldTarget = YDL.yieldTarget(
            sSTT, 
            sJTT, 
            Y, // YDL.targetAPYBIPS(), 
            Q, // YDL.targetRatioBIPS(), 
            T // YDL.daysBetweenDistributions()
        );

        assertEq(
            yieldTarget,
            (Y * T * (sSTT + sJTT * Q / BIPS) / BIPS) / 365
        );

        emit Debug('yieldTarget', yieldTarget);
    }

    function test_ZivoeYDL_Math_seniorRateBase_0() public {

        (uint256 sSTT, uint256 sJTT) = GBL.adjustedSupplies();

        uint256 seniorRateBase = YDL.seniorRateBase(
            100000 ether,
            sSTT,
            YDL.targetAPYBIPS(),
            YDL.daysBetweenDistributions()
        );

        emit Debug('seniorRateBase', seniorRateBase);

        uint256 juniorProportion = YDL.juniorProportion(
            sSTT,
            sJTT,
            seniorRateBase,    // RAY precision
            YDL.targetRatioBIPS()
        );

        emit Debug('juniorProportion', juniorProportion);
    }

    function test_ZivoeYDL_Math_seniorProportionShortfall_0() public {

        (uint256 sSTT, uint256 sJTT) = GBL.adjustedSupplies();

        uint256 seniorProportionShortfall = YDL.seniorProportionShortfall(
            sSTT,
            sJTT,
            YDL.targetRatioBIPS()
        );

        emit Debug('seniorProportionShortfall', seniorProportionShortfall);

        uint256 juniorProportion = YDL.juniorProportion(
            sSTT,
            sJTT,
            seniorProportionShortfall,    // RAY precision
            YDL.targetRatioBIPS()
        );

        emit Debug('juniorProportion', juniorProportion);
    }

    function test_ZivoeYDL_Math_seniorProportionCatchup_0() public {

        (uint256 sSTT, uint256 sJTT) = GBL.adjustedSupplies();

        uint256 seniorProportionCatchup = YDL.seniorProportionCatchup(
            25000 ether,
            25000 ether, // NOTE: this is "emaYield" ... 
            33500 ether, // NOTE: this is "yT" ... 
            sSTT,
            sJTT,
            YDL.retrospectiveDistributions(),
            YDL.targetRatioBIPS()
        );

        emit Debug('seniorProportionCatchup', seniorProportionCatchup);

        uint256 juniorProportion = YDL.juniorProportion(
            sSTT,
            sJTT,
            seniorProportionCatchup,    // RAY precision
            YDL.targetRatioBIPS()
        );

        emit Debug('juniorProportion', juniorProportion);
    }

    function test_ZivoeYDL_Math_seniorProportion_RAY_0() public {

        (uint256 sSTT, uint256 sJTT) = GBL.adjustedSupplies();

        uint256 seniorProportion = YDL.seniorProportion(
            100000 ether,
            YDL.yieldTarget(sSTT, sJTT, YDL.targetAPYBIPS(), YDL.targetRatioBIPS(), YDL.daysBetweenDistributions()),
            YDL.emaYield(),
            sSTT,
            sJTT,
            YDL.targetAPYBIPS(),
            YDL.targetRatioBIPS(),
            YDL.daysBetweenDistributions(),
            YDL.retrospectiveDistributions()
        );

        emit Debug('seniorProportion', seniorProportion);

        uint256 juniorProportion = YDL.juniorProportion(
            sSTT,
            sJTT,
            seniorProportion,    // RAY precision
            YDL.targetRatioBIPS()
        );

        emit Debug('juniorProportion', juniorProportion);
    }

    function test_ZivoeYDL_Math_juniorProportion_0() public {

        (uint256 sSTT, uint256 sJTT) = GBL.adjustedSupplies();

        uint256 juniorProportion = YDL.juniorProportion(
            sSTT,
            sJTT,
            326975476839237057220708446,    // RAY precision (0.3269 % => senior tranche)
            YDL.targetRatioBIPS()
        );

        emit Debug('juniorProportion', juniorProportion);
    }

    function test_ZivoeYDL_Math_juniorProportion_1() public {

        (uint256 sSTT, uint256 sJTT) = GBL.adjustedSupplies();

        uint256 juniorProportion = YDL.juniorProportion(
            sSTT,
            sJTT,
            0.30 * 10**27,
            YDL.targetRatioBIPS()
        );

        emit Debug('juniorProportion', juniorProportion);

        juniorProportion = YDL.juniorProportion(
            sSTT,
            sJTT,
            0.40 * 10**27,
            YDL.targetRatioBIPS()
        );

        emit Debug('juniorProportion', juniorProportion);

        juniorProportion = YDL.juniorProportion(
            sSTT,
            sJTT,
            0.50 * 10**27,
            YDL.targetRatioBIPS()
        );

        emit Debug('juniorProportion', juniorProportion);
    }

    // Miscellaneous tests, unrelated.

    function test_gas_1() public pure returns (bool bob) {
        bob = ((address(5) == address(0)) || (address(34343434) == address(0)));
    }

    function test_gas_2() public pure returns (bool bob) {
        bob = ((uint160(address(5))) | (uint160(address(34343434))) == 0);
    }

    function test_gas_3() public pure returns (bool bob) {
        bob = ((uint160(address(5)) == 0) || (uint160(address(34343434)) == 0));
    }

    function test_gas_4() public pure returns (bool bob) {
        bob = ((uint160(address(5)) | uint160(address(34343434))) == 0);
    }

    function test_gas_5() public pure returns (bool bob) {
        bob = ((uint160(address(5)) * uint160(address(34343434))) == 0);
    }
}
