// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

import "lib/zivoe-core-foundry/src/lockers/OCG/OCG_Defaults.sol";

contract Test_ZivoeGlobals is Utility {

    OCG_Defaults GenericDefaultsLocker;

    function setUp() public {
        deployCore(false);
    }

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

    // For additional testing purposes, validate restrictions on OCG_Defaults locker endpoints.
    
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
        assert(zvl.try_updateIsLocker(address(GBL), address(GenericDefaultsLocker), true));

        // Pre-state.
        assertEq(GBL.defaults(), 0);

        // increaseDefaults().
        assert(god.try_increaseDefaults(address(GenericDefaultsLocker), increaseBy));

        // Post-state, increaseDefaults().
        assertEq(GBL.defaults(), increaseBy);

        // decreaseDefaults().
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
    // Validate state changes updateIsKeeper() / updateIsLocker() / updateStablecoinWhitelist().
    // Note: These functions are managed by Zivoe Lab / Dev entity ("ZVL").

    function test_ZivoeGlobals_restrictions_onlyZVL_updateIsKeeper() public {
        
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeGlobals::onlyZVL() _msgSender() != ZVL");
        GBL.updateIsKeeper(address(1), true);
        hevm.stopPrank();
    }

    function test_ZivoeGlobals_restrictions_onlyZVL_updateIsLocker() public {

        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeGlobals::onlyZVL() _msgSender() != ZVL");
        GBL.updateIsLocker(address(1), true);
        hevm.stopPrank();
    }

    function test_ZivoeGlobals_restrictions_onlyZVL_updateStablecoinWhitelist() public {

        assert(!bob.try_updateStablecoinWhitelist(address(GBL), address(3), true));
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeGlobals::onlyZVL() _msgSender() != ZVL");
        GBL.updateStablecoinWhitelist(address(1), true);
        hevm.stopPrank();
    }

    function test_ZivoeGlobals_onlyZVL_state(address entity) public {
        
        // updateIsKeeper() false => true.
        assert(!GBL.isKeeper(entity));
        assert(zvl.try_updateIsKeeper(address(GBL), address(entity), true));
        assert(GBL.isKeeper(entity));

        // updateIsLocker() false => true.
        assert(!GBL.isLocker(entity));
        assert(zvl.try_updateIsLocker(address(GBL), address(entity), true));
        assert(GBL.isLocker(entity));

        // updateStablecoinWhitelist() false => true.
        assert(!GBL.stablecoinWhitelist(entity));
        assert(zvl.try_updateStablecoinWhitelist(address(GBL), address(entity), true));
        assert(GBL.stablecoinWhitelist(entity));

        // updateIsKeeper() true => false.
        assert(GBL.isKeeper(entity));
        assert(zvl.try_updateIsKeeper(address(GBL), address(entity), false));
        assert(!GBL.isKeeper(entity));

        // updateIsLocker() true => false.
        assert(GBL.isLocker(entity));
        assert(zvl.try_updateIsLocker(address(GBL), address(entity), false));
        assert(!GBL.isLocker(entity));

        // updateStablecoinWhitelist() true => false.
        assert(GBL.stablecoinWhitelist(entity));
        assert(zvl.try_updateStablecoinWhitelist(address(GBL), address(entity), false));
        assert(!GBL.stablecoinWhitelist(entity));

    }

    
    // TODO: Experiment various values for two following functions.

    function test_ZivoeGlobals_standardize_view() public {
        
    }

    function test_ZivoeGlobals_adjustedSupplies_view() public {
        
    }
    
}
