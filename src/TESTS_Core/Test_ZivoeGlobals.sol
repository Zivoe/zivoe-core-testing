// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../Utility/Utility.sol";

import "../../lib/zivoe-core-foundry/src/lockers/OCG/OCG_Defaults.sol";

contract Test_ZivoeGlobals is Utility {

    OCG_Defaults GenericDefaultsLocker;

    function setUp() public {
        deployCore(false);
    }

    // ----------------------
    //    Helper Functions
    // ----------------------

    function updatedDefaults(uint256 increaseBy, uint256 decreaseBy) public view returns (uint256 updated) { 
        updated = decreaseBy > increaseBy ? 0 : increaseBy - decreaseBy;
    }

    // ------------
    //    Events
    // ------------

    event TransferredZVL(address indexed controller);

    event DefaultsDecreased(address indexed locker, uint256 amount, uint256 updatedDefaults);

    event DefaultsIncreased(address indexed locker, uint256 amount, uint256 updatedDefaults);

    event UpdatedKeeperStatus(address indexed account, bool status);

    event UpdatedLockerStatus(address indexed locker, bool status);

    event UpdatedStablecoinWhitelist(address indexed asset, bool allowed);    

    // ------------
    //  Unit tests
    // ------------

    // Validate restrictions of decreaseDefaults() / increaseDefaults().
    // This includes:
    //  - _msgSender() must be a whitelisted ZivoeLocker.

    function test_ZivoeGlobals_decreaseDefaults_restrictions_direct() public {
        // Ensure non-whitelisted address may not call decrease default, directly via ZivoeGlobals.sol.
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeGlobals::decreaseDefaults() !isLocker[_msgSender()]");
        GBL.decreaseDefaults(100 ether);
        hevm.stopPrank();
    }

    function test_ZivoeGlobals_increaseDefaults_restrictions_direct() public {
        // Non-whitelisted address can not call increase default.
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeGlobals::increaseDefaults() !isLocker[_msgSender()]");
        GBL.increaseDefaults(100 ether);
        hevm.stopPrank();
    }

    // Validate restrictions on OCG_Defaults locker endpoints.
    
    function test_ZivoeGlobals_decreaseDefaults_restrictions_indirect() public {
        // Create OCG_Defaults locker, with default adjustment capability, add this to whitelist.
        GenericDefaultsLocker = new OCG_Defaults(address(DAO), address(GBL));
        assert(zvl.try_updateIsLocker(address(GBL), address(GenericDefaultsLocker), true));

        // Ensure the "onlyGovernance" modifier in OCG_Defaults::decreaseDefaults() prevents this call.
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCG_Defaults::onlyGovernance() _msgSender!= IZivoeGlobals_OCG_Defaults(GBL).TLC()");
        GenericDefaultsLocker.decreaseDefaults(100 ether);
        hevm.stopPrank();
    }

    function test_ZivoeGlobals_increaseDefaults_restrictions_indirect() public {
        // Create GenericDefaults locker, with default adjustment capability, add this to whitelist.
        GenericDefaultsLocker = new OCG_Defaults(address(DAO), address(GBL));
        assert(zvl.try_updateIsLocker(address(GBL), address(GenericDefaultsLocker), true));

        // Ensure the "onlyGovernance" modifier in OCG_Defaults::increaseDefaults() prevents this call.
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCG_Defaults::onlyGovernance() _msgSender!= IZivoeGlobals_OCG_Defaults(GBL).TLC()");
        GenericDefaultsLocker.increaseDefaults(100 ether);
        hevm.stopPrank();
    }
    
    // Validate state changes of increaseDefaults() / decreaseDefaults().

    function test_ZivoeGlobals_increase_or_decreaseDefaults_state(uint96 increaseAmount, uint96 decreaseAmount) public {
        
        uint256 increaseBy = uint256(increaseAmount);
        uint256 decreaseBy = uint256(decreaseAmount);

        // Create GenericDefaults locker, with default adjustment capability, add this to whitelist.
        GenericDefaultsLocker = new OCG_Defaults(address(DAO), address(GBL));

        hevm.expectEmit(true, false, false, true, address(GBL));
        emit UpdatedLockerStatus(address(GenericDefaultsLocker), true);
        assert(zvl.try_updateIsLocker(address(GBL), address(GenericDefaultsLocker), true));

        // Pre-state.
        assertEq(GBL.defaults(), 0);

        // increaseDefaults().
        hevm.expectEmit(true, false, false, true, address(GBL));
        emit DefaultsIncreased(address(GenericDefaultsLocker), increaseBy, increaseBy);
        assert(god.try_increaseDefaults(address(GenericDefaultsLocker), increaseBy));

        // Post-state, increaseDefaults().
        assertEq(GBL.defaults(), increaseBy);

        // decreaseDefaults().
        uint256 updated = updatedDefaults(increaseBy, decreaseBy);
        hevm.expectEmit(true, false, false, true, address(GBL));
        emit DefaultsDecreased(address(GenericDefaultsLocker), decreaseBy, updated);
        assert(god.try_decreaseDefaults(address(GenericDefaultsLocker), decreaseBy));

        // Post-state, decreaseDefaults().
        if (decreaseBy > increaseBy) {
            assertEq(GBL.defaults(), 0);
        }
        else {
            assertEq(GBL.defaults(), increaseBy - decreaseBy);
        }

    }
    
    // Validate restrictions updateIsKeeper() / updateIsLocker() / updateStablecoinWhitelist().
    // This includes:
    //  - _msgSender() MUST be "zvl"
    

    function test_ZivoeGlobals_updateIsKeeper_restrictions_onlyZVL() public {
        
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeGlobals::onlyZVL() _msgSender() != ZVL");
        GBL.updateIsKeeper(address(1), true);
        hevm.stopPrank();
    }

    function test_ZivoeGlobals_updateIsLocker_restrictions_onlyZVL() public {

        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeGlobals::onlyZVL() _msgSender() != ZVL");
        GBL.updateIsLocker(address(1), true);
        hevm.stopPrank();
    }

    function test_ZivoeGlobals_updateStablecoinWhitelist_restrictions_onlyZVL() public {

        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeGlobals::onlyZVL() _msgSender() != ZVL");
        GBL.updateStablecoinWhitelist(address(1), true);
        hevm.stopPrank();
    }

    // Validate state changes updateIsKeeper() / updateIsLocker() / updateStablecoinWhitelist().
    
    function test_ZivoeGlobals_onlyZVL_state(address entity) public {
        
        // updateIsKeeper() false => true.
        assert(!GBL.isKeeper(entity));

        hevm.expectEmit(true, false, false, true, address(GBL));
        emit UpdatedKeeperStatus(address(entity), true);

        assert(zvl.try_updateIsKeeper(address(GBL), address(entity), true));
        assert(GBL.isKeeper(entity));

        // updateIsKeeper() true => false.
        assert(GBL.isKeeper(entity));

        hevm.expectEmit(true, false, false, true, address(GBL));
        emit UpdatedKeeperStatus(address(entity), false);

        assert(zvl.try_updateIsKeeper(address(GBL), address(entity), false));
        assert(!GBL.isKeeper(entity));

        // updateIsLocker() false => true.
        assert(!GBL.isLocker(entity));

        hevm.expectEmit(true, false, false, true, address(GBL));
        emit UpdatedLockerStatus(address(entity), true);

        assert(zvl.try_updateIsLocker(address(GBL), address(entity), true));
        assert(GBL.isLocker(entity));

        // updateIsLocker() true => false.
        assert(GBL.isLocker(entity));

        hevm.expectEmit(true, false, false, true, address(GBL));
        emit UpdatedLockerStatus(address(entity), false);

        assert(zvl.try_updateIsLocker(address(GBL), address(entity), false));
        assert(!GBL.isLocker(entity));

        // updateStablecoinWhitelist() false => true.
        assert(!GBL.stablecoinWhitelist(entity));

        hevm.expectEmit(true, false, false, true, address(GBL));
        emit UpdatedStablecoinWhitelist(address(entity), true);

        assert(zvl.try_updateStablecoinWhitelist(address(GBL), address(entity), true));
        assert(GBL.stablecoinWhitelist(entity));

        // updateStablecoinWhitelist() true => false.
        assert(GBL.stablecoinWhitelist(entity));

        hevm.expectEmit(true, false, false, true, address(GBL));
        emit UpdatedStablecoinWhitelist(address(entity), false);

        assert(zvl.try_updateStablecoinWhitelist(address(GBL), address(entity), false));
        assert(!GBL.stablecoinWhitelist(entity));

    }

    // Validate various values for standardize() view function.

    function test_ZivoeGlobals_standardize_view(uint96 amount) public {

        uint256 conversionAmount = uint256(amount);

        // USDC 6 Decimals -> 18 Decimals
        // USDT 6 Decimals -> 18 Decimals
        (uint256 standardizedAmountUSDC) = GBL.standardize(conversionAmount, USDC);
        (uint256 standardizedAmountUSDT) = GBL.standardize(conversionAmount, USDT);

        assertEq(standardizedAmountUSDC, conversionAmount * 10**12);
        assertEq(standardizedAmountUSDT, conversionAmount * 10**12);

    }
    
}
