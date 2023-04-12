// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "lib/zivoe-core-foundry/src/lockers/OCR/OCR_Modular.sol";

contract Test_OCR_Modular is Utility {

    OCR_Modular OCR_Modular_DAI;

    function setup() public {

        deployCore(false);

        // Initialize and whitelist OCR_Modular lockers.
        OCR_Modular_DAI = new OCR_Modular(address(DAO), address(DAI), address(GBL));
        zvl.try_updateIsLocker(address(GBL), address(OCC_Modular_DAI), true);

    }

    // ----------------------
    //    Helper Functions
    // ----------------------

    // ----------------
    //    Unit Tests
    // ----------------

    // Validate initial state.
    function test_OCR_Modular_init() public {
        
        // Ownership.
        assertEq(OCR_Modular_DAI.owner(), address(DAO));

        // State variables.
        assertEq(OCR_Modular_DAI.stablecoin(), address(DAI));
        assertEq(OCR_Modular_DAI.GBL(), address(GBL));

        // Permissions
        assert(OCR_Modular_DAI.canPush());
        assert(OCR_Modular_DAI.canPull());

    }
}