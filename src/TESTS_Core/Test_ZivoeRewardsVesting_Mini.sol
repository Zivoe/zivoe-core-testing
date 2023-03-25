// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;

import "../TESTS_Utility/Utility.sol";

contract Test_ZivoeRewardsVesting is Utility {

    function setUp() public {
        deployCore(false);
    }

    // Validate vest() restrictions.
    //  - Restricting vest if user has deposited to ITO.

    function test_ZivoeRewardsVesting_vest_restrictions_itoDepositSenior() public {
        
        hevm.warp(ITO.start() + 1 seconds);

        mint("DAI", address(sam), 100 ether);
        assert(sam.try_approveToken(DAI, address(ITO), 100 ether));
        assert(sam.try_depositSenior(address(ITO), 100 ether, DAI));

        // Can't call vest if deposited to ITO.
        hevm.startPrank(address(zvl));
        hevm.expectRevert("ZivoeRewardsVesting::vest() seniorCredits(_msgSender) > 0 || juniorCredits(_msgSender) > 0");
        vestZVE.vest(address(sam), 30, 90, 100 ether, false);
        hevm.stopPrank();
    }

    function test_ZivoeRewardsVesting_vest_restrictions_itoDepositJunior() public {
        
        hevm.warp(ITO.start() + 1 seconds);

        mint("DAI", address(jim), 100 ether);
        assert(jim.try_approveToken(DAI, address(ITO), 100 ether));
        assert(jim.try_depositJunior(address(ITO), 100 ether, DAI));

        // Can't call vest if deposited to ITO.
        hevm.startPrank(address(zvl));
        hevm.expectRevert("ZivoeRewardsVesting::vest() seniorCredits(_msgSender) > 0 || juniorCredits(_msgSender) > 0");
        vestZVE.vest(address(jim), 30, 90, 100 ether, false);
        hevm.stopPrank();
    }    
    
}
