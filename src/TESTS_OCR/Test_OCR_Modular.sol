// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "lib/zivoe-core-foundry/src/lockers/OCR/OCR_Modular.sol";

contract Test_OCR_Modular is Utility {

    using SafeERC20 for IERC20;

    OCR_Modular OCR_Modular_DAI;

    function setUp() public {

        deployCore(false);
        simulateITO_byTranche_stakeTokens(16_000_000 ether, 4_000_000 ether);

        // Initialize and whitelist OCR_Modular lockers.
        OCR_Modular_DAI = new OCR_Modular(address(DAO), address(DAI), address(GBL), 1000);
        zvl.try_updateIsLocker(address(GBL), address(OCR_Modular_DAI), true);

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
        assertEq(OCR_Modular_DAI.currentEpochDistribution(), block.timestamp);
        assertEq(OCR_Modular_DAI.nextEpochDistribution(), block.timestamp + 30 days);
        assertEq(OCR_Modular_DAI.redemptionFee(), 1000);
        assertEq(OCR_Modular_DAI.withdrawRequestsNextEpoch(), 0);
        assertEq(OCR_Modular_DAI.withdrawRequestsEpoch(), 0);
        assertEq(OCR_Modular_DAI.amountWithdrawableInEpoch(), 0);


        // Permissions
        assert(OCR_Modular_DAI.canPush());
        assert(OCR_Modular_DAI.canPull());

    }

    // Validate redemptionRequestJunior() state changes
    function test_OCR_redemptionRequestJunior_state() public {

        uint256 amountToRedeem = 2_000_000 ether;
        assert(OCR_Modular_DAI.withdrawRequestsNextEpoch() == 0);

        // Withdraw staked tranche tokens
        hevm.startPrank(address(jim));
        stJTT.fullWithdraw();
        IERC20(zJTT).safeApprove(address(OCR_Modular_DAI), amountToRedeem);
        // initial values
        uint256 userInitBalance = IERC20(zJTT).balanceOf(address(jim));
        // call function
        OCR_Modular_DAI.redemptionRequestJunior(amountToRedeem);
        hevm.stopPrank();

        // checks
        assert(IERC20(zJTT).balanceOf(address(jim)) == userInitBalance - amountToRedeem);
        assert(OCR_Modular_DAI.withdrawRequestsNextEpoch() == amountToRedeem);
        assert(OCR_Modular_DAI.juniorBalances(address(jim)) == amountToRedeem);
        assert(OCR_Modular_DAI.userClaimTimestamp(address(jim)) == block.timestamp);
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
        hevm.expectRevert("OCR_Modular::redemptionRequestJunior() balanceOf(_msgSender()) < amount");
        // call function
        OCR_Modular_DAI.redemptionRequestJunior(amountToRedeem);

        hevm.stopPrank();

    }   

    // Validate redemptionRequestSenior() state changes
    function test_OCR_redemptionRequestSenior_state() public {

        uint256 amountToRedeem = 10_000_000 ether;
        assert(OCR_Modular_DAI.withdrawRequestsNextEpoch() == 0);

        // Withdraw staked tranche tokens
        hevm.startPrank(address(sam));
        stSTT.fullWithdraw();
        IERC20(zSTT).safeApprove(address(OCR_Modular_DAI), amountToRedeem);
        // initial values
        uint256 userInitBalance = IERC20(zSTT).balanceOf(address(sam));
        // call function
        OCR_Modular_DAI.redemptionRequestSenior(amountToRedeem);
        hevm.stopPrank();

        // checks
        assert(IERC20(zSTT).balanceOf(address(sam)) == userInitBalance - amountToRedeem);
        assert(OCR_Modular_DAI.withdrawRequestsNextEpoch() == amountToRedeem);
        assert(OCR_Modular_DAI.seniorBalances(address(sam)) == amountToRedeem);
        assert(OCR_Modular_DAI.userClaimTimestamp(address(sam)) == block.timestamp);
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
        hevm.expectRevert("OCR_Modular::redemptionRequestSenior() balanceOf(_msgSender()) < amount");
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

        // simulate a redemption request
        hevm.startPrank(address(sam));
        stSTT.fullWithdraw();
        IERC20(zSTT).safeApprove(address(OCR_Modular_DAI), amountToRedeem);
        OCR_Modular_DAI.redemptionRequestSenior(amountToRedeem);
        hevm.stopPrank();

        // warp time to next epoch distribution
        hevm.warp(block.timestamp + 30 days + 1);

        // pre check
        assert(IERC20(DAI).balanceOf(address(OCR_Modular_DAI)) == amountToDistribute);
        assert(OCR_Modular_DAI.withdrawRequestsNextEpoch() == amountToRedeem);
        // distribute new epoch
        OCR_Modular_DAI.distributeEpoch();

        // checks
        assertEq(OCR_Modular_DAI.amountWithdrawableInEpoch(), amountToDistribute);
        assertEq(OCR_Modular_DAI.nextEpochDistribution(), block.timestamp + 30 days);
        assertEq(OCR_Modular_DAI.currentEpochDistribution(), block.timestamp);
        assertEq(OCR_Modular_DAI.withdrawRequestsEpoch(), amountToRedeem);
        assertEq(OCR_Modular_DAI.withdrawRequestsNextEpoch(), 0);

    }



}