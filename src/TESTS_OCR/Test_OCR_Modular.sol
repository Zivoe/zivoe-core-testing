// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "lib/zivoe-core-foundry/src/lockers/OCR/OCR_Modular.sol";
import "lib/zivoe-core-foundry/src/lockers/OCG/OCG_Defaults.sol";

// todo: restrictions testing redeem() fcts
contract Test_OCR_Modular is Utility {

    using SafeERC20 for IERC20;

    OCR_Modular OCR_Modular_DAI;
    OCG_Defaults OCG_Defaults_Test;

    function setUp() public {

        deployCore(false);
        simulateITO_byTranche_stakeTokens(21_000_000 ether, 4_000_000 ether);

        // Initialize and whitelist OCR_Modular lockers.
        OCR_Modular_DAI = new OCR_Modular(address(DAO), address(DAI), address(GBL), 1000);
        zvl.try_updateIsLocker(address(GBL), address(OCR_Modular_DAI), true);

        // Initialize an OCG_Defaults locker to account for defaults in the system
        OCG_Defaults_Test = new OCG_Defaults(address(DAO), address(GBL));
        zvl.try_updateIsLocker(address(GBL), address(OCG_Defaults_Test), true);
    }

    // ----------------------
    //    Helper Functions
    // ----------------------

    // helper function to initiate a redemption request
    function redemptionRequestJunior(uint256 amount) public returns (uint256 userInitBalance) {

        // Withdraw staked tranche tokens
        hevm.startPrank(address(jim));
        stJTT.fullWithdraw();
        IERC20(zJTT).safeApprove(address(OCR_Modular_DAI), amount);
        // initial values
        uint256 userInitBalance = IERC20(zJTT).balanceOf(address(jim));
        // call function
        OCR_Modular_DAI.redemptionRequestJunior(amount);
        hevm.stopPrank();

        return userInitBalance;
    }

    // helper function to initiate a redemption request
    function redemptionRequestSenior(uint256 amount) public returns (uint256 userInitBalance) {

        // Withdraw staked tranche tokens
        hevm.startPrank(address(sam));
        stSTT.fullWithdraw();
        IERC20(zSTT).safeApprove(address(OCR_Modular_DAI), amount);
        // initial values
        uint256 userInitBalance = IERC20(zSTT).balanceOf(address(sam));
        // call function
        OCR_Modular_DAI.redemptionRequestSenior(amount);
        hevm.stopPrank();

        return userInitBalance;

    }


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
        assertEq(OCR_Modular_DAI.currentEpochDistribution(), block.timestamp);
        assertEq(OCR_Modular_DAI.nextEpochDistribution(), block.timestamp + 30 days);
        assertEq(OCR_Modular_DAI.redemptionFee(), 1000);
        assertEq(OCR_Modular_DAI.withdrawRequestsNextEpoch(), 0);
        assertEq(OCR_Modular_DAI.withdrawRequestsEpoch(), 0);
        assertEq(OCR_Modular_DAI.amountWithdrawableInEpoch(), 0);
        assertEq(OCR_Modular_DAI.unclaimedWithdrawRequests(), 0);

        // Permissions
        assert(OCR_Modular_DAI.canPush());
        assert(OCR_Modular_DAI.canPull());
    }

    // validate pullFromLocker() state changes
    function test_OCR_pullFromLocker_state() public {
        uint256 amountToPush = 4_000_000 ether;

        // push stablecoins to the locker
        hevm.startPrank(address(DAO));
        IERC20(DAI).safeApprove(address(OCR_Modular_DAI), amountToPush);
        OCR_Modular_DAI.pushToLocker(DAI, amountToPush, "");
        hevm.stopPrank();

        // warp time to next epoch distribution
        hevm.warp(block.timestamp + 31 days);

        // distribute new epoch
        OCR_Modular_DAI.distributeEpoch();

        // pre check
        assert(OCR_Modular_DAI.amountWithdrawableInEpoch() == amountToPush);

        // pull from locker
        hevm.startPrank(address(DAO));
        OCR_Modular_DAI.pullFromLocker(DAI, "");
        hevm.stopPrank();

        // check
        assert(OCR_Modular_DAI.amountWithdrawableInEpoch() == 0);
        assert(IERC20(DAI).balanceOf(address(OCR_Modular_DAI)) == 0);
    }

    // pullFromLocker() should not be able to withdraw zJTT
    function test_OCR_pullFromLocker_zJTT_restrictions() public {

        redemptionRequestJunior(1_000_000 ether);

        // pull from locker
        hevm.startPrank(address(DAO));
        hevm.expectRevert("OCR_Modular::pullFromLocker() asset == zJTT || asset == zSTT");
        OCR_Modular_DAI.pullFromLocker(address(zJTT), "");
        hevm.stopPrank();
    }

    // pullFromLocker() should not be able to withdraw zSTT
    function test_OCR_pullFromLocker_zSTT_restrictions() public {

        redemptionRequestSenior(1_000_000 ether);

        // pull from locker
        hevm.startPrank(address(DAO));
        hevm.expectRevert("OCR_Modular::pullFromLocker() asset == zJTT || asset == zSTT");
        OCR_Modular_DAI.pullFromLocker(address(zSTT), "");
        hevm.stopPrank();
    }

    // Validate redemptionRequestJunior() state changes
    function test_OCR_redemptionRequestJunior_state() public {
        
        uint256 amountToRedeem = 2_000_000 ether;
        assert(OCR_Modular_DAI.withdrawRequestsNextEpoch() == 0);

        uint256 userInitBalance = redemptionRequestJunior(amountToRedeem);

        // checks
        assert(IERC20(zJTT).balanceOf(address(jim)) == userInitBalance - amountToRedeem);
        assert(OCR_Modular_DAI.withdrawRequestsNextEpoch() == amountToRedeem);
        assert(OCR_Modular_DAI.juniorBalances(address(jim)) == amountToRedeem);
        assert(OCR_Modular_DAI.userClaimTimestampJunior(address(jim)) == block.timestamp);
    }    

    // Validate redemptionRequestJunior() restrictions
    function test_OCR_redemptionRequestJunior_restrictions() public {

        uint256 amountToRedeem = 20_000_000 ether;
        assert(OCR_Modular_DAI.withdrawRequestsNextEpoch() == 0);

        // Withdraw staked tranche tokens
        hevm.startPrank(address(jim));
        stJTT.fullWithdraw();
        IERC20(zJTT).safeApprove(address(OCR_Modular_DAI), amountToRedeem);
        // initial values
        uint256 userInitBalance = IERC20(zJTT).balanceOf(address(jim));
        assert(userInitBalance < amountToRedeem);
        // checks
        hevm.expectRevert("ERC20: transfer amount exceeds balance");
        // call function
        OCR_Modular_DAI.redemptionRequestJunior(amountToRedeem);

        hevm.stopPrank();
    }   

    // Validate redemptionRequestSenior() state changes
    function test_OCR_redemptionRequestSenior_state() public {

        uint256 amountToRedeem = 10_000_000 ether;
        assert(OCR_Modular_DAI.withdrawRequestsNextEpoch() == 0);

        uint256 userInitBalance = redemptionRequestSenior(amountToRedeem);

        // checks
        assert(IERC20(zSTT).balanceOf(address(sam)) == userInitBalance - amountToRedeem);
        assert(OCR_Modular_DAI.withdrawRequestsNextEpoch() == amountToRedeem);
        assert(OCR_Modular_DAI.seniorBalances(address(sam)) == amountToRedeem);
        assert(OCR_Modular_DAI.userClaimTimestampSenior(address(sam)) == block.timestamp);
    }  

    // Validate redemptionRequestSenior() restrictions
    function test_OCR_redemptionRequestSenior_restrictions() public {

        uint256 amountToRedeem = 20_000_000 ether;
        assert(OCR_Modular_DAI.withdrawRequestsNextEpoch() == 0);

        // Withdraw staked tranche tokens
        hevm.startPrank(address(sam));
        stSTT.fullWithdraw();
        IERC20(zSTT).safeApprove(address(OCR_Modular_DAI), amountToRedeem);
        // initial values
        uint256 userInitBalance = IERC20(zSTT).balanceOf(address(sam));
        assert(userInitBalance < amountToRedeem);
        // check
        hevm.expectRevert("ERC20: transfer amount exceeds balance");
        // call function
        OCR_Modular_DAI.redemptionRequestSenior(amountToRedeem);
        hevm.stopPrank();
    }  

    // Validate distributeEpoch state changes
    function test_OCR_distributeEpoch_state() public {
        uint256 amountToDistribute= 2_000_000 ether;
        uint256 amountToRedeem = 4_000_000 ether;
        // push stablecoins to the locker
        hevm.startPrank(address(DAO));
        IERC20(DAI).safeApprove(address(OCR_Modular_DAI), amountToDistribute);
        OCR_Modular_DAI.pushToLocker(DAI, amountToDistribute, "");
        hevm.stopPrank();

        // initiate a redemption request
        redemptionRequestSenior(amountToRedeem);

        // warp time to next epoch distribution
        hevm.warp(block.timestamp + 30 days + 1);

        // pre check
        assert(IERC20(DAI).balanceOf(address(OCR_Modular_DAI)) == amountToDistribute);
        assert(OCR_Modular_DAI.withdrawRequestsNextEpoch() == amountToRedeem);
        uint256 currentEpochDistribution = OCR_Modular_DAI.currentEpochDistribution();
        // distribute new epoch
        OCR_Modular_DAI.distributeEpoch();

        // checks
        assertEq(OCR_Modular_DAI.amountWithdrawableInEpoch(), amountToDistribute);
        assertEq(OCR_Modular_DAI.nextEpochDistribution(), block.timestamp + 30 days);
        assertEq(OCR_Modular_DAI.currentEpochDistribution(), block.timestamp);
        assertEq(OCR_Modular_DAI.withdrawRequestsEpoch(), amountToRedeem);
        assertEq(OCR_Modular_DAI.withdrawRequestsNextEpoch(), 0);
        assertEq(OCR_Modular_DAI.unclaimedWithdrawRequests(), amountToRedeem);
    }

    // Validate distributeEpoch restrictions
    function test_OCR_distributeEpoch_restrictions() public {
        uint256 amountToDistribute= 2_000_000 ether;
        uint256 amountToRedeem = 4_000_000 ether;
        // push stablecoins to the locker
        hevm.startPrank(address(DAO));
        IERC20(DAI).safeApprove(address(OCR_Modular_DAI), amountToDistribute);
        OCR_Modular_DAI.pushToLocker(DAI, amountToDistribute, "");
        hevm.stopPrank();

        // initiate a redemption request
        redemptionRequestSenior(amountToRedeem);

        // warp time 1 day before next distribution
        hevm.warp(block.timestamp + 29 days);

        // check
        hevm.expectRevert("OCR_Modular::distributeEpoch() block.timestamp <= nextEpochDistribution");
        // distribute new epoch
        OCR_Modular_DAI.distributeEpoch();
    }

    // validate a scenario where amount of stablecoins >= total redemption amount
    function test_OCR_redeemJunior_full_state() public {
        uint256 amountToRedeem = 2_000_000 ether;
        // push stablecoins to the locker
        hevm.startPrank(address(DAO));
        IERC20(DAI).safeApprove(address(OCR_Modular_DAI), amountToRedeem);
        OCR_Modular_DAI.pushToLocker(DAI, amountToRedeem, "");
        hevm.stopPrank(); 

        // pre check
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(OCR_Modular_DAI)) == amountToRedeem);
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(jim)) == 0);
        uint256 initSupplyJTT = zJTT.totalSupply();

        // initiate a redemption request
        redemptionRequestJunior(amountToRedeem);
        emit log_named_uint("jim claimed timestamp", OCR_Modular_DAI.userClaimTimestampJunior(address(jim)));

        // warp time to next redemption epoch
        hevm.warp(block.timestamp + 31 days);

        // distribute new epoch
        OCR_Modular_DAI.distributeEpoch();

        // warp time + 1 day
        hevm.warp(block.timestamp + 1 days);

        // redeem
        hevm.startPrank(address(jim));
        OCR_Modular_DAI.redeemJunior();
        hevm.stopPrank();

        // checks
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(OCR_Modular_DAI)) == 0);
        assert(OCR_Modular_DAI.juniorBalances(address(jim)) == 0);
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(jim)) == amountToRedeem);
        assert(zJTT.totalSupply() == initSupplyJTT - amountToRedeem);
    }

    // validate a scenario where amount of stablecoins <= total redemption amount
    function test_OCR_redeemJunior_partial_state() public {
        uint256 amountToRedeem = 2_000_000 ether;
        uint256 amountInLocker = amountToRedeem / 2;
        // push stablecoins to the locker
        hevm.startPrank(address(DAO));
        IERC20(DAI).safeApprove(address(OCR_Modular_DAI), amountInLocker);
        OCR_Modular_DAI.pushToLocker(DAI, amountInLocker, "");
        hevm.stopPrank(); 

        // pre check
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(OCR_Modular_DAI)) == amountInLocker);
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(jim)) == 0);
        uint256 initSupplyJTT = zJTT.totalSupply();

        // initiate a redemption request
        redemptionRequestJunior(amountToRedeem);
        emit log_named_uint("jim claimed timestamp", OCR_Modular_DAI.userClaimTimestampJunior(address(jim)));

        // warp time to next redemption epoch
        hevm.warp(block.timestamp + 31 days);

        // distribute new epoch
        OCR_Modular_DAI.distributeEpoch();

        // warp time + 1 day
        hevm.warp(block.timestamp + 1 days);

        // redeem
        hevm.startPrank(address(jim));
        OCR_Modular_DAI.redeemJunior();
        hevm.stopPrank();

        // checks
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(OCR_Modular_DAI)) == 0);
        assert(OCR_Modular_DAI.juniorBalances(address(jim)) == amountToRedeem - amountInLocker);
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(jim)) == amountToRedeem - amountInLocker);
        assert(zJTT.totalSupply() == initSupplyJTT - (amountInLocker));
    }

    // validate a scenario where amount of stablecoins <= total redemption amount
    function test_OCR_redeemSenior_full_state() public {
        uint256 amountToRedeem = 6_000_000 ether;
        // push stablecoins to the locker
        hevm.startPrank(address(DAO));
        IERC20(DAI).safeApprove(address(OCR_Modular_DAI), amountToRedeem);
        OCR_Modular_DAI.pushToLocker(DAI, amountToRedeem, "");
        hevm.stopPrank(); 

        // pre check
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(OCR_Modular_DAI)) == amountToRedeem);
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(sam)) == 0);
        uint256 initSupplySTT = zSTT.totalSupply();

        // initiate a redemption request
        redemptionRequestSenior(amountToRedeem);

        // warp time to next redemption epoch
        hevm.warp(block.timestamp + 31 days);

        // distribute new epoch
        OCR_Modular_DAI.distributeEpoch();

        // warp time + 1 day
        hevm.warp(block.timestamp + 1 days);

        // redeem
        hevm.startPrank(address(sam));
        OCR_Modular_DAI.redeemSenior();
        hevm.stopPrank();

        // checks
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(OCR_Modular_DAI)) == 0);
        assert(OCR_Modular_DAI.seniorBalances(address(sam)) == 0);
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(sam)) == amountToRedeem);
        assert(zSTT.totalSupply() == initSupplySTT - amountToRedeem);
    } 

    // validate a scenario where amount of stablecoins <= total redemption amount
    function test_OCR_redeemSenior_partial_state() public {
        uint256 amountToRedeem = 2_000_000 ether;
        uint256 amountInLocker = amountToRedeem / 2;
        // push stablecoins to the locker
        hevm.startPrank(address(DAO));
        IERC20(DAI).safeApprove(address(OCR_Modular_DAI), amountInLocker);
        OCR_Modular_DAI.pushToLocker(DAI, amountInLocker, "");
        hevm.stopPrank(); 

        // pre check
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(OCR_Modular_DAI)) == amountInLocker);
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(sam)) == 0);
        uint256 initSupplySTT = zSTT.totalSupply();

        // initiate a redemption request
        redemptionRequestSenior(amountToRedeem);

        // warp time to next redemption epoch
        hevm.warp(block.timestamp + 31 days);

        // distribute new epoch
        OCR_Modular_DAI.distributeEpoch();

        // warp time + 1 day
        hevm.warp(block.timestamp + 1 days);

        // redeem
        hevm.startPrank(address(sam));
        OCR_Modular_DAI.redeemSenior();
        hevm.stopPrank();

        // checks
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(OCR_Modular_DAI)) == 0);
        assert(OCR_Modular_DAI.seniorBalances(address(sam)) == amountToRedeem - amountInLocker);
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(sam)) == amountToRedeem - amountInLocker);
        assert(zSTT.totalSupply() == initSupplySTT - (amountInLocker));

    }

    // validate a scenario where amount of stablecoins < total redemption amount
    // and there are some defaults in the system
    function test_OCR_redeemJunior_partialWithDefault_state() public {
        uint256 amountToRedeem = 2_000_000 ether;
        uint256 amountInLocker = amountToRedeem / 2;
        // push stablecoins to the locker
        hevm.startPrank(address(DAO));
        IERC20(DAI).safeApprove(address(OCR_Modular_DAI), amountInLocker);
        OCR_Modular_DAI.pushToLocker(DAI, amountInLocker, "");
        hevm.stopPrank(); 

        // increase defaults in the system (25% of zJTT supply)
        hevm.startPrank(address(god));
        OCG_Defaults_Test.increaseDefaults(1_000_000 ether);
        hevm.stopPrank();

        // pre check
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(OCR_Modular_DAI)) == amountInLocker);
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(jim)) == 0);
        assert(GBL.defaults() == 1_000_000 ether);
        uint256 initSupplyJTT = zJTT.totalSupply();

        // initiate a redemption request
        redemptionRequestJunior(amountToRedeem);

        // warp time to next redemption epoch
        hevm.warp(block.timestamp + 31 days);

        // distribute new epoch
        OCR_Modular_DAI.distributeEpoch();

        // warp time + 1 day
        hevm.warp(block.timestamp + 1 days);

        // redeem
        hevm.startPrank(address(jim));
        OCR_Modular_DAI.redeemJunior();
        hevm.stopPrank();

        // checks
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(OCR_Modular_DAI)) == 
        (25 * (amountInLocker)) / 100);
        assert(OCR_Modular_DAI.juniorBalances(address(jim)) == amountToRedeem - amountInLocker);
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(jim)) == (75 * (amountInLocker)) / 100); 
        assert(zJTT.totalSupply() == initSupplyJTT - (amountInLocker));
    }

    // validate a scenario where amount of stablecoins < total redemption amount
    // and there are some defaults in the system
    function test_OCR_redeemSenior_partialWithDefault_state() public {
        uint256 amountToRedeem = 2_000_000 ether;
        uint256 amountInLocker = amountToRedeem / 2;
        // push stablecoins to the locker
        hevm.startPrank(address(DAO));
        IERC20(DAI).safeApprove(address(OCR_Modular_DAI), amountInLocker);
        OCR_Modular_DAI.pushToLocker(DAI, amountInLocker, "");
        hevm.stopPrank(); 

        // increase defaults in the system (all zJTT + 25% of zSTT supply)
        hevm.startPrank(address(god));
        OCG_Defaults_Test.increaseDefaults(8_000_000 ether);
        hevm.stopPrank();

        // pre check
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(OCR_Modular_DAI)) == amountInLocker);
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(sam)) == 0);
        assert(GBL.defaults() == 8_000_000 ether);
        uint256 initSupplySTT = zSTT.totalSupply();

        // initiate a redemption request
        redemptionRequestSenior(amountToRedeem);

        // warp time to next redemption epoch
        hevm.warp(block.timestamp + 31 days);

        // distribute new epoch
        OCR_Modular_DAI.distributeEpoch();

        // warp time + 1 day
        hevm.warp(block.timestamp + 1 days);

        // redeem
        hevm.startPrank(address(sam));
        OCR_Modular_DAI.redeemSenior();
        hevm.stopPrank();

        // checks
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(OCR_Modular_DAI)) == 
        (25 * (amountInLocker)) / 100);
        assert(OCR_Modular_DAI.seniorBalances(address(sam)) == amountToRedeem - amountInLocker);
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(sam)) == (75 * (amountInLocker)) / 100); 
        assert(zSTT.totalSupply() == initSupplySTT - (amountInLocker));
    }

    // perform a fuzz testing on a dynamic basis (have to add defaults)
    function test_OCR_fuzzTest(
        uint88 depositTranches
    ) public {
        // In order to have a minimum of "depositJTT" = 1
        // we have to assume the following:
        hevm.assume(depositTranches >= 5);
        // accounting
        uint256 depositJTT = uint256((20 * uint256(depositTranches)) / 100);
        uint256 depositSTT = uint256(depositTranches);

        // start epoch 1
        // fund accounts with DAI
        deal(DAI, address(jim), depositJTT);
        deal(DAI, address(sam), depositSTT);

        // deposit in tranches
        // senior
        hevm.startPrank(address(sam));
        IERC20(DAI).safeApprove(address(ZVT), depositSTT);
        ZVT.depositSenior(depositSTT, DAI);
        hevm.stopPrank();
        // junior
        hevm.startPrank(address(jim));
        IERC20(DAI).safeApprove(address(ZVT), depositJTT);
        ZVT.depositJunior(depositJTT, DAI);
        hevm.stopPrank();

        // push half of deposits to the locker in epoch 1
        hevm.startPrank(address(DAO));
        IERC20(DAI).safeApprove(address(OCR_Modular_DAI), (depositJTT / 2) + (depositSTT / 2));
        OCR_Modular_DAI.pushToLocker(DAI, (depositJTT / 2) + (depositSTT / 2), "");
        hevm.stopPrank();

        // warp 2 days through time
        hevm.warp(block.timestamp + 2 days);

        // make redemption request for full amount
        redemptionRequestJunior(depositJTT);
        redemptionRequestSenior(depositSTT);

        assert(OCR_Modular_DAI.juniorBalances(address(jim)) == depositJTT);
        assert(OCR_Modular_DAI.seniorBalances(address(sam)) == depositSTT);

        // go to end of epoch
        hevm.warp(block.timestamp + 29 days);

        // distribute epoch
        OCR_Modular_DAI.distributeEpoch();

        // start epoch 2
        // +2 days 
        hevm.warp(block.timestamp + 2 days);

        // redeem junior
        hevm.startPrank(address(jim));
        OCR_Modular_DAI.redeemJunior();
        hevm.stopPrank();

        // +2 days 
        hevm.warp(block.timestamp + 2 days);

        // redeem senior
        hevm.startPrank(address(sam));
        OCR_Modular_DAI.redeemSenior();
        hevm.stopPrank();

        // push other half of deposits to the locker in epoch 2
        hevm.startPrank(address(DAO));
        IERC20(DAI).safeApprove(address(OCR_Modular_DAI), (depositJTT / 2) + (depositSTT / 2));
        OCR_Modular_DAI.pushToLocker(DAI, (depositJTT / 2) + (depositSTT / 2), "");
        hevm.stopPrank();

        // warp to end of epoch
        hevm.warp(block.timestamp + 27 days);

        // distribute epoch
        OCR_Modular_DAI.distributeEpoch();

        // redeem junior
        hevm.startPrank(address(jim));
        OCR_Modular_DAI.redeemJunior();
        hevm.stopPrank();

        // redeem senior
        hevm.startPrank(address(sam));
        OCR_Modular_DAI.redeemSenior();
        hevm.stopPrank();
        
        assert(OCR_Modular_DAI.juniorBalances(address(jim)) + OCR_Modular_DAI.seniorBalances(address(sam))
        == OCR_Modular_DAI.unclaimedWithdrawRequests());

        // If we have some unclaimed amounts due to roundings
        // we continue redeeming in the next epoch
        hevm.startPrank(address(DAO));
        IERC20(DAI).safeApprove(address(OCR_Modular_DAI), OCR_Modular_DAI.unclaimedWithdrawRequests());
        OCR_Modular_DAI.pushToLocker(DAI, OCR_Modular_DAI.unclaimedWithdrawRequests(), "");
        hevm.stopPrank();

        // warp to end of epoch
        hevm.warp(block.timestamp + 31 days);

        // distribute epoch
        OCR_Modular_DAI.distributeEpoch();

        // if we have remaining amounts for junior, redeem
        if (OCR_Modular_DAI.juniorBalances(address(jim)) > 0) {
            hevm.startPrank(address(jim));
            OCR_Modular_DAI.redeemJunior();
            hevm.stopPrank();
        }

        // if we have remaining amounts for senior, redeem
        if (OCR_Modular_DAI.seniorBalances(address(sam)) > 0) {
            hevm.startPrank(address(sam));
            OCR_Modular_DAI.redeemSenior();
            hevm.stopPrank();
        }

        // checks
        assert(OCR_Modular_DAI.juniorBalances(address(jim)) == 0);
        assert(OCR_Modular_DAI.seniorBalances(address(sam)) == 0);
    }

}