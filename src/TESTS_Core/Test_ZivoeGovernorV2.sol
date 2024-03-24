// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../lib/zivoe-core-foundry/src/lockers/OCG/OCG_ERC20.sol";

import "../Utility/Utility.sol";

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

    function giveTiaProposalRights(uint256 amount) public {

        // createVestingSchedule() 1mm $ZVE to the address "tia".
        assert(zvl.try_createVestingSchedule(
            address(vestZVE), 
            address(tia), 
            1,  // 1 Day Cliff
            3,  // 3 Day Total
            amount,  // Amount to vest.
            false
        ));

        // Warp to the end of vesting period for "tia", claim all $ZVE tokens.
        hevm.warp(block.timestamp + 3 * 86400);
        assert(tia.try_fullWithdraw(address(vestZVE)));
        assertEq(ZVE.balanceOf(address(tia)), amount);

        // NOTE: Account must delegate to themselves to utilize governance of personally held tokens.
        assert(tia.try_delegate(address(ZVE), address(tia)));
        hevm.roll(block.number + 1);
        assertEq(GOV.getVotes(address(tia), block.number - 1), amount);

        // Validate account "tia" has enough votes to create a proposal.
        assertGt(GOV.getVotes(address(tia), block.number - 1), GOV.proposalThreshold());
    }

    // Validate _getVotes() view endpoint for two scenarios:
    //  - Account is currently vesting $ZVE in ZivoeRewardsVesting.
    //  - Account stakes $ZVE in ZivoeRewards.

    function test_ZivoeGovernorV2_getVotes_vesting(uint96 random) public {

        uint256 amount = uint256(random);

        // Pre-state.
        assertEq(GOV.getVotes(address(tia), block.number - 1), 0);

        // createVestingSchedule() $ZVE to the address "tia".
        assert(zvl.try_createVestingSchedule(
            address(vestZVE), 
            address(tia), 
            amount % 360 + 1,
            (amount % 360 * 5 + 1),
            amount % 12_500_000 ether + 1,  // Amount to vest.
            false
        ));

        // emit log_named_uint("votes", GOV.getVotes(address(tia), block.number - 1));
        // emit log_named_uint("votes", GOV.getVotes(address(tia), block.number));

        hevm.roll(block.number + 1);

        // Post-state.
        assertEq(GOV.getVotes(address(tia), block.number - 1), amount % 12_500_000 ether + 1);

    }

    function test_ZivoeGovernorV2_getVotes_staking(uint96 random) public {

        uint256 amount = uint256(random);

        // createVestingSchedule() $ZVE to the address "tia".
        assert(zvl.try_createVestingSchedule(
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

        // NOTE: Account must delegate to themselves to utilize governance of personally held tokens.
        assert(tia.try_delegate(address(ZVE), address(tia)));
        hevm.roll(block.number + 1);

        // Pre-state.
        assertEq(GOV.getVotes(address(tia), block.number - 1), amount % 12_500_000 ether + 1);

        // stake() into $stZVE (NOTE: the account should retain voting power when staking).
        assert(tia.try_approveToken(address(ZVE), address(stZVE), ZVE.balanceOf(address(tia))));
        assert(tia.try_stake(address(stZVE), ZVE.balanceOf(address(tia))));
        hevm.roll(block.number + 1);

        // Post-state.
        assertEq(GOV.getVotes(address(tia), block.number - 1), amount % 12_500_000 ether + 1);
    
    }

    // Validate TimelockController executeBatch() if/else logic on keepers.

    function test_ZivoeGovernorV2_proposeAndExecuteBatch_nonKeeper_1() public {

        giveTiaProposalRights(3_000_000 ether); // 3mm $ZVE > 2.5mm (QuorumThreshold)

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);     // Leave as default of 0, this is msg.value input (ether).
        bytes[] memory calldatas = new bytes[](1);
        string memory description = "Move 100 DAI to OCG_ERC20Locker";

        targets[0] = address(DAO);

        // push(address locker, address asset, uint256 amount, bytes calldata data)
        calldatas[0] = abi.encodeWithSignature(
            "push(address,address,uint256,bytes)", 
            address(OCG_ERC20Locker), address(DAI), 100 ether, ""
        );

        // "tia" creates a proposal to move capital.
        hevm.startPrank(address(tia));
        (uint256 proposalId) = GOV.propose(targets, values, calldatas, description);
        hevm.stopPrank();

        // emit Debug('proposalId', proposalId);
        // emit Debug('GOV.state(proposalId)0', uint(GOV.state(proposalId)));   // Note: Return var is enum, typecast to uint()
        // emit Debug('GOV.proposalSnapshot(proposalId)', GOV.proposalSnapshot(proposalId));
        // emit Debug('GOV.proposalDeadline(proposalId)', GOV.proposalDeadline(proposalId));
        // emit Debug('GOV.votingDelay()', GOV.votingDelay());
        // emit Debug('GOV.votingPeriod()', GOV.votingPeriod());
        // emit Debug('GOV.quorum(block.number)', GOV.quorum(block.number - 1)); // -1 to avoid "ERC20Votes: block not mined"

        // Increase block number past votingDelay() period.
        hevm.roll(block.number + GOV.votingDelay() + 1);
        assertEq(uint(GOV.state(proposalId)), 1);  // "1" = Enum for Proposal.Active

        // castVote().
        hevm.startPrank(address(tia));
        (uint256 weight) = GOV.castVote(proposalId, uint8(1)); // 0 = Against, 1 = For, 2 = Abstain
        hevm.stopPrank();

        // Increase block number past proposalDeadline() period.
        hevm.roll(block.number + GOV.proposalDeadline(proposalId) + 1);
        assertEq(uint(GOV.state(proposalId)), 4);  // "4" = Enum for Proposal.Succeeded
        
        // Queueing is public, call queue() directly.
        GOV.queue(targets, values, calldatas, keccak256(bytes(description)));

        // Warp past delay period for execute().
        hevm.warp(block.timestamp + TLC.getMinDelay() - 12 hours - 1);
        hevm.roll(block.number + 1);

        // Assert "tia" can't call executeBatch() as non-keeper.
        assert(!tia.try_executeBatch(address(TLC), targets, values, calldatas, 0, keccak256(bytes(description))));

        // Add keeper to whitelist
        assert(zvl.try_updateIsKeeper(address(GBL), address(tia), true));

        // Assert "tia" can't call executeBatch() as keeper more than 12 hours in advance.
        assert(!tia.try_executeBatch(address(TLC), targets, values, calldatas, 0, keccak256(bytes(description))));

        // Tick past 12 hour threshold.
        hevm.warp(block.timestamp + 1);

        // Assert "tia" can call executeBatch() as keeper.
        assert(tia.try_executeBatch(address(TLC), targets, values, calldatas, 0, keccak256(bytes(description))));
        

    }

    // Validate TimelockController executeBatch() if/else logic on keepers.

    function test_ZivoeGovernorV2_proposeAndExecuteBatch_nonKeeper_2() public {

        giveTiaProposalRights(3_000_000 ether); // 3mm $ZVE > 2.5mm (QuorumThreshold)

        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory calldatas = new bytes[](2);
        string memory description = "Move 100 DAI and 100 FRAX to OCG_ERC20Locker";

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

        // "tia" creates a proposal to move capital twice.
        hevm.startPrank(address(tia));
        (uint256 proposalId) = GOV.propose(targets, values, calldatas, description);
        hevm.stopPrank();

        // Increase block number past votingDelay() period.
        hevm.roll(block.number + GOV.votingDelay() + 1);
        assertEq(uint(GOV.state(proposalId)), 1);  // "1" = Enum for Proposal.Active

        // castVote().
        hevm.startPrank(address(tia));
        (uint256 weight) = GOV.castVote(proposalId, uint8(1)); // 0 = Against, 1 = For, 2 = Abstain
        hevm.stopPrank();

        // Increase block number past proposalDeadline() period.
        hevm.roll(block.number + GOV.proposalDeadline(proposalId) + 1);
        assertEq(uint(GOV.state(proposalId)), 4);  // "4" = Enum for Proposal.Succeeded
        
        // Queueing is public, call queue() directly.
        GOV.queue(targets, values, calldatas, keccak256(bytes(description)));

        // Warp past delay period for execute(), right before non-keeper's can call.
        hevm.warp(block.timestamp + TLC.getMinDelay() - 12 hours - 1);
        hevm.roll(block.number + 1);

        // Assert "tia" can't call executeBatch() as non-keeper.
        assert(!tia.try_executeBatch(address(TLC), targets, values, calldatas, 0, keccak256(bytes(description))));

        // Add keeper to whitelist
        assert(zvl.try_updateIsKeeper(address(GBL), address(tia), true));

        // Assert "tia" can't call executeBatch() as keeper more than 12 hours in advance.
        assert(!tia.try_executeBatch(address(TLC), targets, values, calldatas, 0, keccak256(bytes(description))));

        // Tick past 12 hour threshold.
        hevm.warp(block.timestamp + 1);

        // Assert "tia" can call executeBatch() as keeper.
        assert(tia.try_executeBatch(address(TLC), targets, values, calldatas, 0, keccak256(bytes(description))));
        
    }

    
}
