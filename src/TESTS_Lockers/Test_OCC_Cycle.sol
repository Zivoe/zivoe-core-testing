// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../Utility/Utility.sol";

import "../../lib/zivoe-core-foundry/src/lockers/OCC/OCC_Cycle.sol";
import "../../lib/zivoe-core-foundry/src/misc/MockStablecoin.sol";



contract Test_OCC_Cycle is Utility {

    using SafeERC20 for IERC20;

    // Events for testing
    event AdjustLimit(uint256 amount, address user);
    event AdjustUsage(uint256 amount, address user);
    event Draw(uint256 amount, address user);
    event Repay(uint256 amount, uint256 base, address user);
    event Cycle(uint256 amount, uint256 base, address user);

    // Mainnet addresses
    address public m_DAO = address(0xB65a66621D7dE34afec9b9AC0755133051550dD7);
    address public m_USDC = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address public m_GBL = address(0xEa537eB0bBcC7783bDF7c595bF9371984583dA66);
    address public m_zVLT = address(0x94BaBe9Ee75C38034920bC6ed42748E8eEFbedd4);
    address public m_zSTT = address(0x7aA5Bf30042b2145B9F0629ea68De55B42ad3BB6);
    address public m_ZVL = address(0x0C03592375ed4Aa105C0C19249297bD7c65fb731);
    address public m_TLC = address(0xE1A68a0404426d6BBc459794e576640dEE3FC916);

    address public m_Underwriter = 0x1FA2700AA0544716D4597d094f4adaCF67D47ab6;
    address public m_Borrower = 0xC8d6248fFbc59BFD51B23E69b962C60590d5f026;

    OCC_Cycle public OCC;

    bool live = true;

    uint256 startingSupplySTT = 10_000_000 ether;
    uint256 startingSupplyJTT = 2_000_000 ether;

    function setUp() public {

        deployCore(false);

        // NOTE: "sam" owns $zSTT and "jim" owns $zJTT
        simulateITO_byTranche_optionalStake(startingSupplySTT, false);

        // OCC_Cycle Initialization & Whitelist - using mainnet addresses
        OCC = new OCC_Cycle(m_DAO, m_USDC, m_GBL, address(m_Underwriter));
        
        // Use mainnet ZVL address with hevm.prank
        hevm.startPrank(m_ZVL);
        IZivoeGlobals(m_GBL).updateIsLocker(address(OCC), true);
        hevm.stopPrank();

        // Whitelist cycle caller (tim) as cycler via underwriter
        hevm.startPrank(address(m_Underwriter));
        OCC.adjustCycleList(address(tim), true);
        hevm.stopPrank();

    }

    // -----------
    //    Tests
    // -----------

    // Validate OCC_Cycle initial state.

    function test_OCC_Cycle_state() public {

        assertEq(OCC.GBL(), m_GBL);
        assertEq(OCC.USDC(), m_USDC);
        assertEq(OCC.owner(), m_DAO);

    }

    // Validate pushToLocker() state changes.
    // Validate pushToLocker() restrictions.
    // This includes:
    //  - asset must be stablecoin
    //  - onlyOwner can call

    function test_OCC_Cycle_pushToLocker_restrictions_asset() public {

        // asset must be stablecoin - test with non-USDC asset
        bool success = god.try_push(address(DAO), address(OCC), address(ZVE), 10_000 ether, "");
        assertFalse(success, "Should fail when trying to push non-USDC asset");
    }

    function test_OCC_Cycle_pushToLocker_restrictions_onlyOwner() public {

        // onlyOwner can call
        hevm.startPrank(address(tim));
        hevm.expectRevert("Ownable: caller is not the owner");
        DAO.push(address(OCC), address(USDC), 10_000 ether, "");
        hevm.stopPrank();
    }

    function test_OCC_Cycle_pushToLocker_state(uint96 amountUSDC) public {

        // Bound the amount to reasonable values
        amountUSDC = uint96(bound(amountUSDC, 1 ether, 1_000_000 ether));

        // Pre-state.
        assertEq(IERC20(USDC).balanceOf(address(OCC)), 0);

        deal(USDC, address(DAO), amountUSDC);

        // Push to locker.
        assert(god.try_push(address(DAO), address(OCC), address(USDC), amountUSDC, ""));

        // Post-state.
        assertEq(IERC20(USDC).balanceOf(address(OCC)), amountUSDC);

    }

    // Validate pullFromLocker() state changes.
    // Validate pullFromLocker() restrictions.
    // This includes:
    //  - asset must be stablecoin
    //  - onlyOwner can call

    function test_OCC_Cycle_pullFromLocker_restrictions_asset() public {

        // asset must be stablecoin - test with non-USDC asset
        bool success = god.try_pull(address(DAO), address(OCC), address(ZVE), "");
        assertFalse(success, "Should fail when trying to pull non-USDC asset");
    }

    function test_OCC_Cycle_pullFromLocker_restrictions_onlyOwner() public {

        // onlyOwner can call
        hevm.startPrank(address(tim));
        hevm.expectRevert("Ownable: caller is not the owner");
        DAO.pull(address(OCC), address(USDC), "");
        hevm.stopPrank();
    }

    function test_OCC_Cycle_pullFromLocker_state(uint96 amountUSDC) public {

        // Bound the amount to reasonable values
        amountUSDC = uint96(bound(amountUSDC, 1 ether, 1_000_000 ether));

        // Setup: Give DAO USDC and push to OCC
        deal(USDC, address(DAO), amountUSDC);
        assert(god.try_push(address(DAO), address(OCC), address(USDC), amountUSDC, ""));

        // Pre-state.
        assertEq(IERC20(USDC).balanceOf(address(OCC)), amountUSDC);

        // Pull from locker.
        assert(god.try_pull(address(DAO), address(OCC), address(USDC), ""));

        // Post-state.
        assertEq(IERC20(USDC).balanceOf(address(OCC)), 0);
        assertEq(IERC20(USDC).balanceOf(address(DAO)), amountUSDC);

    }

    // Validate pullFromLockerPartial() state changes.
    // Validate pullFromLockerPartial() restrictions.
    // This includes:
    //  - asset must be stablecoin
    //  - onlyOwner can call

    function test_OCC_Cycle_pullFromLockerPartial_restrictions_asset() public {

        // asset must be stablecoin - test with non-USDC asset
        bool success = god.try_pullPartial(address(DAO), address(OCC), address(ZVE), 10_000 ether, "");
        assertFalse(success, "Should fail when trying to pullPartial non-USDC asset");
    }

    function test_OCC_Cycle_pullFromLockerPartial_restrictions_onlyOwner() public {

        // onlyOwner can call
        hevm.startPrank(address(tim));
        hevm.expectRevert("Ownable: caller is not the owner");
        DAO.pullPartial(address(OCC), address(USDC), 10_000 ether, "");
        hevm.stopPrank();
    }

    function test_OCC_Cycle_pullFromLockerPartial_state(uint96 amountUSDC) public {

        // Bound the amount to reasonable values (minimum 2 ether to allow partial withdrawal)
        amountUSDC = uint96(bound(amountUSDC, 2 ether, 1_000_000 ether));

        // Setup: Give DAO USDC and push to OCC
        deal(USDC, address(DAO), amountUSDC);
        assert(god.try_push(address(DAO), address(OCC), address(USDC), amountUSDC, ""));

        // Pre-state.
        assertEq(IERC20(USDC).balanceOf(address(OCC)), amountUSDC);

        // Pull a random partial amount (less than the total)
        uint96 partialAmount = uint96(bound(amountUSDC, 1 ether, amountUSDC - 1 ether));
        assert(god.try_pullPartial(address(DAO), address(OCC), address(USDC), partialAmount, ""));

        // Post-state.
        assertEq(IERC20(USDC).balanceOf(address(OCC)), amountUSDC - partialAmount);
        assertEq(IERC20(USDC).balanceOf(address(DAO)), partialAmount);

    }

    // -----------
    //    Tests for adjustLimit()
    // -----------

    // Validate adjustLimit() state changes.
    // Validate adjustLimit() restrictions.
    // This includes:
    //  - only underwriter can call
    //  - limit is properly set
    //  - event is emitted

    function test_OCC_Cycle_adjustLimit_restrictions_onlyUnderwriter() public {

        // only underwriter can call
        hevm.startPrank(address(tim));
        hevm.expectRevert("OCC_Cycle::isUnderwriter() _msgSender() != underwriter");
        OCC.adjustLimit(10_000 ether, address(tim));
        hevm.stopPrank();
    }

    function test_OCC_Cycle_adjustLimit_state() public {

        address testUser = address(0x123);
        uint256 testLimit = 50_000 ether;

        // Pre-state.
        assertEq(OCC.limit(testUser), 0);

        // Adjust limit.
        hevm.startPrank(address(m_Underwriter));
        OCC.adjustLimit(testLimit, testUser);
        hevm.stopPrank();

        // Post-state.
        assertEq(OCC.limit(testUser), testLimit);

    }

    // function test_OCC_Cycle_adjustLimit_event() public {

    //     address testUser = address(0x456);
    //     uint256 testLimit = 75_000 ether;

    //     // Expect event emission.
    //     hevm.expectEmit(true, true, false, true, address(OCC));
    //     emit AdjustLimit(testLimit, testUser);

    //     // Adjust limit.
    //     hevm.startPrank(address(m_Underwriter));
    //     OCC.adjustLimit(testLimit, testUser);
    //     hevm.stopPrank();

    // }

    function test_OCC_Cycle_adjustLimit_multipleUsers() public {

        address user1 = address(0x111);
        address user2 = address(0x222);
        uint256 limit1 = 25_000 ether;
        uint256 limit2 = 35_000 ether;

        // Set limits for multiple users.
        hevm.startPrank(address(m_Underwriter));
        OCC.adjustLimit(limit1, user1);
        OCC.adjustLimit(limit2, user2);
        hevm.stopPrank();

        // Verify limits are set correctly.
        assertEq(OCC.limit(user1), limit1);
        assertEq(OCC.limit(user2), limit2);

    }

    function test_OCC_Cycle_adjustLimit_updateExistingLimit() public {

        address testUser = address(0x789);
        uint256 initialLimit = 10_000 ether;
        uint256 updatedLimit = 20_000 ether;

        // Set initial limit.
        hevm.startPrank(address(m_Underwriter));
        OCC.adjustLimit(initialLimit, testUser);
        assertEq(OCC.limit(testUser), initialLimit);

        // Update the limit.
        OCC.adjustLimit(updatedLimit, testUser);
        hevm.stopPrank();

        // Verify limit is updated.
        assertEq(OCC.limit(testUser), updatedLimit);

    }

    function test_OCC_Cycle_adjustLimit_zeroLimit() public {

        address testUser = address(0xABC);
        uint256 zeroLimit = 0;

        // Set limit to zero.
        hevm.startPrank(address(m_Underwriter));
        OCC.adjustLimit(zeroLimit, testUser);
        hevm.stopPrank();

        // Verify limit is set to zero.
        assertEq(OCC.limit(testUser), zeroLimit);

    }

    function test_OCC_Cycle_adjustLimit_largeAmount() public {

        address testUser = address(0xDEF);
        uint256 largeLimit = type(uint256).max;

        // Set very large limit.
        hevm.startPrank(address(m_Underwriter));
        OCC.adjustLimit(largeLimit, testUser);
        hevm.stopPrank();

        // Verify large limit is set correctly.
        assertEq(OCC.limit(testUser), largeLimit);

    }

    function test_OCC_Cycle_adjustLimit_fuzz(uint96 amount, address user) public {

        // Bound the amount to reasonable values
        amount = uint96(bound(amount, 0, 1_000_000 ether));

        // Pre-state.
        // uint256 preLimit = OCC.limit(user); // Unused variable

        // Adjust limit.
        hevm.startPrank(address(m_Underwriter));
        OCC.adjustLimit(amount, user);
        hevm.stopPrank();

        // Post-state.
        assertEq(OCC.limit(user), amount);

    }

    // -----------
    //    Tests for adjustUsage()
    // -----------

    // Validate adjustUsage() state changes.
    // Validate adjustUsage() restrictions.
    // This includes:
    //  - only underwriter can call
    //  - usage is properly set
    //  - event is emitted

    function test_OCC_Cycle_adjustUsage_restrictions_onlyUnderwriter() public {

        // only underwriter can call
        hevm.startPrank(address(tim));
        hevm.expectRevert("OCC_Cycle::isUnderwriter() _msgSender() != underwriter");
        OCC.adjustUsage(10_000 ether, address(tim));
        hevm.stopPrank();
    }

    function test_OCC_Cycle_adjustUsage_state() public {

        address testUser = address(0x123);
        uint256 testUsage = 50_000 ether;

        // Pre-state.
        assertEq(OCC.usage(testUser), 0);

        // Adjust usage.
        hevm.startPrank(address(m_Underwriter));
        OCC.adjustUsage(testUsage, testUser);
        hevm.stopPrank();

        // Post-state.
        assertEq(OCC.usage(testUser), testUsage);

    }

    // function test_OCC_Cycle_adjustUsage_event() public {

    //     address testUser = address(0x456);
    //     uint256 testUsage = 75_000 ether;

    //     // Expect event emission.
    //     hevm.expectEmit(true, true, false, true, address(OCC));
    //     emit AdjustUsage(testUsage, testUser);

    //     // Adjust usage.
    //     hevm.startPrank(address(m_Underwriter));
    //     OCC.adjustUsage(testUsage, testUser);
    //     hevm.stopPrank();

    // }

    function test_OCC_Cycle_adjustUsage_multipleUsers() public {

        address user1 = address(0x111);
        address user2 = address(0x222);
        uint256 usage1 = 25_000 ether;
        uint256 usage2 = 35_000 ether;

        // Set usage for multiple users.
        hevm.startPrank(address(m_Underwriter));
        OCC.adjustUsage(usage1, user1);
        OCC.adjustUsage(usage2, user2);
        hevm.stopPrank();

        // Verify usage is set correctly.
        assertEq(OCC.usage(user1), usage1);
        assertEq(OCC.usage(user2), usage2);

    }

    function test_OCC_Cycle_adjustUsage_updateExistingUsage() public {

        address testUser = address(0x789);
        uint256 initialUsage = 10_000 ether;
        uint256 updatedUsage = 20_000 ether;

        // Set initial usage.
        hevm.startPrank(address(m_Underwriter));
        OCC.adjustUsage(initialUsage, testUser);
        assertEq(OCC.usage(testUser), initialUsage);

        // Update the usage.
        OCC.adjustUsage(updatedUsage, testUser);
        hevm.stopPrank();

        // Verify usage is updated.
        assertEq(OCC.usage(testUser), updatedUsage);

    }

    function test_OCC_Cycle_adjustUsage_zeroUsage() public {

        address testUser = address(0xABC);
        uint256 zeroUsage = 0;

        // Set usage to zero.
        hevm.startPrank(address(m_Underwriter));
        OCC.adjustUsage(zeroUsage, testUser);
        hevm.stopPrank();

        // Verify usage is set to zero.
        assertEq(OCC.usage(testUser), zeroUsage);

    }

    function test_OCC_Cycle_adjustUsage_largeAmount() public {

        address testUser = address(0xDEF);
        uint256 largeUsage = type(uint256).max;

        // Set very large usage.
        hevm.startPrank(address(m_Underwriter));
        OCC.adjustUsage(largeUsage, testUser);
        hevm.stopPrank();

        // Verify large usage is set correctly.
        assertEq(OCC.usage(testUser), largeUsage);

    }

    function test_OCC_Cycle_adjustUsage_fuzz(uint96 amount, address user) public {

        // Bound the amount to reasonable values
        amount = uint96(bound(amount, 0, 1_000_000 ether));

        // Pre-state.
        // uint256 preUsage = OCC.usage(user); // Unused variable

        // Adjust usage.
        hevm.startPrank(address(m_Underwriter));
        OCC.adjustUsage(amount, user);
        hevm.stopPrank();

        // Post-state.
        assertEq(OCC.usage(user), amount);

    }

    // -----------
    //    Tests for cycle()
    // -----------

    // Validate cycle() state changes.
    // Validate cycle() restrictions.
    // This includes:
    //  - usage is properly updated for each user
    //  - USDC is transferred to YDL
    //  - events are emitted for each cycle
    //  - arrays must have same length
    //  - caller must have sufficient USDC and allowance

    function test_OCC_Cycle_cycle_singleUser() public {

        address testUser = address(0x111);
        uint256 cycleAmount = 10_000 ether;
        uint256[] memory amounts = new uint256[](1);
        address[] memory users = new address[](1);
        amounts[0] = cycleAmount;
        users[0] = testUser;

        // Setup: Give caller USDC and approve OCC
        deal(m_USDC, address(tim), cycleAmount);
        hevm.startPrank(address(tim));
        IERC20(m_USDC).approve(address(OCC), cycleAmount);
        hevm.stopPrank();

        // Pre-state.
        assertEq(OCC.usage(testUser), 0);
        uint256 preYDLBalance = IERC20(m_USDC).balanceOf(IZivoeGlobals(m_GBL).YDL());

        // Cycle.
        hevm.startPrank(address(tim));
        OCC.cycle(amounts, users);
        hevm.stopPrank();

        // Post-state.
        assertEq(OCC.usage(testUser), cycleAmount);
        assertEq(IERC20(m_USDC).balanceOf(IZivoeGlobals(m_GBL).YDL()), preYDLBalance + cycleAmount);

    }

    function test_OCC_Cycle_cycle_multipleUsers() public {

        address user1 = address(0x111);
        address user2 = address(0x222);
        address user3 = address(0x333);
        uint256 amount1 = 5_000 ether;
        uint256 amount2 = 7_500 ether;
        uint256 amount3 = 2_500 ether;
        uint256 totalAmount = amount1 + amount2 + amount3;

        uint256[] memory amounts = new uint256[](3);
        address[] memory users = new address[](3);
        amounts[0] = amount1;
        amounts[1] = amount2;
        amounts[2] = amount3;
        users[0] = user1;
        users[1] = user2;
        users[2] = user3;

        // Setup: Give caller USDC and approve OCC
        deal(USDC, address(tim), totalAmount);
        hevm.startPrank(address(tim));
        IERC20(USDC).approve(address(OCC), totalAmount);
        hevm.stopPrank();

        // Pre-state.
        assertEq(OCC.usage(user1), 0);
        assertEq(OCC.usage(user2), 0);
        assertEq(OCC.usage(user3), 0);
        uint256 preYDLBalance = IERC20(USDC).balanceOf(GBL.YDL());

        // Cycle.
        hevm.startPrank(address(tim));
        OCC.cycle(amounts, users);
        hevm.stopPrank();

        // Post-state.
        assertEq(OCC.usage(user1), amount1);
        assertEq(OCC.usage(user2), amount2);
        assertEq(OCC.usage(user3), amount3);
        assertEq(IERC20(USDC).balanceOf(GBL.YDL()), preYDLBalance + totalAmount);

    }

    // function test_OCC_Cycle_cycle_event() public {

    //     address testUser = address(0x444);
    //     uint256 cycleAmount = 15_000 ether;
    //     uint256[] memory amounts = new uint256[](1);
    //     address[] memory users = new address[](1);
    //     amounts[0] = cycleAmount;
    //     users[0] = testUser;

    //     // Setup: Give caller USDC and approve OCC
    //     deal(USDC, address(tim), cycleAmount);
    //     hevm.startPrank(address(tim));
    //     IERC20(USDC).approve(address(OCC), cycleAmount);
    //     hevm.stopPrank();

    //     // Expect event emission.
    //     hevm.expectEmit(true, true, false, true, address(OCC));
    //     emit Cycle(cycleAmount, cycleAmount, testUser); // base = usage after increment

    //     // Cycle.
    //     hevm.startPrank(address(tim));
    //     OCC.cycle(amounts, users);
    //     hevm.stopPrank();

    // }

    // function test_OCC_Cycle_cycle_multipleEvents() public {

    //     address user1 = address(0x555);
    //     address user2 = address(0x666);
    //     uint256 amount1 = 8_000 ether;
    //     uint256 amount2 = 12_000 ether;

    //     uint256[] memory amounts = new uint256[](2);
    //     address[] memory users = new address[](2);
    //     amounts[0] = amount1;
    //     amounts[1] = amount2;
    //     users[0] = user1;
    //     users[1] = user2;

    //     // Setup: Give caller USDC and approve OCC
    //     deal(USDC, address(tim), amount1 + amount2);
    //     hevm.startPrank(address(tim));
    //     IERC20(USDC).approve(address(OCC), amount1 + amount2);
    //     hevm.stopPrank();

    //     // Expect multiple event emissions.
    //     hevm.expectEmit(true, true, false, true, address(OCC));
    //     emit Cycle(amount1, amount1, user1);
    //     hevm.expectEmit(true, true, false, true, address(OCC));
    //     emit Cycle(amount2, amount2, user2);

    //     // Cycle.
    //     hevm.startPrank(address(tim));
    //     OCC.cycle(amounts, users);
    //     hevm.stopPrank();

    // }

    function test_OCC_Cycle_cycle_existingUsage() public {

        address testUser = address(0x777);
        uint256 existingUsage = 5_000 ether;
        uint256 cycleAmount = 3_000 ether;
        uint256[] memory amounts = new uint256[](1);
        address[] memory users = new address[](1);
        amounts[0] = cycleAmount;
        users[0] = testUser;

        // Setup: Set existing usage
        hevm.startPrank(address(m_Underwriter));
        OCC.adjustUsage(existingUsage, testUser);
        hevm.stopPrank();

        // Setup: Give caller USDC and approve OCC
        deal(USDC, address(tim), cycleAmount);
        hevm.startPrank(address(tim));
        IERC20(USDC).approve(address(OCC), cycleAmount);
        hevm.stopPrank();

        // Pre-state.
        assertEq(OCC.usage(testUser), existingUsage);

        // Cycle.
        hevm.startPrank(address(tim));
        OCC.cycle(amounts, users);
        hevm.stopPrank();

        // Post-state.
        assertEq(OCC.usage(testUser), existingUsage + cycleAmount);

    }

    function test_OCC_Cycle_cycle_zeroAmount() public {

        address testUser = address(0x888);
        uint256 zeroAmount = 0;
        uint256[] memory amounts = new uint256[](1);
        address[] memory users = new address[](1);
        amounts[0] = zeroAmount;
        users[0] = testUser;

        // Setup: Give caller USDC and approve OCC
        deal(USDC, address(tim), 1 ether); // Give some USDC but cycle 0
        hevm.startPrank(address(tim));
        IERC20(USDC).approve(address(OCC), 1 ether);
        hevm.stopPrank();

        // Pre-state.
        assertEq(OCC.usage(testUser), 0);
        uint256 preYDLBalance = IERC20(USDC).balanceOf(GBL.YDL());

        // Cycle.
        hevm.startPrank(address(tim));
        OCC.cycle(amounts, users);
        hevm.stopPrank();

        // Post-state.
        assertEq(OCC.usage(testUser), zeroAmount);
        assertEq(IERC20(USDC).balanceOf(GBL.YDL()), preYDLBalance); // No transfer for zero amount

    }

    function test_OCC_Cycle_cycle_insufficientBalance() public {

        address testUser = address(0x999);
        uint256 cycleAmount = 10_000 ether;
        uint256[] memory amounts = new uint256[](1);
        address[] memory users = new address[](1);
        amounts[0] = cycleAmount;
        users[0] = testUser;

        // Setup: Give caller less USDC than needed
        deal(USDC, address(tim), cycleAmount - 1 ether);
        hevm.startPrank(address(tim));
        IERC20(USDC).approve(address(OCC), cycleAmount);
        hevm.stopPrank();

        // Try to cycle (should fail due to insufficient balance)
        hevm.startPrank(address(tim));
        hevm.expectRevert("ERC20: transfer amount exceeds balance");
        OCC.cycle(amounts, users);
        hevm.stopPrank();

    }

    function test_OCC_Cycle_cycle_insufficientAllowance() public {

        address testUser = address(0xAAA);
        uint256 cycleAmount = 10_000 ether;
        uint256[] memory amounts = new uint256[](1);
        address[] memory users = new address[](1);
        amounts[0] = cycleAmount;
        users[0] = testUser;

        // Setup: Give caller USDC but don't approve
        deal(USDC, address(tim), cycleAmount);

        // Try to cycle without approval (should fail)
        hevm.startPrank(address(tim));
        hevm.expectRevert("ERC20: transfer amount exceeds allowance");
        OCC.cycle(amounts, users);
        hevm.stopPrank();

    }

    function test_OCC_Cycle_cycle_emptyArrays() public {

        uint256[] memory amounts = new uint256[](0);
        address[] memory users = new address[](0);

        // Cycle with empty arrays (should succeed but do nothing)
        hevm.startPrank(address(tim));
        OCC.cycle(amounts, users);
        hevm.stopPrank();

        // No state changes expected

    }

    function test_OCC_Cycle_cycle_mismatchedArrayLengths() public {

        address testUser = address(0xBBB);
        uint256[] memory amounts = new uint256[](1);
        address[] memory users = new address[](2);
        amounts[0] = 10_000 ether;
        users[0] = testUser;
        users[1] = address(0xCCC);

        // Setup: Give caller USDC and approve OCC
        deal(USDC, address(tim), 20_000 ether);
        hevm.startPrank(address(tim));
        IERC20(USDC).approve(address(OCC), 20_000 ether);
        hevm.stopPrank();

        // Try to cycle with mismatched arrays (should fail due to array bounds)
        hevm.startPrank(address(tim));
        hevm.expectRevert("OCC_Cycle::cycle() amounts.length != users.length");
        OCC.cycle(amounts, users);
        hevm.stopPrank();

    }

    // function test_OCC_Cycle_cycle_fuzz(uint96[] calldata amounts, address[] calldata users) public {

    //     // Bound the arrays to reasonable sizes
    //     vm.assume(amounts.length <= 5);
    //     vm.assume(users.length <= 5);
    //     vm.assume(amounts.length == users.length);
    //     vm.assume(amounts.length > 0);

    //     // Create memory arrays for processing
    //     uint256[] memory amounts_mem = new uint256[](amounts.length);
    //     address[] memory users_mem = new address[](users.length);
        
    //     // Bound amounts to reasonable values
    //     for (uint i = 0; i < amounts.length; i++) {
    //         amounts_mem[i] = uint256(bound(amounts[i], 0, 100_000 ether));
    //         users_mem[i] = users[i];
    //     }

    //     // Calculate total amount needed
    //     uint256 totalAmount = 0;
    //     for (uint i = 0; i < amounts_mem.length; i++) {
    //         totalAmount += amounts_mem[i];
    //     }

    //     // Setup: Give caller USDC and approve OCC
    //     deal(USDC, address(tim), totalAmount);
    //     hevm.startPrank(address(tim));
    //     IERC20(USDC).approve(address(OCC), totalAmount);
    //     hevm.stopPrank();

    //     // Pre-state: Record initial usage for each user
    //     uint256[] memory preUsage = new uint256[](users_mem.length);
    //     for (uint i = 0; i < users_mem.length; i++) {
    //         preUsage[i] = OCC.usage(users_mem[i]);
    //     }

    //     uint256 preYDLBalance = IERC20(USDC).balanceOf(GBL.YDL());

    //     // Cycle.
    //     hevm.startPrank(address(tim));
    //     OCC.cycle(amounts_mem, users_mem);
    //     hevm.stopPrank();

    //     // Post-state: Verify usage and YDL balance
    //     for (uint i = 0; i < users_mem.length; i++) {
    //         assertEq(OCC.usage(users_mem[i]), preUsage[i] + amounts_mem[i]);
    //     }
    //     assertEq(IERC20(USDC).balanceOf(GBL.YDL()), preYDLBalance + totalAmount);

    // }

    // -----------
    //    Tests for draw()
    // -----------

    // Validate draw() state changes.
    // Validate draw() restrictions.
    // This includes:
    //  - only owner can call
    //  - amount + usage <= limit
    //  - usage is properly updated
    //  - USDC is transferred
    //  - event is emitted



    function test_OCC_Cycle_draw_restrictions_limitExceeded() public {

        address testUser = address(0x1111111111111111111111111111111111111111);
        
        // Setup: Set a limit and try to draw more than allowed
        hevm.startPrank(address(m_Underwriter));
        OCC.adjustLimit(10_000 ether, testUser);
        hevm.stopPrank();

        // Try to draw more than the limit
        hevm.startPrank(testUser);
        hevm.expectRevert("OCC_Cycle::draw() amount + usage > limit");
        OCC.draw(15_000 ether);
        hevm.stopPrank();
    }

    function test_OCC_Cycle_draw_restrictions_usageExceedsLimit() public {

        address testUser = address(0x2222222222222222222222222222222222222222);
        
        // Setup: Set a limit and draw up to it, then try to draw more
        deal(USDC, address(OCC), 15_000 ether); // Give OCC enough USDC
        hevm.startPrank(address(m_Underwriter));
        OCC.adjustLimit(10_000 ether, testUser);
        hevm.stopPrank();

        // First draw (should succeed)
        hevm.startPrank(testUser);
        OCC.draw(10_000 ether);
        
        // Try to draw more (should fail)
        hevm.expectRevert("OCC_Cycle::draw() amount + usage > limit");
        OCC.draw(1 ether);
        hevm.stopPrank();
    }

    function test_OCC_Cycle_draw_state() public {

        address testUser = address(0x3333333333333333333333333333333333333333);
        uint256 testLimit = 50_000 ether;
        uint256 drawAmount = 25_000 ether;

        // Setup: Give OCC USDC and set limit
        deal(USDC, address(OCC), testLimit);
        hevm.startPrank(address(m_Underwriter));
        OCC.adjustLimit(testLimit, testUser);
        hevm.stopPrank();

        // Pre-state.
        assertEq(OCC.limit(testUser), testLimit);
        assertEq(OCC.usage(testUser), 0);
        assertEq(IERC20(USDC).balanceOf(testUser), 0);

        // Draw.
        hevm.startPrank(testUser);
        OCC.draw(drawAmount);
        hevm.stopPrank();

        // Post-state.
        assertEq(OCC.usage(testUser), drawAmount);
        assertEq(IERC20(USDC).balanceOf(testUser), drawAmount);

    }

    // function test_OCC_Cycle_draw_event() public {

    //     address testUser = address(0x4444444444444444444444444444444444444444);
    //     uint256 testLimit = 30_000 ether;
    //     uint256 drawAmount = 15_000 ether;

    //     // Setup: Give OCC USDC and set limit
    //     deal(USDC, address(OCC), testLimit);
    //     hevm.startPrank(address(m_Underwriter));
    //     OCC.adjustLimit(testLimit, testUser);
    //     hevm.stopPrank();

    //     // Expect event emission.
    //     hevm.expectEmit(true, true, false, true, address(OCC));
    //     emit Draw(drawAmount, testUser);

    //     // Draw.
    //     hevm.startPrank(testUser);
    //     OCC.draw(drawAmount);
    //     hevm.stopPrank();

    // }

    function test_OCC_Cycle_draw_multipleDraws() public {

        address testUser = address(0x5555555555555555555555555555555555555555);
        uint256 testLimit = 100_000 ether;
        uint256 draw1 = 30_000 ether;
        uint256 draw2 = 40_000 ether;

        // Setup: Give OCC USDC and set limit
        deal(USDC, address(OCC), testLimit);
        hevm.startPrank(address(m_Underwriter));
        OCC.adjustLimit(testLimit, testUser);
        hevm.stopPrank();

        // First draw.
        hevm.startPrank(testUser);
        OCC.draw(draw1);
        assertEq(OCC.usage(testUser), draw1);
        assertEq(IERC20(USDC).balanceOf(testUser), draw1);

        // Second draw.
        OCC.draw(draw2);
        hevm.stopPrank();

        // Post-state.
        assertEq(OCC.usage(testUser), draw1 + draw2);
        assertEq(IERC20(USDC).balanceOf(testUser), draw1 + draw2);

    }

    function test_OCC_Cycle_draw_exactLimit() public {

        address testUser = address(0x6666666666666666666666666666666666666666);
        uint256 testLimit = 25_000 ether;

        // Setup: Give OCC USDC and set limit
        deal(USDC, address(OCC), testLimit);
        hevm.startPrank(address(m_Underwriter));
        OCC.adjustLimit(testLimit, testUser);
        hevm.stopPrank();

        // Draw exactly the limit.
        hevm.startPrank(testUser);
        OCC.draw(testLimit);
        hevm.stopPrank();

        // Post-state.
        assertEq(OCC.usage(testUser), testLimit);
        assertEq(IERC20(USDC).balanceOf(testUser), testLimit);

    }

    function test_OCC_Cycle_draw_zeroAmount() public {

        address testUser = address(0x7777777777777777777777777777777777777777);
        uint256 testLimit = 10_000 ether;

        // Setup: Give OCC USDC and set limit
        deal(USDC, address(OCC), testLimit);
        hevm.startPrank(address(m_Underwriter));
        OCC.adjustLimit(testLimit, testUser);
        hevm.stopPrank();

        // Draw zero amount.
        hevm.startPrank(testUser);
        OCC.draw(0);
        hevm.stopPrank();

        // Post-state.
        assertEq(OCC.usage(testUser), 0);
        assertEq(IERC20(USDC).balanceOf(testUser), 0);

    }

    function test_OCC_Cycle_draw_insufficientUSDC() public {

        address testUser = address(0x8888888888888888888888888888888888888888);
        uint256 testLimit = 50_000 ether;
        uint256 drawAmount = 25_000 ether;

        // Setup: Give OCC less USDC than the draw amount
        deal(USDC, address(OCC), drawAmount - 1 ether);
        hevm.startPrank(address(m_Underwriter));
        OCC.adjustLimit(testLimit, testUser);
        hevm.stopPrank();

        // Try to draw (should fail due to insufficient USDC)
        hevm.startPrank(testUser);
        hevm.expectRevert("ERC20: transfer amount exceeds balance");
        OCC.draw(drawAmount);
        hevm.stopPrank();

    }

    function test_OCC_Cycle_draw_fuzz(uint96 amount, uint96 limit) public {

        // Bound the values to reasonable ranges
        limit = uint96(bound(limit, 1 ether, 1_000_000 ether));
        amount = uint96(bound(amount, 0, limit));

        address testUser = address(0x9999999999999999999999999999999999999999);

        // Setup: Give OCC USDC and set limit
        deal(USDC, address(OCC), limit);
        hevm.startPrank(address(m_Underwriter));
        OCC.adjustLimit(limit, testUser);
        hevm.stopPrank();

        // Pre-state.
        uint256 preUsage = OCC.usage(testUser);
        uint256 preBalance = IERC20(USDC).balanceOf(testUser);

        // Draw.
        hevm.startPrank(testUser);
        OCC.draw(amount);
        hevm.stopPrank();

        // Post-state.
        assertEq(OCC.usage(testUser), preUsage + amount);
        assertEq(IERC20(USDC).balanceOf(testUser), preBalance + amount);

    }

    // -----------
    //    Tests for repay()
    // -----------

    // Validate repay() state changes.
    // Validate repay() restrictions.
    // This includes:
    //  - only owner can call
    //  - base <= amount
    //  - amount <= usage
    //  - USDC transfers work correctly
    //  - usage is properly updated
    //  - event is emitted



    function test_OCC_Cycle_repay_restrictions_baseGreaterThanAmount() public {

        address testUser = address(0xaAaAaAaaAaAaAaaAaAAAAAAAAaaaAaAaAaaAaaAa);
        
        // Setup: Set a limit and draw some amount
        deal(USDC, address(OCC), 20_000 ether);
        hevm.startPrank(address(m_Underwriter));
        OCC.adjustLimit(20_000 ether, testUser);
        hevm.stopPrank();

        hevm.startPrank(testUser);
        OCC.draw(10_000 ether);
        
        // Try to repay with base > amount
        hevm.expectRevert("OCC_Cycle::repay() base > amount");
        OCC.repay(5_000 ether, 10_000 ether);
        hevm.stopPrank();
    }

    function test_OCC_Cycle_repay_restrictions_amountGreaterThanUsage() public {

        address testUser = address(0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB);
        
        // Setup: Set a limit and draw some amount
        deal(USDC, address(OCC), 20_000 ether);
        hevm.startPrank(address(m_Underwriter));
        OCC.adjustLimit(20_000 ether, testUser);
        hevm.stopPrank();

        hevm.startPrank(testUser);
        OCC.draw(10_000 ether);
        
        // Try to repay more than usage
        hevm.expectRevert("OCC_Cycle::repay() amount > usage");
        OCC.repay(15_000 ether, 5_000 ether);
        hevm.stopPrank();
    }

    function test_OCC_Cycle_repay_state() public {

        address testUser = address(0x9876543210987654321098765432109876543210); // Different from DAO
        uint256 testLimit = 50_000 ether;
        uint256 drawAmount = 30_000 ether;
        uint256 repayAmount = 20_000 ether;
        uint256 baseAmount = 15_000 ether;

        // Setup: Give OCC USDC and set limit
        deal(USDC, address(OCC), testLimit);
        hevm.startPrank(address(m_Underwriter));
        OCC.adjustLimit(testLimit, testUser);
        hevm.stopPrank();

        // Draw some amount
        hevm.startPrank(testUser);
        OCC.draw(drawAmount);
        hevm.stopPrank();

        // Give USDC to the user for repayment
        deal(USDC, testUser, repayAmount);

        // Approve OCC to spend USDC
        hevm.startPrank(testUser);
        IERC20(USDC).approve(address(OCC), repayAmount);
        hevm.stopPrank();

        // Pre-state.
        assertEq(OCC.usage(testUser), drawAmount);
        assertEq(IERC20(USDC).balanceOf(testUser), repayAmount);
        assertEq(IERC20(USDC).balanceOf(address(OCC)), testLimit - drawAmount);

        // Repay.
        hevm.startPrank(testUser);
        OCC.repay(repayAmount, baseAmount);
        hevm.stopPrank();

        // Post-state.
        assertEq(OCC.usage(testUser), drawAmount - baseAmount);
        assertEq(IERC20(USDC).balanceOf(testUser), 0); // User's USDC was transferred to OCC, base amount goes to DAO
        assertEq(IERC20(USDC).balanceOf(address(OCC)), testLimit - drawAmount); // OCC keeps the same amount as before repayment

    }

    // function test_OCC_Cycle_repay_event() public {

    //     address testUser = address(0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC);
    //     uint256 testLimit = 40_000 ether;
    //     uint256 drawAmount = 25_000 ether;
    //     uint256 repayAmount = 15_000 ether;
    //     uint256 baseAmount = 10_000 ether;

    //     // Setup: Give OCC USDC and set limit
    //     deal(USDC, address(OCC), testLimit);
    //     hevm.startPrank(address(m_Underwriter));
    //     OCC.adjustLimit(testLimit, testUser);
    //     hevm.stopPrank();

    //     // Draw some amount
    //     hevm.startPrank(testUser);
    //     OCC.draw(drawAmount);
    //     hevm.stopPrank();

    //     // Give USDC to the user for repayment
    //     deal(USDC, testUser, repayAmount);

    //     // Approve OCC to spend USDC
    //     hevm.startPrank(testUser);
    //     IERC20(USDC).approve(address(OCC), repayAmount);
    //     hevm.stopPrank();

    //     // Expect event emission.
    //     hevm.expectEmit(true, true, false, true, address(OCC));
    //     emit Repay(repayAmount, baseAmount, testUser);

    //     // Repay.
    //     hevm.startPrank(testUser);
    //     OCC.repay(repayAmount, baseAmount);
    //     hevm.stopPrank();

    // }

    function test_OCC_Cycle_repay_multipleRepayments() public {

        address testUser = address(0x4040404040404040404040404040404040404040);
        uint256 testLimit = 100_000 ether;
        uint256 drawAmount = 60_000 ether;
        uint256 repay1 = 20_000 ether;
        uint256 base1 = 15_000 ether;
        uint256 repay2 = 25_000 ether;
        uint256 base2 = 20_000 ether;

        // Setup: Give OCC USDC and set limit
        deal(USDC, address(OCC), testLimit);
        hevm.startPrank(address(m_Underwriter));
        OCC.adjustLimit(testLimit, testUser);
        hevm.stopPrank();

        // Draw some amount
        hevm.startPrank(testUser);
        OCC.draw(drawAmount);
        hevm.stopPrank();

        // First repayment
        deal(USDC, testUser, repay1);
        hevm.startPrank(testUser);
        IERC20(USDC).approve(address(OCC), repay1);
        OCC.repay(repay1, base1);
        assertEq(OCC.usage(testUser), drawAmount - base1);

        // Second repayment
        deal(USDC, testUser, repay2);
        IERC20(USDC).approve(address(OCC), repay2);
        OCC.repay(repay2, base2);
        hevm.stopPrank();

        // Post-state.
        assertEq(OCC.usage(testUser), drawAmount - base1 - base2);

    }

    function test_OCC_Cycle_repay_exactUsage() public {

        address testUser = address(0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd);
        uint256 testLimit = 30_000 ether;
        uint256 drawAmount = 20_000 ether;
        uint256 baseAmount = 20_000 ether;

        // Setup: Give OCC USDC and set limit
        deal(USDC, address(OCC), testLimit);
        hevm.startPrank(address(m_Underwriter));
        OCC.adjustLimit(testLimit, testUser);
        hevm.stopPrank();

        // Draw some amount
        hevm.startPrank(testUser);
        OCC.draw(drawAmount);
        hevm.stopPrank();

        // Give USDC to the user for repayment
        deal(USDC, testUser, drawAmount);

        // Approve OCC to spend USDC
        hevm.startPrank(testUser);
        IERC20(USDC).approve(address(OCC), drawAmount);
        OCC.repay(drawAmount, baseAmount);
        hevm.stopPrank();

        // Post-state.
        assertEq(OCC.usage(testUser), 0);

    }

    function test_OCC_Cycle_repay_zeroAmount() public {

        address testUser = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
        uint256 testLimit = 20_000 ether;
        uint256 drawAmount = 10_000 ether;

        // Setup: Give OCC USDC and set limit
        deal(USDC, address(OCC), testLimit);
        hevm.startPrank(address(m_Underwriter));
        OCC.adjustLimit(testLimit, testUser);
        hevm.stopPrank();

        // Draw some amount
        hevm.startPrank(testUser);
        OCC.draw(drawAmount);
        hevm.stopPrank();

        // Repay zero amount
        hevm.startPrank(testUser);
        OCC.repay(0, 0);
        hevm.stopPrank();

        // Post-state.
        assertEq(OCC.usage(testUser), drawAmount);

    }

    function test_OCC_Cycle_repay_baseEqualsAmount() public {

        address testUser = address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF);
        uint256 testLimit = 25_000 ether;
        uint256 drawAmount = 15_000 ether;
        uint256 repayAmount = 10_000 ether;

        // Setup: Give OCC USDC and set limit
        deal(USDC, address(OCC), testLimit);
        hevm.startPrank(address(m_Underwriter));
        OCC.adjustLimit(testLimit, testUser);
        hevm.stopPrank();

        // Draw some amount
        hevm.startPrank(testUser);
        OCC.draw(drawAmount);
        hevm.stopPrank();

        // Give USDC to the user for repayment
        deal(USDC, testUser, repayAmount);

        // Approve OCC to spend USDC
        hevm.startPrank(testUser);
        IERC20(USDC).approve(address(OCC), repayAmount);
        OCC.repay(repayAmount, repayAmount);
        hevm.stopPrank();

        // Post-state.
        assertEq(OCC.usage(testUser), drawAmount - repayAmount);

    }

    function test_OCC_Cycle_repay_insufficientAllowance() public {

        address testUser = address(0x1010101010101010101010101010101010101010);
        uint256 testLimit = 20_000 ether;
        uint256 drawAmount = 10_000 ether;
        uint256 repayAmount = 5_000 ether;
        uint256 baseAmount = 3_000 ether;

        // Setup: Give OCC USDC and set limit
        deal(USDC, address(OCC), testLimit);
        hevm.startPrank(address(m_Underwriter));
        OCC.adjustLimit(testLimit, testUser);
        hevm.stopPrank();

        // Draw some amount
        hevm.startPrank(testUser);
        OCC.draw(drawAmount);
        hevm.stopPrank();

        // Give USDC to the user but don't approve
        deal(USDC, testUser, repayAmount);

        // Try to repay without approval (should fail)
        hevm.startPrank(testUser);
        hevm.expectRevert("ERC20: transfer amount exceeds allowance");
        OCC.repay(repayAmount, baseAmount);
        hevm.stopPrank();

    }

    function test_OCC_Cycle_repay_fuzz(uint96 amount, uint96 base, uint96 limit) public {

        // Bound the values to reasonable ranges
        limit = uint96(bound(limit, 1 ether, 1_000_000 ether));
        amount = uint96(bound(amount, 0, limit));
        base = uint96(bound(base, 0, amount));

        address testUser = address(0x2020202020202020202020202020202020202020);

        // Setup: Give OCC USDC and set limit
        deal(USDC, address(OCC), limit);
        hevm.startPrank(address(m_Underwriter));
        OCC.adjustLimit(limit, testUser);
        hevm.stopPrank();

        // Draw some amount
        hevm.startPrank(testUser);
        OCC.draw(amount);
        hevm.stopPrank();

        // Give USDC to the user for repayment
        deal(USDC, testUser, amount);

        // Approve OCC to spend USDC
        hevm.startPrank(testUser);
        IERC20(USDC).approve(address(OCC), amount);
        hevm.stopPrank();

        // Pre-state.
        uint256 preUsage = OCC.usage(testUser);

        // Repay.
        hevm.startPrank(testUser);
        OCC.repay(amount, base);
        hevm.stopPrank();

        // Post-state.
        assertEq(OCC.usage(testUser), preUsage - base);

    }

    function test_OCC_Cycle_repay_insufficientBalance() public {

        address testUser = address(0x3030303030303030303030303030303030303030);
        uint256 testLimit = 20_000 ether;
        uint256 drawAmount = 10_000 ether;
        uint256 repayAmount = 5_000 ether;
        uint256 baseAmount = 3_000 ether;

        // Setup: Give OCC USDC and set limit
        deal(USDC, address(OCC), testLimit);
        hevm.startPrank(address(m_Underwriter));
        OCC.adjustLimit(testLimit, testUser);
        hevm.stopPrank();

        // Draw some amount
        hevm.startPrank(testUser);
        OCC.draw(drawAmount);
        hevm.stopPrank();

        // Give USDC to the user but less than repay amount
        deal(USDC, testUser, repayAmount - 1 ether);

        // Approve OCC to spend USDC
        hevm.startPrank(testUser);
        IERC20(USDC).approve(address(OCC), repayAmount);
        hevm.stopPrank();

        // Try to repay (should fail due to insufficient balance)
        hevm.startPrank(testUser);
        hevm.expectRevert("ERC20: transfer amount exceeds balance");
        OCC.repay(repayAmount, baseAmount);
        hevm.stopPrank();

    }

    function test_OCC_Cycle_repay_distributionToYDLAndDAO() public {

        address testUser = address(0x1234567890123456789012345678901234567890); // Different from DAO
        uint256 testLimit = 30_000 ether;
        uint256 drawAmount = 20_000 ether;
        uint256 repayAmount = 15_000 ether;
        uint256 baseAmount = 10_000 ether;
        uint256 ydlAmount = repayAmount - baseAmount; // 5_000 ether

        // Setup: Give OCC USDC and set limit
        deal(USDC, address(OCC), testLimit);
        hevm.startPrank(address(m_Underwriter));
        OCC.adjustLimit(testLimit, testUser);
        hevm.stopPrank();

        // Draw some amount
        hevm.startPrank(testUser);
        OCC.draw(drawAmount);
        hevm.stopPrank();

        // Give USDC to the user for repayment
        deal(USDC, testUser, repayAmount);

        // Approve OCC to spend USDC
        hevm.startPrank(testUser);
        IERC20(USDC).approve(address(OCC), repayAmount);
        hevm.stopPrank();

        // Pre-state balances
        uint256 preYDLBalance = IERC20(USDC).balanceOf(GBL.YDL());
        uint256 preDAOBalance = IERC20(USDC).balanceOf(GBL.DAO());

        // Repay.
        hevm.startPrank(testUser);
        OCC.repay(repayAmount, baseAmount);
        hevm.stopPrank();

        // Post-state balances - verify distribution
        assertEq(IERC20(USDC).balanceOf(GBL.YDL()), preYDLBalance + ydlAmount);
        assertEq(IERC20(USDC).balanceOf(GBL.DAO()), preDAOBalance + baseAmount);

    }

} 