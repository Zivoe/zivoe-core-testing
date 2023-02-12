// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

contract Test_ZivoeGovernorV2 is Utility {

    function setUp() public {

        deployCore(false);
        
    }

    // Validate _getVotes() view endpoint for two scenarios:
    //  - User is currently vesting $ZVE in ZivoeRewardsVesting.
    //  - User stakes $ZVE in ZivoeRewards.

    function test_ZivoeGovernorV2_getVotes_vesting(uint96 random) public {

        uint256 amount = uint256(random);

        // Pre-state.
        assertEq(GOV.getVotes(address(tia), block.number - 1), 0);

        // vest() $ZVE to the address "tia".
        assert(zvl.try_vest(
            address(vestZVE), 
            address(tia), 
            amount % 360 + 1,
            (amount % 360 * 5 + 1),
            amount % 12_500_000 ether + 1,  // Amount to vest.
            false
        ));

        // Post-state.
        assertEq(GOV.getVotes(address(tia), block.number - 1), amount % 12_500_000 ether + 1);

    }

    function test_ZivoeGovernorV2_getVotes_staking(uint96 random) public {

        uint256 amount = uint256(random);

        // vest() $ZVE to the address "tia".
        assert(zvl.try_vest(
            address(vestZVE), 
            address(tia), 
            amount % 360 + 1,
            (amount % 360 * 5 + 1),
            amount % 12_500_000 ether + 1,  // Amount to vest.
            false
        ));

        // Warp to the end of vesting period for "tia", claim all $ZVE tokens.
        hevm.warp(block.timestamp + (amount % 360 * 5 + 1) * 86400);
        assert(tia.try_fullWithdraw(address(vestZVE)));
        assertEq(ZVE.balanceOf(address(tia)), amount % 12_500_000 ether + 1);

        // NOTE: User must delegate to themselves to utilize governance of personally held tokens.
        assert(tia.try_delegate(address(ZVE), address(tia)));
        hevm.roll(block.number + 1);

        // Pre-state.
        assertEq(GOV.getVotes(address(tia), block.number - 1), amount % 12_500_000 ether + 1);

        // stake() into $stZVE (NOTE: the user should retain voting power when staking).
        assert(tia.try_approveToken(address(ZVE), address(stZVE), ZVE.balanceOf(address(tia))));
        assert(tia.try_stake(address(stZVE), ZVE.balanceOf(address(tia))));
        hevm.roll(block.number + 1);

        // Post-state.
        assertEq(GOV.getVotes(address(tia), block.number - 1), amount % 12_500_000 ether + 1);
    
    }

    
}
