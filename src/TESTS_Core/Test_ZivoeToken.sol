// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "lib/zivoe-core-foundry/src/lockers/OCG/OCG_ERC20.sol";

import "../TESTS_Utility/Utility.sol";

contract Test_ZivoeGovernorV2 is Utility {

    ZivoeToken tZVE;

    function setUp() public {
        
        // Launch a new ZivoeToken contract, give initial supply to this contract.
        tZVE = new ZivoeToken("Zivoe", "ZVE", address(this));

    }

    function test_ZivoeToken_burn_state(uint96 random) {

        uint256 amt = uint96 % 25_000_000; // Burn arbitrary amount of existing tokens (total 25mm).

        // Pre-state.
        assertEq(tZVE.totalSupply(), 25_000_000 ether);
        assertEq(tZVE.balanceOf(address(this)), 25_000_000 ether);

        // burn().
        tZVE.burn(amt);

        // Post-state.
        assertEq(tZVE.totalSupply(), 25_000_000 ether - amt);
        assertEq(tZVE.balanceOf(address(this)), 25_000_000 ether - amt);

    }

    
}
