// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "lib/zivoe-core-foundry/src/ZivoeYDL.sol";

contract Test_ZivoeYDL_seniorProportionBase is Utility {

    function setUp() public {
        deployCore(false);
    }

    function test_ZivoeYDL_seniorProportionBase_static_0() public {

        uint256 yD = 66_666 ether;
        uint256 eSTT = 8_000_000 ether;
        uint256 Y = 800;
        uint256 T = 30;

        uint256 sPB = YDL.seniorProportionBase(
            yD,     // yD
            eSTT,   // eSTT
            Y,      // Y
            T       // T
        );

        emit log_named_uint("sPB", sPB);
        
    }

    function test_ZivoeYDL_seniorProportionBase_fuzzTesting(
        uint88 yD,
        uint96 eSTT,
        uint16 Y,
        uint8 T
    ) public {
        // We can assume that yield distributed is greater than 0,
        // otherwise no need of distributing yield.
        hevm.assume(yD > 0);
        hevm.assume(Y > 1);
        hevm.assume(T >= 1);
        hevm.assume(eSTT > 1 ether);

        assert(YDL.seniorProportionBase(yD, eSTT, Y, T) > 0);
    }

}