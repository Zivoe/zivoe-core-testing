// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../Utility/Utility.sol";

contract Test_ZivoeITO is Utility {

    function setUp() public {
        deployCore(false);
    }

    // ----------------------
    //    Helper Functions
    // ----------------------

    // Note: This helper function ends with time warped to exactly 1 second after ITO starts.
    function depositJunior(address asset, uint256 amount) public {
        
        if (asset == DAI) {
            mint("DAI", address(jim), amount);
        }
        else if (asset == FRAX) {
            mint("FRAX", address(jim), amount);
        }
        else if (asset == USDC) {
            mint("USDC", address(jim), amount);
        }
        else if (asset == USDT) {
            mint("USDT", address(jim), amount);
        }
        else { revert(); }

        hevm.warp(ITO.end() - 30 days + 1 seconds);

        assert(jim.try_approveToken(asset, address(ITO), amount));


        hevm.expectEmit(true, true, false, true, address(ITO));
        emit JuniorDeposit(address(jim), address(asset), amount, GBL.standardize(amount, asset), GBL.standardize(amount, asset));

        assert(jim.try_depositJunior(address(ITO), amount, asset));

    }

    // Note: This helper function ends with time warped to exactly 1 second after ITO starts.
    function depositSenior(address asset, uint256 amount) public {
        
        if (asset == DAI) {
            mint("DAI", address(sam), amount);
        }
        else if (asset == FRAX) {
            mint("FRAX", address(sam), amount);
        }
        else if (asset == USDC) {
            mint("USDC", address(sam), amount);
        }
        else if (asset == USDT) {
            mint("USDT", address(sam), amount);
        }
        else { revert(); }

        hevm.warp(ITO.end() - 30 days + 1 seconds);

        assert(sam.try_approveToken(asset, address(ITO), amount));

        hevm.expectEmit(true, true, false, true, address(ITO));
        emit SeniorDeposit(address(sam), address(asset), amount, GBL.standardize(amount, asset) * 3, GBL.standardize(amount, asset));

        assert(sam.try_depositSenior(address(ITO), amount, asset));

    }

    // Note: This helper function ends with time warped to exactly 1 second after ITO starts.
    function depositBoth(address asset, uint256 amountJunior, uint256 amountSenior) public {
        
        if (asset == DAI) {
            mint("DAI", address(sam), amountJunior + amountSenior);
        }
        else if (asset == FRAX) {
            mint("FRAX", address(sam), amountJunior + amountSenior);
        }
        else if (asset == USDC) {
            mint("USDC", address(sam), amountJunior + amountSenior);
        }
        else if (asset == USDT) {
            mint("USDT", address(sam), amountJunior + amountSenior);
        }
        else { revert(); }

        hevm.warp(ITO.end() - 30 days + 1 seconds);

        assert(sam.try_approveToken(asset, address(ITO), amountJunior + amountSenior));

        assert(sam.try_depositBoth(address(ITO), amountSenior, asset, amountJunior, asset));

    }

    // Note: This helper function ends with time warped to exactly 1 second after ITO starts.
    function depositBoth(address asset, uint256 amount) public {
        
        uint amountTotal = amount * 120 / 100;

        if (asset == DAI) {
            mint("DAI", address(jim), amountTotal);
        }
        else if (asset == FRAX) {
            mint("FRAX", address(jim), amountTotal);
        }
        else if (asset == USDC) {
            mint("USDC", address(jim), amountTotal);
        }
        else if (asset == USDT) {
            mint("USDT", address(jim), amountTotal);
        }
        else { revert(); }

        hevm.warp(ITO.end() - 30 days + 1 seconds);

        assert(jim.try_approveToken(asset, address(ITO), amountTotal));
        assert(jim.try_depositSenior(address(ITO), amount, asset));
        assert(jim.try_depositJunior(address(ITO), amount / 5, asset));

    }

    // ------------
    //    Events
    // ------------

    event JuniorDeposit(address indexed account, address indexed asset, uint256 amount, uint256 credits, uint256 trancheTokens);

    event SeniorDeposit(address indexed account, address indexed asset, uint256 amount, uint256 credits, uint256 trancheTokens);

    event AirdropClaimed(address indexed account, uint256 zSTTClaimed, uint256 zJTTClaimed, uint256 ZVEVested);

    event DepositsMigrated(uint256 DAI, uint256 FRAX, uint256 USDC, uint256 USDT);

    // ----------------
    //    Unit Tests
    // ----------------

    // Validate depositJunior() and depositSenior() restrictions.
    // For both functions, this includes:
    //   - Restricting deposits until the ITO starts.
    //   - Restricting deposits after the ITO ends.
    //   - Restricting deposits if ITO ended prematuraly (at ZVL discretion)
    //   - Restricting deposits of non-whitelisted assets.
    //   - Restricting deposits if account has a vesting schedule.

    function test_ZivoeITO_depositJunior_restrictions_notStarted() public {

        // Mint 100 DAI and 100 WETH for "bob", approve ITO contract.
        mint("DAI", address(bob), 100 ether);
        mint("WETH", address(bob), 100 ether);
        assert(bob.try_approveToken(DAI, address(ITO), 100 ether));
        assert(bob.try_approveToken(WETH, address(ITO), 100 ether));

        // Should throw with: "ZivoeITO::depositJunior() block.timestamp >= end""
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeITO::depositJunior() block.timestamp >= end");
        ITO.depositJunior(100 ether, address(DAI));
        hevm.stopPrank();
    }

    function test_ZivoeITO_depositJunior_restrictions_ended() public {

        zvl.try_commence(address(ITO));

        // Mint 100 DAI and 100 WETH for "bob", approve ITO contract.
        mint("DAI", address(bob), 100 ether);
        mint("WETH", address(bob), 100 ether);
        assert(bob.try_approveToken(DAI, address(ITO), 100 ether));
        assert(bob.try_approveToken(WETH, address(ITO), 100 ether));

        // Warp in time to "end" (post-ITO time).
        hevm.warp(ITO.end());

        // Should throw with: "ZivoeITO::depositJunior() block.timestamp >= end"
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeITO::depositJunior() block.timestamp >= end");
        ITO.depositJunior(100 ether, address(DAI));
        hevm.stopPrank();
    }

    function test_ZivoeITO_depositJunior_restrictions_migrated(uint96 amountIn) public {

        zvl.try_commence(address(ITO));

        uint256 amount_A = uint256(amountIn) + 1;

        hevm.warp(ITO.end() - 30 days + 1 seconds);

        depositSenior(FRAX, amount_A);
        depositSenior(DAI, amount_A);
        depositJunior(FRAX, amount_A / 5);
        depositJunior(DAI, amount_A / 5);
        depositBoth(USDC, amount_A);
        depositBoth(USDT, amount_A);
        
        // Give Bob some tokens
        mint("DAI", address(bob), 100 ether);
        assert(bob.try_approveToken(DAI, address(ITO), 100 ether));

        // zvl decides to end ITO earlier
        hevm.warp(ITO.end() - 1 hours);
        hevm.startPrank(address(zvl));
        ITO.migrateDeposits();
        hevm.stopPrank();

        // Should throw with: "ZivoeITO::depositJunior() migrated"
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeITO::depositJunior() migrated");
        ITO.depositJunior(100 ether, DAI);
        hevm.stopPrank();
        
    }

    function test_ZivoeITO_depositJunior_restrictions_notWhitelisted() public {

        zvl.try_commence(address(ITO));

        // Mint 100 DAI and 100 WETH for "bob", approve ITO contract.
        mint("DAI", address(bob), 100 ether);
        mint("WETH", address(bob), 100 ether);
        assert(bob.try_approveToken(DAI, address(ITO), 100 ether));
        assert(bob.try_approveToken(WETH, address(ITO), 100 ether));

        // Warp in time to middle-point of ITO.
        hevm.warp(ITO.end() - 30 days + 1 seconds);

        // Should throw with: "ZivoeITO::depositJunior() !stablecoinWhitelist[asset]"
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeITO::depositJunior() asset != stables[0-3]");
        ITO.depositJunior(100 ether, address(WETH));
        hevm.stopPrank();
    }

    function test_ZivoeITO_depositJunior_restrictions_vestingSchedule() public {

        zvl.try_commence(address(ITO));

        // Mint 100 DAI for "bob", approve ITO contract.
        mint("DAI", address(bob), 100 ether);
        assert(bob.try_approveToken(DAI, address(ITO), 100 ether));

        // Assign vesting schedule to "bob".
        assert(zvl.try_createVestingSchedule(address(vestZVE), address(bob), 30, 90, 100 ether, false));

        // Should throw with: "ZivoeITO::depositJunior() ~ has vesting schedule ~"
        hevm.startPrank(address(bob));
        hevm.warp(ITO.end() - 30 days + 1 seconds);
        hevm.expectRevert("ZivoeITO::depositJunior() ITO_IZivoeRewardsVesting(vestZVE).vestingScheduleSet(_msgSender())");
        ITO.depositJunior(100 ether, address(DAI));
        hevm.stopPrank();
    }

    function test_ZivoeITO_depositSenior_restrictions_notStarted() public {

        // Mint 100 DAI and 100 WETH for "bob", approve ITO contract.
        mint("DAI", address(bob), 100 ether);
        mint("WETH", address(bob), 100 ether);
        assert(bob.try_approveToken(DAI, address(ITO), 100 ether));
        assert(bob.try_approveToken(WETH, address(ITO), 100 ether));

        // Should throw with: "ZivoeITO::depositSenior() block.timestamp >= end""
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeITO::depositSenior() block.timestamp >= end");
        ITO.depositSenior(100 ether, address(DAI));
        hevm.stopPrank();
    }

    function test_ZivoeITO_depositSenior_restrictions_ended() public {

        zvl.try_commence(address(ITO));
        
        // Mint 100 DAI and 100 WETH for "bob", approve ITO contract.
        mint("DAI", address(bob), 100 ether);
        mint("WETH", address(bob), 100 ether);
        assert(bob.try_approveToken(DAI, address(ITO), 100 ether));
        assert(bob.try_approveToken(WETH, address(ITO), 100 ether));

        // Warp in time to "end" (post-ITO time).
        hevm.warp(ITO.end());

        // Should throw with: "ZivoeITO::depositSenior() block.timestamp >= end"
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeITO::depositSenior() block.timestamp >= end");
        ITO.depositSenior(100 ether, address(DAI));
        hevm.stopPrank();
    }

    function test_ZivoeITO_depositSenior_restrictions_migrated(uint96 amountIn_A) public {

        zvl.try_commence(address(ITO));

        uint256 amount_A = uint256(amountIn_A) + 1;

        hevm.warp(ITO.end() - 30 days + 1 seconds);

        depositSenior(FRAX, amount_A);
        depositSenior(DAI, amount_A);
        depositJunior(FRAX, amount_A / 5);
        depositJunior(DAI, amount_A / 5);
        depositBoth(USDC, amount_A);
        depositBoth(USDT, amount_A);
        
        // Give Bob some tokens
        mint("DAI", address(bob), 100 ether);
        assert(bob.try_approveToken(DAI, address(ITO), 100 ether));

        // zvl decides to end ITO earlier
        hevm.warp(ITO.end() - 1 hours);
        hevm.startPrank(address(zvl));
        ITO.migrateDeposits();
        hevm.stopPrank();

        // Should throw with: "ZivoeITO::depositSenior() migrated"
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeITO::depositSenior() migrated");
        ITO.depositSenior(100 ether, DAI);
        hevm.stopPrank();
        
    }

    function test_ZivoeITO_depositSenior_restrictions_notWhitelisted() public {

        zvl.try_commence(address(ITO));

        // Mint 100 DAI and 100 WETH for "bob", approve ITO contract.
        mint("DAI", address(bob), 100 ether);
        mint("WETH", address(bob), 100 ether);
        assert(bob.try_approveToken(DAI, address(ITO), 100 ether));
        assert(bob.try_approveToken(WETH, address(ITO), 100 ether));

        // Warp in time to middle-point of ITO.
        hevm.warp(ITO.end() - 30 days + 1 seconds);

        // Should throw with: "ZivoeITO::depositSenior() !stablecoinWhitelist[asset]"
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeITO::depositSenior() asset != stables[0-3]");
        ITO.depositSenior(100 ether, address(WETH));
        hevm.stopPrank();
    }

    function test_ZivoeITO_depositSenior_restrictions_vestingSchedule() public {

        zvl.try_commence(address(ITO));

        // Mint 100 DAI for "bob", approve ITO contract.
        mint("DAI", address(bob), 100 ether);
        assert(bob.try_approveToken(DAI, address(ITO), 100 ether));

        // Assign vesting schedule to "bob".
        assert(zvl.try_createVestingSchedule(address(vestZVE), address(bob), 30, 90, 100 ether, false));

        // Should throw with: "ZivoeITO::depositSenior() ~ has vesting schedule ~"
        hevm.startPrank(address(bob));
        hevm.warp(ITO.end() - 30 days + 1 seconds);
        hevm.expectRevert("ZivoeITO::depositSenior() ITO_IZivoeRewardsVesting(vestZVE).vestingScheduleSet(_msgSender())");
        ITO.depositSenior(100 ether, address(DAI));
        hevm.stopPrank();
    }

    // Verify depositBoth() functionality.

    function test_ZivoeITO_depositBoth(uint160 amountIn) public {
        
        hevm.assume(amountIn != 0);

        zvl.try_commence(address(ITO));
        hevm.warp(ITO.end() - 30 days + 1 seconds);

        uint256 amount = uint256(amountIn);

        // Deposit to both
        depositBoth(DAI, amount, amount * 5);

    }

    // Validate depositJunior() state changes.
    // Validate depositSenior() state changes.
    // Note: Test all 4 coins (DAI/FRAX/USDC/USDT) for initial ITO whitelisted assets.

    function test_ZivoeITO_depositJunior_DAI_state(uint160 amountIn) public {
        
        hevm.assume(amountIn != 0);

        zvl.try_commence(address(ITO));
        hevm.warp(ITO.end() - 30 days + 1 seconds);

        uint256 amount = uint256(amountIn);

        // Deposit senior to enable junior deposits (open tranche)
        depositSenior(DAI, amount * 5);
        
        // Pre-state DAI deposit.
        uint256 _pre_JuniorCredits = ITO.juniorCredits(address(jim));
        uint256 _pre_zJTT = zJTT.balanceOf(address(ITO));
        uint256 _pre_DAI = IERC20(DAI).balanceOf(address(ITO));

        // depositJunior()
        depositJunior(DAI, amount);

        // Post-state DAI deposit.
        uint256 _post_JuniorCredits = ITO.juniorCredits(address(jim));
        uint256 _post_zJTT = zJTT.balanceOf(address(ITO));
        uint256 _post_DAI = IERC20(DAI).balanceOf(address(ITO));

        assertEq(_post_JuniorCredits - _pre_JuniorCredits, GBL.standardize(amount, DAI));
        assertEq(_post_zJTT - _pre_zJTT, GBL.standardize(amount, DAI));
        assertEq(_post_DAI - _pre_DAI, amount);

    }

    function test_ZivoeITO_depositJunior_FRAX_state(uint160 amountIn) public {
        
        zvl.try_commence(address(ITO));
        hevm.warp(ITO.end() - 30 days + 1 seconds);

        uint256 amount = uint256(amountIn);

        // Deposit senior to enable junior deposits (open tranche)
        depositSenior(FRAX, amount * 5);

        // Pre-state FRAX deposit.
        uint256 _pre_JuniorCredits = ITO.juniorCredits(address(jim));
        uint256 _pre_zJTT = zJTT.balanceOf(address(ITO));
        uint256 _pre_FRAX = IERC20(FRAX).balanceOf(address(ITO));

        depositJunior(FRAX, amountIn);

        // Post-state FRAX deposit.
        uint256 _post_JuniorCredits = ITO.juniorCredits(address(jim));
        uint256 _post_zJTT = zJTT.balanceOf(address(ITO));
        uint256 _post_FRAX = IERC20(FRAX).balanceOf(address(ITO));

        assertEq(_post_JuniorCredits - _pre_JuniorCredits, GBL.standardize(amount, FRAX));
        assertEq(_post_zJTT - _pre_zJTT, GBL.standardize(amount, FRAX));
        assertEq(_post_FRAX - _pre_FRAX, amount);
    }

    function test_ZivoeITO_depositJunior_USDC_state(uint160 amountIn) public {
        
        zvl.try_commence(address(ITO));
        hevm.warp(ITO.end() - 30 days + 1 seconds);

        uint256 amount = uint256(amountIn);

        // Deposit senior to enable junior deposits (open tranche)
        depositSenior(USDC, amount * 5);

        // Pre-state USDC deposit.
        uint256 _pre_JuniorCredits = ITO.juniorCredits(address(jim));
        uint256 _pre_zJTT = zJTT.balanceOf(address(ITO));
        uint256 _pre_USDC = IERC20(USDC).balanceOf(address(ITO));

        depositJunior(USDC, amountIn);

        // Post-state USDC deposit.
        uint256 _post_JuniorCredits = ITO.juniorCredits(address(jim));
        uint256 _post_zJTT = zJTT.balanceOf(address(ITO));
        uint256 _post_USDC = IERC20(USDC).balanceOf(address(ITO));

        assertEq(_post_JuniorCredits - _pre_JuniorCredits, GBL.standardize(amount, USDC));
        assertEq(_post_zJTT - _pre_zJTT, GBL.standardize(amount, USDC));
        assertEq(_post_USDC - _pre_USDC, amount);
    }

    function test_ZivoeITO_depositJunior_USDT_state(uint160 amountIn) public {
        
        zvl.try_commence(address(ITO));
        hevm.warp(ITO.end() - 30 days + 1 seconds);

        uint256 amount = uint256(amountIn);

        // Deposit senior to enable junior deposits (open tranche)
        depositSenior(USDT, amount * 5);

        // Pre-state USDT deposit.
        uint256 _pre_JuniorCredits = ITO.juniorCredits(address(jim));
        uint256 _pre_zJTT = zJTT.balanceOf(address(ITO));
        uint256 _pre_USDT = IERC20(USDT).balanceOf(address(ITO));

        depositJunior(USDT, amount);

        // Post-state USDT deposit.
        uint256 _post_JuniorCredits = ITO.juniorCredits(address(jim));
        uint256 _post_zJTT = zJTT.balanceOf(address(ITO));
        uint256 _post_USDT = IERC20(USDT).balanceOf(address(ITO));

        assertEq(_post_JuniorCredits - _pre_JuniorCredits, GBL.standardize(amount, USDT));
        assertEq(_post_zJTT - _pre_zJTT, GBL.standardize(amount, USDT));
        assertEq(_post_USDT - _pre_USDT, amount);
    }

    function test_ZivoeITO_depositSenior_DAI_state(uint160 amountIn) public {
        
        zvl.try_commence(address(ITO));
        hevm.warp(ITO.end() - 30 days + 1 seconds);

        uint256 amount = uint256(amountIn);

        // Pre-state DAI deposit.
        uint256 _pre_SeniorCredits = ITO.seniorCredits(address(sam));
        uint256 _pre_zSTT = zSTT.balanceOf(address(ITO));
        uint256 _pre_DAI = IERC20(DAI).balanceOf(address(ITO));

        depositSenior(DAI, amount);

        // Post-state DAI deposit.
        uint256 _post_SeniorCredits = ITO.seniorCredits(address(sam));
        uint256 _post_zSTT = zSTT.balanceOf(address(ITO));
        uint256 _post_DAI = IERC20(DAI).balanceOf(address(ITO));

        assertEq(_post_SeniorCredits - _pre_SeniorCredits, GBL.standardize(amount, DAI) * 3);
        assertEq(_post_zSTT - _pre_zSTT, GBL.standardize(amount, DAI));
        assertEq(_post_DAI - _pre_DAI, amount);

    }

    function test_ZivoeITO_depositSenior_FRAX_state(uint160 amountIn) public {
        
        zvl.try_commence(address(ITO));
        hevm.warp(ITO.end() - 30 days + 1 seconds);

        uint256 amount = uint256(amountIn);

        // Pre-state FRAX deposit.
        uint256 _pre_SeniorCredits = ITO.seniorCredits(address(sam));
        uint256 _pre_zSTT = zSTT.balanceOf(address(ITO));
        uint256 _pre_FRAX = IERC20(FRAX).balanceOf(address(ITO));

        depositSenior(FRAX, amount);

        // Post-state FRAX deposit.
        uint256 _post_SeniorCredits = ITO.seniorCredits(address(sam));
        uint256 _post_zSTT = zSTT.balanceOf(address(ITO));
        uint256 _post_FRAX = IERC20(FRAX).balanceOf(address(ITO));

        assertEq(_post_SeniorCredits - _pre_SeniorCredits, GBL.standardize(amount, FRAX) * 3);
        assertEq(_post_zSTT - _pre_zSTT, GBL.standardize(amount, FRAX));
        assertEq(_post_FRAX - _pre_FRAX, amount);

    }

    function test_ZivoeITO_depositSenior_USDC_state(uint160 amountIn) public {
        
        zvl.try_commence(address(ITO));
        hevm.warp(ITO.end() - 30 days + 1 seconds);

        uint256 amount = uint256(amountIn);

        // Pre-state USDC deposit.
        uint256 _pre_SeniorCredits = ITO.seniorCredits(address(sam));
        uint256 _pre_zSTT = zSTT.balanceOf(address(ITO));
        uint256 _pre_USDC = IERC20(USDC).balanceOf(address(ITO));

        depositSenior(USDC, amount);

        // Post-state USDC deposit.
        uint256 _post_SeniorCredits = ITO.seniorCredits(address(sam));
        uint256 _post_zSTT = zSTT.balanceOf(address(ITO));
        uint256 _post_USDC = IERC20(USDC).balanceOf(address(ITO));

        assertEq(_post_SeniorCredits - _pre_SeniorCredits, GBL.standardize(amount, USDC) * 3);
        assertEq(_post_zSTT - _pre_zSTT, GBL.standardize(amount, USDC));
        assertEq(_post_USDC - _pre_USDC, amount);

    }

    function test_ZivoeITO_depositSenior_USDT_state(uint160 amountIn) public {
        
        zvl.try_commence(address(ITO));
        hevm.warp(ITO.end() - 30 days + 1 seconds);

        uint256 amount = uint256(amountIn);

        // Pre-state USDT deposit.
        uint256 _pre_SeniorCredits = ITO.seniorCredits(address(sam));
        uint256 _pre_zSTT = zSTT.balanceOf(address(ITO));
        uint256 _pre_USDT = IERC20(USDT).balanceOf(address(ITO));

        depositSenior(USDT, amount);

        // Post-state USDT deposit.
        uint256 _post_SeniorCredits = ITO.seniorCredits(address(sam));
        uint256 _post_zSTT = zSTT.balanceOf(address(ITO));
        uint256 _post_USDT = IERC20(USDT).balanceOf(address(ITO));

        assertEq(_post_SeniorCredits - _pre_SeniorCredits, GBL.standardize(amount, USDT) * 3);
        assertEq(_post_zSTT - _pre_zSTT, GBL.standardize(amount, USDT));
        assertEq(_post_USDT - _pre_USDT, amount);

    }


    // Validate claimAirdrop() restrictions.
    // This includes:
    //   - Restricting claim until after the ITO concludes (block.timestamp > end).
    //   - Restricting claim if person has already claimed (a one-time only action).
    //   - Restricting claim if (seniorCredits || juniorCredits) == 0.
 
    function test_ZivoeITO_claimAirdrop_restrictions_notEnded() public {

        // Warp to the end unix.
        zvl.try_commence(address(ITO));
        hevm.warp(ITO.end());

        // Can't call claim() until block.timestamp > end.
        hevm.startPrank(address(sam));
        hevm.expectRevert("ZivoeITO::claimAirdrop() block.timestamp <= end && !migrated");
        ITO.claimAirdrop(address(sam));
        hevm.stopPrank();
    }

    // Note: uint96 works, uint160 throws overflow/underflow error.
    function test_ZivoeITO_claimAirdrop_restrictions_claimAirdropTwice(uint96 amountIn) public {
        
        uint256 amount = uint256(amountIn) + 1;

        // Warp to the end unix.
        zvl.try_commence(address(ITO));
        hevm.warp(ITO.end());

        // "sam" will depositSenior() ...
        // "jim" will depositJunior() ...
        depositSenior(FRAX, amount);
        depositJunior(FRAX, amount / 5);

        // Warp to end.
        hevm.warp(ITO.end() + 1);

        // "sam" will claimAirdrop once (successful) but cannot claimAirdrop again.
        assert(sam.try_claimAirdrop(address(ITO), address(sam)));
        hevm.startPrank(address(sam));
        hevm.expectRevert("ZivoeITO::claimAirdrop() airdropClaimed[depositor]");
        ITO.claimAirdrop(address(sam));
        hevm.stopPrank();
    }

    function test_ZivoeITO_claimAirdrop_restrictions_zeroCredits() public {

        // Warp to end.
        zvl.try_commence(address(ITO));
        hevm.warp(ITO.end() + 1);

        // Can't call claimAirdrop() if seniorCredits == 0 && juniorCredits == 0.
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeITO::claimAirdrop() seniorCredits[depositor] == 0 && juniorCredits[depositor] == 0");
        ITO.claimAirdrop(address(bob));
        hevm.stopPrank();
    }

    // Validate claimAirdrop() state changes, single account depositing into ITO (a single tranche), a.k.a. "_single_senior".
    // Validate claimAirdrop() state changes, single account depositing into ITO (both tranches), a.k.a. "_both".

    function test_ZivoeITO_claimAirdrop_state_single_senior_DAI(uint96 amountIn_senior) public {

        uint256 amount_senior = uint256(amountIn_senior) + 1;

        zvl.try_commence(address(ITO));
        hevm.warp(ITO.end() - 30 days + 1 seconds);

        depositSenior(DAI, amount_senior);

        // Warp to end of ITO.
        hevm.warp(ITO.end() + 1 seconds);

        // Pre-state claimAirdrop (senior).
        uint256 _pre_SeniorCredits = ITO.seniorCredits(address(sam));
        uint256 _pre_zSTT_ITO = zSTT.balanceOf(address(ITO));
        assert(!ITO.airdropClaimed(address(sam)));
        
        (uint256 _zSTT_Claimed_SAM,, uint256 _ZVE_Vested_SAM) = sam.claimAirdrop(address(ITO), address(sam));

        // Post-state claimAirdrop (senior).
        uint256 _post_SeniorCredits = ITO.seniorCredits(address(sam));

        // Note: * 3 for the 3x Multiplier on credits for depositing into SeniorTranche
        assertEq(_pre_SeniorCredits - _post_SeniorCredits, amount_senior * 3);
        assertEq(ITO.seniorCredits(address(sam)), 0);
        assertEq(ITO.juniorCredits(address(sam)), 0);
        assert(ITO.airdropClaimed(address(sam)));
        
        uint256 _post_zSTT_ITO = zSTT.balanceOf(address(ITO));
        assertEq(_pre_zSTT_ITO - _post_zSTT_ITO, amount_senior);
        assertEq(_pre_zSTT_ITO - _post_zSTT_ITO, _zSTT_Claimed_SAM);

        (
            uint256 start, 
            uint256 cliff, 
            uint256 end, 
            uint256 totalVesting, 
            , 
            ,
            bool revokable
        ) = vestZVE.viewSchedule(address(sam));

        assertEq(start, block.timestamp);
        assertEq(cliff, block.timestamp);
        assertEq(end, block.timestamp + 360 days);
        assertEq(totalVesting, _ZVE_Vested_SAM);
        assert(!revokable);
    }

    function test_ZivoeITO_claimAirdrop_state_single_senior_FRAX(uint96 amountIn_senior) public {

        uint256 amount_senior = uint256(amountIn_senior) + 1;

        zvl.try_commence(address(ITO));
        hevm.warp(ITO.end() - 30 days + 1 seconds);

        depositSenior(FRAX, amount_senior);

        // Warp to end of ITO.
        hevm.warp(ITO.end() + 1 seconds);

        // Pre-state claimAirdrop (senior).
        uint256 _pre_SeniorCredits = ITO.seniorCredits(address(sam));
        uint256 _pre_zSTT_ITO = zSTT.balanceOf(address(ITO));
        assert(!ITO.airdropClaimed(address(sam)));
        
        (uint256 _zSTT_Claimed_SAM,, uint256 _ZVE_Vested_SAM) = sam.claimAirdrop(address(ITO), address(sam));

        // Post-state claimAirdrop (senior).
        uint256 _post_SeniorCredits = ITO.seniorCredits(address(sam));

        // Note: * 3 for the 3x Multiplier on credits for depositing into SeniorTranche
        assertEq(_pre_SeniorCredits - _post_SeniorCredits, amount_senior * 3);
        assertEq(ITO.seniorCredits(address(sam)), 0);
        assertEq(ITO.juniorCredits(address(sam)), 0);
        assert(ITO.airdropClaimed(address(sam)));
        
        uint256 _post_zSTT_ITO = zSTT.balanceOf(address(ITO));
        assertEq(_pre_zSTT_ITO - _post_zSTT_ITO, amount_senior);
        assertEq(_pre_zSTT_ITO - _post_zSTT_ITO, _zSTT_Claimed_SAM);

        (
            uint256 start, 
            uint256 cliff, 
            uint256 end, 
            uint256 totalVesting, 
            , 
            ,
            bool revokable
        ) = vestZVE.viewSchedule(address(sam));

        assertEq(start, block.timestamp);
        assertEq(cliff, block.timestamp);
        assertEq(end, block.timestamp + 360 days);
        assertEq(totalVesting, _ZVE_Vested_SAM);
        assert(!revokable);
    }

    function test_ZivoeITO_claimAirdrop_state_single_senior_USDC(uint96 amountIn_senior) public {

        uint256 amount_senior = uint256(amountIn_senior) + 1;

        zvl.try_commence(address(ITO));
        hevm.warp(ITO.end() - 30 days + 1 seconds);

        depositSenior(USDC, amount_senior);

        // Warp to end of ITO.
        hevm.warp(ITO.end() + 1 seconds);

        // Pre-state claimAirdrop (senior).
        uint256 _pre_SeniorCredits = ITO.seniorCredits(address(sam));
        uint256 _pre_zSTT_ITO = zSTT.balanceOf(address(ITO));
        assert(!ITO.airdropClaimed(address(sam)));
        
        (uint256 _zSTT_Claimed_SAM,, uint256 _ZVE_Vested_SAM) = sam.claimAirdrop(address(ITO), address(sam));

        // Post-state claimAirdrop (senior).
        uint256 _post_SeniorCredits = ITO.seniorCredits(address(sam));

        // Note: * 3 for the 3x Multiplier on credits for depositing into SeniorTranche
        assertEq(_pre_SeniorCredits - _post_SeniorCredits, GBL.standardize(amount_senior, USDC) * 3);
        assertEq(ITO.seniorCredits(address(sam)), 0);
        assertEq(ITO.juniorCredits(address(sam)), 0);
        assert(ITO.airdropClaimed(address(sam)));
        
        uint256 _post_zSTT_ITO = zSTT.balanceOf(address(ITO));
        assertEq(_pre_zSTT_ITO - _post_zSTT_ITO, GBL.standardize(amount_senior, USDC));
        assertEq(_pre_zSTT_ITO - _post_zSTT_ITO, _zSTT_Claimed_SAM);

        (
            uint256 start, 
            uint256 cliff, 
            uint256 end, 
            uint256 totalVesting, 
            , 
            ,
            bool revokable
        ) = vestZVE.viewSchedule(address(sam));

        assertEq(start, block.timestamp);
        assertEq(cliff, block.timestamp);
        assertEq(end, block.timestamp + 360 days);
        assertEq(totalVesting, _ZVE_Vested_SAM);
        assert(!revokable);
    }

    function test_ZivoeITO_claimAirdrop_state_single_senior_USDT(uint96 amountIn_senior) public {

        uint256 amount_senior = uint256(amountIn_senior) + 1;

        zvl.try_commence(address(ITO));
        hevm.warp(ITO.end() - 30 days + 1 seconds);

        depositSenior(USDT, amount_senior);

        // Warp to end of ITO.
        hevm.warp(ITO.end() + 1 seconds);

        // Pre-state claimAirdrop (senior).
        uint256 _pre_SeniorCredits = ITO.seniorCredits(address(sam));
        uint256 _pre_zSTT_ITO = zSTT.balanceOf(address(ITO));
        assert(!ITO.airdropClaimed(address(sam)));
        
        (uint256 _zSTT_Claimed_SAM,, uint256 _ZVE_Vested_SAM) = sam.claimAirdrop(address(ITO), address(sam));

        // Post-state claimAirdrop (senior).
        uint256 _post_SeniorCredits = ITO.seniorCredits(address(sam));

        // Note: * 3 for the 3x Multiplier on credits for depositing into SeniorTranche
        assertEq(_pre_SeniorCredits - _post_SeniorCredits, GBL.standardize(amount_senior, USDT) * 3);
        assertEq(ITO.seniorCredits(address(sam)), 0);
        assertEq(ITO.juniorCredits(address(sam)), 0);
        assert(ITO.airdropClaimed(address(sam)));
        
        uint256 _post_zSTT_ITO = zSTT.balanceOf(address(ITO));
        assertEq(_pre_zSTT_ITO - _post_zSTT_ITO, GBL.standardize(amount_senior, USDT));
        assertEq(_pre_zSTT_ITO - _post_zSTT_ITO, _zSTT_Claimed_SAM);

        (
            uint256 start, 
            uint256 cliff, 
            uint256 end, 
            uint256 totalVesting, 
            , 
            ,
            bool revokable
        ) = vestZVE.viewSchedule(address(sam));

        assertEq(start, block.timestamp);
        assertEq(cliff, block.timestamp);
        assertEq(end, block.timestamp + 360 days);
        assertEq(totalVesting, _ZVE_Vested_SAM);
        assert(!revokable);
    }

    function test_ZivoeITO_claimAirdrop_state_single_junior_DAI(uint96 amountIn_junior) public {

        uint256 amount_junior = uint256(amountIn_junior) + 1;

        zvl.try_commence(address(ITO));
        hevm.warp(ITO.end() - 30 days + 1 seconds);

        depositSenior(DAI, amount_junior * 5);
        depositJunior(DAI, amount_junior);

        // Warp to end of ITO.
        hevm.warp(ITO.end() + 1 seconds);

        // Pre-state claimAirdrop (junior).
        uint256 _pre_JuniorCredits = ITO.juniorCredits(address(jim));
        uint256 _pre_zJTT_ITO = zJTT.balanceOf(address(ITO));
        assert(!ITO.airdropClaimed(address(jim)));
        
        uint256 upper = _pre_JuniorCredits;
        uint256 middle = ZVE.totalSupply() / 20;
        uint256 lower = zSTT.totalSupply() * 3 + zJTT.totalSupply();

        hevm.expectEmit(true, false, false, false, address(ITO));
        emit AirdropClaimed(
            address(jim), 0, _pre_JuniorCredits, upper * middle / lower
        );
        (, uint256 _zJTT_Claimed_JIM, uint256 _ZVE_Vested_JIM) = jim.claimAirdrop(address(ITO), address(jim));

        // Post-state claimAirdrop (junior).
        uint256 _post_JuniorCredits = ITO.juniorCredits(address(jim));
        assertEq(_pre_JuniorCredits - _post_JuniorCredits, amount_junior);
        assertEq(ITO.seniorCredits(address(jim)), 0);
        assertEq(ITO.juniorCredits(address(jim)), 0);
        assert(ITO.airdropClaimed(address(jim)));

        uint256 _post_zJTT_ITO = zJTT.balanceOf(address(ITO));
        assertEq(_pre_zJTT_ITO - _post_zJTT_ITO, amount_junior);
        assertEq(_pre_zJTT_ITO - _post_zJTT_ITO, _zJTT_Claimed_JIM);

        (
            uint256 start, 
            uint256 cliff, 
            uint256 end, 
            uint256 totalVesting, 
            , 
            ,
            bool revokable
        ) = vestZVE.viewSchedule(address(jim));

        assertEq(start, block.timestamp);
        assertEq(cliff, block.timestamp);
        assertEq(end, block.timestamp + 360 days);
        assertEq(totalVesting, _ZVE_Vested_JIM);
        assert(!revokable);
    }

    function test_ZivoeITO_claimAirdrop_state_single_junior_FRAX(uint96 amountIn_junior) public {

        uint256 amount_junior = uint256(amountIn_junior) + 1;

        zvl.try_commence(address(ITO));
        hevm.warp(ITO.end() - 30 days + 1 seconds);

        depositSenior(FRAX, amount_junior * 5);
        depositJunior(FRAX, amount_junior);

        // Warp to end of ITO.
        hevm.warp(ITO.end() + 1 seconds);

        // Pre-state claimAirdrop (junior).
        uint256 _pre_JuniorCredits = ITO.juniorCredits(address(jim));
        uint256 _pre_zJTT_ITO = zJTT.balanceOf(address(ITO));
        assert(!ITO.airdropClaimed(address(jim)));
        
        (, uint256 _zJTT_Claimed_JIM, uint256 _ZVE_Vested_JIM) = jim.claimAirdrop(address(ITO), address(jim));

        // Post-state claimAirdrop (junior).
        uint256 _post_JuniorCredits = ITO.juniorCredits(address(jim));
        assertEq(_pre_JuniorCredits - _post_JuniorCredits, amount_junior);
        assertEq(ITO.seniorCredits(address(jim)), 0);
        assertEq(ITO.juniorCredits(address(jim)), 0);
        assert(ITO.airdropClaimed(address(jim)));

        uint256 _post_zJTT_ITO = zJTT.balanceOf(address(ITO));
        assertEq(_pre_zJTT_ITO - _post_zJTT_ITO, amount_junior);
        assertEq(_pre_zJTT_ITO - _post_zJTT_ITO, _zJTT_Claimed_JIM);

        (
            uint256 start, 
            uint256 cliff, 
            uint256 end, 
            uint256 totalVesting, 
            , 
            ,
            bool revokable
        ) = vestZVE.viewSchedule(address(jim));

        assertEq(start, block.timestamp);
        assertEq(cliff, block.timestamp);
        assertEq(end, block.timestamp + 360 days);
        assertEq(totalVesting, _ZVE_Vested_JIM);
        assert(!revokable);
    }

    function test_ZivoeITO_claimAirdrop_state_single_junior_USDC(uint96 amountIn_junior) public {

        uint256 amount_junior = uint256(amountIn_junior) + 1;

        zvl.try_commence(address(ITO));
        hevm.warp(ITO.end() - 30 days + 1 seconds);

        depositSenior(USDC, amount_junior * 5);
        depositJunior(USDC, amount_junior);

        // Warp to end of ITO.
        hevm.warp(ITO.end() + 1 seconds);

        // Pre-state claimAirdrop (junior).
        uint256 _pre_JuniorCredits = ITO.juniorCredits(address(jim));
        uint256 _pre_zJTT_ITO = zJTT.balanceOf(address(ITO));
        assert(!ITO.airdropClaimed(address(jim)));
        
        (, uint256 _zJTT_Claimed_JIM, uint256 _ZVE_Vested_JIM) = jim.claimAirdrop(address(ITO), address(jim));

        // Post-state claimAirdrop (junior).
        uint256 _post_JuniorCredits = ITO.juniorCredits(address(jim));
        assertEq(_pre_JuniorCredits - _post_JuniorCredits, GBL.standardize(amount_junior, USDC));
        assertEq(ITO.seniorCredits(address(jim)), 0);
        assertEq(ITO.juniorCredits(address(jim)), 0);
        assert(ITO.airdropClaimed(address(jim)));

        uint256 _post_zJTT_ITO = zJTT.balanceOf(address(ITO));
        assertEq(_pre_zJTT_ITO - _post_zJTT_ITO, GBL.standardize(amount_junior, USDC));
        assertEq(_pre_zJTT_ITO - _post_zJTT_ITO, _zJTT_Claimed_JIM);

        (
            uint256 start, 
            uint256 cliff, 
            uint256 end, 
            uint256 totalVesting, 
            , 
            ,
            bool revokable
        ) = vestZVE.viewSchedule(address(jim));

        assertEq(start, block.timestamp);
        assertEq(cliff, block.timestamp);
        assertEq(end, block.timestamp + 360 days);
        assertEq(totalVesting, _ZVE_Vested_JIM);
        assert(!revokable);
    }

    function test_ZivoeITO_claimAirdrop_state_single_junior_USDT(uint96 amountIn_junior) public {

        uint256 amount_junior = uint256(amountIn_junior) + 1;

        zvl.try_commence(address(ITO));
        hevm.warp(ITO.end() - 30 days + 1 seconds);

        depositSenior(USDT, amount_junior * 5);
        depositJunior(USDT, amount_junior);

        // Warp to end of ITO.
        hevm.warp(ITO.end() + 1 seconds);

        // Pre-state claimAirdrop (junior).
        uint256 _pre_JuniorCredits = ITO.juniorCredits(address(jim));
        uint256 _pre_zJTT_ITO = zJTT.balanceOf(address(ITO));
        assert(!ITO.airdropClaimed(address(jim)));
        
        (, uint256 _zJTT_Claimed_JIM, uint256 _ZVE_Vested_JIM) = jim.claimAirdrop(address(ITO), address(jim));

        // Post-state claimAirdrop (junior).
        uint256 _post_JuniorCredits = ITO.juniorCredits(address(jim));
        assertEq(_pre_JuniorCredits - _post_JuniorCredits, GBL.standardize(amount_junior, USDT));
        assertEq(ITO.seniorCredits(address(jim)), 0);
        assertEq(ITO.juniorCredits(address(jim)), 0);
        assert(ITO.airdropClaimed(address(jim)));

        uint256 _post_zJTT_ITO = zJTT.balanceOf(address(ITO));
        assertEq(_pre_zJTT_ITO - _post_zJTT_ITO, GBL.standardize(amount_junior, USDT));
        assertEq(_pre_zJTT_ITO - _post_zJTT_ITO, _zJTT_Claimed_JIM);

        (
            uint256 start, 
            uint256 cliff, 
            uint256 end, 
            uint256 totalVesting, 
            , 
            ,
            bool revokable
        ) = vestZVE.viewSchedule(address(jim));

        assertEq(start, block.timestamp);
        assertEq(cliff, block.timestamp);
        assertEq(end, block.timestamp + 360 days);
        assertEq(totalVesting, _ZVE_Vested_JIM);
        assert(!revokable);
    }

    function test_ZivoeITO_claimAirdrop_state_both_DAI(uint96 amountIn) public {

        uint256 amount = uint256(amountIn) + 1;

        zvl.try_commence(address(ITO));
        hevm.warp(ITO.end() - 30 days + 1 seconds);

        depositBoth(DAI, amount);

        // Warp to end of ITO.
        hevm.warp(ITO.end() + 1 seconds);

        // Pre-state claimAirdrop (junior + senior).
        uint256 _pre_JuniorCredits = ITO.juniorCredits(address(jim));
        uint256 _pre_SeniorCredits = ITO.seniorCredits(address(jim));
        uint256 _pre_zJTT_ITO = zJTT.balanceOf(address(ITO));
        uint256 _pre_zSTT_ITO = zSTT.balanceOf(address(ITO));
        assert(!ITO.airdropClaimed(address(jim)));
        
        uint256 upper = _pre_JuniorCredits + _pre_SeniorCredits;
        uint256 middle = ZVE.totalSupply() / 20;
        uint256 lower = zSTT.totalSupply() * 3 + zJTT.totalSupply();

        hevm.expectEmit(true, false, false, false, address(ITO));
        emit AirdropClaimed(
            address(jim), _pre_SeniorCredits / 3, _pre_JuniorCredits, upper * middle / lower
        );
        (uint256 _zSTT_Claimed_JIM, uint256 _zJTT_Claimed_JIM, uint256 _ZVE_Vested_JIM) = jim.claimAirdrop(address(ITO), address(jim));

        // Post-state claimAirdrop (junior + senior).

        {
            uint256 _post_JuniorCredits = ITO.juniorCredits(address(jim));
            assertEq(_pre_JuniorCredits - _post_JuniorCredits, amount / 5);
            assertEq(ITO.seniorCredits(address(jim)), 0);
            assertEq(ITO.juniorCredits(address(jim)), 0);
            assert(ITO.airdropClaimed(address(jim)));
        }

        {
            uint256 _post_SeniorCredits = ITO.seniorCredits(address(jim));
            assertEq(_pre_SeniorCredits - _post_SeniorCredits, amount * 3);  
        }

        {
            uint256 _post_zJTT_ITO = zJTT.balanceOf(address(ITO));
            assertEq(_pre_zJTT_ITO - _post_zJTT_ITO, amount / 5);
            assertEq(_pre_zJTT_ITO - _post_zJTT_ITO, _zJTT_Claimed_JIM);
        }

        {
            uint256 _post_zSTT_ITO = zSTT.balanceOf(address(ITO));
            assertEq(_pre_zSTT_ITO - _post_zSTT_ITO, amount);
            assertEq(_pre_zSTT_ITO - _post_zSTT_ITO, _zSTT_Claimed_JIM);
        }

        (
            uint256 start, 
            uint256 cliff, 
            uint256 end, 
            uint256 totalVesting, 
            , 
            ,
            bool revokable
        ) = vestZVE.viewSchedule(address(jim));

        assertEq(start, block.timestamp);
        assertEq(cliff, block.timestamp);
        assertEq(end, block.timestamp + 360 days);
        assertEq(totalVesting, _ZVE_Vested_JIM);
        assert(!revokable);
    }

    function test_ZivoeITO_claimAirdrop_state_both_FRAX(uint96 amountIn) public {

        uint256 amount = uint256(amountIn) + 1;

        zvl.try_commence(address(ITO));
        hevm.warp(ITO.end() - 30 days + 1 seconds);

        depositBoth(FRAX, amount);

        // Warp to end of ITO.
        hevm.warp(ITO.end() + 1 seconds);

        // Pre-state claimAirdrop (junior + senior).
        uint256 _pre_JuniorCredits = ITO.juniorCredits(address(jim));
        uint256 _pre_SeniorCredits = ITO.seniorCredits(address(jim));
        uint256 _pre_zJTT_ITO = zJTT.balanceOf(address(ITO));
        uint256 _pre_zSTT_ITO = zSTT.balanceOf(address(ITO));
        assert(!ITO.airdropClaimed(address(jim)));
        
        (uint256 _zSTT_Claimed_JIM, uint256 _zJTT_Claimed_JIM, uint256 _ZVE_Vested_JIM) = jim.claimAirdrop(address(ITO), address(jim));

        // Post-state claimAirdrop (junior + senior).

        {
            uint256 _post_JuniorCredits = ITO.juniorCredits(address(jim));
            assertEq(_pre_JuniorCredits - _post_JuniorCredits, amount / 5);
            assertEq(ITO.seniorCredits(address(jim)), 0);
            assertEq(ITO.juniorCredits(address(jim)), 0);
            assert(ITO.airdropClaimed(address(jim)));
        }

        {
            uint256 _post_SeniorCredits = ITO.seniorCredits(address(jim));
            assertEq(_pre_SeniorCredits - _post_SeniorCredits, amount * 3);  
        }

        {
            uint256 _post_zJTT_ITO = zJTT.balanceOf(address(ITO));
            assertEq(_pre_zJTT_ITO - _post_zJTT_ITO, amount / 5);
            assertEq(_pre_zJTT_ITO - _post_zJTT_ITO, _zJTT_Claimed_JIM);
        }

        {
            uint256 _post_zSTT_ITO = zSTT.balanceOf(address(ITO));
            assertEq(_pre_zSTT_ITO - _post_zSTT_ITO, amount);
            assertEq(_pre_zSTT_ITO - _post_zSTT_ITO, _zSTT_Claimed_JIM);
        }

        (
            uint256 start, 
            uint256 cliff, 
            uint256 end, 
            uint256 totalVesting, 
            , 
            ,
            bool revokable
        ) = vestZVE.viewSchedule(address(jim));

        assertEq(start, block.timestamp);
        assertEq(cliff, block.timestamp);
        assertEq(end, block.timestamp + 360 days);
        assertEq(totalVesting, _ZVE_Vested_JIM);
        assert(!revokable);
    }

    function test_ZivoeITO_claimAirdrop_state_both_USDC(uint96 amountIn) public {

        uint256 amount = uint256(amountIn) + 1;

        zvl.try_commence(address(ITO));
        hevm.warp(ITO.end() - 30 days + 1 seconds);

        depositBoth(USDC, amount);

        // Warp to end of ITO.
        hevm.warp(ITO.end() + 1 seconds);

        // Pre-state claimAirdrop (junior + senior).
        uint256 _pre_JuniorCredits = ITO.juniorCredits(address(jim));
        uint256 _pre_SeniorCredits = ITO.seniorCredits(address(jim));
        uint256 _pre_zJTT_ITO = zJTT.balanceOf(address(ITO));
        uint256 _pre_zSTT_ITO = zSTT.balanceOf(address(ITO));
        assert(!ITO.airdropClaimed(address(jim)));
        
        (uint256 _zSTT_Claimed_JIM, uint256 _zJTT_Claimed_JIM, uint256 _ZVE_Vested_JIM) = jim.claimAirdrop(address(ITO), address(jim));

        // Post-state claimAirdrop (junior + senior).

        {
            uint256 _post_JuniorCredits = ITO.juniorCredits(address(jim));
            assertEq(_pre_JuniorCredits - _post_JuniorCredits, GBL.standardize(amount / 5, USDC));
            assertEq(ITO.seniorCredits(address(jim)), 0);
            assertEq(ITO.juniorCredits(address(jim)), 0);
            assert(ITO.airdropClaimed(address(jim)));
        }

        {
            uint256 _post_SeniorCredits = ITO.seniorCredits(address(jim));
            assertEq(_pre_SeniorCredits - _post_SeniorCredits, GBL.standardize(amount, USDC) * 3);  
        }

        {
            uint256 _post_zJTT_ITO = zJTT.balanceOf(address(ITO));
            assertEq(_pre_zJTT_ITO - _post_zJTT_ITO, GBL.standardize(amount / 5, USDC));
            assertEq(_pre_zJTT_ITO - _post_zJTT_ITO, _zJTT_Claimed_JIM);
        }

        {
            uint256 _post_zSTT_ITO = zSTT.balanceOf(address(ITO));
            assertEq(_pre_zSTT_ITO - _post_zSTT_ITO, GBL.standardize(amount, USDC));
            assertEq(_pre_zSTT_ITO - _post_zSTT_ITO, _zSTT_Claimed_JIM);
        }

        (
            uint256 start, 
            uint256 cliff, 
            uint256 end, 
            uint256 totalVesting, 
            , 
            ,
            bool revokable
        ) = vestZVE.viewSchedule(address(jim));

        assertEq(start, block.timestamp);
        assertEq(cliff, block.timestamp);
        assertEq(end, block.timestamp + 360 days);
        assertEq(totalVesting, _ZVE_Vested_JIM);
        assert(!revokable);
    }

    function test_ZivoeITO_claimAirdrop_state_both_USDT(uint96 amountIn) public {

        uint256 amount = uint256(amountIn) + 1;

        zvl.try_commence(address(ITO));
        hevm.warp(ITO.end() - 30 days + 1 seconds);

        depositBoth(USDT, amount);

        // Warp to end of ITO.
        hevm.warp(ITO.end() + 1 seconds);

        // Pre-state claimAirdrop (junior + senior).
        uint256 _pre_JuniorCredits = ITO.juniorCredits(address(jim));
        uint256 _pre_SeniorCredits = ITO.seniorCredits(address(jim));
        uint256 _pre_zJTT_ITO = zJTT.balanceOf(address(ITO));
        uint256 _pre_zSTT_ITO = zSTT.balanceOf(address(ITO));
        assert(!ITO.airdropClaimed(address(jim)));

        (uint256 _zSTT_Claimed_JIM, uint256 _zJTT_Claimed_JIM, uint256 _ZVE_Vested_JIM) = jim.claimAirdrop(address(ITO), address(jim));

        // Post-state claimAirdrop (junior + senior).

        {
            uint256 _post_JuniorCredits = ITO.juniorCredits(address(jim));
            assertEq(_pre_JuniorCredits - _post_JuniorCredits, GBL.standardize(amount / 5, USDT));
            assertEq(ITO.seniorCredits(address(jim)), 0);
            assertEq(ITO.juniorCredits(address(jim)), 0);
            assert(ITO.airdropClaimed(address(jim)));
        }

        {
            uint256 _post_SeniorCredits = ITO.seniorCredits(address(jim));
            assertEq(_pre_SeniorCredits - _post_SeniorCredits, GBL.standardize(amount, USDT) * 3);  
        }

        {
            uint256 _post_zJTT_ITO = zJTT.balanceOf(address(ITO));
            assertEq(_pre_zJTT_ITO - _post_zJTT_ITO, GBL.standardize(amount / 5, USDT));
            assertEq(_pre_zJTT_ITO - _post_zJTT_ITO, _zJTT_Claimed_JIM);
        }

        {
            uint256 _post_zSTT_ITO = zSTT.balanceOf(address(ITO));
            assertEq(_pre_zSTT_ITO - _post_zSTT_ITO, GBL.standardize(amount, USDT));
            assertEq(_pre_zSTT_ITO - _post_zSTT_ITO, _zSTT_Claimed_JIM);
        }

        (
            uint256 start, 
            uint256 cliff, 
            uint256 end, 
            uint256 totalVesting, 
            , 
            ,
            bool revokable
        ) = vestZVE.viewSchedule(address(jim));

        assertEq(start, block.timestamp);
        assertEq(cliff, block.timestamp);
        assertEq(end, block.timestamp + 360 days);
        assertEq(totalVesting, _ZVE_Vested_JIM);
        assert(!revokable);
    }

    // Validate migrateDeposits() restrictions.
    // This includes:
    //  - Not callable until after ITO ends.
    //  - Not callable more than once.

    function test_ZivoeITO_migrateDeposits_restrictions_notEnded(uint96 amountIn) public {
        
        uint256 amount_A = uint256(amountIn) + 1;

        zvl.try_commence(address(ITO));
        hevm.warp(ITO.end() - 30 days + 1 seconds);

        depositSenior(FRAX, amount_A);
        depositSenior(DAI, amount_A);
        depositJunior(FRAX, amount_A / 5);
        depositJunior(DAI, amount_A / 5);

        hevm.warp(ITO.end());

        // Can't call until after ITO ends (block.timestamp > end).
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeITO::migrateDeposits() block.timestamp <= end");
        ITO.migrateDeposits();
        hevm.stopPrank();
    }

    function test_ZivoeITO_migrateDeposits_restrictions_migrateTwice(uint96 amountIn) public {
        
        uint256 amount_A = uint256(amountIn) + 1;

        zvl.try_commence(address(ITO));
        hevm.warp(ITO.end() - 30 days + 1 seconds);

        depositSenior(FRAX, amount_A);
        depositSenior(DAI, amount_A);
        depositJunior(FRAX, amount_A / 5);
        depositJunior(DAI, amount_A / 5);
        
        hevm.warp(ITO.end() + 1 seconds);

        // Succesfull call now that ITO ends.
        assert(bob.try_migrateDeposits(address(ITO)));

        hevm.warp(ITO.end() + 50 days);

        // Can't call a second time later on.
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeITO::migrateDeposits() migrated");
        ITO.migrateDeposits();
        hevm.stopPrank();
    }

    // Validate migrateDeposits() state changes.

    function test_ZivoeITO_migrateDeposits_state(uint96 amountIn) public {
        
        uint256 amount_A = uint256(amountIn) + 1;

        zvl.try_commence(address(ITO));
        hevm.warp(ITO.end() - 30 days + 1 seconds);

        depositBoth(DAI, amount_A);
        depositBoth(FRAX, amount_A);
        depositBoth(USDC, amount_A);
        depositBoth(USDT, amount_A);

        hevm.warp(ITO.end() + 1 seconds);

        // Pre-state.

        uint256 _preBalance_DAI_DAO = IERC20(DAI).balanceOf(address(DAO));
        uint256 _preBalance_FRAX_DAO = IERC20(FRAX).balanceOf(address(DAO));
        uint256 _preBalance_USDC_DAO = IERC20(USDC).balanceOf(address(DAO));
        uint256 _preBalance_USDT_DAO = IERC20(USDT).balanceOf(address(DAO));
        
        assert(!ITO.migrated());
        assert(!YDL.unlocked());
        assert(!ZVT.tranchesUnlocked());
        

        hevm.expectEmit(false, false, false, false, address(ITO));
        emit DepositsMigrated(
            IERC20(DAI).balanceOf(address(ITO)),
            IERC20(FRAX).balanceOf(address(ITO)),
            IERC20(USDC).balanceOf(address(ITO)),
            IERC20(USDT).balanceOf(address(ITO))
        );
        ITO.migrateDeposits();

        // Post-state.
        withinDiff(IERC20(DAI).balanceOf(address(DAO)) - _preBalance_DAI_DAO, amount_A * 120/100, 1);
        withinDiff(IERC20(FRAX).balanceOf(address(DAO)) - _preBalance_FRAX_DAO, amount_A * 120/100, 1);
        withinDiff(IERC20(USDC).balanceOf(address(DAO)) - _preBalance_USDC_DAO, amount_A * 120/100, 1);
        withinDiff(IERC20(USDT).balanceOf(address(DAO)) - _preBalance_USDT_DAO, amount_A * 120/100, 1);

        assert(ITO.migrated());
        assert(YDL.unlocked());
        assert(ZVT.tranchesUnlocked());

    }
    
}
