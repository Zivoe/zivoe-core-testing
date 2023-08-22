// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../Utility/Utility.sol";

contract Test_ZivoeTrancheToken is Utility {

    ZivoeTrancheToken zTT;

    function setUp() public {

        // Launch a new ZivoeTrancheToken contract.
        zTT = new ZivoeTrancheToken("ZivoeTrancheToken", "zTT");

    }

    function test_ZivoeTrancheToken_burn_state(uint96 random) public {

        // Give address(this) minting privlidges and mint some for testing burn().
        zTT.changeMinterRole(address(this), true);
        zTT.mint(address(this), uint256(random));

        // Pre-state.
        assertEq(zTT.totalSupply(), uint256(random));
        assertEq(zTT.balanceOf(address(this)), uint256(random));

        // burn().
        zTT.burn(uint256(random));

        // Post-state.
        assertEq(zTT.totalSupply(), 0);
        assertEq(zTT.balanceOf(address(this)), 0);

    }

    function test_ZivoeTrancheToken_mint_restrictions() public {
        // Can't mint unless isMinterRole().
        hevm.startPrank(address(bob));
        hevm.expectRevert("ZivoeTrancheToken::isMinterRole() !_isMinter[_msgSender()]");
        zTT.mint(address(this), 100);
        hevm.stopPrank();
    }

    function test_ZivoeTrancheToken_mint_state(uint96 random) public {

        // Give address(this) minting privlidges and mint some for testing burn().
        zTT.changeMinterRole(address(this), true);

        // Pre-state.
        assertEq(zTT.totalSupply(), 0);
        assertEq(zTT.balanceOf(address(this)), 0);

        // mint().
        zTT.mint(address(this), uint256(random));

        // Post-state.
        assertEq(zTT.totalSupply(), uint256(random));
        assertEq(zTT.balanceOf(address(this)), uint256(random));

    }

    function test_ZivoeTrancheToken_changeMinterRole_restrictions() public {
        // Can't update isMinterRole() unless _owner().
        hevm.startPrank(address(bob));
        hevm.expectRevert("Ownable: caller is not the owner");
        zTT.changeMinterRole(address(bob), true);
        hevm.stopPrank();
    }

    /// @notice This event is emitted when changeMinterRole() is called.
    /// @param  account The account who is receiving or losing the minter role.
    /// @param  allowed If true, the account is receiving minter role privlidges, if false the account is losing minter role privlidges.
    event MinterUpdated(address indexed account, bool allowed);

    function test_ZivoeTrancheToken_changeMinterRole_state() public {

        // Pre-state.
        assert(!zTT.isMinter(address(this)));
        
        // mint().
        hevm.expectEmit(true, false, false, true, address(zTT));
        emit MinterUpdated(address(this), true);
        zTT.changeMinterRole(address(this), true);

        // Post-state.
        assert(zTT.isMinter(address(this)));

    }
    
}
