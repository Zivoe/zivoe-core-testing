// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../Utility/Utility.sol";

import "../../lib/zivoe-core-foundry/src/lockers/OCG/OCG_ERC20_FreeClaim.sol";


contract Test_ZivoeRewards is Utility {

    OCG_ERC20_FreeClaim ZVEClaimer;

    function setUp() public {

        deployCore(false);

        // Simulate ITO (10mm * 8 * 4), DAI/FRAX/USDC/USDT.
        simulateITO(10_000_000 ether, 10_000_000 ether, 10_000_000 * USD, 10_000_000 * USD);

        claimITO_and_approveTokens_and_stakeTokens(false);

        // Create an OCG locker which moves ZVE from DAO -> OCG ... allows another account to claim.
        // We need ZVE accessible by someone to test the ZivoeRewards functionality contract (generic $ZVE staking contract).
        ZVEClaimer = new OCG_ERC20_FreeClaim(address(DAO));
        assert(zvl.try_updateIsLocker(address(GBL), address(ZVEClaimer), true));
        assert(god.try_push(address(DAO), address(ZVEClaimer), address(ZVE), 5000 ether, ""));
        ZVEClaimer.forward(address(ZVE), 5000 ether, address(sam));
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

    event StakedFor(address indexed account, uint256 amount, address indexed by);

    event Withdrawn(address indexed account, uint256 amount);

    event RewardDistributed(address indexed account, address indexed rewardsToken, uint256 reward);

    // ----------------
    //    Unit Tests
    // ----------------

    // Validate addReward() state changes.
    // Validate addReward() restrictions.
    // This includes:
    //  - Reward isn't already set (rewardData[_rewardsToken].rewardsDuration == 0)
    //  - Maximum of 10 rewards are set (rewardTokens.length < 10) .. TODO: Discuss with auditors @RTV what max feasible size is?

    function test_ZivoeRewards_addReward_restrictions_ZVL_stZVE() public {
        // Can't call if not ZVL().
        hevm.startPrank(address(bob));
        hevm.expectRevert("_msgSender() != IZivoeGlobals_ZivoeRewards(GBL).ZVL()");
        stZVE.addReward(FRAX, 30 days);
        hevm.stopPrank();
    }

    function test_ZivoeRewards_addReward_restrictions_rewardsDuration0() public {
        // Can't call if rewardData[_rewardsToken].rewardsDuration != 0 (meaning subsequent addReward() calls).
        assert(zvl.try_addReward(address(stZVE), WETH, 30 days));
        hevm.startPrank(address(zvl));
        hevm.expectRevert("ZivoeRewards::addReward() rewardData[_rewardsToken].rewardsDuration != 0");
        stZVE.addReward(WETH, 20 days);
        hevm.stopPrank();
    }

    function test_ZivoeRewards_addReward_restrictions_maxRewards() public {
        // Can't call if more than 10 rewards have been added.
        assert(zvl.try_addReward(address(stZVE), WETH, 30 days)); // Note: DAI, ZVE added already.
        assert(zvl.try_addReward(address(stZVE), address(4), 1));
        assert(zvl.try_addReward(address(stZVE), address(5), 1));
        assert(zvl.try_addReward(address(stZVE), address(6), 1));
        assert(zvl.try_addReward(address(stZVE), address(7), 1));
        assert(zvl.try_addReward(address(stZVE), address(8), 1));
        assert(zvl.try_addReward(address(stZVE), address(9), 1));
        assert(zvl.try_addReward(address(stZVE), address(10), 1));
        assert(!zvl.try_addReward(address(stZVE), address(11), 1));

        hevm.startPrank(address(zvl));
        hevm.expectRevert("ZivoeRewards::addReward() rewardTokens.length >= 10");
        stZVE.addReward(address(11), 1);
        hevm.stopPrank();
    }

    function test_ZivoeRewards_addReward_state(uint96 random) public {

        uint256 duration = uint256(random) + 1;

        // Pre-state.
        (
            uint256 rewardsDuration,
            uint256 periodFinish,
            uint256 rewardRate,
            uint256 lastUpdateTime,
            uint256 rewardPerTokenStored
        ) = stZVE.rewardData(WETH);

        assertEq(rewardsDuration, 0);
        assertEq(periodFinish, 0);
        assertEq(rewardRate, 0);
        assertEq(lastUpdateTime, 0);
        assertEq(rewardPerTokenStored, 0);

        hevm.expectEmit(true, false, false, false, address(stZVE));
        emit RewardAdded(WETH);
        assert(zvl.try_addReward(address(stZVE), WETH, duration));

        // Post-state.
        assertEq(stZVE.rewardTokens(2), WETH);

        (
            rewardsDuration,
            periodFinish,
            rewardRate,
            lastUpdateTime,
            rewardPerTokenStored
        ) = stZVE.rewardData(WETH);

        assertEq(rewardsDuration, duration);
        assertEq(periodFinish, 0);
        assertEq(rewardRate, 0);
        assertEq(lastUpdateTime, 0);
        assertEq(rewardPerTokenStored, 0);

    }

    // Validate depositReward() state changes.
    
    function test_ZivoeRewards_depositReward_initial_state(uint96 random) public {

        uint256 deposit = uint256(random);

        // Pre-state.
        uint256 _preDAI = IERC20(DAI).balanceOf(address(stZVE));

        (
            uint256 rewardsDuration,
            uint256 periodFinish,
            uint256 rewardRate,
            uint256 lastUpdateTime,
            uint256 rewardPerTokenStored
        ) = stZVE.rewardData(DAI);

        assert(block.timestamp >= periodFinish);

        // depositReward().
        mint("DAI", address(bob), deposit);
        assert(bob.try_approveToken(DAI, address(stZVE), deposit));

        hevm.expectEmit(true, true, false, true, address(stZVE));
        emit RewardDeposited(DAI, deposit, address(bob));
        assert(bob.try_depositReward(address(stZVE), DAI, deposit));

        // Post-state.
        assertEq(IERC20(DAI).balanceOf(address(stZVE)), _preDAI + deposit);

        (
            rewardsDuration,
            periodFinish,
            rewardRate,
            lastUpdateTime,
            rewardPerTokenStored
        ) = stZVE.rewardData(DAI);

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

    function test_ZivoeRewards_depositReward_subsequent_state(uint96 random) public {

        uint256 deposit = uint256(random);

        depositReward_DAI(address(stZVE), deposit);

        hevm.warp(block.timestamp + random % 60 days); // 50% chance warp past periodFinish

        // Pre-state.
        uint256 _preDAI = IERC20(DAI).balanceOf(address(stZVE));

        (
            uint256 rewardsDuration,
            uint256 _prePeriodFinish,
            uint256 _preRewardRate,
            uint256 lastUpdateTime,
            uint256 rewardPerTokenStored
        ) = stZVE.rewardData(DAI);
        
        uint256 _postPeriodFinish;
        uint256 _postRewardRate;

        // depositReward().
        mint("DAI", address(bob), deposit);
        assert(bob.try_approveToken(DAI, address(stZVE), deposit));

        hevm.expectEmit(true, true, false, true, address(stZVE));
        emit RewardDeposited(DAI, deposit, address(bob));
        assert(bob.try_depositReward(address(stZVE), DAI, deposit));

        // Post-state.
        assertEq(IERC20(DAI).balanceOf(address(stZVE)), _preDAI + deposit);
        (
            rewardsDuration,
            _postPeriodFinish,
            _postRewardRate,
            lastUpdateTime,
            rewardPerTokenStored
        ) = stZVE.rewardData(DAI);

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

    function test_ZivoeRewards_depositReward_subsequent_state(uint96 random, bool preStake) public {

        uint256 deposit = uint256(random);

        // stake().
        if (preStake) {
            // stakeTokens();
            assert(sam.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam))));
            sam.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam)));
        }

        // depositReward().
        depositReward_DAI(address(stZVE), deposit);

        hevm.warp(block.timestamp + random % 60 days); // 50% chance warp past periodFinish

        // Pre-state.
        uint256 _preDAI = IERC20(DAI).balanceOf(address(stZVE));

        (
            uint256 rewardsDuration,
            uint256 _prePeriodFinish,
            uint256 _preRewardRate,
            uint256 lastUpdateTime,
            uint256 rewardPerTokenStored
        ) = stZVE.rewardData(DAI);
        
        uint256 _postPeriodFinish;
        uint256 _postRewardRate;

        assertEq(rewardPerTokenStored, 0);

        // depositReward().
        mint("DAI", address(bob), deposit);
        assert(bob.try_approveToken(DAI, address(stZVE), deposit));

        hevm.expectEmit(true, true, false, true, address(stZVE));
        emit RewardDeposited(DAI, deposit, address(bob));
        assert(bob.try_depositReward(address(stZVE), DAI, deposit));

        // Post-state.
        assertEq(IERC20(DAI).balanceOf(address(stZVE)), _preDAI + deposit);
        (
            rewardsDuration,
            _postPeriodFinish,
            _postRewardRate,
            lastUpdateTime,
            rewardPerTokenStored
        ) = stZVE.rewardData(DAI);

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
        assertEq(rewardPerTokenStored, stZVE.rewardPerToken(address(DAI)));

    }
    
    // Validate stake() state changes.
    // Validate stake() restrictions.
    // This includes:
    //  - Stake amount must be greater than 0.

    function test_ZivoeRewards_stake_restrictions_stake0() public {
        // Can't stake a 0 amount.
        assert(sam.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam))));

        hevm.startPrank(address(sam));
        hevm.expectRevert("ZivoeRewards::stake() amount == 0");
        stZVE.stake(0);
        hevm.stopPrank();
    }

    function test_ZivoeRewards_stake_initial_state(uint96 random) public {

        uint256 deposit = uint256(random) % (ZVE.balanceOf(address(sam)) - 1) + 1;

        // Pre-state.
        uint256 _preSupply = stZVE.totalSupply();
        uint256 _preBal_stZVE_sam = stZVE.balanceOf(address(sam));
        uint256 _preBal_ZVE_sam = ZVE.balanceOf(address(sam));
        uint256 _preBal_ZVE_stZVE = ZVE.balanceOf(address(stZVE));

        assertEq(_preSupply, 0);
        assertEq(_preBal_stZVE_sam, 0);
        assertGt(_preBal_ZVE_sam, 0);
        assertEq(_preBal_ZVE_stZVE, 0);

        assertEq(stZVE.viewRewards(address(sam), DAI), 0);
        assertEq(stZVE.viewAccountRewardPerTokenPaid(address(sam), DAI), 0);

        // stake().
        assert(sam.try_approveToken(address(ZVE), address(stZVE), deposit));

        hevm.expectEmit(true, false, false, true, address(stZVE));
        emit Staked(address(sam), deposit);
        assert(sam.try_stake(address(stZVE), deposit));

        // Post-state.
        assertEq(stZVE.totalSupply(), _preSupply + deposit);
        assertEq(stZVE.balanceOf(address(sam)), _preBal_stZVE_sam + deposit);
        assertEq(ZVE.balanceOf(address(sam)), _preBal_ZVE_sam - deposit);
        assertEq(ZVE.balanceOf(address(stZVE)), _preBal_ZVE_stZVE + deposit);

        assertEq(stZVE.viewRewards(address(sam), DAI), 0);
        assertEq(stZVE.viewAccountRewardPerTokenPaid(address(sam), DAI), 0);

    }

    function test_ZivoeRewards_stake_subsequent_state(uint96 random, bool preStake, bool preDeposit) public {

        // stake(), 50% chance for sam to pre-stake 50% of his ZVE.
        if (preStake) {
            assert(sam.try_approveToken(address(ZVE), address(stZVE), ZVE.balanceOf(address(sam)) / 2));

            hevm.expectEmit(true, false, false, true, address(stZVE));
            emit Staked(address(sam), ZVE.balanceOf(address(sam)) / 2);
            assert(sam.try_stake(address(stZVE), ZVE.balanceOf(address(sam)) / 2));
        }

        // depositReward(), 50% chance to deposit a reward.
        if (preDeposit) {
            depositReward_DAI(address(stZVE), uint256(random));
        }

        hevm.warp(block.timestamp + random % 60 days); // 50% chance to warp past rewardsDuration (30 days).

        uint256 deposit = uint256(random) % (ZVE.balanceOf(address(sam)) - 1) + 1;

        // Pre-state.
        uint256 _preSupply = stZVE.totalSupply();
        uint256 _preBal_stZVE_sam = stZVE.balanceOf(address(sam));
        uint256 _preBal_ZVE_sam = ZVE.balanceOf(address(sam));
        uint256 _preBal_ZVE_stZVE = ZVE.balanceOf(address(stZVE));

        preStake ? assertGt(_preSupply, 0) : assertEq(_preSupply, 0);
        preStake ? assertGt(_preBal_stZVE_sam, 0) : assertEq(_preBal_stZVE_sam, 0);
        preStake ? assertGt(_preBal_ZVE_stZVE, 0) : assertEq(_preBal_ZVE_stZVE, 0);
        assertGt(_preBal_ZVE_sam, 0);

        assertEq(stZVE.viewRewards(address(sam), DAI), 0);
        assertEq(stZVE.viewAccountRewardPerTokenPaid(address(sam), DAI), 0);

        // stake().
        assert(sam.try_approveToken(address(ZVE), address(stZVE), deposit));

        hevm.expectEmit(true, false, false, true, address(stZVE));
        emit Staked(address(sam), deposit);
        assert(sam.try_stake(address(stZVE), deposit));

        // Post-state.
        (,,,, uint256 rewardPerTokenStored) = stZVE.rewardData(DAI);

        assertEq(stZVE.totalSupply(), _preSupply + deposit);
        assertEq(stZVE.balanceOf(address(sam)), _preBal_stZVE_sam + deposit);
        assertEq(ZVE.balanceOf(address(sam)), _preBal_ZVE_sam - deposit);
        assertEq(ZVE.balanceOf(address(stZVE)), _preBal_ZVE_stZVE + deposit);

        assertEq(stZVE.viewRewards(address(sam), DAI), stZVE.earned(address(sam), DAI));
        assertEq(stZVE.viewAccountRewardPerTokenPaid(address(sam), DAI), rewardPerTokenStored);

    }
    
    // Validate stakeFor() state changes.
    // Validate stakeFor() restrictions.
    // This includes:
    //  - Stake amount must be greater than 0.
    //  - Account must not be address(0)

    function test_ZivoeRewards_stakeFor_restrictions_stake0() public {
        // Can't stake a 0 amount.
        assert(sam.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam))));

        hevm.startPrank(address(sam));
        hevm.expectRevert("ZivoeRewards::stakeFor() amount == 0");
        stZVE.stakeFor(0, address(jim));
        hevm.stopPrank();
    }

    function test_ZivoeRewards_stakeFor_restrictions_account0() public {
        // Can't stake for address(0).
        assert(sam.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam))));

        hevm.startPrank(address(sam));
        hevm.expectRevert("ZivoeRewards::stakeFor() account == address(0)");
        stZVE.stakeFor(1, address(0));
        hevm.stopPrank();
    }

    function test_ZivoeRewards_stakeFor_initial_state(uint96 random) public {

        uint256 deposit = uint256(random) % (ZVE.balanceOf(address(sam)) - 1) + 1;

        // Pre-state.
        uint256 _preSupply = stZVE.totalSupply();
        uint256 _preBal_stZVE_jim = stZVE.balanceOf(address(jim));
        uint256 _preBal_ZVE_sam = ZVE.balanceOf(address(sam));
        uint256 _preBal_ZVE_stZVE = ZVE.balanceOf(address(stZVE));

        assertEq(_preSupply, 0);
        assertEq(_preBal_stZVE_jim, 0);
        assertGt(_preBal_ZVE_sam, 0);
        assertEq(_preBal_ZVE_stZVE, 0);

        assertEq(stZVE.viewRewards(address(jim), DAI), 0);
        assertEq(stZVE.viewAccountRewardPerTokenPaid(address(jim), DAI), 0);

        // stakeFor().
        assert(sam.try_approveToken(address(ZVE), address(stZVE), deposit));

        hevm.expectEmit(true, true, false, true, address(stZVE));
        emit StakedFor(address(jim), deposit, address(sam));
        assert(sam.try_stakeFor(address(stZVE), deposit, address(jim)));

        // Post-state.
        assertEq(stZVE.totalSupply(), _preSupply + deposit);
        assertEq(stZVE.balanceOf(address(jim)), _preBal_stZVE_jim + deposit);
        assertEq(ZVE.balanceOf(address(sam)), _preBal_ZVE_sam - deposit);
        assertEq(ZVE.balanceOf(address(stZVE)), _preBal_ZVE_stZVE + deposit);

        assertEq(stZVE.viewRewards(address(jim), DAI), 0);
        assertEq(stZVE.viewAccountRewardPerTokenPaid(address(jim), DAI), 0);

    }

    function test_ZivoeRewards_stakeFor_subsequent_state(uint96 random, bool preStake, bool preDeposit) public {

        // stake(), 50% chance for sam to pre-stake 50% of his ZVE.
        if (preStake) {
            assert(sam.try_approveToken(address(ZVE), address(stZVE), ZVE.balanceOf(address(sam)) / 2));

            hevm.expectEmit(true, false, false, true, address(stZVE));
            emit StakedFor(address(jim), ZVE.balanceOf(address(sam)) / 2, address(sam));
            assert(sam.try_stakeFor(address(stZVE), ZVE.balanceOf(address(sam)) / 2, address(jim)));
        }

        // depositReward(), 50% chance to deposit a reward.
        if (preDeposit) {
            depositReward_DAI(address(stZVE), uint256(random));
        }

        hevm.warp(block.timestamp + random % 60 days); // 50% chance to warp past rewardsDuration (30 days).

        uint256 deposit = uint256(random) % (ZVE.balanceOf(address(sam)) - 1) + 1;

        // Pre-state.
        uint256 _preSupply = stZVE.totalSupply();
        uint256 _preBal_stZVE_jim = stZVE.balanceOf(address(jim));
        uint256 _preBal_ZVE_sam = ZVE.balanceOf(address(sam));
        uint256 _preBal_ZVE_stZVE = ZVE.balanceOf(address(stZVE));

        preStake ? assertGt(_preSupply, 0) : assertEq(_preSupply, 0);
        preStake ? assertGt(_preBal_stZVE_jim, 0) : assertEq(_preBal_stZVE_jim, 0);
        preStake ? assertGt(_preBal_ZVE_stZVE, 0) : assertEq(_preBal_ZVE_stZVE, 0);
        assertGt(_preBal_ZVE_sam, 0);

        assertEq(stZVE.viewRewards(address(jim), DAI), 0);
        assertEq(stZVE.viewAccountRewardPerTokenPaid(address(jim), DAI), 0);

        // stake().
        assert(sam.try_approveToken(address(ZVE), address(stZVE), deposit));

        hevm.expectEmit(true, true, false, true, address(stZVE));
        emit StakedFor(address(jim), deposit, address(sam));
        assert(sam.try_stakeFor(address(stZVE), deposit, address(jim)));

        // Post-state.
        (,,,, uint256 rewardPerTokenStored) = stZVE.rewardData(DAI);

        assertEq(stZVE.totalSupply(), _preSupply + deposit);
        assertEq(stZVE.balanceOf(address(jim)), _preBal_stZVE_jim + deposit);
        assertEq(ZVE.balanceOf(address(sam)), _preBal_ZVE_sam - deposit);
        assertEq(ZVE.balanceOf(address(stZVE)), _preBal_ZVE_stZVE + deposit);

        assertEq(stZVE.viewRewards(address(jim), DAI), stZVE.earned(address(jim), DAI));
        assertEq(stZVE.viewAccountRewardPerTokenPaid(address(jim), DAI), rewardPerTokenStored);

    }

    // Validate withdraw() state changes.
    // Validate withdraw() restrictions.
    // This includes:
    //  - amount > 0

    function test_ZivoeRewards_withdraw_restrictions() public {

        // stakeTokens();
        assert(sam.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam))));
        sam.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam)));

        // Can't withdraw if amount == 0.
        hevm.startPrank(address(sam));
        hevm.expectRevert("ZivoeRewards::withdraw() amount == 0");
        stZVE.withdraw(0);
        hevm.stopPrank();
    }

    function test_ZivoeRewards_withdraw_state(uint96 random) public {

        // stakeTokens();
        assert(sam.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam))));
        sam.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam)));

        uint256 unstake = uint256(random) % (stZVE.balanceOf(address(sam)) - 1) + 1;

        // Pre-state.
        uint256 _preSupply = stZVE.totalSupply();
        uint256 _preBal_stZVE_sam = stZVE.balanceOf(address(sam));
        uint256 _preBal_ZVE_sam = ZVE.balanceOf(address(sam));
        uint256 _preBal_ZVE_stZVE = ZVE.balanceOf(address(stZVE));

        assertGt(_preSupply, 0);
        assertGt(_preBal_stZVE_sam, 0);
        assertEq(_preBal_ZVE_sam, 0);
        assertGt(_preBal_ZVE_stZVE, 0);

        // withdraw().
        hevm.expectEmit(true, false, false, true, address(stZVE));
        emit Withdrawn(address(sam), unstake);
        assert(sam.try_withdraw(address(stZVE), unstake));

        // Post-state.
        assertEq(stZVE.totalSupply(), _preSupply - unstake);
        assertEq(stZVE.balanceOf(address(sam)), _preBal_stZVE_sam - unstake);
        assertEq(ZVE.balanceOf(address(sam)), _preBal_ZVE_sam + unstake);
        assertEq(ZVE.balanceOf(address(stZVE)), _preBal_ZVE_stZVE - unstake);

    }

    // Validate getRewardAt() state changes.

    function Xtest_ZivoeRewards_getRewardAt_state(uint96 random) public {
        
        uint256 deposit = uint256(random) + 100 ether; // Minimum 100 DAI deposit.

        // stake().
        // depositReward().
        // stakeTokens();
        assert(sam.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam))));
        sam.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam)));
        depositReward_DAI(address(stZVE), deposit);

        hevm.warp(block.timestamp + random % 60 days + 1 seconds); // 50% chance to go past periodFinish.

        // Pre-state.
        uint256 _preDAI_sam = IERC20(DAI).balanceOf(address(sam));
        
        {
            uint256 _preEarned = stZVE.viewRewards(address(sam), DAI);
            uint256 _preURPTP = stZVE.viewAccountRewardPerTokenPaid(address(sam), DAI);
            assertEq(_preEarned, 0);
            assertEq(_preURPTP, 0);
        }
        
        assertGt(IERC20(DAI).balanceOf(address(stZVE)), 0);
        
        // getRewardAt().

        uint256 rewardsEarned = IZivoeRewards(address(stZVE)).earned(address(sam), DAI);

        hevm.expectEmit(true, true, false, true, address(stZVE));
        emit RewardDistributed(address(sam), DAI, rewardsEarned);
        assert(sam.try_getRewardAt(address(stZVE), 0));

        // Post-state.
        assertGt(IERC20(DAI).balanceOf(address(sam)), _preDAI_sam);

        (
            ,
            ,
            ,
            uint256 _postLastUpdateTime,
            uint256 _postRewardPerTokenStored
        ) = stZVE.rewardData(DAI);
        
        assertEq(_postRewardPerTokenStored, stZVE.rewardPerToken(DAI));
        assertEq(_postLastUpdateTime, stZVE.lastTimeRewardApplicable(DAI));

        assertEq(stZVE.viewAccountRewardPerTokenPaid(address(sam), DAI), _postRewardPerTokenStored);
        assertEq(stZVE.viewRewards(address(sam), DAI), 0);
        assertEq(IERC20(DAI).balanceOf(address(sam)), _postRewardPerTokenStored * stZVE.balanceOf(address(sam)) / 10**18);

    }

    // Validate getRewards() works.
    // Validate fullWithdraw() works.
    // Note: These simply call other tested functions.

    function test_ZivoeRewards_fullWithdraw_works(uint96 random) public {

        uint256 deposit = uint256(random) + 100 ether; // Minimum 100 DAI deposit.

        // stake().
        // depositReward().
        // stakeTokens();
        assert(sam.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam))));
        uint256 stakedAmount = IERC20(address(ZVE)).balanceOf(address(sam));
        sam.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam)));
        depositReward_DAI(address(stZVE), deposit);

        hevm.warp(block.timestamp + random % 60 days + 1 seconds); // 50% chance to go past periodFinish.

        // fullWithdraw().
        // hevm.expectEmit(true, false, false, true, address(stZVE));
        // emit Withdrawn(address(sam), stakedAmount);
        // hevm.expectEmit(true, true, false, true, address(stZVE));
        // emit RewardDistributed(address(sam), DAI, IZivoeRewards(address(stZVE)).earned(address(sam), DAI));
        assert(sam.try_fullWithdraw(address(stZVE)));

    }

    function test_ZivoeRewards_getRewards_works(uint96 random) public {

        uint256 deposit = uint256(random) + 100 ether; // Minimum 100 DAI deposit.

        // stake().
        // depositReward().
        // stakeTokens();
        assert(sam.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam))));
        sam.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam)));
        depositReward_DAI(address(stZVE), deposit);

        hevm.warp(block.timestamp + random % 60 days + 1 seconds); // 50% chance to go past periodFinish.

        // getRewards().
        // hevm.expectEmit(true, true, false, true, address(stZVE));
        // emit RewardDistributed(address(sam), DAI, IZivoeRewards(address(stZVE)).earned(address(sam), DAI));
        assert(sam.try_getRewards(address(stZVE)));

    }
    
}
