// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

contract Test_ZivoeYDL_Accounting is Utility {

    ZivoeTrancheToken MUSD;

    function setUp() public {

        // Deploy the core protocol.
        deployCore(false);

        // Fake stablecoin.
        MUSD = new ZivoeTrancheToken("MUSD", "MUSD");
        MUSD.changeMinterRole(address(this), true);
        MUSD.mint(address(this), 100_000_000 ether);

        // Update YDL distributed asset.
        assert(zvl.try_updateStablecoinWhitelist(address(GBL), address(MUSD), true));
        assert(god.try_setDistributedAsset(address(YDL), address(MUSD)));

        // Simulate ITO.
        assert(zvl.try_updateStablecoinWhitelist(address(GBL), address(DAI), false));
        assert(zvl.try_updateStablecoinWhitelist(address(GBL), address(USDC), false));
        assert(zvl.try_updateStablecoinWhitelist(address(GBL), address(USDT), false));
        assert(zvl.try_updateStablecoinWhitelist(address(GBL), address(FRAX), false));

    }

    function test_YDL_default_settings() public {

        // Ownership.
        assertEq(YDL.owner(), address(0));

        // State variables.
        assertEq(YDL.GBL(), address(GBL));
        assertEq(YDL.distributedAsset(), address(MUSD));
        assertEq(YDL.emaSTT(), 0);
        assertEq(YDL.emaJTT(), 0);
        assertEq(YDL.emaYield(), 0);
        assertEq(YDL.numDistributions(), 0);
        assertEq(YDL.lastDistribution(), 0);
        assertEq(YDL.targetAPYBIPS(), 800);
        assertEq(YDL.targetRatioBIPS(), 16250);
        assertEq(YDL.protocolEarningsRateBIPS(), 2000);
        assertEq(YDL.daysBetweenDistributions(), 30);
        assertEq(YDL.retrospectiveDistributions(), 6);

        assert(!YDL.unlocked());

    }

    /// @notice Simulates an ITO and calls migrateDeposits().
    function simulateITOBasic(
        uint256 senior,
        uint256 junior
    ) public {
        
        // Mint investor's stablecoins.
        MUSD.mint(address(sam), senior);
        MUSD.mint(address(jim), junior);

        // Warp to start of ITO.
        hevm.warp(ITO.start() + 1 seconds);

        // Approve ITO for stablecoins.
        assert(sam.try_approveToken(address(MUSD), address(ITO), senior));
        assert(jim.try_approveToken(address(MUSD), address(ITO), junior));

        // Deposit stablecoins.
        assert(sam.try_depositSenior(address(ITO), senior, address(MUSD)));
        assert(jim.try_depositJunior(address(ITO), junior, address(MUSD)));

        hevm.warp(ITO.end() + 1 seconds);
        
        ITO.migrateDeposits();

    }

    function test_YDL_addRewards(
        uint96 random
    ) public {

        uint256 amount = uint256(random);

        // Simulating the ITO will "unlock" the YDL, and allow calls to recoverAsset().
        simulateITOBasic(100_000 ether, 20_000 ether);

        MUSD.transfer(address(YDL), 100_000 ether);

        YDL.distributeYield();
    }

}
