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

    event RequestProcessed
        (uint256 indexed id, 
        address indexed account, 
        uint256 burnAmount, 
        uint256 redeemAmount, 
        bool indexed seniorElseJunior
    );

    event UpdatedRedemptionsFee(uint256 oldFee, uint256 newFee);


    // ----------------------
    //    Helper Functions
    // ----------------------

    function helper_createRequest(uint256 amount, bool seniorElseJunior) public {

        hevm.startPrank(address(tim));

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

    function test_OCR_createRequest_state_DAI(uint96 amountJunior, uint96 amountSenior) public {

        hevm.assume(amountJunior > 0 && amountJunior <= startingSupplyJTT);
        hevm.assume(amountSenior > 0 && amountSenior <= startingSupplySTT);

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

    function test_OCR_createRequest_state_USDC(uint96 amountJunior, uint96 amountSenior) public {

        hevm.assume(amountJunior > 0 && amountSenior > 0);

        hevm.startPrank(address(jim));
        IERC20(USDC).approve(address(OCR_USDC), amountJunior);
        hevm.stopPrank();

        hevm.startPrank(address(sam));
        IERC20(USDC).approve(address(OCR_USDC), amountSenior);
        hevm.stopPrank();

        // createRequest() junior

        // Post-state.

        // createRequest() senior

        // Post-state.

    }

    // Validate destroyRequest() state changes.
    // Validate destroyRequest() restrictions.
    // This includes:
    //  - _msgSender() must be requests[id].account
    //  - requests[id].amount > 0

    function test_OCR_destroyRequest_restrictions_msgSender() public {
        
    }

    function test_OCR_destroyRequest_restrictions_requests() public {
        
    }

    function test_OCR_destroyRequest_state() public {
        
    }

    // Validate processRequest() state changes.
    // Validate processRequest() restrictions.
    // This includes:
    //  - _msgSender() must be requests[id].account
    //  - requests[id].amount > 0

    function test_OCR_processRequest_restrictions_msgSender() public {
        
    }

    function test_OCR_processRequest_restrictions_unlocks() public {
        
    }

    function test_OCR_processRequest_state() public {
        
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