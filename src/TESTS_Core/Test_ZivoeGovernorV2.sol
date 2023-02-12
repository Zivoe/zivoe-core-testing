// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "lib/zivoe-core-foundry/src/lockers/OCG/OCG_ERC20.sol";

import "../TESTS_Utility/Utility.sol";

contract Test_ZivoeGovernorV2 is Utility {

    OCG_ERC20 OCG_ERC20Locker;

    function setUp() public {
        deployCore(true);       // Note: Use "true" input for TLC/GTC testing purposes.

        // Deploy 1 OCG (On-Chain Generic) locker for ERC20 token movements.
        OCG_ERC20Locker = new OCG_ERC20(address(DAO));

        // Whitelist OCG locker.
        assert(zvl.try_updateIsLocker(address(GBL), address(OCG_ERC20Locker), true));

        // Simulate ITO, supply ERC20 tokens to DAO.
        simulateITO(100_000_000 ether, 100_000_000 ether, 100_000_000 * USD, 100_000_000 * USD);
    }

    // ----------------------
    //    Helper Functions
    // ----------------------

    function giveTiaProposalRights() public {

        // vest() 1mm $ZVE to the address "tia".
        assert(zvl.try_vest(
            address(vestZVE), 
            address(tia), 
            1,  // 1 Day Cliff
            3,  // 3 Day Total
            1_000_000 ether,  // Amount to vest.
            false
        ));

        // Warp to the end of vesting period for "tia", claim all $ZVE tokens.
        hevm.warp(block.timestamp + 3 * 86400);
        assert(tia.try_fullWithdraw(address(vestZVE)));
        assertEq(ZVE.balanceOf(address(tia)), 1_000_000 ether);

        // NOTE: User must delegate to themselves to utilize governance of personally held tokens.
        assert(tia.try_delegate(address(ZVE), address(tia)));
        hevm.roll(block.number + 1);
        assertEq(GOV.getVotes(address(tia), block.number - 1), 1_000_000 ether);

        // Validate user "tia" has enough votes to create a proposal.
        assertGt(GOV.getVotes(address(tia), block.number - 1), GOV.proposalThreshold());
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

    // Validate TimelockController execute() if/else logic on keepers.

    function test_ZivoeGovernorV2_proposeAndExecute_logic() public {

        giveTiaProposalRights();

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);     // Leave as default of 0, this is msg.value input (ether).
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(DAO);

        // push(address locker, address asset, uint256 amount, bytes calldata data)
        calldatas[0] = abi.encodeWithSignature(
            "push(address,address,uint256,bytes)", 
            address(OCG_ERC20Locker), address(DAI), 100 ether, ""
        );

        // "tia" creates a proposal to move capital.
        assert(tia.try_propose(
            address(GOV), targets, values, calldatas, 
            "Move 100 DAI to OCG_ERC20Locker"
        ));
    }

    // TODO: Test TimelockController executeBatch() if/else logic on keepers.

    function test_ZivoeGovernorV2_proposeAndExecuteBatch_logic() public {

        giveTiaProposalRights();

        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory calldatas = new bytes[](2);

        // "tia" creates a proposal to move capital twice.
        targets[0] = address(DAO);
        targets[1] = address(DAO);
        
        // push(address locker, address asset, uint256 amount, bytes calldata data)
        calldatas[0] = abi.encodeWithSignature(
            "push(address,address,uint256,bytes)", 
            address(OCG_ERC20Locker), address(DAI), 100 ether, ""
        );
        calldatas[1] = abi.encodeWithSignature(
            "push(address,address,uint256,bytes)", 
            address(OCG_ERC20Locker), address(FRAX), 100 ether, ""
        );

        // "tia" creates a proposal to move capital.
        assert(tia.try_propose(
            address(GOV), targets, values, calldatas, 
            "Move 100 DAI and 100 FRAX to OCG_ERC20Locker"
        ));
        
    }

    
}
