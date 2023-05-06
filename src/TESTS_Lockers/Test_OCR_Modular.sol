// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.17;

import "../Utility/Utility.sol";

import "../../lib/zivoe-core-foundry/src/lockers/OCR/OCR_Modular.sol";
import "../../lib/zivoe-core-foundry/src/lockers/OCG/OCG_Defaults.sol";

contract Test_OCR_Modular is Utility {

    using SafeERC20 for IERC20;

    OCR_Modular OCR_DAI;
    OCR_Modular OCR_USDC;

    OCG_Defaults OCG_Defaults_Test;

    struct Request {
        address account;        /// @dev The account making the request.
        uint256 amount;         /// @dev The amount of the request ($zSTT or $zJTT).
        uint256 unlocks;        /// @dev The timestamp after which this request may be processed.
        bool seniorElseJunior;  /// @dev The tranche this request is for (true = Senior, false = Junior).
    }

    uint256 startingSupplySTT = 10_000_000 ether;
    uint256 startingSupplyJTT = 4_000_000 ether;
    
    function setUp() public {

        deployCore(false);

        // NOTE: "sam" owns $zSTT and "jim" owns $zJTT
        simulateITO_byTranche_optionalStake(startingSupplySTT, startingSupplyJTT, false);

        // OCR_Modular Initialization & Whitelist
        OCR_DAI = new OCR_Modular(address(DAO), address(DAI), address(GBL), 1000);
        OCR_USDC = new OCR_Modular(address(DAO), address(USDC), address(GBL), 1000);
        zvl.try_updateIsLocker(address(GBL), address(OCR_DAI), true);
        zvl.try_updateIsLocker(address(GBL), address(OCR_USDC), true);

        // OCG_Defaults Initialization
        OCG_Defaults_Test = new OCG_Defaults(address(DAO), address(GBL));
        zvl.try_updateIsLocker(address(GBL), address(OCG_Defaults_Test), true);

    }

    // ------------
    //    Events
    // ------------

    event EpochTicked(
        uint256 epoch, 
        uint256 redemptionsAllowedJunior, 
        uint256 redemptionsAllowedSenior,
        uint256 epochDiscountJunior, 
        uint256 epochDiscountSenior
    );

    event RequestCreated(uint256 indexed id, address indexed account, uint256 amount, bool indexed seniorElseJunior);

    event RequestDestroyed(uint256 indexed id, address indexed account, uint256 amount, bool indexed seniorElseJunior);

    event RequestProcessed(
        uint256 indexed id, 
        address indexed account, 
        uint256 burnAmount, 
        uint256 redeemAmount, 
        bool indexed seniorElseJunior
    );

    event UpdatedRedemptionsFee(uint256 oldFee, uint256 newFee);


    // ----------------------
    //    Helper Functions
    // ----------------------

    function helper_createRequest_DAI(uint256 amount, bool seniorElseJunior) public returns (uint id) {

        id = OCR_DAI.requestCounter();

        if (seniorElseJunior) {
            hevm.startPrank(address(sam));
            IERC20(address(zSTT)).approve(address(OCR_DAI), amount);
            OCR_DAI.createRequest(amount, true);
            hevm.stopPrank();
        }
        else {
            hevm.startPrank(address(jim));
            IERC20(address(zJTT)).approve(address(OCR_DAI), amount);
            OCR_DAI.createRequest(amount, false);
            hevm.stopPrank();
        }

    }

    function helper_createRequest_USDC(uint256 amount, bool seniorElseJunior) public returns (uint id) {

        id = OCR_USDC.requestCounter();

        if (seniorElseJunior) {
            hevm.startPrank(address(sam));
            IERC20(address(zSTT)).approve(address(OCR_USDC), amount);
            OCR_USDC.createRequest(amount, true);
            hevm.stopPrank();
        }
        else {
            hevm.startPrank(address(jim));
            IERC20(address(zJTT)).approve(address(OCR_USDC), amount);
            OCR_USDC.createRequest(amount, false);
            hevm.stopPrank();
        }

    }


    // -----------
    //    Tests
    // -----------

    // Validate OCR_Modular initial state.

    function test_OCR_init_state() public {

        // OCR_DAI
        assertEq(OCR_DAI.owner(),           address(DAO));
        assertEq(OCR_DAI.stablecoin(),      DAI);
        assertEq(OCR_DAI.GBL(),             address(GBL));
        assertEq(OCR_DAI.redemptionsFee(),  1000);
        assertEq(OCR_DAI.epoch(),           block.timestamp);

        // OCR_USDC
        assertEq(OCR_USDC.owner(),          address(DAO));
        assertEq(OCR_USDC.stablecoin(),     USDC);
        assertEq(OCR_USDC.GBL(),            address(GBL));
        assertEq(OCR_USDC.redemptionsFee(), 1000);
        assertEq(OCR_USDC.epoch(),          block.timestamp);

    }

    // Validate pushToLocker() state changes.
    // Validate pushToLocker() restrictions.
    // This includes:
    //  - asset must be stablecoin
    //  - onlyOwner can call

    function test_OCR_pushToLocker_restrictions_asset() public {

        // asset must be stablecoin
        hevm.startPrank(address(god));
        hevm.expectRevert("OCR_Modular::pushToLocker() asset != stablecoin");
        DAO.push(address(OCR_DAI), address(USDC), 10_000 ether, "");
        hevm.stopPrank();
    }

    function test_OCR_pushToLocker_restrictions_onlyOwner() public {

        // onlyOwner can call
        hevm.startPrank(address(tim));
        hevm.expectRevert("Ownable: caller is not the owner");
        DAO.push(address(OCR_DAI), address(DAI), 10_000 ether, "");
        hevm.stopPrank();
    }

    function test_OCR_pushToLocker_state(uint96 amountDAI, uint96 amountUSDC) public {
        
        // Pre-state.
        assertEq(IERC20(DAI).balanceOf(address(OCR_DAI)), 0);
        assertEq(IERC20(USDC).balanceOf(address(OCR_USDC)), 0);

        deal(DAI, address(DAO), amountDAI);
        deal(USDC, address(DAO), amountUSDC);

        // pushToLocker()
        hevm.startPrank(address(god));
        DAO.push(address(OCR_DAI), DAI, amountDAI, "");
        DAO.push(address(OCR_USDC), USDC, amountUSDC, "");
        hevm.stopPrank();

        // Post-state.
        assertEq(IERC20(DAI).balanceOf(address(OCR_DAI)), amountDAI);
        assertEq(IERC20(USDC).balanceOf(address(OCR_USDC)), amountUSDC);
    }

    // Validate pullFromLocker() state changes.
    // Validate pullFromLocker() restrictions.
    // This includes:
    //  - asset must NOT be $zJTT or $zSTT
    //  - onlyOwner can call

    function test_OCR_pullFromLocker_restrictions_asset() public {

        // asset must NOT be $zJTT or $zSTT
        hevm.startPrank(address(god));
        hevm.expectRevert("OCR_Modular::pullFromLocker() asset == zJTT || asset == zSTT");
        DAO.pull(address(OCR_DAI), address(zJTT), "");
        hevm.expectRevert("OCR_Modular::pullFromLocker() asset == zJTT || asset == zSTT");
        DAO.pull(address(OCR_DAI), address(zSTT), "");
        hevm.stopPrank();
    }

    function test_OCR_pullFromLocker_restrictions_onlyOwner() public {

        // onlyOwner can call
        hevm.startPrank(address(tim));
        hevm.expectRevert("Ownable: caller is not the owner");
        DAO.pull(address(OCR_DAI), address(DAI), "");
        hevm.stopPrank();
    }

    function test_OCR_pullFromLocker_state(uint96 amountDAI, uint96 amountUSDC) public {
        
        // Pre-state.
        assertEq(IERC20(DAI).balanceOf(address(OCR_DAI)), 0);
        assertEq(IERC20(USDC).balanceOf(address(OCR_USDC)), 0);

        deal(DAI, address(DAO), amountDAI);
        deal(USDC, address(DAO), amountUSDC);

        // pushToLocker()
        hevm.startPrank(address(god));
        DAO.push(address(OCR_DAI), DAI, amountDAI, "");
        DAO.push(address(OCR_USDC), USDC, amountUSDC, "");
        hevm.stopPrank();

        // Post-state.
        assertEq(IERC20(DAI).balanceOf(address(OCR_DAI)), amountDAI);
        assertEq(IERC20(USDC).balanceOf(address(OCR_USDC)), amountUSDC);

        // pullFromLocker()
        hevm.startPrank(address(god));
        DAO.pull(address(OCR_DAI), DAI, "");
        DAO.pull(address(OCR_USDC), USDC, "");
        hevm.stopPrank();

        // Post-state.
        assertEq(IERC20(DAI).balanceOf(address(OCR_DAI)), 0);
        assertEq(IERC20(USDC).balanceOf(address(OCR_USDC)), 0);
    }

    // Validate pullFromLockerPartial() state changes.
    // Validate pullFromLockerPartial() restrictions.
    // This includes:
    //  - asset must NOT be $zJTT or $zSTT
    //  - onlyOwner can call

    function test_OCR_pullFromLockerPartial_restrictions_asset() public {

        // asset must NOT be $zJTT or $zSTT
        hevm.startPrank(address(god));
        hevm.expectRevert("OCR_Modular::pullFromLockerPartial() asset == zJTT || asset == zSTT");
        DAO.pullPartial(address(OCR_DAI), address(zJTT), 1, "");
        hevm.expectRevert("OCR_Modular::pullFromLockerPartial() asset == zJTT || asset == zSTT");
        DAO.pullPartial(address(OCR_DAI), address(zSTT), 1, "");
        hevm.stopPrank();

    }

    function test_OCR_pullFromLockerPartial_restrictions_onlyOwner() public {

        // onlyOwner can call
        hevm.startPrank(address(tim));
        hevm.expectRevert("Ownable: caller is not the owner");
        DAO.pullPartial(address(OCR_DAI), address(zJTT), 1, "");
        hevm.stopPrank();

    }

    function test_OCR_pullFromLockerPartial_state(uint96 amountDAI, uint96 amountUSDC, uint96 random) public {
        
        hevm.assume(amountDAI > 0 && amountUSDC > 0);
        
        // Pre-state.
        assertEq(IERC20(DAI).balanceOf(address(OCR_DAI)), 0);
        assertEq(IERC20(USDC).balanceOf(address(OCR_USDC)), 0);

        deal(DAI, address(DAO), amountDAI);
        deal(USDC, address(DAO), amountUSDC);

        // pushToLocker()
        hevm.startPrank(address(god));
        DAO.push(address(OCR_DAI), DAI, amountDAI, "");
        DAO.push(address(OCR_USDC), USDC, amountUSDC, "");
        hevm.stopPrank();

        // Post-state.
        assertEq(IERC20(DAI).balanceOf(address(OCR_DAI)), amountDAI);
        assertEq(IERC20(USDC).balanceOf(address(OCR_USDC)), amountUSDC);

        // pullFromLockerPartial()
        hevm.startPrank(address(god));
        DAO.pullPartial(address(OCR_DAI), DAI, random % (amountDAI), "");
        DAO.pullPartial(address(OCR_USDC), USDC, random % (amountUSDC), "");
        hevm.stopPrank();

        // Post-state.
        assertEq(IERC20(DAI).balanceOf(address(OCR_DAI)), amountDAI - random % (amountDAI));
        assertEq(IERC20(USDC).balanceOf(address(OCR_USDC)), amountUSDC - random % (amountUSDC));

    }

    // Validate createRequest() state changes.
    // Validate createRequest() restrictions.
    // This includes:
    //   - amount > 0


    function test_OCR_createRequest_restrictions_amount() public {

        hevm.startPrank(address(bob));
        hevm.expectRevert("OCR_Modular::createRequest() amount == 0");
        OCR_DAI.createRequest(0, true);
        hevm.stopPrank();

    }

    function test_OCR_createRequest_state(uint96 amountJunior, uint96 amountSenior) public {

        hevm.assume(amountSenior > 0 && amountSenior <= startingSupplySTT);
        hevm.assume(amountJunior > 0 && amountJunior <= startingSupplyJTT);

        // createRequest() junior
        hevm.startPrank(address(jim));
        IERC20(address(zJTT)).approve(address(OCR_DAI), amountJunior);

        hevm.expectEmit(true, true, true, true, address(OCR_DAI));
        emit RequestCreated(OCR_DAI.requestCounter(), address(jim), amountJunior, false);
        OCR_DAI.createRequest(amountJunior, false);
        hevm.stopPrank();

        // Post-state.
        (address account, uint amount, uint unlocks, bool seniorElseJunior) = OCR_DAI.requests(0);

        assertEq(account, address(jim));
        assertEq(amount, amountJunior);
        assertEq(unlocks, OCR_DAI.epoch() + 14 days);
        assert(!seniorElseJunior);
        
        assertEq(OCR_DAI.redemptionsQueuedJunior(), amountJunior);
        assertEq(OCR_DAI.requestCounter(), 1);
        assertEq(IERC20(address(zJTT)).balanceOf(address(OCR_DAI)), amountJunior);

        // createRequest() senior
        hevm.startPrank(address(sam));
        IERC20(address(zSTT)).approve(address(OCR_DAI), amountSenior);

        hevm.expectEmit(true, true, true, true, address(OCR_DAI));
        emit RequestCreated(OCR_DAI.requestCounter(), address(sam), amountSenior, true);
        OCR_DAI.createRequest(amountSenior, true);
        hevm.stopPrank();

        // Post-state.
        (account, amount, unlocks, seniorElseJunior) = OCR_DAI.requests(1);

        assertEq(account, address(sam));
        assertEq(amount, amountSenior);
        assertEq(unlocks, OCR_DAI.epoch() + 14 days);
        assert(seniorElseJunior);
        
        assertEq(OCR_DAI.redemptionsQueuedSenior(), amountSenior);
        assertEq(OCR_DAI.requestCounter(), 2);
        assertEq(IERC20(address(zSTT)).balanceOf(address(OCR_DAI)), amountSenior);

    }

    // Validate destroyRequest() state changes.
    // Validate destroyRequest() restrictions.
    // This includes:
    //  - _msgSender() must be requests[id].account
    //  - requests[id].amount > 0

    function test_OCR_destroyRequest_restrictions_msgSender() public {
        
        uint id = helper_createRequest_DAI(1_000 ether, true);

        // Can't destroyRequest if _msgSender() != account
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCR_Modular::destroyRequest() requests[id].account != _msgSender()");
        OCR_DAI.destroyRequest(id);
        hevm.stopPrank();
    }

    function test_OCR_destroyRequest_restrictions_amount() public {
        
        uint id = helper_createRequest_DAI(1_000 ether, true);

        // Can't destroyRequest if amount == 0 (meaning request already destroyed)
        hevm.startPrank(address(sam));
        OCR_DAI.destroyRequest(id);

        hevm.expectRevert("OCR_Modular::destroyRequest() requests[id].amount == 0");
        OCR_DAI.destroyRequest(id);
        hevm.stopPrank();
    }

    function test_OCR_destroyRequest_state(uint96 amountJunior, uint96 amountSenior, uint96 random) public {
        
        hevm.assume(amountSenior > 0 && amountSenior <= startingSupplySTT / 2);
        hevm.assume(amountJunior > 0 && amountJunior <= startingSupplyJTT / 2);

        uint id_senior = helper_createRequest_DAI(amountSenior, true);
        uint id_junior = helper_createRequest_DAI(amountJunior, false);

        id_senior = helper_createRequest_DAI(amountSenior, true);   // Utilize 2nd request
        id_junior = helper_createRequest_DAI(amountJunior, false);  // Utilize 2nd request

        hevm.warp(block.timestamp + random % (20 days)); // ~33% chance to warp past epoch, forces _tickEpoch modifier

        // Pre-state (pre _tickEpoch)
        assertEq(OCR_DAI.redemptionsQueuedSenior(), amountSenior * 2);
        assertEq(OCR_DAI.redemptionsQueuedJunior(), amountJunior * 2);
        assertEq(OCR_DAI.redemptionsAllowedSenior(), 0);
        assertEq(OCR_DAI.redemptionsAllowedJunior(), 0);

        uint256 preBalance_zSTT_sam = IERC20(address(zSTT)).balanceOf(address(sam));
        uint256 preBalance_zJTT_jim = IERC20(address(zJTT)).balanceOf(address(jim));

        (address account, uint256 amount, uint256 unlocks, bool seniorElseJunior) = OCR_DAI.requests(0); // senior

        // If _tickEpoch(), handle differently
        if (block.timestamp + 14 days > OCR_DAI.epoch()) {

            // destroyRequest() senior
            hevm.startPrank(address(sam));
            (, amount,,) = OCR_DAI.requests(id_senior);
            hevm.expectEmit(true, true, true, true, address(OCR_DAI));
            emit RequestDestroyed(id_senior, address(sam), amount, true);
            OCR_DAI.destroyRequest(id_senior);
            hevm.stopPrank();

            assertEq(OCR_DAI.redemptionsQueuedSenior(), 0);
            assertEq(OCR_DAI.redemptionsQueuedJunior(), 0);
            assertEq(OCR_DAI.redemptionsAllowedSenior(), amountSenior);
            assertEq(OCR_DAI.redemptionsAllowedJunior(), amountJunior * 2);
            assertEq(amount, IERC20(address(zSTT)).balanceOf(address(sam)) - preBalance_zSTT_sam);

            (, amount,,) = OCR_DAI.requests(id_senior); 
            assertEq(amount, 0);

            // destroyRequest() junior
            hevm.startPrank(address(jim));
            (, amount,,) = OCR_DAI.requests(id_junior); 
            hevm.expectEmit(true, true, true, true, address(OCR_DAI));
            emit RequestDestroyed(id_junior, address(jim), amount, false);
            OCR_DAI.destroyRequest(id_junior);
            hevm.stopPrank();

            assertEq(OCR_DAI.redemptionsQueuedSenior(), 0);
            assertEq(OCR_DAI.redemptionsQueuedJunior(), 0);
            assertEq(OCR_DAI.redemptionsAllowedSenior(), amountSenior);
            assertEq(OCR_DAI.redemptionsAllowedJunior(), amountJunior);
            assertEq(amount, IERC20(address(zJTT)).balanceOf(address(jim)) - preBalance_zJTT_jim);

            (, amount,,) = OCR_DAI.requests(id_junior);
            assertEq(amount, 0);


        }
        else {

            // destroyRequest() senior
            hevm.startPrank(address(sam));
            (, amount,,) = OCR_DAI.requests(id_senior);
            hevm.expectEmit(true, true, true, true, address(OCR_DAI));
            emit RequestDestroyed(id_senior, address(sam), amount, true);
            OCR_DAI.destroyRequest(id_senior);
            hevm.stopPrank();

            assertEq(OCR_DAI.redemptionsQueuedSenior(), amountSenior);
            assertEq(OCR_DAI.redemptionsQueuedJunior(), amountJunior * 2);
            assertEq(OCR_DAI.redemptionsAllowedSenior(), 0);
            assertEq(OCR_DAI.redemptionsAllowedJunior(), 0);

            assertEq(amount, IERC20(address(zSTT)).balanceOf(address(sam)) - preBalance_zSTT_sam);

            (, amount,,) = OCR_DAI.requests(id_senior); 
            assertEq(amount, 0);

            // destroyRequest() junior
            hevm.startPrank(address(jim));
            (, amount,,) = OCR_DAI.requests(id_junior); 
            hevm.expectEmit(true, true, true, true, address(OCR_DAI));
            emit RequestDestroyed(id_junior, address(jim), amount, false);
            OCR_DAI.destroyRequest(id_junior);
            hevm.stopPrank();

            assertEq(OCR_DAI.redemptionsQueuedSenior(), amountSenior);
            assertEq(OCR_DAI.redemptionsQueuedJunior(), amountJunior);
            assertEq(OCR_DAI.redemptionsAllowedSenior(), 0);
            assertEq(OCR_DAI.redemptionsAllowedJunior(), 0);

            assertEq(amount, IERC20(address(zJTT)).balanceOf(address(jim)) - preBalance_zJTT_jim);

            (, amount,,) = OCR_DAI.requests(id_junior);
            assertEq(amount, 0);

        }

    }

    // Validate processRequest() state changes.
    // Validate processRequest() restrictions.
    // This includes:
    //  - amount > 0
    //  - unlocks <= epoch

    function test_OCR_processRequest_restrictions_amount() public {
        
        uint id = helper_createRequest_DAI(1_000 ether, true);

        hevm.startPrank(address(sam));
        OCR_DAI.destroyRequest(id);
        hevm.expectRevert("OCR_Modular::processRequest() requests[id].amount == 0");
        OCR_DAI.processRequest(id);
        hevm.stopPrank();
    }

    function test_OCR_processRequest_restrictions_unlocks() public {
        
        uint id = helper_createRequest_DAI(1_000 ether, true);

        hevm.expectRevert("OCR_Modular::processRequest() requests[id].unlocks > epoch");
        OCR_DAI.processRequest(id);

        // Show success when arriving at epoch (totalRedemptions == 0 however, so no actions taken).
        hevm.warp(OCR_DAI.epoch() + 14 days);
        OCR_DAI.processRequest(id);
        
    }

    function test_OCR_processRequest_state_DAI(uint96 amountJunior, uint96 amountSenior, uint96 amountDAI, uint96 defaults) public {
        
        hevm.assume(amountSenior > 0 && amountSenior <= startingSupplySTT / 2);
        hevm.assume(amountJunior > 0 && amountJunior <= startingSupplyJTT / 2);
        hevm.assume(defaults <= startingSupplySTT + startingSupplyJTT);

        // Create 4 different requests (2 senior, 2 junior)
        uint id_senior = helper_createRequest_DAI(amountSenior, true);
        uint id_junior = helper_createRequest_DAI(amountJunior, false);

        id_senior = helper_createRequest_DAI(amountSenior, true);
        id_junior = helper_createRequest_DAI(amountJunior, false);

        // Increase defaults in system
        assert(god.try_increaseDefaults(address(OCG_Defaults_Test), defaults));
        assertEq(GBL.defaults(), defaults);

        // Warp to epoch start, tickEpoch
        hevm.warp(OCR_DAI.epoch() + 14 days);
        OCR_DAI.tickEpoch();

        assertEq(OCR_DAI.redemptionsAllowedSenior(), amountSenior * 2);
        assertEq(OCR_DAI.redemptionsAllowedJunior(), amountJunior * 2);

        // Provide stablecoin to OCR_DAI
        deal(DAI, address(OCR_DAI), amountDAI);

        uint256 totalRedemptions = OCR_DAI.redemptionsAllowedSenior() * (BIPS - OCR_DAI.epochDiscountSenior()) + (
            OCR_DAI.redemptionsAllowedJunior() * (BIPS - OCR_DAI.epochDiscountJunior())
        );

        uint256 preRedemptionsAllowedSenior = OCR_DAI.redemptionsAllowedSenior();
        
        // Burn senior position first
        if (totalRedemptions == 0) { }  // Nothing to test in this situation
        else {
            (, uint256 amountPre,,) = OCR_DAI.requests(id_senior);

            uint256 portion = (IERC20(DAI).balanceOf(address(OCR_DAI)) * RAY / totalRedemptions) / 10**23;
            if (portion > BIPS) { portion = BIPS; }
            uint256 burnAmount = amountPre * portion / BIPS;
            uint256 redeemAmount = burnAmount * (BIPS - OCR_DAI.epochDiscountSenior()) / BIPS;

            // processRequest().
            hevm.expectEmit(true, true, true, true, address(OCR_DAI));
            emit RequestProcessed(id_senior, address(sam), burnAmount, redeemAmount, true);
            OCR_DAI.processRequest(id_senior);

            (, uint256 amountPost,,) = OCR_DAI.requests(id_senior);
            
            assertEq(amountPost, amountPre - burnAmount);
            assertEq(OCR_DAI.redemptionsAllowedSenior(), preRedemptionsAllowedSenior - burnAmount);
        }

        // Recalculate totalRedemptions
        totalRedemptions = OCR_DAI.redemptionsAllowedSenior() * (BIPS - OCR_DAI.epochDiscountSenior()) + (
            OCR_DAI.redemptionsAllowedJunior() * (BIPS - OCR_DAI.epochDiscountJunior())
        );

        uint256 preRedemptionsAllowedJunior = OCR_DAI.redemptionsAllowedJunior();

        // Burn junior position next
        if (totalRedemptions == 0) { }  // Nothing to test in this situation
        else {
            (, uint256 amountPre,,) = OCR_DAI.requests(id_junior);

            uint256 portion = (IERC20(DAI).balanceOf(address(OCR_DAI)) * RAY / totalRedemptions) / 10**23;
            if (portion > BIPS) { portion = BIPS; }
            uint256 burnAmount = amountPre * portion / BIPS;
            uint256 redeemAmount = burnAmount * (BIPS - OCR_DAI.epochDiscountJunior()) / BIPS;

            // processRequest().
            hevm.expectEmit(true, true, true, true, address(OCR_DAI));
            emit RequestProcessed(id_junior, address(jim), burnAmount, redeemAmount, false);
            OCR_DAI.processRequest(id_junior);

            (, uint256 amountPost,,) = OCR_DAI.requests(id_junior);

            assertEq(amountPost, amountPre - burnAmount);
            assertEq(OCR_DAI.redemptionsAllowedJunior(), preRedemptionsAllowedJunior - burnAmount);
        }

    }

    // Validate tickEpoch() state changes.

    function test_OCR_tickEpoch_state() public {
        
    }

    function test_OCR_tickEpoch_state_recursive() public {
        
    }

    // Validate updateRedemptionsFee() state changes.
    // Validate updateRedemptionsFee() restrictions.
    // This includes:
    //  - _msgSender() must be TLC
    //  - _redemptionsFee must be in range [250, 2000]

    function test_OCR_updateRedemptionsFee_restrictions_msgSender() public {
        
        // Can't call if _msgSender() != TLC
        hevm.startPrank(address(tim));
        hevm.expectRevert("OCR_Modular::updateRedemptionsFee() _msgSender() != TLC()");
        OCR_DAI.updateRedemptionsFee(500);
        hevm.stopPrank();
    }

    function test_OCR_updateRedemptionsFee_restrictions_range(uint16 fee) public {
        
        // Can't update if fee < 250 || fee > 2000
        hevm.startPrank(address(god));
        if (fee < 250 || fee > 2000) {
            hevm.expectRevert("OCR_Modular::updateRedemptionsFee() _redemptionsFee > 2000 && _redemptionsFee < 250");
        }
        OCR_DAI.updateRedemptionsFee(fee);
        hevm.stopPrank();
    }

    function test_OCR_updateRedemptionsFee_state(uint16 fee) public {

        hevm.assume(fee >= 250 && fee <= 2000);

        // Pre-state.
        assertEq(OCR_DAI.redemptionsFee(), 1000);

        // updateRedemptionsFee().
        hevm.startPrank(address(god));
        hevm.expectEmit(false, false, false, true, address(OCR_DAI));
        emit UpdatedRedemptionsFee(1000, fee);
        OCR_DAI.updateRedemptionsFee(fee);
        hevm.stopPrank();

        // Post-state.
        assertEq(OCR_DAI.redemptionsFee(), fee);   
    }

}