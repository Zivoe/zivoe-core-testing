// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../Utility/Utility.sol";

import "../../lib/zivoe-core-foundry/src/libraries/FloorMath.sol";

contract Test_ZivoeMath_ema is Utility {

    using FloorMath for uint256;

    function setUp() public {
        deployCore(false);
    }

    function test_ZivoeMath_ema_increasingValues() public {

        uint256 eV = 10_000_000;
        uint256 N = 1;

        // Increasing values.

        uint256[12] memory arr = [
            uint256(10_200_000), 10_500_000, 10_900_000, 11_900_000, 13_500_000, 16_500_000,
            uint256(17_500_000), 17_800_000, 17_900_000, 18_300_000, 20_500_000, 21_000_000
        ];
        
        for (uint8 i = 0; i < arr.length; i++) {
            N += 1;
            eV = MATH.ema(
                eV,             // bV
                arr[i],         // cV
                N.min(6)        // N (take minimum between N and 6)
            );
            emit log_named_uint("eV", eV);
        }

    }

    function test_ZivoeMath_ema_decreasingValues() public {

        uint256 eV = 21_200_000;
        uint256 N = 1;

        // Decreasing values.

        uint256[12] memory arr = [
            21_000_000, 20_500_000, 18_300_000, 17_900_000, 17_800_000, uint256(17_500_000),
            16_500_000, 13_500_000, 11_900_000, 10_900_000, 10_500_000, uint256(10_200_000)
        ];
        
        for (uint8 i = 0; i < arr.length; i++) {
            N += 1;
            eV = MATH.ema(
                eV,             // bV
                arr[i],         // cV
                N.min(6)        // N (take minimum between N and 6)
            );
            emit log_named_uint("eV", eV);
        }

    }

    function test_ZivoeMath_ema_oscillatingValues() public {

        uint256 eV = 15_000_000;
        uint256 N = 1;

        // Oscillating values.

        uint256[12] memory arr = [
            16_000_000, 14_500_000, 18_300_000, 17_900_000, 19_800_000, uint256(16_500_000),
            17_500_000, 12_500_000, 15_900_000, 18_900_000, 22_500_000, uint256(24_200_000)
        ];
        
        for (uint8 i = 0; i < arr.length; i++) {
            N += 1;
            eV = MATH.ema(
                eV,             // bV
                arr[i],         // cV
                N.min(6)        // N (take minimum between N and 6)
            );
            emit log_named_uint("eV", eV);
        }

    }

    // Testing for first window (when number of steps < number steps we are averaging over)
    function test_ZivoeMath_ema_fuzzTesting(
        uint96 bV,
        uint96 cV,
        uint96 N
    ) public {
        // We always initiate the first value for "bV" in the code
        hevm.assume(bV > 100 ether);

        // We increment the number of distributions prior to calling ema()
        hevm.assume(N > 0);

        // Here we have to assume that the difference between "bV" and "cV"
        // is at least bigger than max value of "retrospectiveDistributions"
        // otherwise it will have no impact on new value as division would give 0
        // (no issue as we should deal with values in WEI and amount
        // of "retrospectiveDistributions" should be limited)
        if (bV != cV && bV > cV) { hevm.assume(bV - cV > 255); }
        if (bV != cV && bV < cV) { hevm.assume(cV - bV > 255); }

        uint256 eV = MATH.ema(
            bV,
            cV,
            YDL.retrospectiveDistributions().min(N)
        );

        // The three invariants we want to test (fundamentally for an average calculation):
        //   1| When current-value is greater than base-value, we assume output is greater than base-value.
        //   2| When current-value is equal to base-value, we assume output is equal to base-value.
        //   3| When current-value is less than base-value, we assume output is less than base-value.

        if (cV > bV) { assert(eV > bV); } 
        else if (cV == bV) { assert(eV == bV); }
        else { assert(eV < bV); }
    }

}