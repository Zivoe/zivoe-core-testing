// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../Utility/Utility.sol";

contract Test_ZivoeRewardsVesting is Utility {

    function setUp() public {
        deployCore(false);
    }

    // Validate createVestingSchedule() restrictions.
    //  - Restricting vest if account has deposited to ITO.

    function test_ZivoeRewardsVesting_vest_restrictions_itoDepositSenior() public {
        
        zvl.try_commence(address(ITO));
        hevm.warp(ITO.end() - 30 days + 1 seconds);

        mint("DAI", address(sam), 100 ether);
        assert(sam.try_approveToken(DAI, address(ITO), 100 ether));
        assert(sam.try_depositSenior(address(ITO), 100 ether, DAI));

        // Can't call vest if deposited to ITO.
        hevm.startPrank(address(zvl));
        hevm.expectRevert("ZivoeRewardsVesting::createVestingSchedule() seniorCredits(_msgSender) > 0 || juniorCredits(_msgSender) > 0");
        vestZVE.createVestingSchedule(address(sam), 30, 90, 100 ether, false);
        hevm.stopPrank();
    }

    function test_ZivoeRewardsVesting_vest_restrictions_itoDepositJunior() public {
        
        zvl.try_commence(address(ITO));
        hevm.warp(ITO.end() - 30 days + 1 seconds);

        mint("DAI", address(jim), 100 ether);
        assert(jim.try_approveToken(DAI, address(ITO), 100 ether));
        assert(jim.try_depositSenior(address(ITO), 100 ether, DAI));

        mint("DAI", address(jim), 20 ether);
        assert(jim.try_approveToken(DAI, address(ITO), 20 ether));
        assert(jim.try_depositJunior(address(ITO), 20 ether, DAI));

        // Can't call vest if deposited to ITO.
        hevm.startPrank(address(zvl));
        hevm.expectRevert("ZivoeRewardsVesting::createVestingSchedule() seniorCredits(_msgSender) > 0 || juniorCredits(_msgSender) > 0");
        vestZVE.createVestingSchedule(address(jim), 30, 90, 100 ether, false);
        hevm.stopPrank();
    }    
    
}
