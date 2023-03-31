// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "lib/zivoe-core-foundry/src/ZivoeYDL.sol";

contract Test_ZivoeYDL_ema is Utility {

    function setUp() public {
        deployCore(false);
    }    

    // Testing for first window (when number of steps < number steps we are averaging over)
    function test_ZivoeYDL_ema_firstWindow_chosenValues() public {

        // t < N && newval > avg
        uint256 ema = YDL.ema(
            2000, // avg
            2500, // newval
            6,    // N
            2     // t
        );

        assert(ema == 2250);
        emit log_named_uint("ema", ema);

        // t < N && newval < avg
        ema = YDL.ema(
            2500, // avg
            2000, // newval
            6,    // N
            2     // t
        );

        assert(ema == 2250);
        emit log_named_uint("ema", ema);

    }

    // Testing for first window (when number of steps < number steps we are averaging over)
    function test_ZivoeYDL_ema_afterWindow_chosenValues() public {

        // t > N && newval > avg
        uint256 ema = YDL.ema(
            2000, // avg
            2500, // newval
            6,    // N
            10    // t
        );

        assert(ema == 2083);
        emit log_named_uint("ema", ema);

        // t > N && newval < avg
        ema = YDL.ema(
            2500, // avg
            2000, // newval
            6,    // N
            10    // t
        );

        assert(ema == 2416);
        emit log_named_uint("ema", ema);

    }

    // Testing for first window (when number of steps < number steps we are averaging over)
    function test_ZivoeYDL_ema_fuzzTesting(
        uint96 avg,
        uint96 newval,
        uint8 retrospectiveDistributions,
        uint96 numDistributions
    ) 
    public 
    {
        // We always initiate the first value for "avg" in the code
        hevm.assume(avg > 0);
        // We have to at least average over 1 step
        hevm.assume(retrospectiveDistributions > 0);
        // We increment the number of distributions prior calling ema()
        hevm.assume(numDistributions > 0);

        // Here we have to assume that the difference between "avg" and "newval"
        // is at least bigger than max value of "retrospectiveDistributions"
        // otherwise it will have no impact on new value as division would give 0
        // (no issue as we should deal with values in WEI and amount
        // of "retrospectiveDistributions" should be limited)
        if (avg != newval && avg > newval) {
            hevm.assume(avg - newval > 255);
        }

        if (avg != newval && avg < newval) {
            hevm.assume(newval - avg > 255);
        }

        uint256 ema = YDL.ema(
            avg,
            newval,
            retrospectiveDistributions, 
            numDistributions  
        );

        if (newval > avg) {
            assert(ema > avg);
        } else if (newval == avg) {
            assert(ema == avg);
        } else {
            assert(ema < avg);
        }
    }
}