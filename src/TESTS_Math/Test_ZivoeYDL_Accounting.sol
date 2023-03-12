// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

contract Test_ZivoeYDL_Accounting is Utility {

    address _GBL;

    bool live = false;

    ZivoeTrancheToken MUSD;

    function setUp() public {

        // Deploy the core protocol.
        deployCore(live);

        MUSD = new ZivoeTrancheToken("MUSD", "MUSD");
        MUSD.changeMinterRole(address(this), true);
        MUSD.mint(address(this), 100_000_000 ether);

        // Note: Replace _GBL value with main-net address of GBL for 
        //       live post-deployment validation.
        _GBL = address(GBL);
        // _GBL = 0x00000...;

    }

    function test_YDL_default_settings() public {

        address _YDL = IZivoeGlobals(_GBL).YDL();

        // Ownership.
        assertEq(IZivoeYDL(_YDL).owner(), address(0));

        // State variables.
        assertEq(IZivoeYDL(_YDL).GBL(), _GBL);
        assertEq(IZivoeYDL(_YDL).distributedAsset(), DAI);
        assertEq(IZivoeYDL(_YDL).emaSTT(), 0);
        assertEq(IZivoeYDL(_YDL).emaJTT(), 0);
        assertEq(IZivoeYDL(_YDL).emaYield(), 0);
        assertEq(IZivoeYDL(_YDL).numDistributions(), 0);
        assertEq(IZivoeYDL(_YDL).lastDistribution(), 0);
        assertEq(IZivoeYDL(_YDL).targetAPYBIPS(), 800);
        assertEq(IZivoeYDL(_YDL).targetRatioBIPS(), 16250);
        assertEq(IZivoeYDL(_YDL).protocolEarningsRateBIPS(), 2000);
        assertEq(IZivoeYDL(_YDL).daysBetweenDistributions(), 30);
        assertEq(IZivoeYDL(_YDL).retrospectiveDistributions(), 6);

        assert(!IZivoeYDL(_YDL).unlocked());

    }

    function test_YDL_addRewards() public {

        // address _YDL = IZivoeGlobals(_GBL).YDL();
        assert(zvl.try_updateStablecoinWhitelist(address(GBL), address(MUSD), true));
        assert(god.try_setDistributedAsset(address(YDL), address(MUSD)));

    }

}
