// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "lib/zivoe-core-foundry/src/libraries/FloorMath.sol";

contract Test_ZivoeYDL is Utility {
    
    using FloorMath for uint256;

    struct Recipients {
        address[] recipients;
        uint256[] proportion;
    }

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
        
    }

    // ----------------------
    //    Helper Functions
    // ----------------------

    function updateRecipients_restrictions_init() public pure returns (
        address[] memory zeroRecipients,
        uint256[] memory zeroProportions,
        address[] memory badRecipients,
        uint256[] memory badProportions,
        address[] memory goodRecipients,
        uint256[] memory goodProportions
    ) 
    {
        zeroRecipients = new address[](0);
        zeroProportions = new uint256[](0);
        badRecipients = new address[](3);
        badProportions = new uint256[](4);
        goodRecipients = new address[](4);
        goodProportions = new uint256[](4);
        
        badRecipients[0] = address(0);
        badRecipients[1] = address(1);
        badRecipients[2] = address(2);
        
        badProportions[0] = 2500;
        badProportions[1] = 2500;
        badProportions[2] = 2500;
        badProportions[3] = 2501;

        goodRecipients[0] = address(0);
        goodRecipients[1] = address(1);
        goodRecipients[2] = address(2);
        goodRecipients[3] = address(3);
        
        goodProportions[0] = 2500;
        goodProportions[1] = 2500;
        goodProportions[2] = 2500;
        goodProportions[3] = 2500;
    }

    // ----------------
    //    Unit Tests
    // ----------------

    function test_ZivoeYDL_Accounting2_distributeYield(uint96 randomSenior, uint96 randomJunior) public {

        uint256 amtSenior = uint256(randomSenior) + 1000 ether; // Minimum amount $1,000 USD for each coin.
        uint256 amtJunior = uint256(randomJunior) + 1000 ether; // Minimum amount $1,000 USD for each coin.

        // Simulating the ITO will "unlock" the YDL, and allow calls to recoverAsset().
        simulateITO_byTranche_stakeTokens(amtSenior, amtJunior);

        // Must warp forward to make successfull distributYield() call.
        hevm.warp(YDL.lastDistribution() + YDL.daysBetweenDistributions() * 86400);

        mint("DAI", address(YDL), uint256(amtSenior));

        (uint256 seniorSupp, uint256 juniorSupp) = GBL.adjustedSupplies();

        // Pre-state.
        assertEq(YDL.numDistributions(), 0);

        assertEq(YDL.emaYield(), 0);
        assertEq(YDL.emaSTT(), zSTT.totalSupply());
        assertEq(YDL.emaJTT(), zJTT.totalSupply());

        // distributeYield().
        YDL.distributeYield();

        // Post-state.
        assertEq(YDL.emaYield(), uint256(amtSenior));

        assertEq(YDL.emaSTT(), zSTT.totalSupply()); // Note: Shouldn't change unless deposits occured to ZVT.
        assertEq(YDL.emaJTT(), zJTT.totalSupply()); // Note: Shouldn't change unless deposits occured to ZVT.

        assertEq(YDL.numDistributions(), 1);

    }

}
