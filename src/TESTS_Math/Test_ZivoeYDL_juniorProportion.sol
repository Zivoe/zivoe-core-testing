// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "lib/zivoe-core-foundry/src/ZivoeYDL.sol";

contract Test_ZivoeYDL_juniorProportion is Utility {

    uint256 sSTT = 30_000_000 ether;
    uint256 sJTT = 6_000_000 ether;

    function setUp() public {
        deployCore(false);
    }

    function test_ZivoeYDL_juniorProportion_fuzzInvariant(uint128 eSTT, uint128 eJTT, uint256 Y) public {
        
        // The invariant for juniorProportion() is that return value never exceeds RAY (10**27).

        hevm.assume(Y <= RAY);

        uint256 juniorProportion = YDL.juniorProportion(
            eSTT, // eSTT
            eJTT, // eJTT
            Y, // Y
            YDL.targetRatioBIPS() // Q
        );

        assert(juniorProportion <= RAY);

    }

}