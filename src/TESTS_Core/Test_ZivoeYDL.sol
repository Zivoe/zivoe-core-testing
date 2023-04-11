// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "lib/zivoe-core-foundry/src/ZivoeMath.sol";

import "lib/zivoe-core-foundry/src/libraries/FloorMath.sol";

contract Test_ZivoeYDL is Utility {
    
    using FloorMath for uint256;

    struct Recipients {
        address[] recipients;
        uint256[] proportion;
    }

    function setUp() public {
        deployCore(false);
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

    // Validate unlock() state changes.
    // Validate unlock() restrictions.
    // This includes:
    //  - Caller must be ITO

    function test_ZivoeYDL_unlock_restrictions() public {
        
        // Can't call if _msgSendeR() != ITO.
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeYDL::unlock() _msgSender() != YDL_IZivoeGlobals(GBL).ITO()");
        YDL.unlock();
        hevm.stopPrank();
    }

    function test_ZivoeYDL_unlock_state(uint96 random) public {

        uint256 amount = uint256(random) + 1000 ether; // Minimum amount $1,000 USD for each coin.

        // Pre-state.
        assertEq(YDL.emaSTT(), 0);
        assertEq(YDL.emaJTT(), 0);
        assertEq(YDL.lastDistribution(), 0);

        assert(!YDL.unlocked());

        // Simulating the ITO will "unlock" the YDL.
        simulateITO(amount, amount, amount / 10**12, amount / 10**12);

        // Stake tokens to view downstream YDL accounting effects.
        claimITO_and_approveTokens_and_stakeTokens(true);

        // Post-state.
        assertEq(YDL.lastDistribution(), block.timestamp);

        assertEq(YDL.emaSTT(), zSTT.totalSupply());
        assertEq(YDL.emaJTT(), zSTT.totalSupply());

        assert(YDL.unlocked());

        (
            address[] memory protocolEarningsRecipients,
            uint256[] memory protocolEarningsProportion,
            address[] memory residualEarningsRecipients,
            uint256[] memory residualEarningsProportion
        ) = YDL.viewDistributions();

        assertEq(protocolEarningsRecipients[0], address(stZVE));
        assertEq(protocolEarningsRecipients[1], address(DAO));
        assertEq(protocolEarningsRecipients.length, 2);

        assertEq(protocolEarningsProportion[0], 7500);
        assertEq(protocolEarningsProportion[1], 2500);
        assertEq(protocolEarningsProportion.length, 2);

        assertEq(residualEarningsRecipients[0], address(stJTT));
        assertEq(residualEarningsRecipients[1], address(stSTT));
        assertEq(residualEarningsRecipients[2], address(stZVE));
        assertEq(residualEarningsRecipients[3], address(DAO));
        assertEq(residualEarningsRecipients.length, 4);

        assertEq(residualEarningsProportion[0], 2500);
        assertEq(residualEarningsProportion[1], 500);
        assertEq(residualEarningsProportion[2], 4500);
        assertEq(residualEarningsProportion[3], 2500);
        assertEq(residualEarningsProportion.length, 4);

    }

    // Validate setTargetAPYBIPS() state changes.
    // Validate setTargetAPYBIPS() restrictions.
    // This includes:
    //  - Caller must be TLC

    function test_ZivoeYDL_setTargetAPYBIPS_restrictions(uint96 random) public {

        uint256 amount = uint256(random);

        // Can't call if _msgSender() != TLC.
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeYDL::setTargetAPYBIPS() _msgSender() != TLC()");
        YDL.setTargetAPYBIPS(amount);
        hevm.stopPrank();
    }

    function test_ZivoeYDL_setTargetAPYBIPS_state(uint96 random) public {

        uint256 amount = uint256(random);

        // Pre-state.
        assertEq(YDL.targetAPYBIPS(), 800);
        
        // setTargetAPYBIPS().
        assert(god.try_setTargetAPYBIPS(address(YDL), amount));

        // Post-state.
        assertEq(YDL.targetAPYBIPS(), amount);

    }

    // Validate setTargetRatioBIPS() state changes.
    // Validate setTargetRatioBIPS() restrictions.
    // This includes:
    //  - Caller must be TLC

    function test_ZivoeYDL_setTargetRatioBIPS_restrictions(uint96 random) public {
        
        uint256 amount = uint256(random);
        
        // Can't call if _msgSender() != TLC.
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeYDL::setTargetRatioBIPS() _msgSender() != TLC()");
        YDL.setTargetRatioBIPS(amount);
        hevm.stopPrank();
    }

    function test_ZivoeYDL_setTargetRatioBIPS_state(uint96 random) public {

        uint256 amount = uint256(random);

        // Pre-state.
        assertEq(YDL.targetRatioBIPS(), 16250);
        
        // setTargetRatioBIPS().
        assert(god.try_setTargetRatioBIPS(address(YDL), amount));

        // Post-state.
        assertEq(YDL.targetRatioBIPS(), amount);

    }

    // Validate setProtocolEarningsRateBIPS() state changes.
    // Validate setProtocolEarningsRateBIPS() restrictions.
    // This includes:
    //  - Caller must be TLC
    //  - Amount must be <= 10000.

    function test_ZivoeYDL_setProtocolEarningsRateBIPS_restrictions_msgSender(uint96 random) public {
        
        uint256 amount = uint256(random);
        
        // Can't call if _msgSender() != TLC.
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeYDL::setProtocolEarningsRateBIPS() _msgSender() != TLC()");
        YDL.setProtocolEarningsRateBIPS(amount);
        hevm.stopPrank();

        // Example success.
        assert(god.try_setProtocolEarningsRateBIPS(address(YDL), 1200));
    }

    function test_ZivoeYDL_setProtocolEarningsRateBIPS_restrictions_max10000() public {
        
        // Can't call if > 3000.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeYDL::setProtocolEarningsRateBIPS() _protocolEarningsRateBIPS > 3000");
        YDL.setProtocolEarningsRateBIPS(3001);
        hevm.stopPrank();
    }

    function test_ZivoeYDL_setProtocolEarningsRateBIPS_state(uint96 random) public {

        uint256 amount = uint256(random) % 3000;

        // Pre-state.
        assertEq(YDL.protocolEarningsRateBIPS(), 2000);
        
        // setProtocolEarningsRateBIPS().
        assert(god.try_setProtocolEarningsRateBIPS(address(YDL), amount));

        // Post-state.
        assertEq(YDL.protocolEarningsRateBIPS(), amount);

    }

    // Validate setDistributedAsset() state changes.
    // Validate setDistributedAsset() restrictions.
    // This includes:
    //  - _distributedAsset must be on stablecoinWhitelist
    //  - Caller must be TLC

    function test_ZivoeYDL_setDistributedAsset_restrictions_distributedAsset() public {
        
        // Can't call distributedAsset == _distributedAsset.
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeYDL::setDistributedAsset() _distributedAsset == distributedAsset");
        YDL.setDistributedAsset(DAI);
        hevm.stopPrank();

        // Example success call.
        assert(god.try_setDistributedAsset(address(YDL), USDC));

    }

    function test_ZivoeYDL_setDistributedAsset_restrictions_msgSender() public {
        
        // Can't call if _msgSender() != TLC.
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeYDL::setDistributedAsset() _msgSender() != TLC()");
        YDL.setDistributedAsset(USDC);
        hevm.stopPrank();
    }

    function test_ZivoeYDL_setDistributedAsset_restrictions_notWhitelisted() public {

        // Can't call if asset not whitelisted.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeYDL::setDistributedAsset() !YDL_IZivoeGlobals(GBL).stablecoinWhitelist(_distributedAsset)");
        YDL.setDistributedAsset(WETH);
        hevm.stopPrank();
    }

    function test_ZivoeYDL_setDistributedAsset_state() public {

        // Pre-state.
        assertEq(YDL.distributedAsset(), DAI);

        // Example success call.
        assert(god.try_setDistributedAsset(address(YDL), USDC));

        // Post-state.
        assertEq(YDL.distributedAsset(), USDC);

    }

    // Validate updateRecipients() (protocol) state changes.
    // Validate updateRecipients() (protocol) restrictions.
    // This includes:
    //  - Input parameter arrays must have equal length (recipients.length == proportions.length)
    //  - Sum of proporitions values must equal 10000 (BIPS)
    //  - Caller must be TLC()

    function test_ZivoeYDL_updateRecipientsTrue_restrictions_msgSender() public {
        
        (,,,,
        address[] memory goodRecipients,
        uint256[] memory goodProportions
        ) = updateRecipients_restrictions_init();

        // Can't call if _msgSender() != TLC.
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeYDL::updateRecipients() _msgSender() != TLC()");
        YDL.updateRecipients(goodRecipients, goodProportions, true);
        hevm.stopPrank();

    }

    function test_ZivoeYDL_updateRecipientsTrue_restrictions_length() public {
        
        (,,
        address[] memory badRecipients,
        ,,
        uint256[] memory goodProportions
        ) = updateRecipients_restrictions_init();

        // Can't call if recipients.length == proportions.length.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeYDL::updateRecipients() recipients.length != proportions.length || recipients.length == 0");
        YDL.updateRecipients(badRecipients, goodProportions, true);
        hevm.stopPrank();
    }

    function test_ZivoeYDL_updateRecipientsTrue_restrictions_recipientsLength0() public {
        
        (address[] memory zeroRecipients,
        uint256[] memory zeroProportions,
        ,,,
        ) = updateRecipients_restrictions_init();


        // Can't call if recipients.length == 0.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeYDL::updateRecipients() recipients.length != proportions.length || recipients.length == 0");
        YDL.updateRecipients(zeroRecipients, zeroProportions, true);
        hevm.stopPrank();
    }

    function test_ZivoeYDL_updateRecipientsTrue_restrictions_locked() public {
        
        (,,,,
        address[] memory goodRecipients,
        uint256[] memory goodProportions
        ) = updateRecipients_restrictions_init();

        // Can't call if !YDL.unlocked().
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeYDL::updateRecipients() !unlocked");
        YDL.updateRecipients(goodRecipients, goodProportions, true);
        hevm.stopPrank();
    }

    function test_ZivoeYDL_updateRecipientsTrue_restrictions_maxProportions(uint96 random) public {
        
        (,,,
        uint256[] memory badProportions,
        address[] memory goodRecipients,
        uint256[] memory goodProportions
        ) = updateRecipients_restrictions_init();

        uint256 amount = uint256(random);

        // Simulating the ITO will "unlock" the YDL, and allow calls to updateRecipients().
        simulateITO(amount, amount, amount / 10**12, amount / 10**12);

        // Can't call if proportions total != 10000 (BIPS).
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeYDL::updateRecipients() proportionTotal != BIPS (10,000)");
        YDL.updateRecipients(goodRecipients, badProportions, true);
        hevm.stopPrank();

        // Example success call.
        assert(god.try_updateRecipients(address(YDL), goodRecipients, goodProportions, true));
    }

    function test_ZivoeYDL_updateRecipientsTrue_state(uint96 random) public {

        uint256 amount = uint256(random) + 1000 ether; // Minimum amount $1,000 USD for each coin.

        address[] memory recipients = new address[](4);
        uint256[] memory proportions = new uint256[](4);

        recipients[0] = address(1);
        recipients[1] = address(2);
        recipients[2] = address(3);
        recipients[3] = address(4);

        proportions[0] = 1;
        proportions[1] = 1;
        proportions[2] = 1;
        proportions[3] = 1;

        proportions[0] += amount % 2500;
        proportions[1] += amount % 2500;
        proportions[2] += amount % 2500;
        proportions[3] += amount % 2500;

        if (proportions[0] + proportions[1] + proportions[2] + proportions[3] < 10000) {
            proportions[3] = 10000 - proportions[0] - proportions[1] - proportions[2];
        }

        // Simulating the ITO will "unlock" the YDL, and allow calls to updateRecipients().
        simulateITO(amount, amount, amount / 10**12, amount / 10**12);

        // Pre-state.
        (
            address[] memory protocolEarningsRecipients,
            uint256[] memory protocolEarningsProportion,
            ,
        ) = YDL.viewDistributions();

        assertEq(protocolEarningsRecipients[0], address(stZVE));
        assertEq(protocolEarningsRecipients[1], address(DAO));
        assertEq(protocolEarningsRecipients.length, 2);

        assertEq(protocolEarningsProportion[0], 7500);
        assertEq(protocolEarningsProportion[1], 2500);
        assertEq(protocolEarningsProportion.length, 2);

        // updateRecipients().        
        assert(god.try_updateRecipients(address(YDL), recipients, proportions, true));

        // Post-state.
        (
            protocolEarningsRecipients,
            protocolEarningsProportion,
            ,
        ) = YDL.viewDistributions();

        assertEq(protocolEarningsRecipients[0], address(1));
        assertEq(protocolEarningsRecipients[1], address(2));
        assertEq(protocolEarningsRecipients[2], address(3));
        assertEq(protocolEarningsRecipients[3], address(4));
        assertEq(protocolEarningsRecipients.length, 4);

        assertEq(protocolEarningsProportion[0], proportions[0]);
        assertEq(protocolEarningsProportion[1], proportions[1]);
        assertEq(protocolEarningsProportion[2], proportions[2]);
        assertEq(protocolEarningsProportion[3], proportions[3]);
        assertEq(protocolEarningsProportion.length, 4);

    }

    // Validate updateRecipients() (residual) state changes.
    // Validate updateRecipients() (residual) restrictions.
    // This includes:
    //  - Input parameter arrays must have equal length (recipients.length == proportions.length)
    //  - Sum of proporitions values must equal 10000 (BIPS)
    //  - Caller must be TLC

    function test_ZivoeYDL_updateRecipientsFalse_restrictions_msgSender() public {
        
        (,,,,
        address[] memory goodRecipients,
        uint256[] memory goodProportions
        ) = updateRecipients_restrictions_init();

        // Can't call if _msgSender() != TLC.
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeYDL::updateRecipients() _msgSender() != TLC()");
        YDL.updateRecipients(goodRecipients, goodProportions, false);
        hevm.stopPrank();

    }

    function test_ZivoeYDL_updateRecipientsFalse_restrictions_length() public {
        
        (,,
        address[] memory badRecipients,
        ,,
        uint256[] memory goodProportions
        ) = updateRecipients_restrictions_init();

        // Can't call if recipients.length == proportions.length.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeYDL::updateRecipients() recipients.length != proportions.length || recipients.length == 0");
        YDL.updateRecipients(badRecipients, goodProportions, false);
        hevm.stopPrank();
    }

    function test_ZivoeYDL_updateRecipientsFalse_restrictions_recipientsLength0() public {
        
        (address[] memory zeroRecipients,
        uint256[] memory zeroProportions,
        ,,,
        ) = updateRecipients_restrictions_init();


        // Can't call if recipients.length == 0.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeYDL::updateRecipients() recipients.length != proportions.length || recipients.length == 0");
        YDL.updateRecipients(zeroRecipients, zeroProportions, false);
        hevm.stopPrank();
    }

    function test_ZivoeYDL_updateRecipientsFalse_restrictions_locked() public {
        
        (,,,,
        address[] memory goodRecipients,
        uint256[] memory goodProportions
        ) = updateRecipients_restrictions_init();

        // Can't call if !YDL.unlocked().
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeYDL::updateRecipients() !unlocked");
        YDL.updateRecipients(goodRecipients, goodProportions, false);
        hevm.stopPrank();
    }

    function test_ZivoeYDL_updateRecipientsFalse_restrictions_maxProportions(uint96 random) public {
        
        (,,,
        uint256[] memory badProportions,
        address[] memory goodRecipients,
        uint256[] memory goodProportions
        ) = updateRecipients_restrictions_init();

        uint256 amount = uint256(random);

        // Simulating the ITO will "unlock" the YDL, and allow calls to updateRecipients().
        simulateITO(amount, amount, amount / 10**12, amount / 10**12);

        // Can't call if proportions total != 10000 (BIPS).
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeYDL::updateRecipients() proportionTotal != BIPS (10,000)");
        YDL.updateRecipients(goodRecipients, badProportions, false);
        hevm.stopPrank();

        // Example success call.
        assert(god.try_updateRecipients(address(YDL), goodRecipients, goodProportions, false));
    }

    function test_ZivoeYDL_updateRecipientsFalse_state(uint96 random) public {

        uint256 amount = uint256(random) + 1000 ether; // Minimum amount $1,000 USD for each coin.

        address[] memory recipients = new address[](4);
        uint256[] memory proportions = new uint256[](4);

        recipients[0] = address(1);
        recipients[1] = address(2);
        recipients[2] = address(3);
        recipients[3] = address(4);

        proportions[0] = 1;
        proportions[1] = 1;
        proportions[2] = 1;
        proportions[3] = 1;

        proportions[0] += amount % 2500;
        proportions[1] += amount % 2500;
        proportions[2] += amount % 2500;
        proportions[3] += amount % 2500;

        if (proportions[0] + proportions[1] + proportions[2] + proportions[3] < 10000) {
            proportions[3] = 10000 - proportions[0] - proportions[1] - proportions[2];
        }

        // Simulating the ITO will "unlock" the YDL, and offer initial settings.
        simulateITO(amount, amount, amount / 10**12, amount / 10**12);

        // Pre-state.
        (
            ,
            ,
            address[] memory residualEarningsRecipients,
            uint256[] memory residualEarningsProportion
        ) = YDL.viewDistributions();

        assertEq(residualEarningsRecipients[0], address(stJTT));
        assertEq(residualEarningsRecipients[1], address(stSTT));
        assertEq(residualEarningsRecipients[2], address(stZVE));
        assertEq(residualEarningsRecipients[3], address(DAO));
        assertEq(residualEarningsRecipients.length, 4);

        assertEq(residualEarningsProportion[0], 2500);
        assertEq(residualEarningsProportion[1], 500);
        assertEq(residualEarningsProportion[2], 4500);
        assertEq(residualEarningsProportion[3], 2500);
        assertEq(residualEarningsProportion.length, 4);

        // updateRecipients().        
        assert(god.try_updateRecipients(address(YDL), recipients, proportions, false));

        // Post-state.
        (
            ,
            ,
            residualEarningsRecipients,
            residualEarningsProportion
        ) = YDL.viewDistributions();

        assertEq(residualEarningsRecipients[0], address(1));
        assertEq(residualEarningsRecipients[1], address(2));
        assertEq(residualEarningsRecipients[2], address(3));
        assertEq(residualEarningsRecipients[3], address(4));
        assertEq(residualEarningsRecipients.length, 4);

        assertEq(residualEarningsProportion[0], proportions[0]);
        assertEq(residualEarningsProportion[1], proportions[1]);
        assertEq(residualEarningsProportion[2], proportions[2]);
        assertEq(residualEarningsProportion[3], proportions[3]);
        assertEq(residualEarningsProportion.length, 4);

    }

    // Validate distributeYield() state changes.
    // Validate distributeYield() restrictions.
    // This includes:
    //  - YDL must be unlocked
    //  - block.timestamp >= lastDistribution + daysBetweenDistributions * 86400

    function test_ZivoeYDL_distributeYield_restrictions_locked() public {

        // Can't call distributeYield() if !YDL.unlocked().
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeYDL::distributeYield() !unlocked");
        YDL.distributeYield();
        hevm.stopPrank();
    }

    function test_ZivoeYDL_distributeYield_restrictions_distributionPeriod(
        uint96 randomSenior, 
        uint96 randomJunior
    ) 
    public
    {
        uint256 amtSenior = uint256(randomSenior) + 1000 ether; // Minimum amount $1,000 USD for each coin.
        uint256 amtJunior = uint256(randomJunior) + 1000 ether; // Minimum amount $1,000 USD for each coin.

        // Simulating the ITO will "unlock" the YDL
        simulateITO_byTranche_stakeTokens(amtSenior, amtJunior);
        
        // Can't call distributeYield() if block.timestamp < lastDistribution + daysBetweenDistributions * 86400
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeYDL::distributeYield() block.timestamp < lastDistribution + daysBetweenDistributions * 86400");
        YDL.distributeYield();
        hevm.stopPrank();

        // Must warp forward to make successfull distributYield() call.
        hevm.warp(YDL.lastDistribution() + YDL.daysBetweenDistributions() * 86400);

        // mint().
        mint("DAI", address(YDL), uint256(randomSenior));

        // Example success.
        assert(bob.try_distributeYield(address(YDL)));
    }

    function test_ZivoeYDL_distributeYield_state(uint96 randomSenior, uint96 randomJunior) public {

        // TODO: Reimplement ...

        // uint256 amtSenior = uint256(randomSenior) + 1000 ether; // Minimum amount $1,000 USD for each coin.
        // uint256 amtJunior = uint256(randomJunior) + 1000 ether; // Minimum amount $1,000 USD for each coin.

        // // Simulating the ITO will "unlock" the YDL
        // simulateITO_byTranche_stakeTokens(amtSenior, amtJunior);

        // // Must warp forward to make successfull distributYield() call.
        // hevm.warp(YDL.lastDistribution() + YDL.daysBetweenDistributions() * 86400);

        // mint("DAI", address(YDL), uint256(amtSenior));

        // (uint256 seniorSupp, uint256 juniorSupp) = GBL.adjustedSupplies();

        // // Pre-state.
        // assertEq(YDL.numDistributions(), 0);

        // assertEq(YDL.emaYield(), 0);
        // assertEq(YDL.emaSTT(), zSTT.totalSupply());
        // assertEq(YDL.emaJTT(), zJTT.totalSupply());

        // // distributeYield().
        // YDL.distributeYield();

        // // Post-state.
        // assertEq(YDL.emaYield(), uint256(amtSenior) * (BIPS - YDL.protocolEarningsRateBIPS())/BIPS);

        // assertEq(YDL.emaSTT(), zSTT.totalSupply()); // Note: Shouldn't change unless deposits occured to ZVT.
        // assertEq(YDL.emaJTT(), zJTT.totalSupply()); // Note: Shouldn't change unless deposits occured to ZVT.

        // assertEq(YDL.numDistributions(), 1);

    }

}
