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
        assertEq(OCR_Modular_DAI.previousEpochDistribution(), 0);
        assertEq(OCR_Modular_DAI.nextEpochDistribution(), block.timestamp + 30 days);
        assertEq(OCR_Modular_DAI.redemptionFee(), 1000);
        assertEq(OCR_Modular_DAI.withdrawRequestsNextEpoch(), 0);
        assertEq(OCR_Modular_DAI.withdrawRequestsEpoch(), 0);
        assertEq(OCR_Modular_DAI.amountWithdrawableInEpoch(), 0);


        // Permissions
        assert(OCR_Modular_DAI.canPush());
        //assert(OCR_Modular_DAI.canPull());

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
        hevm.expectRevert("OCR_Modular::redemptionRequestJunior() balanceOf(_msgSender()) < amount");
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
        assertEq(OCR_Modular_DAI.previousEpochDistribution(), currentEpochDistribution);
        assertEq(OCR_Modular_DAI.withdrawRequestsEpoch(), amountToRedeem);
        assertEq(OCR_Modular_DAI.withdrawRequestsNextEpoch(), 0);

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
        hevm.expectRevert("OCR_Modular::distributeEpoch() block.timestamp < nextEpochDistribution");
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
        emit log_named_uint("previousEpochDistribution", OCR_Modular_DAI.previousEpochDistribution());

        // warp time + 1 day
        hevm.warp(block.timestamp + 1 days);

        // redeem
        hevm.startPrank(address(jim));
        OCR_Modular_DAI.redeemJunior();
        hevm.stopPrank();

        // checks
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(OCR_Modular_DAI)) == 0);
        assert(OCR_Modular_DAI.userClaimTimestampJunior(address(jim)) == 0);
        assert(OCR_Modular_DAI.juniorBalances(address(jim)) == 0);
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(jim)) == amountToRedeem);
        assert(zJTT.totalSupply() == initSupplyJTT - amountToRedeem);

    }

/*     // validate a scenario where amount of stablecoins <= total redemption amount
    function test_OCR_redeemJunior_partial_state() public {

    } */

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
        assert(OCR_Modular_DAI.userClaimTimestampSenior(address(sam)) == 0);
        assert(OCR_Modular_DAI.seniorBalances(address(sam)) == 0);
        assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(sam)) == amountToRedeem);
        assert(zSTT.totalSupply() == initSupplySTT - amountToRedeem);


    } 



}