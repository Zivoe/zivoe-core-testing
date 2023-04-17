// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.17;

import "../TESTS_Utility/Utility.sol";

import "../../lib/zivoe-core-foundry/src/libraries/FloorMath.sol";

contract Test_ZivoeTranches is Utility {
    
    using FloorMath for uint256;

    function setUp() public {

        deployCore(false);

        // Move 2.5mm ZVE from DAO to ZVT.
        assert(god.try_push(address(DAO), address(ZVT), address(ZVE), 2500000 ether, ""));

    }

    // ----------------------
    //    Helper Functions
    // ----------------------

    // ----------------
    //    Unit Tests
    // ----------------

    // Validate pushToLocker() state, restrictions.
    // This includes:
    //  - "asset" must be $ZVE.

    function test_ZivoeTranches_pushToLocker_restrictions_nonZVE() public {

        // Can't push non-ZVE asset to ZVT.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeTranches::pushToLocker() asset != ZivoeTranches_IZivoeGlobals(GBL).ZVE()");
        DAO.push(address(ZVT), address(FRAX), 10_000 ether, "");
        hevm.stopPrank();
    }

    function test_ZivoeTranches_pushToLocker_state(uint96 random) public {

        uint256 amount = uint256(random) % 2500000 ether;

        // Pre-state.
        uint256 _preZVE = IERC20(address(ZVE)).balanceOf(address(ZVT));

        assert(god.try_push(address(DAO), address(ZVT), address(ZVE), amount, ""));
        
        // Post-state.
        assertEq(IERC20(address(ZVE)).balanceOf(address(ZVT)), _preZVE + amount);
    }

    // Validate depositJunior() state.
    // Validate depositJunior() restrictions.
    // This includes:
    //  - asset must be whitelisted
    //  - unlocked must be true
    //  - isJuniorOpen(amount, asset) must return true

    function test_ZivoeTranches_depositJunior_restrictions_notWhitelisted() public {
        
        mint("WETH", address(bob), 100 ether);
        mint("DAI", address(bob), 100 ether);
        assert(bob.try_approveToken(address(DAI), address(ZVT), 100 ether));
        assert(bob.try_approveToken(address(WETH), address(ZVT), 100 ether));

        // Can't call depositJunior() if asset not whitelisted.
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeTranches::depositJunior() !ZivoeTranches_IZivoeGlobals(GBL).stablecoinWhitelist(asset)");
        ZVT.depositJunior(100 ether, address(WETH));
        hevm.stopPrank();
    }

    function test_ZivoeTranches_depositJunior_restrictions_notOpen() public {
        
        mint("WETH", address(bob), 100 ether);
        mint("DAI", address(bob), 100 ether);
        assert(bob.try_approveToken(address(DAI), address(ZVT), 100 ether));
        assert(bob.try_approveToken(address(WETH), address(ZVT), 100 ether));
        
        simulateITO(100_000_000 ether, 100_000_000 ether, 100_000_000 * USD, 100_000_000 * USD);

        // Can't call depositJunior() if !isJuniorOpen()
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeTranches::depositJunior() !isJuniorOpen(amount, asset)");
        ZVT.depositJunior(100 ether, address(DAI));
        hevm.stopPrank();
    }

    function test_ZivoeTranches_depositJunior_restrictions_locked() public {
        
        mint("WETH", address(bob), 100 ether);
        mint("DAI", address(bob), 100 ether);
        assert(bob.try_approveToken(address(DAI), address(ZVT), 100 ether));
        assert(bob.try_approveToken(address(WETH), address(ZVT), 100 ether));
        
        simulateITO(100_000_000 ether, 100_000_000 ether, 100_000_000 * USD, 100_000_000 * USD);

        // Can't call depositJunior() if not unlocked (deploy new ZVT contract to test).
        ZVT = new ZivoeTranches(address(GBL));

        assert(bob.try_approveToken(address(DAI), address(ZVT), 100 ether));

        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeTranches::depositJunior() !tranchesUnlocked");
        ZVT.depositJunior(100 ether, address(DAI));
        hevm.stopPrank();
    }

    function test_ZivoeTranches_depositJunior_state(uint96 random) public {
        
        simulateITO(100_000_000 ether, 100_000_000 ether, 100_000_000 * USD, 100_000_000 * USD);
        
        // Deposit large amount into depositSenior() to open isJuniorOpen().
        mint("DAI", address(sam), 10_000_000_000 ether);

        assert(sam.try_approveToken(address(DAI), address(ZVT), 10_000_000_000 ether));
        assert(sam.try_depositSenior(address(ZVT), 10_000_000_000 ether, address(DAI)));
        
        // Calculate maximum amount depositable in junior tranche.
        (uint256 seniorSupp, uint256 juniorSupp) = GBL.adjustedSupplies();

        uint256 maximumAmount = (seniorSupp * ZVT.maxTrancheRatioBIPS() / BIPS).zSub(juniorSupp);

        if (maximumAmount == 0) { return; } // Can't deposit anything in given state.

        uint256 maximumAmount_18 = uint256(random) % maximumAmount / 3; // Dividing by three to support three deposits.
        uint256 maximumAmount_6 = maximumAmount_18 /= 10**12;

        // Mint amounts for depositJunior() calls.
        mint("DAI", address(jim), maximumAmount_18);
        mint("USDC", address(jim), maximumAmount_6);
        mint("USDT", address(jim), maximumAmount_6);
        assert(jim.try_approveToken(address(DAI), address(ZVT), maximumAmount_18));
        assert(jim.try_approveToken(address(USDC), address(ZVT), maximumAmount_6));
        assert(jim.try_approveToken(address(USDT), address(ZVT), maximumAmount_6));

        {
            uint256 _rewardZVE = ZVT.rewardZVEJuniorDeposit(maximumAmount_18);
            uint256 _preZVE = IERC20(address(ZVE)).balanceOf(address(jim));
            uint256 _preJTT = IERC20(address(zJTT)).balanceOf(address(jim));
            assert(jim.try_depositJunior(address(ZVT), maximumAmount_18, address(DAI)));
            assertEq(IERC20(address(ZVE)).balanceOf(address(jim)), _preZVE + _rewardZVE);
            assertEq(IERC20(address(zJTT)).balanceOf(address(jim)), _preJTT + maximumAmount_18);
        }

        {
            uint256 _rewardZVE = ZVT.rewardZVEJuniorDeposit(GBL.standardize(maximumAmount_6, USDC));
            uint256 _preZVE = IERC20(address(ZVE)).balanceOf(address(jim));
            uint256 _preJTT = IERC20(address(zJTT)).balanceOf(address(jim));
            assert(jim.try_depositJunior(address(ZVT), maximumAmount_6, address(USDC)));
            assertEq(IERC20(address(ZVE)).balanceOf(address(jim)), _preZVE + _rewardZVE);
            assertEq(IERC20(address(zJTT)).balanceOf(address(jim)), _preJTT + GBL.standardize(maximumAmount_6, USDC));
        }

        {
            uint256 _rewardZVE = ZVT.rewardZVEJuniorDeposit(GBL.standardize(maximumAmount_6, USDT));
            uint256 _preZVE = IERC20(address(ZVE)).balanceOf(address(jim));
            uint256 _preJTT = IERC20(address(zJTT)).balanceOf(address(jim));
            assert(jim.try_depositJunior(address(ZVT), maximumAmount_6, address(USDT)));
            assertEq(IERC20(address(ZVE)).balanceOf(address(jim)), _preZVE + _rewardZVE);
            assertEq(IERC20(address(zJTT)).balanceOf(address(jim)), _preJTT + GBL.standardize(maximumAmount_6, USDT));
        }

    }

    // Validate depositSenior() state.
    // Validate depositSenior() restrictions.
    // This includes:
    //  - asset must be whitelisted
    //  - ZVT contact must be unlocked

    function test_ZivoeTranches_depositSenior_restrictions_notWhitelisted() public {
        
        mint("WETH", address(bob), 100 ether);
        mint("DAI", address(bob), 100 ether);
        assert(bob.try_approveToken(address(DAI), address(ZVT), 100 ether));
        assert(bob.try_approveToken(address(WETH), address(ZVT), 100 ether));

        // Can't call depositSenior() if asset not whitelisted.
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeTranches::depositSenior() !ZivoeTranches_IZivoeGlobals(GBL).stablecoinWhitelist(asset)");
        ZVT.depositSenior(100 ether, address(WETH));
        hevm.stopPrank();
    }

    function test_ZivoeTranches_depositSenior_restrictions_locked() public {
        
        mint("WETH", address(bob), 100 ether);
        mint("DAI", address(bob), 100 ether);
        assert(bob.try_approveToken(address(DAI), address(ZVT), 100 ether));
        assert(bob.try_approveToken(address(WETH), address(ZVT), 100 ether));

        // Can't call depositSenior() if not unlocked (deploy new ZVT contract to test).
        ZVT = new ZivoeTranches(address(GBL));

        assert(bob.try_approveToken(address(DAI), address(ZVT), 100 ether));
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeTranches::depositSenior() !tranchesUnlocked");
        ZVT.depositSenior(100 ether, address(DAI));
        hevm.stopPrank();
    }

    function test_ZivoeTranches_depositSenior_state(uint96 random) public {

        simulateITO(100_000_000 ether, 100_000_000 ether, 100_000_000 * USD, 100_000_000 * USD);

        uint256 amount_18 = uint256(random);
        uint256 amount_6 = amount_18 /= 10**12;

        // Mint amounts for depositSenior() calls.
        mint("DAI", address(sam), amount_18);
        mint("USDC", address(sam), amount_6);
        mint("USDT", address(sam), amount_6);
        assert(sam.try_approveToken(address(DAI), address(ZVT), amount_18));
        assert(sam.try_approveToken(address(USDC), address(ZVT), amount_6));
        assert(sam.try_approveToken(address(USDT), address(ZVT), amount_6));

        {
            uint256 _rewardZVE = ZVT.rewardZVESeniorDeposit(amount_18);
            uint256 _preZVE = IERC20(address(ZVE)).balanceOf(address(sam));
            uint256 _preSTT = IERC20(address(zSTT)).balanceOf(address(sam));
            assert(sam.try_depositSenior(address(ZVT), amount_18, address(DAI)));
            assertEq(IERC20(address(ZVE)).balanceOf(address(sam)), _preZVE + _rewardZVE);
            assertEq(IERC20(address(zSTT)).balanceOf(address(sam)), _preSTT + amount_18);
        }

        {
            uint256 _rewardZVE = ZVT.rewardZVESeniorDeposit(GBL.standardize(amount_6, USDC));
            uint256 _preZVE = IERC20(address(ZVE)).balanceOf(address(sam));
            uint256 _preSTT = IERC20(address(zSTT)).balanceOf(address(sam));
            assert(sam.try_depositSenior(address(ZVT), amount_6, address(USDC)));
            assertEq(IERC20(address(ZVE)).balanceOf(address(sam)), _preZVE + _rewardZVE);
            assertEq(IERC20(address(zSTT)).balanceOf(address(sam)), _preSTT + GBL.standardize(amount_6, USDC));
        }

        {
            uint256 _rewardZVE = ZVT.rewardZVESeniorDeposit(GBL.standardize(amount_6, USDT));
            uint256 _preZVE = IERC20(address(ZVE)).balanceOf(address(sam));
            uint256 _preSTT = IERC20(address(zSTT)).balanceOf(address(sam));
            assert(sam.try_depositSenior(address(ZVT), amount_6, address(USDT)));
            assertEq(IERC20(address(ZVE)).balanceOf(address(sam)), _preZVE + _rewardZVE);
            assertEq(IERC20(address(zSTT)).balanceOf(address(sam)), _preSTT + GBL.standardize(amount_6, USDT));
        }
    } 

    // Validate restrictions on update functions (governance controlled).
    // Validate state changes on update functions (governance controlled).
    // This includes following functions:
    //  - updateMaxTrancheRatio()
    //  - updateMinZVEPerJTTMint()
    //  - updateMaxZVEPerJTTMint()
    //  - updateLowerRatioIncentive()
    //  - updateUpperRatioIncentives()

    function test_ZivoeTranches_restrictions_governance_owner_updateMaxTrancheRatio() public {
        // Can't call this function unless "owner" (intended to be governance contract, ZVT.TLC()).
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeTranches::onlyGovernance() _msgSender() != ZivoeTranches_IZivoeGlobals(GBL).TLC()");
        ZVT.updateMaxTrancheRatio(3000);
        hevm.stopPrank();
    }

    function test_ZivoeTranches_restrictions_governance_owner_updateMinZVEPerJTTMint() public {
        // Can't call this function unless "owner" (intended to be governance contract, ZVT.TLC()).
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeTranches::onlyGovernance() _msgSender() != ZivoeTranches_IZivoeGlobals(GBL).TLC()");
        ZVT.updateMinZVEPerJTTMint(0.001 * 10**18);
        hevm.stopPrank();
    }

    function test_ZivoeTranches_restrictions_governance_owner_updateMaxZVEPerJTTMint() public {
        // Can't call this function unless "owner" (intended to be governance contract, ZVT.TLC()).
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeTranches::onlyGovernance() _msgSender() != ZivoeTranches_IZivoeGlobals(GBL).TLC()");
        ZVT.updateMaxZVEPerJTTMint(0.022 * 10**18);
        hevm.stopPrank();
    }

    function test_ZivoeTranches_restrictions_governance_owner_updateLowerRatioIncentive() public {
        // Can't call this function unless "owner" (intended to be governance contract, ZVT.TLC()).
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeTranches::onlyGovernance() _msgSender() != ZivoeTranches_IZivoeGlobals(GBL).TLC()");
        ZVT.updateLowerRatioIncentive(2000);
        hevm.stopPrank();
    }

    function test_ZivoeTranches_restrictions_governance_owner_updateUpperRatioIncentives() public {
        // Can't call this function unless "owner" (intended to be governance contract, ZVT.TLC()).
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeTranches::onlyGovernance() _msgSender() != ZivoeTranches_IZivoeGlobals(GBL).TLC()");
        ZVT.updateUpperRatioIncentives(2250);
        hevm.stopPrank();
    }

    function test_ZivoeTranches_restrictions_governance_greaterThan_updateMaxTrancheRatio() public {
        assert(god.try_updateMaxTrancheRatio(address(ZVT), 3500));
        // Can't updateMaxTrancheRatio() greater than 3500.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeTranches::updateMaxTrancheRatio() ratio > 3500");
        ZVT.updateMaxTrancheRatio(3501);
        hevm.stopPrank();
    }

    function test_ZivoeTranches_restrictions_governance_greaterThan_updateUpperRatioIncentives() public {
        assert(god.try_updateUpperRatioIncentives(address(ZVT), 2499));
        assert(god.try_updateUpperRatioIncentives(address(ZVT), 2500));
        // Can't updateUpperRatioIncentives() > 2500.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeTranches::updateUpperRatioIncentive() upperRatio > 2500");
        ZVT.updateUpperRatioIncentives(2501);
        hevm.stopPrank();
    }

    function test_ZivoeTranches_restrictions_governance_greaterThan_updateMinZVEPerJTTMint() public {
        // Can't updateMinZVEPerJTTMint() greater than or equal to maxZVEPerJTTMint.
        // Note: Call updateMaxZVEPerJTTMint() here to enable increasing min, given max = 0 initially.
        assert(god.try_updateMaxZVEPerJTTMint(address(ZVT), 0.005 * 10**18));
        // Two following calls should succeed as amount is less than MaxZVEPerJTTMint.
        assert(god.try_updateMinZVEPerJTTMint(address(ZVT), 0.004 * 10**18));
        assert(god.try_updateMinZVEPerJTTMint(address(ZVT), 0.00499 * 10**18));

        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeTranches::updateMinZVEPerJTTMint() min >= maxZVEPerJTTMint");
        ZVT.updateMinZVEPerJTTMint(0.005 * 10**18);
        hevm.stopPrank();
    }

    function test_ZivoeTranches_restrictions_governance_greaterThan_updateMaxZVEPerJTTMint() public {
        assert(god.try_updateMaxZVEPerJTTMint(address(ZVT), 0.1 * 10**18 - 1));
        // Can't updateMaxZVEPerJTTMint() greater than 0.1 * 10 **18.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeTranches::updateMaxZVEPerJTTMint() max >= 0.1 * 10**18");
        ZVT.updateMaxZVEPerJTTMint(0.1 * 10**18);
        hevm.stopPrank();
    }

    function test_ZivoeTranches_restrictions_governance_lessThan_updateLowerRatioIncentive() public {
        assert(god.try_updateLowerRatioIncentive(address(ZVT), 1001));
        assert(god.try_updateLowerRatioIncentive(address(ZVT), 1000));
        // Can't updateLowerRatioIncentive() < 1000.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeTranches::updateLowerRatioIncentive() lowerRatio < 1000");
        ZVT.updateLowerRatioIncentive(999);
        hevm.stopPrank();
    }

    function test_ZivoeTranches_restrictions_governance_greaterThan_updateLowerRatioIncentive() public {
        assert(god.try_updateLowerRatioIncentive(address(ZVT), 1999));
        // Can't updateLowerRatioIncentive() > upperRatioIncentive (initially 2000).
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeTranches::updateLowerRatioIncentive() lowerRatio >= upperRatioIncentive");
        ZVT.updateLowerRatioIncentive(2000);
        hevm.stopPrank();
    }

    function test_ZivoeTranches_governance_state(
        uint256 maxTrancheRatioIn,
        uint256 minZVEPerJTTMintIn,
        uint256 maxZVEPerJTTMintIn,
        uint256 lowerRatioIncentiveIn,
        uint256 upperRatioIncentiveIn
    ) public {
        
        uint256 maxTrancheRatio = maxTrancheRatioIn % 3500;
        uint256 minZVEPerJTTMint = minZVEPerJTTMintIn % (0.01 * 10**18);
        uint256 maxZVEPerJTTMint = maxZVEPerJTTMintIn % (0.01 * 10**18) + 1;

        if (minZVEPerJTTMint >= maxZVEPerJTTMint) {
            minZVEPerJTTMint = maxZVEPerJTTMint - 1;
        }

        uint256 lowerRatioIncentive = lowerRatioIncentiveIn % 1500 + 1000;
        uint256 upperRatioIncentive = upperRatioIncentiveIn % 1499 + 1001;

        if (lowerRatioIncentive >= upperRatioIncentive) {
            lowerRatioIncentive = upperRatioIncentive - 1;
        }

        // Pre-state.
        assertEq(ZVT.maxTrancheRatioBIPS(), 2000);
        assertEq(ZVT.minZVEPerJTTMint(), 0);
        assertEq(ZVT.maxZVEPerJTTMint(), 0);
        assertEq(ZVT.lowerRatioIncentive(), 1000);
        assertEq(ZVT.upperRatioIncentive(), 2000);

        assert(god.try_updateMaxTrancheRatio(address(ZVT), maxTrancheRatio));
        assert(god.try_updateMaxZVEPerJTTMint(address(ZVT), maxZVEPerJTTMint));
        assert(god.try_updateMinZVEPerJTTMint(address(ZVT), minZVEPerJTTMint));
        assert(god.try_updateUpperRatioIncentives(address(ZVT), upperRatioIncentive));
        assert(god.try_updateLowerRatioIncentive(address(ZVT), lowerRatioIncentive));

        // Post-state.
        assertEq(ZVT.maxTrancheRatioBIPS(), maxTrancheRatio);
        assertEq(ZVT.maxZVEPerJTTMint(), maxZVEPerJTTMint);
        assertEq(ZVT.minZVEPerJTTMint(), minZVEPerJTTMint);
        assertEq(ZVT.lowerRatioIncentive(), lowerRatioIncentive);
        assertEq(ZVT.upperRatioIncentive(), upperRatioIncentive);

    }
}