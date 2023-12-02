// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../Utility/Utility.sol";

contract Test_ZivoeRewardsVesting is Utility {

    function setUp() public {

        deployCore(false);

        // Simulate ITO (10mm * 8 * 4), DAI/FRAX/USDC/USDT.
        simulateITO(10_000_000 ether, 10_000_000 ether, 10_000_000 * USD, 10_000_000 * USD);

    }

    // ----------------------
    //    Helper Functions
    // ----------------------
    
    function depositReward_DAI(address loc, uint256 amount) public {
        // depositReward().
        mint("DAI", address(bob), amount);
        assert(bob.try_approveToken(DAI, loc, amount));
        assert(bob.try_depositReward(loc, DAI, amount));
    }

    // ------------
    //    Events
    // ------------

    event RewardAdded(address indexed reward);

    event RewardDeposited(address indexed reward, uint256 amount, address indexed depositor);

    event Staked(address indexed account, uint256 amount);

    event Withdrawn(address indexed account, uint256 amount);

    event RewardDistributed(address indexed account, address indexed rewardsToken, uint256 reward);

    event VestingScheduleCreated(address indexed account, uint256 start, uint256 cliff, uint256 end, uint256 totalVesting, uint256 vestingPerSecond, bool revokable);

    event VestingScheduleRevoked(address indexed account, uint256 amountRevoked, uint256 cliff, uint256 end, uint256 totalVesting, bool revokable);


    // ----------------
    //    Unit Tests
    // ----------------

    // Validate addReward() state changes.
    // Validate addReward() restrictions.
    // This includes:
    //  - Reward isn't already set (rewardData[_rewardsToken].rewardsDuration == 0)
    //  - Maximum of 10 rewards are set (rewardTokens.length < 10) .. TODO: Discuss with auditors @RTV what max feasible size is?

    function test_ZivoeRewardsVesting_addReward_restrictions_ZVL() public {
        // Can't call if not ZVL().
        hevm.startPrank(address(bob));
        hevm.expectRevert("_msgSender() != IZivoeGlobals_ZivoeRewardsVesting(GBL).ZVL()");
        vestZVE.addReward(FRAX, 30 days);
        hevm.stopPrank();
    }

    function test_ZivoeRewardsVesting_addReward_restrictions_ZVE() public {
        // Can't call if asset == ZVE().
        hevm.startPrank(address(zvl));
        hevm.expectRevert("ZivoeRewardsVesting::addReward() _rewardsToken == IZivoeGlobals_ZivoeRewardsVesting(GBL).ZVE()");
        vestZVE.addReward(address(ZVE), 30 days);
        hevm.stopPrank();
    }

    function test_ZivoeRewardsVesting_addReward_restrictions_rewardsDuration0() public {
        // Can't call if rewardData[_rewardsToken].rewardsDuration == 0 (meaning subsequent addReward() calls).
        assert(zvl.try_addReward(address(vestZVE), WETH, 30 days));
        hevm.startPrank(address(zvl));
        hevm.expectRevert("ZivoeRewardsVesting::addReward() rewardData[_rewardsToken].rewardsDuration != 0");
        vestZVE.addReward(WETH, 20 days);
        hevm.stopPrank();
    }

    function test_ZivoeRewardsVesting_addReward_restrictions_maxRewards() public {
        // Can't call if more than 10 rewards have been added.
        assert(zvl.try_addReward(address(vestZVE), WETH, 30 days));// Note: DAI added already.
        assert(zvl.try_addReward(address(vestZVE), address(3), 1));
        assert(zvl.try_addReward(address(vestZVE), address(4), 1));
        assert(zvl.try_addReward(address(vestZVE), address(5), 1));
        assert(zvl.try_addReward(address(vestZVE), address(6), 1));
        assert(zvl.try_addReward(address(vestZVE), address(7), 1));
        assert(zvl.try_addReward(address(vestZVE), address(8), 1));
        assert(zvl.try_addReward(address(vestZVE), address(9), 1));
        assert(zvl.try_addReward(address(vestZVE), address(10), 1));

        hevm.startPrank(address(zvl));
        hevm.expectRevert("ZivoeRewardsVesting::addReward() rewardTokens.length >= 10");
        vestZVE.addReward(address(11), 1);
        hevm.stopPrank();
    }

    function test_ZivoeRewardsVesting_addReward_state(uint96 random) public {

        uint256 duration = uint256(random) + 1;

        // Pre-state.
        (
            uint256 rewardsDuration,
            uint256 periodFinish,
            uint256 rewardRate,
            uint256 lastUpdateTime,
            uint256 rewardPerTokenStored
        ) = vestZVE.rewardData(WETH);

        assertEq(rewardsDuration, 0);
        assertEq(periodFinish, 0);
        assertEq(rewardRate, 0);
        assertEq(lastUpdateTime, 0);
        assertEq(rewardPerTokenStored, 0);

        hevm.expectEmit(true, false, false, false, address(vestZVE));
        emit RewardAdded(WETH);
        assert(zvl.try_addReward(address(vestZVE), WETH, duration));

        // Post-state.
        assertEq(vestZVE.rewardTokens(1), WETH);

        (
            rewardsDuration,
            periodFinish,
            rewardRate,
            lastUpdateTime,
            rewardPerTokenStored
        ) = vestZVE.rewardData(WETH);

        assertEq(rewardsDuration, duration);
        assertEq(periodFinish, 0);
        assertEq(rewardRate, 0);
        assertEq(lastUpdateTime, 0);
        assertEq(rewardPerTokenStored, 0);

    }

    // Validate depositReward() state changes.
    
    function test_ZivoeRewardsVesting_depositReward_initial_state(uint96 random) public {

        uint256 deposit = uint256(random);

        // Pre-state.
        uint256 _preDAI = IERC20(DAI).balanceOf(address(vestZVE));

        (
            uint256 rewardsDuration,
            uint256 periodFinish,
            uint256 rewardRate,
            uint256 lastUpdateTime,
            uint256 rewardPerTokenStored
        ) = vestZVE.rewardData(DAI);

        assert(block.timestamp >= periodFinish);

        // depositReward().
        mint("DAI", address(bob), deposit);
        assert(bob.try_approveToken(DAI, address(vestZVE), deposit));

        hevm.expectEmit(true, true, false, true, address(vestZVE));
        emit RewardDeposited(DAI, deposit, address(bob));
        assert(bob.try_depositReward(address(vestZVE), DAI, deposit));

        // Post-state.
        assertEq(IERC20(DAI).balanceOf(address(vestZVE)), _preDAI + deposit);

        (
            rewardsDuration,
            periodFinish,
            rewardRate,
            lastUpdateTime,
            rewardPerTokenStored
        ) = vestZVE.rewardData(DAI);

        assertEq(rewardsDuration, 30 days);
        assertEq(periodFinish, block.timestamp + rewardsDuration);
        /*
            if (block.timestamp >= rewardData[_rewardsToken].periodFinish) {
                rewardData[_rewardsToken].rewardRate = reward.div(rewardData[_rewardsToken].rewardsDuration);
            }
        */
        assertEq(rewardRate, deposit / rewardsDuration);
        assertEq(lastUpdateTime, block.timestamp);
        assertEq(rewardPerTokenStored, 0);

    }

    function test_ZivoeRewardsVesting_depositReward_subsequent_state(uint96 random) public {

        uint256 deposit = uint256(random);

        depositReward_DAI(address(vestZVE), deposit);

        hevm.warp(block.timestamp + random % 60 days); // 50% chance warp past periodFinish

        // Pre-state.
        uint256 _preDAI = IERC20(DAI).balanceOf(address(vestZVE));

        (
            uint256 rewardsDuration,
            uint256 _prePeriodFinish,
            uint256 _preRewardRate,
            uint256 lastUpdateTime,
            uint256 rewardPerTokenStored
        ) = vestZVE.rewardData(DAI);
        
        uint256 _postPeriodFinish;
        uint256 _postRewardRate;

        // depositReward().
        mint("DAI", address(bob), deposit);
        assert(bob.try_approveToken(DAI, address(vestZVE), deposit));

        hevm.expectEmit(true, true, false, true, address(vestZVE));
        emit RewardDeposited(DAI, deposit, address(bob));
        assert(bob.try_depositReward(address(vestZVE), DAI, deposit));

        // Post-state.
        assertEq(IERC20(DAI).balanceOf(address(vestZVE)), _preDAI + deposit);
        (
            rewardsDuration,
            _postPeriodFinish,
            _postRewardRate,
            lastUpdateTime,
            rewardPerTokenStored
        ) = vestZVE.rewardData(DAI);

        assertEq(rewardsDuration, 30 days);
        assertEq(_postPeriodFinish, block.timestamp + rewardsDuration);
        /*
            if (block.timestamp >= rewardData[_rewardsToken].periodFinish) {
                rewardData[_rewardsToken].rewardRate = reward.div(rewardData[_rewardsToken].rewardsDuration);
            }
            else {
                uint256 remaining = rewardData[_rewardsToken].periodFinish.sub(block.timestamp);
                uint256 leftover = remaining.mul(rewardData[_rewardsToken].rewardRate);
                rewardData[_rewardsToken].rewardRate = reward.add(leftover).div(rewardData[_rewardsToken].rewardsDuration);
            }
        */
        if (block.timestamp >= _prePeriodFinish) {
            assertEq(_postRewardRate, deposit / rewardsDuration);
        }
        else {
            uint256 remaining = _prePeriodFinish - block.timestamp;
            uint256 leftover = remaining * _preRewardRate;
            assertEq(_postRewardRate, (deposit + leftover) / rewardsDuration);
        }
        assertEq(lastUpdateTime, block.timestamp);
        assertEq(rewardPerTokenStored, 0);

    }

    // Validate createVestingSchedule() state changes.
    // Validate createVestingSchedule() restrictions.
    // This includes:
    //  - Account must not be assigned vesting schedule (!vestingScheduleSet[account]).
    //  - Must be enough $ZVE present to vest out.
    //  - Cliff timeline must be appropriate (daysToCliff <= daysToVest).
    //  - Restricting vest if account has deposited to ITO.

    function test_ZivoeRewardsVesting_createVestingSchedule_restrictions_maxVest() public {

        uint256 zveBalanceOverflow = ZVE.balanceOf(address(vestZVE)) + 1;
        // Can't vest more ZVE than is present.
        hevm.startPrank(address(zvl));
        hevm.expectRevert("ZivoeRewardsVesting::createVestingSchedule() amountToVest > vestingToken.balanceOf(address(this)) - vestingTokenAllocated");
        vestZVE.createVestingSchedule(address(poe), 30, 90, zveBalanceOverflow, false);
        hevm.stopPrank();
    }

    function test_ZivoeRewardsVesting_createVestingSchedule_restrictions_maxCliff() public {

        // Can't vest if cliff days > vesting days.
        hevm.startPrank(address(zvl));
        hevm.expectRevert("ZivoeRewardsVesting::createVestingSchedule() daysToCliff > daysToVest");
        vestZVE.createVestingSchedule(address(poe), 91, 90, 100 ether, false);
        hevm.stopPrank();
    }

    function test_ZivoeRewardsVesting_createVestingSchedule_restrictions_amount0() public {

        // Can't vest if amount == 0.
        hevm.startPrank(address(zvl));
        hevm.expectRevert("ZivoeRewardsVesting::_stake() amount == 0");
        vestZVE.createVestingSchedule(address(poe), 30, 90, 0, false);
        hevm.stopPrank();       
    }

    function test_ZivoeRewardsVesting_createVestingSchedule_restrictions_scheduleSet() public {
        
        // Can't call vest if schedule already set.
        assert(zvl.try_createVestingSchedule(address(vestZVE), address(poe), 30, 90, 100 ether, false));
        hevm.startPrank(address(zvl));
        hevm.expectRevert("ZivoeRewardsVesting::createVestingSchedule() vestingScheduleSet[account]");
        vestZVE.createVestingSchedule(address(poe), 30, 90, 100 ether, false);
        hevm.stopPrank();  
    }

    function test_ZivoeRewardsVesting_createVestingSchedule_restrictions_depositedITO_senior() public {

        // Mint 100 DAI for "bob", approve ITO contract.
        mint("DAI", address(bob), 100 ether);
        assert(bob.try_approveToken(DAI, address(ITO), 100 ether));

        // Deposit to ITO
        hevm.startPrank(address(zvl));
        hevm.expectRevert("ZivoeRewardsVesting::createVestingSchedule() seniorCredits(_msgSender) > 0 || juniorCredits(_msgSender) > 0");
        vestZVE.createVestingSchedule(address(sam), 30, 90, 100 ether, false);
        hevm.stopPrank();
    }

    function test_ZivoeRewardsVesting_createVestingSchedule_restrictions_depositedITO_junior() public {

        // Mint 100 DAI for "bob", approve ITO contract.
        mint("DAI", address(bob), 100 ether);
        assert(bob.try_approveToken(DAI, address(ITO), 100 ether));

        // Deposit to ITO
        hevm.startPrank(address(zvl));
        hevm.expectRevert("ZivoeRewardsVesting::createVestingSchedule() seniorCredits(_msgSender) > 0 || juniorCredits(_msgSender) > 0");
        vestZVE.createVestingSchedule(address(jim), 30, 90, 100 ether, false);
        hevm.stopPrank();
    }

    function test_ZivoeRewardsVesting_createVestingSchedule_state(uint96 random, bool choice) public {

        uint256 amount = uint256(random);

        // Pre-state.
        (
            uint256 start, 
            uint256 cliff, 
            uint256 end, 
            uint256 totalVesting, 
            uint256 totalWithdrawn, 
            uint256 vestingPerSecond, 
            bool revokable
        ) = vestZVE.viewSchedule(address(tia));

        assertEq(vestZVE.vestingTokenAllocated(), 0);

        assertEq(start, 0);
        assertEq(cliff, 0);
        assertEq(end, 0);
        assertEq(totalVesting, 0);
        assertEq(totalWithdrawn, 0);
        assertEq(vestingPerSecond, 0);
        assertEq(vestZVE.balanceOf(address(tia)), 0);
        assertEq(vestZVE.totalSupply(), 0);

        assert(!vestZVE.vestingScheduleSet(address(tia)));
        assert(!revokable);

        hevm.expectEmit(true, false, false, true, address(vestZVE));
        emit VestingScheduleCreated(
            address(tia),
            block.timestamp,
            block.timestamp + (amount % 360 + 1) * 1 days,
            block.timestamp + (amount % 360 * 5 + 1) * 1 days,
            amount % 12_500_000 ether + 1,
            (amount % 12_500_000 ether + 1) / ((amount % 360 * 5 + 1) * 1 days),
            choice
        );

        assert(zvl.try_createVestingSchedule(
            address(vestZVE), 
            address(tia), 
            amount % 360 + 1, 
            (amount % 360 * 5 + 1),
            amount % 12_500_000 ether + 1, 
            choice
        ));

        // Post-state.
        (
            start, 
            cliff, 
            end, 
            totalVesting, 
            totalWithdrawn, 
            vestingPerSecond, 
            revokable
        ) = vestZVE.viewSchedule(address(tia));

        assertEq(vestZVE.vestingTokenAllocated(), amount % 12_500_000 ether + 1);

        assertEq(start, block.timestamp);
        assertEq(cliff, block.timestamp + (amount % 360 + 1) * 1 days);
        assertEq(end, block.timestamp + (amount % 360 * 5 + 1) * 1 days);
        assertEq(totalVesting, amount % 12_500_000 ether + 1);
        assertEq(totalWithdrawn, 0);
        assertEq(vestingPerSecond, (amount % 12_500_000 ether + 1) / ((amount % 360 * 5 + 1) * 1 days));
        assertEq(vestZVE.balanceOf(address(tia)), amount % 12_500_000 ether + 1);
        assertEq(vestZVE.totalSupply(), amount % 12_500_000 ether + 1);

        assert(vestZVE.vestingScheduleSet(address(tia)));
        assert(revokable == choice);

    }

    // Experiment with amountWithdrawable() view endpoint here.

    function test_ZivoeRewardsVesting_amountWithdrawable_experiment() public {
        
        // Example:
        //  - 1,000,000 $ZVE vesting.
        //  - 30 day cliff period.
        //  - 120 day vesting period (of which 30 days is the cliff).

        // emitted events in createVestingSchedule() already tested above.
        assert(zvl.try_createVestingSchedule(
            address(vestZVE), 
            address(qcp), 
            30, 
            120,
            1_000_000 ether, 
            false
        ));

        // amountWithdrawble() should be 0 prior to cliff period ending.
        hevm.warp(block.timestamp + 30 days - 1 seconds);
        assertEq(vestZVE.amountWithdrawable(address(qcp)), 0);

        // amountWithdrawble() should be (approx) 25% with cliff period ending.
        hevm.warp(block.timestamp + 1 seconds);
        withinDiff(vestZVE.amountWithdrawable(address(qcp)), 250_000 ether, 1 ether);

        // amountWithdrawble() should be (approx) 50% when 60 days through.
        hevm.warp(block.timestamp + 30 days);
        withinDiff(vestZVE.amountWithdrawable(address(qcp)), 500_000 ether, 1 ether);

        // amountWithdrawble() should be 0 after claiming!
        assert(qcp.try_fullWithdraw(address(vestZVE)));
        assertEq(vestZVE.amountWithdrawable(address(qcp)), 0);

        // amountWithdrawble() should be (approx) 50% at end of period (already withdraw 50% above).
        hevm.warp(block.timestamp + 60 days + 1 seconds);
        withinDiff(vestZVE.amountWithdrawable(address(qcp)), 500_000 ether, 1 ether);

        // Should be able to withdraw everything, and have full vesting amount (of $ZVE) in posssession.
        uint256 preBalance = IERC20(address(ZVE)).balanceOf(address(qcp));
        hevm.expectEmit(true, false, false, true, address(vestZVE));
        emit Withdrawn(address(qcp), 1_000_000 ether - preBalance);
        assert(qcp.try_fullWithdraw(address(vestZVE)));
        assertEq(ZVE.balanceOf(address(qcp)), 1_000_000 ether);
    }


    // Validate revokeVestingSchedule() state changes.
    // Validate revokeVestingSchedule() restrictions.
    // This includes:
    //  - Account must be assigned vesting schedule (vestingScheduleSet[account]).
    //  - Account must be revokable (vestingScheduleSet[account]).

    function test_ZivoeRewardsVesting_revokeVestingSchedule_restrictions_noVestingSchedule() public {
        // Can't revokeVestingSchedule an account that doesn't exist.
        hevm.startPrank(address(zvl));
        hevm.expectRevert("ZivoeRewardsVesting::revokeVestingSchedule() !vestingScheduleSet[account]");
        vestZVE.revokeVestingSchedule(address(moe));
        hevm.stopPrank();
    }

    function test_ZivoeRewardsVesting_revokeVestingSchedule_restrictions_notRevokable(uint96 random) public {
        uint256 amount = uint256(random);

        // createVestingSchedule().
        assert(zvl.try_createVestingSchedule(
            address(vestZVE), 
            address(moe), 
            amount % 360 + 1, 
            (amount % 360 * 5 + 1),
            amount % 12_500_000 ether + 1, 
            false
        ));

        // Can't revokeVestingSchedule an account that doesn't exist.
        hevm.startPrank(address(zvl));
        hevm.expectRevert("ZivoeRewardsVesting::revokeVestingSchedule() !vestingScheduleOf[account].revokable");
        vestZVE.revokeVestingSchedule(address(moe));
        hevm.stopPrank();
    }

    function test_ZivoeRewardsVesting_revokeVestingSchedule_state(uint96 random) public {

        uint256 amount = uint256(random);

        // emitted events in createVestingSchedule() already tested above.
        assert(zvl.try_createVestingSchedule(
            address(vestZVE), 
            address(moe), 
            amount % 360 + 1, 
            (amount % 360 * 5 + 1),
            amount % 12_500_000 ether + 1, 
            true
        ));

        // Pre-state.
        (
            uint256 start, 
            uint256 cliff, 
            uint256 end, 
            uint256 totalVesting, 
            uint256 totalWithdrawn, 
            uint256 vestingPerSecond,
        ) = vestZVE.viewSchedule(address(moe));

        assertEq(start, block.timestamp);
        assertEq(cliff, block.timestamp + (amount % 360 + 1) * 1 days);
        assertEq(end, block.timestamp + (amount % 360 * 5 + 1) * 1 days);
        assertEq(totalVesting, amount % 12_500_000 ether + 1);
        assertEq(totalWithdrawn, 0);
        assertEq(vestingPerSecond, (amount % 12_500_000 ether + 1) / ((amount % 360 * 5 + 1) * 1 days));
        assertEq(vestZVE.balanceOf(address(moe)), amount % 12_500_000 ether + 1);
        assertEq(vestZVE.totalSupply(), amount % 12_500_000 ether + 1);
        assertEq(ZVE.balanceOf(address(moe)), 0);

        // warp some random amount of time from now to end.
        hevm.warp(block.timestamp + amount % (end - start));

        uint256 amountWithdrawable = vestZVE.amountWithdrawable(address(moe));

        hevm.expectEmit(true, false, false, true, address(vestZVE));
        emit VestingScheduleRevoked(
            address(moe),
            amount % 12_500_000 ether + 1 - amountWithdrawable,
            block.timestamp - 1,
            block.timestamp,
            amountWithdrawable,
            false
        );

        assert(zvl.try_revokeVestingSchedule(address(vestZVE), address(moe)));

        // Post-state.
        bool revokable;
        (
            , 
            cliff, 
            end, 
            totalVesting, 
            totalWithdrawn, 
            vestingPerSecond,
            revokable
        ) = vestZVE.viewSchedule(address(moe));

        assertEq(totalVesting, amountWithdrawable);
        assertEq(totalWithdrawn, amountWithdrawable);
        assertEq(cliff, block.timestamp - 1);
        assertEq(end, block.timestamp);
        assertEq(vestZVE.totalSupply(), 0);
        assertEq(vestZVE.balanceOf(address(moe)), 0);
        assertEq(ZVE.balanceOf(address(moe)), amountWithdrawable);

        assert(!revokable);

    }
    
    // Validate getRewardAt() state changes.

    function Xtest_ZivoeRewardsVesting_getRewardAt_state(uint96 random) public {

        uint256 amount = uint256(random);
        uint256 deposit = uint256(random) + 100 ether; // Minimum 100 DAI deposit.

        // emitted events in createVestingSchedule() already tested above.
        assert(zvl.try_createVestingSchedule(
            address(vestZVE), 
            address(pam), 
            amount % 360 + 1, 
            (amount % 360 * 5 + 1),
            amount % 12_500_000 ether + 1, 
            true
        ));

        depositReward_DAI(address(vestZVE), deposit);

        hevm.warp(block.timestamp + random % 360 * 10 days + 1 seconds); // 50% chance to go past periodFinish.

        // Pre-state.
        uint256 _preDAI_pam = IERC20(DAI).balanceOf(address(pam));
        
        {
            uint256 _preEarned = vestZVE.viewRewards(address(pam), DAI);
            uint256 _preURPTP = vestZVE.viewAccountRewardPerTokenPaid(address(pam), DAI);
            assertEq(_preEarned, 0);
            assertEq(_preURPTP, 0);
        }
        
        assertGt(IERC20(DAI).balanceOf(address(vestZVE)), 0);
        
        // getRewardAt().
        uint256 rewardsEarned = IZivoeRewards(address(vestZVE)).earned(address(pam), DAI);
        hevm.expectEmit(true, true, false, true, address(vestZVE));
        emit RewardDistributed(address(pam), DAI, rewardsEarned);
        assert(pam.try_getRewardAt(address(vestZVE), 0));

        // Post-state.
        assertGt(IERC20(DAI).balanceOf(address(pam)), _preDAI_pam);

        (
            ,
            ,
            ,
            uint256 _postLastUpdateTime,
            uint256 _postRewardPerTokenStored
        ) = vestZVE.rewardData(DAI);
        
        assertEq(_postRewardPerTokenStored, vestZVE.rewardPerToken(DAI));
        assertEq(_postLastUpdateTime, vestZVE.lastTimeRewardApplicable(DAI));

        assertEq(vestZVE.viewAccountRewardPerTokenPaid(address(pam), DAI), _postRewardPerTokenStored);
        assertEq(vestZVE.viewRewards(address(pam), DAI), 0);
        assertEq(IERC20(DAI).balanceOf(address(pam)), _postRewardPerTokenStored * vestZVE.balanceOf(address(pam)) / 10**18);


    }
    
    // Validate withdraw() state changes.
    // Validate withdraw() restrictions.
    // This includes:
    //  - Withdraw amount must be greater than 0.

    function test_ZivoeRewardsVesting_withdraw_restrictions_withdraw0() public {
        
        // Can't call if amountWithdrawable() == 0.
        hevm.startPrank(address(pam));
        hevm.expectRevert("ZivoeRewardsVesting::withdraw() amountWithdrawable(_msgSender()) == 0");
        vestZVE.withdraw();
        hevm.stopPrank();
    }

    function test_ZivoeRewardsVesting_withdraw_state(uint96 random) public {

        uint256 amount = uint256(random);
        uint256 deposit = uint256(random) + 100 ether; // Minimum 100 DAI deposit.

        // emitted events in createVestingSchedule() already tested above.
        assert(zvl.try_createVestingSchedule(
            address(vestZVE), 
            address(pam), 
            amount % 360 + 1, 
            (amount % 360 * 5 + 1),
            amount % 12_499_999 ether + 1 ether, 
            true
        ));

        depositReward_DAI(address(vestZVE), deposit);

        // Give little breathing room so amountWithdrawable() != 0.
        hevm.warp(block.timestamp + (amount % 360 + 1) * 1 days + random % (5000 days));

        uint256 unstake = vestZVE.amountWithdrawable(address(pam));

        // Pre-state.
        uint256 _preSupply = vestZVE.totalSupply();
        uint256 _preBal_vestZVE_pam = vestZVE.balanceOf(address(pam));
        uint256 _preBal_ZVE_pam = ZVE.balanceOf(address(pam));
        uint256 _preBal_ZVE_vestZVE = ZVE.balanceOf(address(vestZVE));

        assertGt(_preSupply, 0);
        assertGt(_preBal_vestZVE_pam, 0);
        assertEq(_preBal_ZVE_pam, 0);
        assertGt(_preBal_ZVE_vestZVE, 0);

        // withdraw().
        hevm.expectEmit(true, false, false, true, address(vestZVE));
        emit Withdrawn(address(pam), unstake);
        assert(pam.try_withdraw(address(vestZVE)));

        // Post-state.
        assertEq(vestZVE.totalSupply(), _preSupply - unstake);
        assertEq(vestZVE.balanceOf(address(pam)), _preBal_vestZVE_pam - unstake);
        assertEq(ZVE.balanceOf(address(pam)), _preBal_ZVE_pam + unstake);
        assertEq(ZVE.balanceOf(address(vestZVE)), _preBal_ZVE_vestZVE - unstake);

    }

    // Validate fullWithdraw() works.
    // Validate getRewards() works.

    function test_ZivoeRewardsVesting_fullWithdraw_works(uint96 random) public {

        uint256 amount = uint256(random);
        uint256 deposit = uint256(random) + 100 ether; // Minimum 100 DAI deposit.

        // emitted events in createVestingSchedule() already tested above.
        assert(zvl.try_createVestingSchedule(
            address(vestZVE), 
            address(pam), 
            amount % 360 + 1, 
            (amount % 360 * 5 + 1),
            amount % 12_499_999 ether + 1 ether, 
            true
        ));

        depositReward_DAI(address(vestZVE), deposit);
        // Give little breathing room so amountWithdrawable() != 0.
        hevm.warp(block.timestamp + (amount % 360 + 1) * 1 days + random % (5000 days));

        uint256 unstake = vestZVE.amountWithdrawable(address(pam));

        // fullWithdraw().
        // hevm.expectEmit(true, false, false, true, address(vestZVE));
        // emit Withdrawn(address(pam), unstake);
        // hevm.expectEmit(true, true, false, true, address(vestZVE));
        // emit RewardDistributed(address(pam), DAI, IZivoeRewards(address(vestZVE)).earned(address(pam), DAI));
        assert(pam.try_fullWithdraw(address(vestZVE)));

    }

    function test_ZivoeRewardsVesting_getRewards_works(uint96 random) public {
        
        uint256 amount = uint256(random);
        uint256 deposit = uint256(random) + 100 ether; // Minimum 100 DAI deposit.

        // emitted events in createVestingSchedule() already tested above.
        assert(zvl.try_createVestingSchedule(
            address(vestZVE), 
            address(pam), 
            amount % 360 + 1, 
            (amount % 360 * 5 + 1),
            amount % 12_499_999 ether + 1 ether, 
            true
        ));

        depositReward_DAI(address(vestZVE), deposit);

        // Give little breathing room so amountWithdrawable() != 0.
        hevm.warp(block.timestamp + (amount % 360 + 1) * 1 days + random % (5000 days));

        // getRewards().
        // hevm.expectEmit(true, true, false, true, address(vestZVE));
        // emit RewardDistributed(address(pam), DAI, IZivoeRewards(address(vestZVE)).earned(address(pam), DAI));
        assert(pam.try_getRewards(address(vestZVE)));
    }

    
    
}
