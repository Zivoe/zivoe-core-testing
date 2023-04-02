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
}