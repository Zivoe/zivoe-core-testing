// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "lib/zivoe-core-foundry/src/ZivoeYDL.sol";
import "lib/zivoe-core-foundry/src/libraries/FloorMath.sol";

contract Test_ZivoeYDL_ema is Utility {

    using FloorMath for uint256;

    function setUp() public {
        deployCore(false);
    }

    // Testing for first window (when number of steps < number steps we are averaging over)
    function test_ZivoeYDL_ema_firstWindow_chosenValues() public {

        // cV > bV
        uint256 eV = YDL.ema(
            2000, // bV
            2500, // cV
            2     // N
        );

        assert(eV == 2250);
        emit log_named_uint("eV", eV);

        // cv < bV
        eV = YDL.ema(
            2500, // bV
            2000, // cV
            2     // N
        );

        assert(eV == 2250);
        emit log_named_uint("eV", eV);
    }

    // Testing for first window (when number of steps < number steps we are averaging over)
    function test_ZivoeYDL_ema_afterWindow_chosenValues() public {

        // bV < cV
        uint256 eV = YDL.ema(
            2000, // bV
            2500, // cV
            6     // N
        );

        assert(eV == 2083);
        emit log_named_uint("eV", eV);

        // bV > cV
        eV = YDL.ema(
            2500, // bV
            2000, // cV
            6     // N
        );

        assert(eV == 2416);
        emit log_named_uint("eV", eV);
    }

    // Testing for first window (when number of steps < number steps we are averaging over)
    function test_ZivoeYDL_ema_fuzzTesting(
        uint96 bV,
        uint96 cV,
        uint96 N
    ) public {
        // We always initiate the first value for "bV" in the code
        hevm.assume(bV > 0);
        // We increment the number of distributions prior calling ema()
        hevm.assume(N > 0);

        // Here we have to assume that the difference between "bV" and "cV"
        // is at least bigger than max value of "retrospectiveDistributions"
        // otherwise it will have no impact on new value as division would give 0
        // (no issue as we should deal with values in WEI and amount
        // of "retrospectiveDistributions" should be limited)
        if (bV != cV && bV > cV) { hevm.assume(bV - cV > 255); }
        if (bV != cV && bV < cV) { hevm.assume(cV - bV > 255); }

        uint256 ema = YDL.ema(
            bV,
            cV,
            uint256(YDL.retrospectiveDistributions()).min(uint256(N))
        );

        if (cV > bV) { assert(ema > bV); } 
        else if (cV == bV) { assert(ema == bV); }
        else { assert(ema < bV); }
    }

    function test_ZivoeYDL_ema_example_increaseHigh() public {
        
        uint8 increaseFactor = 3;
        // We assume on first step that "eV" has been initialized to 2000
        uint256 eV = 2000;
        uint8 N = 1;

        for (uint8 i = 0; i < 12; i++) {
            N += 1;
            eV = YDL.ema(
                eV,
                eV * increaseFactor, // We increase "eV" at each step by a factor of 3
                N > 6 ? 6 : N
            );
            emit log_named_uint("eV", eV);
        }
    }

    function test_ZivoeYDL_ema_example_decreaseHigh() public {

        uint256 eV = 2000;
        uint8 N = 1;

        for (uint8 i = 0; i < 12; i++) {
            N += 1;
            eV = YDL.ema(
                eV,
                (eV * 50) / 100, // We decrease "eV" at each step by 50%
                N > 6 ? 6 : N
            );
            emit log_named_uint("eV", eV);
        }
    }

    // Here the objective is to test for zero values till "eV" reaches a value of 0 as well.
    function test_ZivoeYDL_ema_example_zeroValues() public {

        uint256 eV = 500 ether;
        uint8 N = 1;

        for (uint8 i = 0; i < 25; i++) {
            N += 1;
            eV = YDL.ema(
                eV,
                0, // We have a "0" value for a certain period of time
                N > 6 ? 6 : N
            );
            emit log_named_uint("eV", eV);
        }
    }

    function test_ZivoeYDL_ema_example_calcs() public {

        uint256 eV = 10_000_000;
        uint256 eV_v2 = 10_000_000;
        uint8 N = 6;

        uint256[6] memory arr = [uint256(10_000_000), 10_500_000, 10_900_000, 11_900_000, 13_500_000, 16_500_000];
        
        for (uint8 i = 0; i < arr.length; i++) {
            eV = YDL.ema(
                eV,
                arr[i],
                6
            );
            eV_v2 = YDL.ema_v2(
                eV_v2,
                arr[i],
                6
            );
            emit log_named_uint("eV", eV);
            emit log_named_uint("eV_v2", eV_v2);
        }
    }

}