// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "../../lib/zivoe-core-foundry/src/lockers/OCR/OCR_Modular.sol";
import "../../lib/zivoe-core-foundry/src/lockers/OCG/OCG_Defaults.sol";

contract Test_OCR_Modular is Utility {

    using SafeERC20 for IERC20;

    OCR_Modular OCR_Modular_DAI;
    OCG_Defaults OCG_Defaults_Test;

    function setUp() public {

        deployCore(false);
        simulateITO_byTranche_stakeTokens(25_000_000 ether, 4_000_000 ether);

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
    function redemptionRequestJunior(uint256 amount) public returns (uint256 accountInitBalance) {

        // Withdraw staked tranche tokens
        hevm.startPrank(address(jim));
        stJTT.fullWithdraw();
        IERC20(zJTT).safeApprove(address(OCR_Modular_DAI), amount);
        // initial values
        uint256 accountInitBalance = IERC20(zJTT).balanceOf(address(jim));
        // call function
        OCR_Modular_DAI.redemptionRequestJunior(amount);
        hevm.stopPrank();

        return accountInitBalance;
    }

    // helper function to initiate a redemption request
    function redemptionRequestSenior(uint256 amount) public returns (uint256 accountInitBalance) {

        // Withdraw staked tranche tokens
        hevm.startPrank(address(sam));
        stSTT.fullWithdraw();
        IERC20(zSTT).safeApprove(address(OCR_Modular_DAI), amount);
        // initial values
        uint256 accountInitBalance = IERC20(zSTT).balanceOf(address(sam));
        // call function
        OCR_Modular_DAI.redemptionRequestSenior(amount);
        hevm.stopPrank();

        return accountInitBalance;

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
        assertEq(OCR_Modular_DAI.amountPushedInCurrentEpoch(), 0);

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

    // validate pullFromLockerPartial() state changes
    function test_OCR_pullFromLockerPartial_state_fuzzTest(uint88 amountToPush, uint88 amountToPull) public {
        hevm.assume(amountToPush > 0);
        hevm.assume(amountToPull > 0 && amountToPull <= (uint256(amountToPush) * 2));

        // fund account with DAI
        deal(DAI, address(sam), uint256(amountToPush) * 2);

        // deposit in senior tranches
        hevm.startPrank(address(sam));
        IERC20(DAI).safeApprove(address(ZVT), uint256(amountToPush) * 2);
        ZVT.depositSenior(uint256(amountToPush) * 2, DAI);
        hevm.stopPrank();

        // push stablecoins to the locker
        hevm.startPrank(address(DAO));
        IERC20(DAI).safeApprove(address(OCR_Modular_DAI), amountToPush);
        OCR_Modular_DAI.pushToLocker(DAI, amountToPush, "");
        hevm.stopPrank();

        // warp time to next epoch (1) distribution
        hevm.warp(block.timestamp + 31 days);

        // distribute new epoch
        OCR_Modular_DAI.distributeEpoch();

        // intermediate check
        assert(OCR_Modular_DAI.amountWithdrawableInEpoch() == amountToPush);
        assert(OCR_Modular_DAI.amountPushedInCurrentEpoch() == 0);

        // warp time further in current epoch
        // as we need to check bot variables "amountPushedInCurrentEpoch" and "amountWithdrawableInEpoch"
        hevm.warp(block.timestamp + 10 days);

        // push stablecoins to the locker
        hevm.startPrank(address(DAO));
        IERC20(DAI).safeApprove(address(OCR_Modular_DAI), amountToPush);
        OCR_Modular_DAI.pushToLocker(DAI, amountToPush, "");
        hevm.stopPrank();

        // intermediate check
        assert(OCR_Modular_DAI.amountWithdrawableInEpoch() == amountToPush);
        assert(OCR_Modular_DAI.amountPushedInCurrentEpoch() == amountToPush);

        // pull from locker partial amount
        hevm.startPrank(address(DAO));
        OCR_Modular_DAI.pullFromLockerPartial(DAI, amountToPull, "");
        hevm.stopPrank();

        // check
        if (amountToPull > amountToPush) {
            assert(OCR_Modular_DAI.amountPushedInCurrentEpoch() == 0);
            uint256 diff = amountToPull - amountToPush;
            assert(OCR_Modular_DAI.amountWithdrawableInEpoch() == amountToPush - diff);
        }

        if (amountToPull <= amountToPush) {
            assert(OCR_Modular_DAI.amountPushedInCurrentEpoch() == amountToPush - amountToPull);
            assert(OCR_Modular_DAI.amountWithdrawableInEpoch() == amountToPush);
        }
    }

    // validate pullFromLockerPartial() restrictions, pull zJTT 
    function test_OCR_pullFromLockerPartial_zJTT_restrictions() public {
        // try to pull zJTT from locker
        hevm.startPrank(address(DAO));
        hevm.expectRevert("OCR_Modular::pullFromLockerPartial() asset == zJTT || asset == zSTT");
        OCR_Modular_DAI.pullFromLockerPartial(address(zJTT), 1, "");
        hevm.stopPrank();
    }

    // validate pullFromLockerPartial() restrictions, pull zSTT
    function test_OCR_pullFromLockerPartial_zSTT_restrictions() public {
        // try to pull zJTT from locker
        hevm.startPrank(address(DAO));
        hevm.expectRevert("OCR_Modular::pullFromLockerPartial() asset == zJTT || asset == zSTT");
        OCR_Modular_DAI.pullFromLockerPartial(address(zSTT), 1, "");
        hevm.stopPrank();
    }

    // validate pullFromLockerPartial() restrictions, pull amount higher than locker balance
    function test_OCR_pullFromLockerPartial_balance_restrictions() public {
        // try to pull higher amount than locker's balance
        hevm.startPrank(address(DAO));
        hevm.expectRevert("OCR_Modular::pullFromLockerPartial()amount > IERC20(asset).balanceOf(address(this)");
        OCR_Modular_DAI.pullFromLockerPartial(DAI, 100_000_000 ether, "");
        hevm.stopPrank();
    }

    // pushToLocker() should not be able to push an asset other than "stablecoin"
    function test_OCR_pushToLocker_restrictions() public {

        // push other stablecoin to locker
        hevm.startPrank(address(DAO));
        hevm.expectRevert("OCR_Modular::pushToLocker() asset != stablecoin");
        OCR_Modular_DAI.pushToLocker(FRAX, 1_000 ether, "");
        hevm.stopPrank();
    }

    // Validate redemptionRequestJunior() state changes
    function test_OCR_redemptionRequestJunior_state() public {
        
        uint256 amountToRedeem = 2_000_000 ether;
        assert(OCR_Modular_DAI.withdrawRequestsNextEpoch() == 0);

        uint256 accountInitBalance = redemptionRequestJunior(amountToRedeem);

        // checks
        assert(IERC20(zJTT).balanceOf(address(jim)) == accountInitBalance - amountToRedeem);
        assert(OCR_Modular_DAI.withdrawRequestsNextEpoch() == amountToRedeem);
        assert(OCR_Modular_DAI.juniorBalances(address(jim)) == amountToRedeem);
        assert(OCR_Modular_DAI.accountClaimTimestampJunior(address(jim)) == block.timestamp);
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
        uint256 accountInitBalance = IERC20(zJTT).balanceOf(address(jim));
        assert(accountInitBalance < amountToRedeem);
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

        uint256 accountInitBalance = redemptionRequestSenior(amountToRedeem);

        // checks
        assert(IERC20(zSTT).balanceOf(address(sam)) == accountInitBalance - amountToRedeem);
        assert(OCR_Modular_DAI.withdrawRequestsNextEpoch() == amountToRedeem);
        assert(OCR_Modular_DAI.seniorBalances(address(sam)) == amountToRedeem);
        assert(OCR_Modular_DAI.accountClaimTimestampSenior(address(sam)) == block.timestamp);
    }  

    // Validate redemptionRequestSenior() restrictions
    function test_OCR_redemptionRequestSenior_restrictions() public {

        uint256 amountToRedeem = 26_000_000 ether;
        assert(OCR_Modular_DAI.withdrawRequestsNextEpoch() == 0);

        // Withdraw staked tranche tokens
        hevm.startPrank(address(sam));
        stSTT.fullWithdraw();
        IERC20(zSTT).safeApprove(address(OCR_Modular_DAI), amountToRedeem);
        // initial values
        uint256 accountInitBalance = IERC20(zSTT).balanceOf(address(sam));
        assert(accountInitBalance < amountToRedeem);
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
        assert(OCR_Modular_DAI.amountPushedInCurrentEpoch() == amountToDistribute);
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
        assertEq(OCR_Modular_DAI.amountPushedInCurrentEpoch(), 0);
    }

    // Validate distributeEpoch() restrictions
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
        emit log_named_uint("jim claimed timestamp", OCR_Modular_DAI.accountClaimTimestampJunior(address(jim)));

        // warp time to next redemption epoch
        hevm.warp(block.timestamp + 31 days);

        // distribute new epoch
        OCR_Modular_DAI.distributeEpoch();

        // warp time + 1 day
        hevm.warp(block.timestamp + 1 days);

        // check init stablecoin balance of DAO
        uint256 initBalanceDAO = IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(DAO));

        // redeem
        hevm.startPrank(address(jim));
        OCR_Modular_DAI.redeemJunior();
        hevm.stopPrank();

        // checks
        uint256 fee = (amountToRedeem * OCR_Modular_DAI.redemptionFee()) / BIPS;
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(OCR_Modular_DAI)) == 0);
        assert(OCR_Modular_DAI.juniorBalances(address(jim)) == 0);
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(jim)) == amountToRedeem - fee);
        assert(zJTT.totalSupply() == initSupplyJTT - amountToRedeem);
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(DAO)) == initBalanceDAO + fee);
    }

    // test for restriction on redeemJunior() when balance = 0
    function test_OCR_redeemJunior_restrictions_balance() public {
        // redeem
        hevm.startPrank(address(jim));
        hevm.expectRevert("OCR_Modular::redeemJunior() juniorBalances[_msgSender] == 0");
        OCR_Modular_DAI.redeemJunior();
        hevm.stopPrank();
    }

    // test for restriction on redeemJunior() when claim time is >= "currentEpochDistribution"
    function test_OCR_redeemJunior_restrictions_timestamp() public {
        uint256 amountToRedeem = 2_000_000 ether;
        // push stablecoins to the locker
        hevm.startPrank(address(DAO));
        IERC20(DAI).safeApprove(address(OCR_Modular_DAI), amountToRedeem);
        OCR_Modular_DAI.pushToLocker(DAI, amountToRedeem, "");
        hevm.stopPrank(); 

        // initiate a redemption request
        redemptionRequestJunior(amountToRedeem);

        // redeem
        hevm.startPrank(address(jim));
        hevm.expectRevert("OCR_Modular::redeemJunior() accountClaimTimestampJunior[_msgSender()] >= currentEpochDistribution");
        OCR_Modular_DAI.redeemJunior();
        hevm.stopPrank();
    }

    // test for restriction on redeemJunior() when no amount to withdraw in epoch
    function test_OCR_redeemJunior_restrictions_noStables() public {
        uint256 amountToRedeem = 2_000_000 ether;

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
        hevm.expectRevert("OCR_Modular::redeemJunior() amountWithdrawableInEpoch == 0");
        OCR_Modular_DAI.redeemJunior();
        hevm.stopPrank();
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
        emit log_named_uint("jim claimed timestamp", OCR_Modular_DAI.accountClaimTimestampJunior(address(jim)));

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
        uint256 fee = (amountInLocker * OCR_Modular_DAI.redemptionFee()) / BIPS;
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(OCR_Modular_DAI)) == 0);
        assert(OCR_Modular_DAI.juniorBalances(address(jim)) == amountToRedeem - amountInLocker);
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(jim)) == amountToRedeem - amountInLocker - fee);
        assert(zJTT.totalSupply() == initSupplyJTT - amountInLocker);
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

        // check init stablecoin balance of DAO
        uint256 initBalanceDAO = IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(DAO));

        // redeem
        hevm.startPrank(address(sam));
        OCR_Modular_DAI.redeemSenior();
        hevm.stopPrank();

        // checks
        uint256 fee = (amountToRedeem * OCR_Modular_DAI.redemptionFee()) / BIPS;
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(OCR_Modular_DAI)) == 0);
        assert(OCR_Modular_DAI.seniorBalances(address(sam)) == 0);
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(sam)) == amountToRedeem - fee);
        assert(zSTT.totalSupply() == initSupplySTT - amountToRedeem);
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(DAO)) == initBalanceDAO + fee);
    } 

    // test for restriction on redeemSenior() when balance = 0
    function test_OCR_redeemSenior_restrictions_balance() public {
        // redeem
        hevm.startPrank(address(sam));
        hevm.expectRevert("OCR_Modular::redeemSenior() seniorBalances[_msgSender] == 0");
        OCR_Modular_DAI.redeemSenior();
        hevm.stopPrank();
    }

    // test for restriction on redeemSenior() when claim time is >= "currentEpochDistribution"
    function test_OCR_redeemSenior_restrictions_timestamp() public {
        uint256 amountToRedeem = 2_000_000 ether;
        // push stablecoins to the locker
        hevm.startPrank(address(DAO));
        IERC20(DAI).safeApprove(address(OCR_Modular_DAI), amountToRedeem);
        OCR_Modular_DAI.pushToLocker(DAI, amountToRedeem, "");
        hevm.stopPrank(); 

        // initiate a redemption request
        redemptionRequestSenior(amountToRedeem);

        // redeem
        hevm.startPrank(address(sam));
        hevm.expectRevert("OCR_Modular::redeemSenior() accountClaimTimestampSenior[_msgSender()] >= currentEpochDistribution");
        OCR_Modular_DAI.redeemSenior();
        hevm.stopPrank();
    }

    // test for restriction on redeemSenior() when no amount to withdraw in epoch
    function test_OCR_redeemSenior_restrictions_noStables() public {
        uint256 amountToRedeem = 2_000_000 ether;

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
        hevm.expectRevert("OCR_Modular::redeemJunior() amountWithdrawableInEpoch == 0");
        OCR_Modular_DAI.redeemSenior();
        hevm.stopPrank();
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
        uint256 fee = (amountInLocker * OCR_Modular_DAI.redemptionFee()) / BIPS;
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(OCR_Modular_DAI)) == 0);
        assert(OCR_Modular_DAI.seniorBalances(address(sam)) == amountToRedeem - amountInLocker);
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(sam)) == amountToRedeem - amountInLocker - fee);
        assert(zSTT.totalSupply() == initSupplySTT - amountInLocker);
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
        uint256 fee = (75 * amountInLocker * OCR_Modular_DAI.redemptionFee()) / (BIPS * 100);
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(OCR_Modular_DAI)) == 
        (25 * (amountInLocker)) / 100);
        assert(OCR_Modular_DAI.juniorBalances(address(jim)) == amountToRedeem - amountInLocker);
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(jim)) == ((75 * (amountInLocker)) / 100) - fee); 
        assert(zJTT.totalSupply() == initSupplyJTT - amountInLocker);
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
        uint256 fee = (84 * amountInLocker * OCR_Modular_DAI.redemptionFee()) / (BIPS * 100);
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(OCR_Modular_DAI)) == (16 * amountInLocker) / 100);
        assert(OCR_Modular_DAI.seniorBalances(address(sam)) == amountToRedeem - amountInLocker);
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(sam)) == ((84 * (amountInLocker)) / 100) - fee); 
        assert(zSTT.totalSupply() == initSupplySTT - amountInLocker);
    }

    // perform a fuzz testing on a dynamic basis over 2 epochs
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

    // validate setRedemptionFee() state changes
    function test_OCR_setRedemptionFee_state() public {
        // pre check
        assertEq(OCR_Modular_DAI.redemptionFee(), 1000);

        // set new redemption fee
        hevm.startPrank(address(god));
        OCR_Modular_DAI.setRedemptionFee(1500);
        hevm.stopPrank();

        // check
        assert(OCR_Modular_DAI.redemptionFee() == 1500);
    }

    // validate setRedemptionFee() restrictions on caller when != TLC
    function test_OCR_setRedemptionFee_caller_restrictions() public {
        // pre check
        assertEq(OCR_Modular_DAI.redemptionFee(), 1000);

        // set new redemption fee with account != TLC
        hevm.expectRevert("OCR_Modular::setRedemptionFee() _msgSender() != TLC()");
        OCR_Modular_DAI.setRedemptionFee(1500);
    }

    // validate setRedemptionFee() restrictions when amount is out of range
    function test_OCR_setRedemptionFee_amount_restrictions() public {
        // pre check
        assertEq(OCR_Modular_DAI.redemptionFee(), 1000);

        // set new redemption fee
        hevm.startPrank(address(god));
        hevm.expectRevert("OCR_Modular::setRedemptionFee() _redemptionFee > 2000 && _redemptionFee < 250");
        OCR_Modular_DAI.setRedemptionFee(5000);
        hevm.stopPrank();
    }

    // validate cancelRedemptionJunior() state changes - fuzz testing
    // we won't test for high amounts here - will be done through the same test for senior tranches
    function test_OCR_cancelRedemptionJunior_state_fuzzTest(
        uint88 amountToCancel, 
        uint88 amountToPush,
        uint88 amountToRedeem
    ) 
        public
    {
        hevm.assume(amountToPush > 0 && amountToRedeem > 0 && amountToCancel > 0);
        hevm.assume(amountToPush < 10_000_000 ether);
        hevm.assume(amountToRedeem <= 2_000_000 ether);
        hevm.assume(amountToCancel <= 2 * amountToRedeem);

        // push stablecoins to the locker
        hevm.startPrank(address(DAO));
        IERC20(DAI).safeApprove(address(OCR_Modular_DAI), amountToPush);
        OCR_Modular_DAI.pushToLocker(DAI, amountToPush, "");
        hevm.stopPrank();

        // do a first redemption request
        redemptionRequestJunior(amountToRedeem);

        // warp time to next epoch (1) distribution
        hevm.warp(block.timestamp + 31 days);

        // distribute new epoch
        OCR_Modular_DAI.distributeEpoch();

        // push stablecoins to the locker
        hevm.startPrank(address(DAO));
        IERC20(DAI).safeApprove(address(OCR_Modular_DAI), amountToPush);
        OCR_Modular_DAI.pushToLocker(DAI, amountToPush, "");
        hevm.stopPrank();

        // do a second redemption request
        // we are not using the helper fct as we want to avoid a fullWithdraw() again
        hevm.startPrank(address(jim));
        IERC20(zJTT).safeApprove(address(OCR_Modular_DAI), amountToRedeem);
        OCR_Modular_DAI.redemptionRequestJunior(amountToRedeem);
        hevm.stopPrank();

        // warp time + 5 days
        hevm.warp(block.timestamp + 5 days);

        // pre-check
        assert(OCR_Modular_DAI.withdrawRequestsEpoch() == amountToRedeem);
        assert(OCR_Modular_DAI.withdrawRequestsNextEpoch() == amountToRedeem);
        assert(OCR_Modular_DAI.amountWithdrawableInEpoch() == amountToPush);
        assert(OCR_Modular_DAI.amountPushedInCurrentEpoch() == amountToPush);
        assert(OCR_Modular_DAI.unclaimedWithdrawRequests() == amountToRedeem);

        // cancel redemption request for a specific amount
        hevm.startPrank(address(jim));
        OCR_Modular_DAI.cancelRedemptionJunior(amountToCancel);
        hevm.stopPrank();

        // final check
        if (amountToCancel > amountToRedeem) {
            uint256 diff = amountToCancel - amountToRedeem;
            assert(OCR_Modular_DAI.withdrawRequestsNextEpoch() == 0);
            assert(OCR_Modular_DAI.withdrawRequestsEpoch() == amountToRedeem - diff);
        }

        if (amountToCancel < amountToRedeem) {
            assert(OCR_Modular_DAI.withdrawRequestsNextEpoch() == amountToRedeem - amountToCancel);
        }
    }










}