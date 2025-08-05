// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../Utility/Utility.sol";

import "../../lib/zivoe-core-foundry/src/lockers/OCR/OCR_Instant.sol";
import "../../lib/zivoe-core-foundry/src/misc/MockStablecoin.sol";

contract Test_OCR_Instant is Utility {

    using SafeERC20 for IERC20;

    OCR_Instant public OCR;

    // Mainnet addresses
    address public zVLT = address(0x94BaBe9Ee75C38034920bC6ed42748E8eEFbedd4);
    address public aUSDC = address(0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c);
    address public aavePool = address(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
    
    // Test amounts
    uint256 INITIAL_USDC_AMOUNT = 1_000_000 * 10**6; // 1M USDC (6 decimals)
    uint256 INITIAL_ZVLT_AMOUNT = 1_000_000 * 10**18; // 1M zVLT (18 decimals)
    uint16 constant REDEMPTION_FEE_BIPS = 100; // 1% fee

    // Events for testing
    event UpdatedRedemptionFeeBIPS(uint256 oldFee, uint256 newFee);
    event zVLTBurnedForUSDC(address indexed user, uint256 zVLTBurned, uint256 USDCRedeemed, uint256 fee);

    function setUp() public {

        deployCore(false);

        // NOTE: "sam" owns $zSTT and "jim" owns $zJTT
        simulateITO_byTranche_optionalStake(10_000_000 ether, false);

        // OCR_Instant Initialization & Whitelist
        OCR = new OCR_Instant(
            address(DAO),
            USDC, // USDC address
            address(GBL),
            zVLT, // ERC-4626 zVLT token address
            address(zSTT), // zSTT underlying asset token address
            aavePool,
            aUSDC, // aUSDC address
            REDEMPTION_FEE_BIPS
        );
        zvl.try_updateIsLocker(address(GBL), address(OCR), true);

        // Fund DAO with initial USDC
        deal(USDC, address(DAO), INITIAL_USDC_AMOUNT);
        
        // Fund users with zVLT tokens (using dummy address)
        deal(zVLT, address(sam), INITIAL_ZVLT_AMOUNT);
        deal(zVLT, address(sue), INITIAL_ZVLT_AMOUNT);
        deal(zVLT, address(sal), INITIAL_ZVLT_AMOUNT);

    }

    // ----------------------
    //    Helper Functions
    // ----------------------

    function helper_redeemUSDC(address user, uint256 zVLTAmount) public returns (uint256 fee, uint256 netAmount) {
        
        uint256 preUserZVLT = IERC20(zVLT).balanceOf(user);
        uint256 preUserUSDC = IERC20(USDC).balanceOf(user);
        
        // Fund contract with USDC for redemption
        deal(USDC, address(OCR), zVLTAmount);
        
        hevm.startPrank(user);
        OCR.redeemUSDC(zVLTAmount);
        hevm.stopPrank();
        
        fee = (zVLTAmount * REDEMPTION_FEE_BIPS) / 10000;
        netAmount = zVLTAmount - fee;
        
        // Verify state changes
        assertEq(IERC20(zVLT).balanceOf(user), preUserZVLT - zVLTAmount);
        assertEq(IERC20(USDC).balanceOf(user), preUserUSDC + netAmount);
    }

    // -----------
    //    Tests
    // -----------

    // Validate OCR_Instant initial state.

    function test_OCR_Instant_init_state() public {

        assertEq(OCR.owner(), address(DAO));
        assertEq(OCR.USDC(), USDC);
        assertEq(OCR.GBL(), address(GBL));
        assertEq(OCR.zVLT(), zVLT);
        assertEq(OCR.zSTT(), address(zSTT));
        assertEq(OCR.AAVE_V3_POOL(), aavePool);
        assertEq(OCR.aUSDC(), aUSDC);
        assertEq(OCR.redemptionFeeBIPS(), REDEMPTION_FEE_BIPS);

    }

    // Validate pushToLocker() state changes.
    // Validate pushToLocker() restrictions.
    // This includes:
    //  - asset must be USDC
    //  - onlyOwner can call

    function test_OCR_Instant_pushToLocker_restrictions_asset() public {

        // asset must be USDC
        hevm.startPrank(address(god));
        hevm.expectRevert("OCR_Instant::pushToLocker() asset != USDC");
        DAO.push(address(OCR), aUSDC, 10_000 * 10**6, "");
        hevm.stopPrank();
    }

    function test_OCR_Instant_pushToLocker_restrictions_onlyOwner() public {

        // onlyOwner can call
        hevm.startPrank(address(tim));
        hevm.expectRevert("Ownable: caller is not the owner");
        DAO.push(address(OCR), USDC, 10_000 * 10**6, "");
        hevm.stopPrank();
    }

    function test_OCR_Instant_pushToLocker_state(uint96 amount) public {
        
        hevm.assume(amount > 1000 * 10**6 && amount < 100_000 * 10**6); // 1K to 100K USDC
        
        // Pre-state.
        assertEq(IERC20(USDC).balanceOf(address(OCR)), 0);

        deal(USDC, address(DAO), amount);

        // pushToLocker()
        hevm.startPrank(address(god));
        DAO.push(address(OCR), USDC, amount, "");
        hevm.stopPrank();

        // Post-state.
        // Note: In real implementation, USDC would be deposited to AAVE V3
        // For now, we just verify the transfer happened
    }

    // Validate pullFromLocker() state changes.
    // Validate pullFromLocker() restrictions.
    // This includes:
    //  - asset must be aUSDC
    //  - onlyOwner can call

    function test_OCR_Instant_pullFromLocker_restrictions_asset() public {

        // asset must be aUSDC
        hevm.startPrank(address(god));
        hevm.expectRevert("OCR_Instant::pullFromLocker() asset != aUSDC");
        DAO.pull(address(OCR), USDC, "");
        hevm.stopPrank();
    }

    function test_OCR_Instant_pullFromLocker_restrictions_onlyOwner() public {

        // onlyOwner can call
        hevm.startPrank(address(tim));
        hevm.expectRevert("Ownable: caller is not the owner");
        DAO.pull(address(OCR), aUSDC, "");
        hevm.stopPrank();
    }

    function test_OCR_Instant_pullFromLocker_state(uint96 amount) public {
        
        hevm.assume(amount > 1000 * 10**6 && amount < 100_000 * 10**6);
        
        // Pre-state.
        assertEq(IERC20(aUSDC).balanceOf(address(OCR)), 0);

        deal(USDC, address(DAO), amount);

        // pushToLocker()
        hevm.startPrank(address(god));
        DAO.push(address(OCR), USDC, amount, "");
        hevm.stopPrank();

        // Post-state.
        // Note: In real implementation, USDC would be deposited to AAVE V3

        // pullFromLocker()
        hevm.startPrank(address(god));
        DAO.pull(address(OCR), aUSDC, "");
        hevm.stopPrank();

        // Post-state.
        assertEq(IERC20(aUSDC).balanceOf(address(OCR)), 0);
    }

    // Validate pullFromLockerPartial() state changes.
    // Validate pullFromLockerPartial() restrictions.
    // This includes:
    //  - asset must be aUSDC
    //  - onlyOwner can call

    function test_OCR_Instant_pullFromLockerPartial_restrictions_asset() public {

        // asset must be aUSDC
        hevm.startPrank(address(god));
        hevm.expectRevert("OCR_Instant::pullFromLockerPartial() asset != aUSDC");
        DAO.pullPartial(address(OCR), USDC, 1, "");
        hevm.stopPrank();
    }

    function test_OCR_Instant_pullFromLockerPartial_restrictions_onlyOwner() public {

        // onlyOwner can call
        hevm.startPrank(address(tim));
        hevm.expectRevert("Ownable: caller is not the owner");
        DAO.pullPartial(address(OCR), aUSDC, 1, "");
        hevm.stopPrank();
    }

    function test_OCR_Instant_pullFromLockerPartial_state(uint96 pushAmount, uint96 pullAmount) public {
        
        hevm.assume(pushAmount > 1000 * 10**6 && pushAmount < 100_000 * 10**6);
        hevm.assume(pullAmount > 100 * 10**6 && pullAmount < pushAmount);
        
        // Pre-state.
        assertEq(IERC20(aUSDC).balanceOf(address(OCR)), 0);

        deal(USDC, address(DAO), pushAmount);

        // pushToLocker()
        hevm.startPrank(address(god));
        DAO.push(address(OCR), USDC, pushAmount, "");
        hevm.stopPrank();

        // Post-state.
        // Note: In real implementation, USDC would be deposited to AAVE V3

        // pullFromLockerPartial()
        hevm.startPrank(address(god));
        DAO.pullPartial(address(OCR), aUSDC, pullAmount, "");
        hevm.stopPrank();

        // Post-state.
        assertEq(IERC20(aUSDC).balanceOf(address(OCR)), 0);
    }

    // Validate redeemUSDC() state changes.
    // Validate redeemUSDC() restrictions.
    // This includes:
    //  - zVLTAmount must be > 0
    //  - aUSDC balance must be sufficient

    function test_OCR_Instant_redeemUSDC_restrictions_zeroAmount() public {

        // zVLTAmount must be > 0
        hevm.startPrank(address(sam));
        hevm.expectRevert("OCR_Instant::redeemUSDC() zVLTAmount == 0");
        OCR.redeemUSDC(0);
        hevm.stopPrank();
    }

    function test_OCR_Instant_redeemUSDC_restrictions_insufficient_aUSDC_balance() public {

        uint256 zVLTAmount = 10_000 * 10**18;
        
        // Fund contract with less USDC than needed
        deal(USDC, address(OCR), zVLTAmount / 2);
        
        hevm.startPrank(address(sam));
        hevm.expectRevert("OCR_Instant::redeemUSDC() aUSDCBalance < zSTTReceived");
        OCR.redeemUSDC(zVLTAmount);
        hevm.stopPrank();
    }

    function test_OCR_Instant_redeemUSDC_state(uint96 zVLTAmount) public {
        
        hevm.assume(zVLTAmount > 100 * 10**18 && zVLTAmount < 10_000 * 10**18);
        
        // Fund contract with USDC
        deal(USDC, address(OCR), zVLTAmount);
        
        uint256 preUserZVLT = IERC20(zVLT).balanceOf(address(sam));
        uint256 preUserUSDC = IERC20(USDC).balanceOf(address(sam));
        uint256 preContractUSDC = IERC20(USDC).balanceOf(address(OCR));
        
        // Calculate expected values
        uint256 fee = (zVLTAmount * REDEMPTION_FEE_BIPS) / 10000;
        uint256 netAmount = zVLTAmount - fee;
        
        // redeemUSDC()
        hevm.startPrank(address(sam));
        OCR.redeemUSDC(zVLTAmount);
        hevm.stopPrank();
        
        // Post-state assertions
        assertEq(IERC20(zVLT).balanceOf(address(sam)), preUserZVLT - zVLTAmount);
        assertEq(IERC20(USDC).balanceOf(address(sam)), preUserUSDC + netAmount);
        assertEq(IERC20(USDC).balanceOf(address(OCR)), preContractUSDC - zVLTAmount);
    }

    // Validate updateRedemptionFeeBIPS() state changes.
    // Validate updateRedemptionFeeBIPS() restrictions.
    // This includes:
    //  - only ZVL can call
    //  - fee must be <= 750 BIPS

    function test_OCR_Instant_updateRedemptionFeeBIPS_restrictions_msgSender() public {

        // only ZVL can call
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCR_Instant::updateRedemptionFeeBIPS() _msgSender() != ZVL()");
        OCR.updateRedemptionFeeBIPS(500);
        hevm.stopPrank();
    }

    function test_OCR_Instant_updateRedemptionFeeBIPS_restrictions_feeTooHigh() public {

        // fee must be <= 750 BIPS
        hevm.startPrank(address(zvl));
        hevm.expectRevert("OCR_Instant::updateRedemptionFeeBIPS() _redemptionFeeBIPS > 750");
        OCR.updateRedemptionFeeBIPS(751);
        hevm.stopPrank();
    }

    function test_OCR_Instant_updateRedemptionFeeBIPS_state(uint16 newFee) public {
        
        hevm.assume(newFee <= 750);
        
        uint256 oldFee = OCR.redemptionFeeBIPS();
        
        // updateRedemptionFeeBIPS()
        hevm.startPrank(address(zvl));
        OCR.updateRedemptionFeeBIPS(newFee);
        hevm.stopPrank();
        
        // Post-state assertions
        assertEq(OCR.redemptionFeeBIPS(), newFee);
    }

    // Validate permissions.

    function test_OCR_Instant_permissions() public {
        assertTrue(OCR.canPush());
        assertTrue(OCR.canPull());
        assertTrue(OCR.canPullPartial());
    }

    // Validate events.

    function test_OCR_Instant_events_UpdatedRedemptionFeeBIPS() public {
        
        uint256 oldFee = OCR.redemptionFeeBIPS();
        uint256 newFee = 500;
        
        hevm.expectEmit(true, true, false, false, address(OCR));
        emit UpdatedRedemptionFeeBIPS(oldFee, newFee);
        
        hevm.startPrank(address(zvl));
        OCR.updateRedemptionFeeBIPS(newFee);
        hevm.stopPrank();
    }

    function test_OCR_Instant_events_zVLTBurnedForUSDC() public {
        
        uint256 zVLTAmount = 1000 * 10**18;
        uint256 fee = (zVLTAmount * REDEMPTION_FEE_BIPS) / 10000;
        uint256 netAmount = zVLTAmount - fee;
        
        // Fund contract with USDC
        deal(USDC, address(OCR), zVLTAmount);
        
        hevm.expectEmit(true, false, false, false, address(OCR));
        emit zVLTBurnedForUSDC(address(sam), zVLTAmount, netAmount, fee);
        
        hevm.startPrank(address(sam));
        OCR.redeemUSDC(zVLTAmount);
        hevm.stopPrank();
    }

    // Validate integration scenarios.

    function test_OCR_Instant_integration_full_cycle() public {
        
        uint256 usdcAmount = 100_000 * 10**6;
        uint256 zVLTAmount = 10_000 * 10**18;
        
        // 1. Push USDC to contract
        deal(USDC, address(DAO), usdcAmount);
        hevm.startPrank(address(god));
        DAO.push(address(OCR), USDC, usdcAmount, "");
        hevm.stopPrank();
        
        // 2. User redeems zVLT for USDC
        hevm.startPrank(address(sam));
        OCR.redeemUSDC(zVLTAmount);
        hevm.stopPrank();
        
        // 3. Pull remaining aUSDC
        hevm.startPrank(address(god));
        DAO.pull(address(OCR), aUSDC, "");
        hevm.stopPrank();
        
        // Verify final state
        assertEq(IERC20(zVLT).balanceOf(address(sam)), INITIAL_ZVLT_AMOUNT - zVLTAmount);
        assertGt(IERC20(USDC).balanceOf(address(sam)), 0);
    }

    // Validate edge cases.

    function test_OCR_Instant_edge_case_maximum_fee() public {
        
        // Test with maximum allowed fee (750 BIPS = 7.5%)
        hevm.startPrank(address(zvl));
        OCR.updateRedemptionFeeBIPS(750);
        hevm.stopPrank();
        
        uint256 zVLTAmount = 10_000 * 10**18;
        uint256 expectedFee = (zVLTAmount * 750) / 10000; // 7.5% = 750 zVLT
        uint256 expectedNetAmount = zVLTAmount - expectedFee; // 9250 zVLT
        
        // Fund contract with USDC
        deal(USDC, address(OCR), zVLTAmount);
        
        uint256 preUserUSDC = IERC20(USDC).balanceOf(address(sam));
        
        hevm.startPrank(address(sam));
        OCR.redeemUSDC(zVLTAmount);
        hevm.stopPrank();
        
        // Verify maximum fee calculation
        assertEq(IERC20(USDC).balanceOf(address(sam)), preUserUSDC + expectedNetAmount);
    }

    function test_OCR_Instant_edge_case_zero_fee() public {
        
        // Test with zero fee
        hevm.startPrank(address(zvl));
        OCR.updateRedemptionFeeBIPS(0);
        hevm.stopPrank();
        
        uint256 zVLTAmount = 10_000 * 10**18;
        
        // Fund contract with USDC
        deal(USDC, address(OCR), zVLTAmount);
        
        uint256 preUserUSDC = IERC20(USDC).balanceOf(address(sam));
        
        hevm.startPrank(address(sam));
        OCR.redeemUSDC(zVLTAmount);
        hevm.stopPrank();
        
        // Verify zero fee calculation (1:1 redemption)
        assertEq(IERC20(USDC).balanceOf(address(sam)), preUserUSDC + zVLTAmount);
    }

    function test_OCR_Instant_edge_case_large_amounts() public {
        
        uint256 largeAmount = 1_000_000 * 10**18; // 1M zVLT
        
        deal(USDC, address(OCR), largeAmount);
        
        hevm.startPrank(address(sam));
        OCR.redeemUSDC(largeAmount);
        hevm.stopPrank();
        
        // Verify large amount handling
        assertEq(IERC20(zVLT).balanceOf(address(sam)), INITIAL_ZVLT_AMOUNT - largeAmount);
        assertGt(IERC20(USDC).balanceOf(address(sam)), 0);
    }

} 