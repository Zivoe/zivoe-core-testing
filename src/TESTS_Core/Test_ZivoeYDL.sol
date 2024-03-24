// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../Utility/Utility.sol";

import "../../lib/zivoe-core-foundry/src/ZivoeMath.sol";

import "../../lib/zivoe-core-foundry/src/libraries/FloorMath.sol";

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
        address[] memory zeroRecipients, uint256[] memory zeroProportions,
        address[] memory badRecipients,  uint256[] memory badProportions,
        address[] memory goodRecipients, uint256[] memory goodProportions
    ) {
        zeroRecipients = new address[](0);
        zeroProportions = new uint256[](0);
        badRecipients = new address[](3);
        badProportions = new uint256[](4);
        goodRecipients = new address[](4);
        goodProportions = new uint256[](4);
        
        badRecipients[0] = address(1);
        badRecipients[1] = address(2);
        badRecipients[2] = address(3);
        
        badProportions[0] = 2500;
        badProportions[1] = 2500;
        badProportions[2] = 2500;
        badProportions[3] = 2501;

        goodRecipients[0] = address(1);
        goodRecipients[1] = address(2);
        goodRecipients[2] = address(3);
        goodRecipients[3] = address(4);
        
        goodProportions[0] = 2500;
        goodProportions[1] = 2500;
        goodProportions[2] = 2500;
        goodProportions[3] = 2500;
    }

    // ------------
    //    Events
    // ------------

    event AssetReturned(address indexed asset, uint256 amount);

    event UpdatedDistributedAsset(address indexed oldAsset, address indexed newAsset);

    event UpdatedProtocolEarningsRateBIPS(uint256 oldValue, uint256 newValue);

    event UpdatedProtocolRecipients(address[] recipients, uint256[] proportion);

    event UpdatedResidualRecipients(address[] recipients, uint256[] proportion);

    event UpdatedTargetAPYBIPS(uint256 oldValue, uint256 newValue);

    event UpdatedTargetRatioBIPS(uint256 oldValue, uint256 newValue);

    event YieldDistributed(uint256[] protocol, uint256 senior, uint256 junior, uint256[] residual);

    event YieldDistributedSingle(address indexed asset, address indexed recipient, uint256 amount);

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
        hevm.expectRevert("ZivoeYDL::unlock() _msgSender() != IZivoeGlobals_YDL(GBL).ITO()");
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
        assertEq(YDL.lastDistribution(), block.timestamp + 30 days);

        assertEq(YDL.emaSTT(), zSTT.totalSupply());
        assertEq(YDL.emaJTT(), zJTT.totalSupply());

        assert(YDL.unlocked());

        // Pre-state.
        (
            address[] memory protocolEarningsRecipients,
            uint256[] memory protocolEarningsProportion,
            address[] memory residualEarningsRecipients,
            uint256[] memory residualEarningsProportion
        ) = YDL.viewDistributions();

        assertEq(protocolEarningsRecipients[0], address(stZVE));
        assertEq(protocolEarningsRecipients[1], GBL.ZVL());
        assertEq(protocolEarningsRecipients.length, 2);

        assertEq(protocolEarningsProportion[0], 6666);
        assertEq(protocolEarningsProportion[1], 3334);
        assertEq(protocolEarningsProportion.length, 2);

        assertEq(residualEarningsRecipients[0], address(stZVE));
        assertEq(residualEarningsRecipients[1], GBL.ZVL());
        assertEq(residualEarningsRecipients.length, 2);

        assertEq(residualEarningsProportion[0], 6000);
        assertEq(residualEarningsProportion[1], 4000);
        assertEq(residualEarningsProportion.length, 2);

    }

    // Validate updateTargetAPYBIPS() state changes.
    // Validate updateTargetAPYBIPS() restrictions.
    // This includes:
    //  - Caller must be TLC

    function test_ZivoeYDL_updateTargetAPYBIPS_restrictions(uint96 random) public {

        uint256 amount = uint256(random);

        // Can't call if _msgSender() != TLC.
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeYDL::updateTargetAPYBIPS() _msgSender() != TLC()");
        YDL.updateTargetAPYBIPS(amount);
        hevm.stopPrank();
    }

    function test_ZivoeYDL_updateTargetAPYBIPS_state(uint96 random) public {

        uint256 amount = uint256(random);

        // Pre-state.
        assertEq(YDL.targetAPYBIPS(), 800);
        
        // updateTargetAPYBIPS().
        hevm.expectEmit(false, false, false, true, address(YDL));
        emit UpdatedTargetAPYBIPS(YDL.targetAPYBIPS(), amount);
        assert(god.try_updateTargetAPYBIPS(address(YDL), amount));

        // Post-state.
        assertEq(YDL.targetAPYBIPS(), amount);

    }

    // Validate updateTargetRatioBIPS() state changes.
    // Validate updateTargetRatioBIPS() restrictions.
    // This includes:
    //  - Caller must be TLC

    function test_ZivoeYDL_updateTargetRatioBIPS_restrictions(uint96 random) public {
        
        uint256 amount = uint256(random);
        
        // Can't call if _msgSender() != TLC.
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeYDL::updateTargetRatioBIPS() _msgSender() != TLC()");
        YDL.updateTargetRatioBIPS(amount);
        hevm.stopPrank();
    }

    function test_ZivoeYDL_updateTargetRatioBIPS_state(uint96 random) public {

        uint256 amount = uint256(random);

        // Pre-state.
        assertEq(YDL.targetRatioBIPS(), 18750);
        
        // updateTargetRatioBIPS().
        hevm.expectEmit(false, false, false, true, address(YDL));
        emit UpdatedTargetRatioBIPS(YDL.targetRatioBIPS(), amount);
        assert(god.try_updateTargetRatioBIPS(address(YDL), amount));

        // Post-state.
        assertEq(YDL.targetRatioBIPS(), amount);

    }

    // Validate updateProtocolEarningsRateBIPS() state changes.
    // Validate updateProtocolEarningsRateBIPS() restrictions.
    // This includes:
    //  - Caller must be TLC
    //  - Amount must be <= 3000.

    function test_ZivoeYDL_updateProtocolEarningsRateBIPS_restrictions_msgSender(uint96 random) public {
        
        uint256 amount = uint256(random);
        
        // Can't call if _msgSender() != TLC.
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeYDL::updateProtocolEarningsRateBIPS() _msgSender() != TLC()");
        YDL.updateProtocolEarningsRateBIPS(amount);
        hevm.stopPrank();

        // Example success.
        assert(god.try_updateProtocolEarningsRateBIPS(address(YDL), 1200));
    }

    function test_ZivoeYDL_updateProtocolEarningsRateBIPS_restrictions_max9000() public {
        
        // Can't call if > 3000.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeYDL::updateProtocolEarningsRateBIPS() _protocolEarningsRateBIPS > 9000");
        YDL.updateProtocolEarningsRateBIPS(9001);
        hevm.stopPrank();
    }

    function test_ZivoeYDL_updateProtocolEarningsRateBIPS_state(uint96 random) public {

        uint256 amount = uint256(random) % 9000;

        // Pre-state.
        assertEq(YDL.protocolEarningsRateBIPS(), 3000);
        
        // updateProtocolEarningsRateBIPS().
        hevm.expectEmit(false, false, false, true, address(YDL));
        emit UpdatedProtocolEarningsRateBIPS(YDL.protocolEarningsRateBIPS(), amount);
        assert(god.try_updateProtocolEarningsRateBIPS(address(YDL), amount));

        // Post-state.
        assertEq(YDL.protocolEarningsRateBIPS(), amount);
    }

    // Validate updateDistributedAsset() state changes.
    // Validate updateDistributedAsset() restrictions.
    // This includes:
    //  - _distributedAsset must not be current asset
    //  - _distributedAsset must be on stablecoinWhitelist
    //  - Caller must be TLC

    function test_ZivoeYDL_updateDistributedAsset_restrictions_distributedAsset() public {
        
        // Can't call distributedAsset == _distributedAsset.
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeYDL::updateDistributedAsset() _distributedAsset == distributedAsset");
        YDL.updateDistributedAsset(DAI);
        hevm.stopPrank();

        // Example success call.
        assert(god.try_updateDistributedAsset(address(YDL), USDC));

    }

    function test_ZivoeYDL_updateDistributedAsset_restrictions_msgSender() public {
        
        // Can't call if _msgSender() != TLC.
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeYDL::updateDistributedAsset() _msgSender() != TLC()");
        YDL.updateDistributedAsset(USDC);
        hevm.stopPrank();
    }

    function test_ZivoeYDL_updateDistributedAsset_restrictions_notWhitelisted() public {

        // Can't call if asset not whitelisted.
        hevm.startPrank(address(god));
        hevm.expectRevert("ZivoeYDL::updateDistributedAsset() !IZivoeGlobals_YDL(GBL).stablecoinWhitelist(_distributedAsset)");
        YDL.updateDistributedAsset(WETH);
        hevm.stopPrank();
    }

    function test_ZivoeYDL_updateDistributedAsset_state() public {

        // Pre-state.
        assertEq(YDL.distributedAsset(), DAI);

        // Example success call.
        hevm.expectEmit(true, true, false, false, address(YDL));
        emit UpdatedDistributedAsset(YDL.distributedAsset(), USDC);
        assert(god.try_updateDistributedAsset(address(YDL), USDC));

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
        assertEq(protocolEarningsRecipients[1], GBL.ZVL());
        assertEq(protocolEarningsRecipients.length, 2);

        assertEq(protocolEarningsProportion[0], 6666);
        assertEq(protocolEarningsProportion[1], 3334);
        assertEq(protocolEarningsProportion.length, 2);

        // updateRecipients().
        hevm.expectEmit(false, false, false, true, address(YDL));
        emit UpdatedProtocolRecipients(recipients, proportions);
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

        assertEq(residualEarningsRecipients[0], address(stZVE));
        assertEq(residualEarningsRecipients[1], GBL.ZVL());
        assertEq(residualEarningsRecipients.length, 2);

        assertEq(residualEarningsProportion[0], 6000);
        assertEq(residualEarningsProportion[1], 4000);
        assertEq(residualEarningsProportion.length, 2);

        // updateRecipients().
        hevm.expectEmit(false, false, false, true, address(YDL));
        emit UpdatedResidualRecipients(recipients, proportions);
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

    // Validate returnAsset() state changes.
    // Validate returnAsset() restrictions.
    // This includes:
    //  - asset != distributedAsset
    
    function test_ZivoeYDL_returnAsset_restrictions_distributedAsset() public {

        // Can't call returnAsset() if asset == distributedAsset
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeYDL::returnAsset() asset == distributedAsset");
        YDL.returnAsset(DAI);
        hevm.stopPrank();
    }
    
    function test_ZivoeYDL_returnAsset_state(uint96 amountA, uint96 amountB) public {

        mint("USDC", address(YDL), uint256(amountA));
        mint("USDT", address(YDL), uint256(amountB));

        // Pre-state.
        uint preYDL_USDC = IERC20(USDC).balanceOf(address(YDL));
        uint preYDL_USDT = IERC20(USDT).balanceOf(address(YDL));
        uint preDAO_USDC = IERC20(USDC).balanceOf(address(DAO));
        uint preDAO_USDT = IERC20(USDT).balanceOf(address(DAO));


        hevm.expectEmit(true, false, false, true, address(YDL));
        emit AssetReturned(USDC, preYDL_USDC);
        YDL.returnAsset(USDC);

        hevm.expectEmit(true, false, false, true, address(YDL));
        emit AssetReturned(USDT, preYDL_USDT);
        YDL.returnAsset(USDT);

        // Post-state.
        uint postYDL_USDC = IERC20(USDC).balanceOf(address(YDL));
        uint postYDL_USDT = IERC20(USDT).balanceOf(address(YDL));
        uint postDAO_USDC = IERC20(USDC).balanceOf(address(DAO));
        uint postDAO_USDT = IERC20(USDT).balanceOf(address(DAO));

        assertEq(postYDL_USDC, 0);
        assertEq(postYDL_USDT, 0);
        assertEq(postDAO_USDC, preYDL_USDC + preDAO_USDC);
        assertEq(postDAO_USDT, preYDL_USDT + preDAO_USDT);


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
        uint96 randomSenior
    ) public {
        uint256 amtSenior = uint256(randomSenior) + 1000 ether; // Minimum amount $1,000 USD for each coin.

        // Simulating the ITO will "unlock" the YDL
        simulateITO_byTranche_optionalStake(amtSenior, true);
        
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

    function test_ZivoeYDL_distributeYield_state_single(uint96 randomSenior, uint96 random) public {
        
        uint256 amtSenior = uint256(randomSenior) + 1000 ether; // Minimum amount $1,000 USD for each coin.

        uint256 amount = uint256(random);

        // Simulating the ITO will "unlock" the YDL
        simulateITO_byTranche_optionalStake(amtSenior, true);

        // Must warp forward to make successfull distributYield() call.
        hevm.warp(YDL.lastDistribution() + YDL.daysBetweenDistributions() * 86400);

        // Deal DAI to the YDL
        mint("DAI", address(YDL), uint256(amount));

        // Use earningsTrancheuse() to identify where yield is distributed
        uint256 protocolEarnings = YDL.protocolEarningsRateBIPS() * amount / BIPS;
        uint256 postFeeYield = amount - protocolEarnings;

        (
            uint256[] memory protocol, 
            uint256 senior, 
            uint256 junior, 
            uint256[] memory residual
        ) = YDL.earningsTrancheuse(protocolEarnings, postFeeYield);

        (uint256 seniorSupp, uint256 juniorSupp) = GBL.adjustedSupplies();

        // Pre-state.
        assertEq(YDL.distributionCounter(), 0);
        assertEq(YDL.lastDistribution(), block.timestamp - YDL.daysBetweenDistributions() * 86400);

        assertEq(YDL.emaSTT(), zSTT.totalSupply());
        assertEq(YDL.emaJTT(), zJTT.totalSupply());

        uint256 _preDAO = IERC20(DAI).balanceOf(address(DAO));

        assertEq(IERC20(DAI).balanceOf(address(YDL)),       amount);
        assertEq(IERC20(DAI).balanceOf(address(stSTT)),     0);
        assertEq(IERC20(DAI).balanceOf(address(stJTT)),     0);
        assertEq(IERC20(DAI).balanceOf(address(DAO)),       _preDAO);
        assertEq(IERC20(DAI).balanceOf(address(stZVE)),     0);
        assertEq(IERC20(DAI).balanceOf(address(vestZVE)),   0);

        uint256 splitBIPS = (stZVE.totalSupply() * BIPS) / (stZVE.totalSupply() + vestZVE.totalSupply());

        vm.expectEmit(false, false, false, false);
        emit YieldDistributed(protocol, senior, junior, residual);
        vm.expectEmit(true, true, false, false);
        emit YieldDistributedSingle(DAI, address(stZVE),    protocol[0] * splitBIPS / BIPS);
        emit YieldDistributedSingle(DAI, address(vestZVE),  protocol[0] * (BIPS - splitBIPS) / BIPS);
        emit YieldDistributedSingle(DAI, GBL.ZVL(),         protocol[1]);
        emit YieldDistributedSingle(DAI, address(stSTT),    senior);
        emit YieldDistributedSingle(DAI, address(stJTT),    junior);
        emit YieldDistributedSingle(DAI, address(stZVE),    residual[0] * splitBIPS / BIPS);
        emit YieldDistributedSingle(DAI, address(vestZVE),  residual[0] * (BIPS - splitBIPS) / BIPS);
        emit YieldDistributedSingle(DAI, GBL.ZVL(),         residual[1]);

        // distributeYield().
        YDL.distributeYield();

        uint256 residualAmt = postFeeYield - senior - junior;

        // Post-state.
        assertEq(YDL.emaSTT(), zSTT.totalSupply()); // Note: Shouldn't change unless deposits occured to ZVT.
        assertEq(YDL.emaJTT(), zJTT.totalSupply()); // Note: Shouldn't change unless deposits occured to ZVT.

        assertEq(YDL.distributionCounter(), 1);
        assertEq(YDL.lastDistribution(), block.timestamp);

        emit log_named_uint("protocol[0] - stZVE", protocol[0]);
        emit log_named_uint("protocol[1] - ZVL", protocol[1]);
        emit log_named_uint("senior", residualAmt);
        emit log_named_uint("junior", residualAmt);
        emit log_named_uint("residual[0] - stZVE", residual[0]);
        emit log_named_uint("residual[1] - ZVL", residual[1]);
        emit log_named_uint("residualAmt", residualAmt);

        withinDiff(IERC20(DAI).balanceOf(address(YDL)),     0, 10);
        withinDiff(IERC20(DAI).balanceOf(address(stSTT)),   senior, 10);
        withinDiff(IERC20(DAI).balanceOf(address(stJTT)),   junior, 10);
        withinDiff(IERC20(DAI).balanceOf(GBL.ZVL()),     protocol[1] + residual[1], 10);

        withinDiff(IERC20(DAI).balanceOf(address(stZVE)),     (protocol[0] + residual[0]) * splitBIPS / BIPS, 10);
        withinDiff(IERC20(DAI).balanceOf(address(vestZVE)),   (protocol[0] + residual[0]) * (BIPS - splitBIPS) / BIPS, 10);

    }

    function test_ZivoeYDL_distributeYield_state_multi(
        uint96 randomSenior, uint96 random
    ) public {
        
        // Simulating the ITO will "unlock" the YDL
        simulateITO_byTranche_optionalStake(uint256(randomSenior) + 1000 ether, true);

        // NOTE: To deal with stack-overflow, simply comment out one of these, then the corresponding ones at end of
        //       the for loop below.

        // uint256 snap_stSTT = IERC20(DAI).balanceOf(address(stSTT));
        // uint256 snap_stJTT = IERC20(DAI).balanceOf(address(stJTT));
        // uint256 snap_DAO = IERC20(DAI).balanceOf(address(DAO));
        // uint256 snap_stZVE = IERC20(DAI).balanceOf(address(stZVE));
        uint256 snap_vestZVE = IERC20(DAI).balanceOf(address(vestZVE));

        uint256[] memory protocol;
        uint256 senior;
        uint256 junior; 
        uint256[] memory residual;

        for (uint i = 0; i < 10; i++) {
            // Must warp forward to make successfull distributYield() call.
            hevm.warp(YDL.lastDistribution() + YDL.daysBetweenDistributions() * 86400);

            // Deal DAI to the YDL
            mint("DAI", address(YDL), uint256(random));

            uint256 trueAmount = IERC20(DAI).balanceOf(address(YDL));

            // Use earningsTrancheuse() to identify where yield is distributed
            uint256 protocolEarnings = YDL.protocolEarningsRateBIPS() * trueAmount / BIPS;
            uint256 postFeeYield = trueAmount - protocolEarnings;

            (
                protocol, 
                senior, 
                junior, 
                residual
            ) = YDL.earningsTrancheuse(protocolEarnings, postFeeYield);

            uint256 splitBIPS = (stZVE.totalSupply() * BIPS) / (stZVE.totalSupply() + vestZVE.totalSupply());
            
            // distributeYield().
            YDL.distributeYield();

            uint256 residualAmt = postFeeYield - senior - junior;

            // Post-state.

            // emit log_named_uint("protocol[0] - stZVE", protocol[0]);
            // emit log_named_uint("protocol[1] - DAO", protocol[1]);
            // emit log_named_uint("senior", residualAmt);
            // emit log_named_uint("junior", residualAmt);
            // emit log_named_uint("residual[0] - stJTT", residual[0]);
            // emit log_named_uint("residual[1] - stSTT", residual[1]);
            // emit log_named_uint("residual[2] - stZVE", residual[2]);
            // emit log_named_uint("residual[3] - DAO", residual[3]);
            // emit log_named_uint("residualAmt", residualAmt);
            
            // withinDiff(IERC20(DAI).balanceOf(address(YDL)),     0, 10);
            // withinDiff(IERC20(DAI).balanceOf(address(stSTT)),   snap_stSTT + senior + residual[1], 10);
            // withinDiff(IERC20(DAI).balanceOf(address(stJTT)),   snap_stJTT + junior + residual[0], 10);
            // withinDiff(IERC20(DAI).balanceOf(address(DAO)),     snap_DAO + protocol[1] + residual[3], 10);
            // withinDiff(IERC20(DAI).balanceOf(address(stZVE)),     snap_stZVE + (protocol[0] + residual[2]) * splitBIPS / BIPS, 10);

            withinDiff(IERC20(DAI).balanceOf(address(vestZVE)),   snap_vestZVE + (protocol[0] + residual[0]) * (BIPS - splitBIPS) / BIPS, 10);
        
            // snap_stSTT = IERC20(DAI).balanceOf(address(stSTT));
            // snap_stJTT = IERC20(DAI).balanceOf(address(stJTT));
            // snap_DAO = IERC20(DAI).balanceOf(address(DAO));
            // snap_stZVE = IERC20(DAI).balanceOf(address(stZVE));

            snap_vestZVE = IERC20(DAI).balanceOf(address(vestZVE));
        }
    }

    // NOTE: uint80 is a nice range for deposits ... max is ~1.2mm (with 18 precision coin)
    function test_ZivoeYDL_distributeYield_state_multi_ema(
        uint96 randomSenior, uint96 random, uint80 deposits
    ) public {
        
        // Simulating the ITO will "unlock" the YDL
        simulateITO_byTranche_optionalStake(uint256(randomSenior) + 1000 ether, true);

        for (uint i = 0; i < 10; i++) {

            // Must warp forward to make successful distributYield() call.
            hevm.warp(YDL.lastDistribution() + YDL.daysBetweenDistributions() * 86400);

            // Deal DAI to the YDL
            mint("DAI", address(YDL), uint256(random));

            // Pre-state.
            if (YDL.distributionCounter() == 0 || YDL.distributionCounter() == 1) {
                assertEq(YDL.emaSTT(), zSTT.totalSupply());
                assertEq(YDL.emaJTT(), zJTT.totalSupply());
            }
            
            uint256 pre_emaSTT = YDL.emaSTT();
            uint256 pre_emaJTT = YDL.emaJTT();

            mint("DAI", address(sam), uint256(deposits) * 80/100);
            assert(sam.try_approveToken(address(DAI), address(ZVT), uint256(deposits) * 80/100));
            assert(sam.try_depositSenior(address(ZVT), uint256(deposits) * 80/100, address(DAI)));
            if (ZVT.isJuniorOpen(uint256(deposits) * 20/100, DAI)) {
                mint("DAI", address(jim), uint256(deposits) * 20/100);
                assert(jim.try_approveToken(address(DAI), address(ZVT), uint256(deposits) * 20/100));
                assert(jim.try_depositJunior(address(ZVT), uint256(deposits) * 20/100, address(DAI)));
            }

            // distributeYield().
            YDL.distributeYield();

            // emaJTT = MATH.ema(emaJTT, aJTT, retrospectiveDistributions.min(distributionCounter));
            // emaSTT = MATH.ema(emaSTT, aSTT, retrospectiveDistributions.min(distributionCounter));

            // Post-state.
            (uint256 aSTT, uint256 aJTT) = GBL.adjustedSupplies();
            assertEq(YDL.emaSTT(), MATH.ema(pre_emaSTT, aSTT, YDL.retrospectiveDistributions().min(YDL.distributionCounter())));
            assertEq(YDL.emaJTT(), MATH.ema(pre_emaJTT, aJTT, YDL.retrospectiveDistributions().min(YDL.distributionCounter())));

        }

    }

}
