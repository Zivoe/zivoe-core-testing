// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.17;

import "../Utility/Utility.sol";

import "../../lib/zivoe-core-foundry/src/lockers/OCT/OCT_DAO.sol";
import "../../lib/zivoe-core-foundry/src/lockers/OCT/OCT_YDL.sol";
import "../../lib/zivoe-core-foundry/src/lockers/OCY/OCY_Convex_B.sol";

import "../../lib/zivoe-core-foundry/lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract Test_OCY_Convex_B is Utility {

    using SafeERC20 for IERC20;

    OCY_Convex_B OCY_CVX_B;

    OCT_DAO TreasuryDAO;
    OCT_YDL TreasuryYDL;

    function setUp() public {

        deployCore(false);

        TreasuryDAO = new OCT_DAO(address(DAO), address(GBL));
        TreasuryYDL = new OCT_YDL(address(DAO), address(GBL));

        OCY_CVX_B = new OCY_Convex_B(address(DAO), address(GBL), address(TreasuryYDL));

        zvl.try_updateIsLocker(address(GBL), address(TreasuryDAO), true);
        zvl.try_updateIsLocker(address(GBL), address(TreasuryYDL), true);
        zvl.try_updateIsLocker(address(GBL), address(OCY_CVX_B), true);

    }
    
    event OCTYDLSetZVL(address indexed newOCT, address indexed oldOCT);

    // Validate intial state of OCY_Convex_B

    function test_OCY_Convex_B_init() public {

        assertEq(OCY_CVX_B.GBL(), address(GBL));
        assertEq(OCY_CVX_B.distributionLast(), block.timestamp);
        assertEq(OCY_CVX_B.INTERVAL(), 14 days);

    }

    // Validate pushToLocker() state changes.
    // Validate pushToLocker() restrictions.
    // This includes:
    //   - asset must be OUSD
    //   - onlyOwner() modifier

    function test_OCY_Convex_B_pushToLocker_restrictions_msgSender() public {

        // Can't push to contract if _msgSender() != owner()
        // hevm.startPrank(address(bob));
        // hevm.expectRevert("Ownable: caller is not the owner");
        // OUSDLocker.pushToLocker(address(OUSD), 100 ether, "");
        // hevm.stopPrank();
    }

    function test_OCY_Convex_B_pushToLocker_restrictions_asset() public {
        
        // Can't push to contract if asset != OUSD
        // hevm.startPrank(address(DAO));
        // hevm.expectRevert("OCY_OUSD::pushToLocker() asset != OUSD");
        // OUSDLocker.pushToLocker(address(ZVE), 100 ether, "");
        // hevm.stopPrank();
    }

    function test_OCY_Convex_B_pushToLocker_state() public {

        // pushToLocker().
        // hevm.expectEmit(false, false, false, true, address(OUSDLocker));
        // emit BasisAdjusted(0, balanceOUSD);
        // assert(god.try_push(address(DAO), address(OUSDLocker), OUSD, balanceOUSD, ""));

        // Post-state.
        // assertEq(balanceOUSD, IERC20(OUSD).balanceOf(address(OUSDLocker)));
        // assertEq(OUSDLocker.basis(), IERC20(OUSD).balanceOf(address(OUSDLocker)));

    }

    // Validate pullFromLocker() state changes.
    // Validate pullFromLocker() restrictions.
    // This includes:
    //   - asset must be OUSD
    //   - onlyOwner() modifier

    function test_OCY_Convex_B_pullFromLocker_restrictions_msgSender() public {

        // Can't push to contract if _msgSender() != owner()
        // hevm.startPrank(address(bob));
        // hevm.expectRevert("Ownable: caller is not the owner");
        // OUSDLocker.pullFromLocker(address(OUSD), "");
        // hevm.stopPrank();

    }

    function test_OCY_Convex_B_pullFromLocker_restrictions_asset() public {
        
        // Can't push to contract if asset != OUSD
        // hevm.startPrank(address(DAO));
        // hevm.expectRevert("OCY_OUSD::pullFromLocker() asset != OUSD");
        // OUSDLocker.pullFromLocker(address(ZVE), "");
        // hevm.stopPrank();
    }

    function test_OCY_Convex_B_pullFromLocker_state() public {

        // pullFromLocker().
        // hevm.expectEmit(false, false, false, true, address(OUSDLocker));
        // emit BasisAdjusted(balanceOUSD, 0);
        // assert(god.try_pull(address(DAO), address(OUSDLocker), OUSD, ""));

        // Post-state.
        // assertEq(balanceOUSD, IERC20(OUSD).balanceOf(address(DAO)));
        // assertEq(OUSDLocker.basis(), 0);

    }

    // Validate pullFromLockerPartial() state changes.
    // Validate pullFromLockerPartial() restrictions.
    // This includes:
    //   - asset must be OUSD
    //   - onlyOwner() modifier

    function test_OCY_Convex_B_pullFromLockerPartial_restrictions_msgSender() public {

    }

    function test_OCY_Convex_B_pullFromLockerPartial_restrictions_asset() public {
        
    }

    function test_OCY_Convex_B_pullFromLockerPartial_state(uint96 random) public {
        
    }

    // Validate claimRewards() state changes.
    // Validate claimRewards() restrictions.
    // This includes:
    //   - Must be past the INTERVAL

    function test_OCY_Convex_B_claimRewards_restrictions_interval(uint96 random) public {

    }

    function test_OCY_Convex_B_claimRewards_state(uint96 random) public {

    }

    // Validate setOCTYDL() state changes.
    // Validate setOCTYDL() restrictions.
    // This includes:
    //   - _msgSender() must be ZVL

    function test_OCY_Convex_B_setOCTYDL_restrictions_msgSender() public {

        // Can't call if _msgSender() is not ZVL.
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCY_Convex_B::setOCTYDL() _msgSender() != IZivoeGlobals_OCY_Convex_B(GBL).ZVL()");
        OCY_CVX_B.setOCTYDL(address(bob));
        hevm.stopPrank();
    }

    function test_OCY_Convex_B_setOCTYDL_state(address fuzzed) public {
        
        // Pre-state.
        assertEq(OCY_CVX_B.OCT_YDL(), address(TreasuryYDL));

        // setOCTYDL().
        hevm.expectEmit(true, true, false, false, address(OCY_CVX_B));
        emit OCTYDLSetZVL(address(fuzzed), address(TreasuryYDL));
        hevm.startPrank(address(zvl));
        OCY_CVX_B.setOCTYDL(address(fuzzed));
        hevm.stopPrank();

        // Post-state.
        assertEq(OCY_CVX_B.OCT_YDL(), address(fuzzed));

    }

}