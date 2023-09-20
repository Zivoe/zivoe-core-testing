// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../Utility/Utility.sol";

import "../../lib/zivoe-core-foundry/src/lockers/OCT/OCT_DAO.sol";
import "../../lib/zivoe-core-foundry/src/lockers/OCT/OCT_YDL.sol";
import "../../lib/zivoe-core-foundry/src/lockers/OCY/OCY_Convex_A.sol";

import "../../lib/zivoe-core-foundry/lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract Test_OCY_Convex_A is Utility {

    using SafeERC20 for IERC20;

    OCY_Convex_A OCY_CVX_A;

    OCT_DAO TreasuryDAO;
    OCT_YDL TreasuryYDL;

    function setUp() public {

        deployCore(false);

        TreasuryDAO = new OCT_DAO(address(DAO), address(GBL));
        TreasuryYDL = new OCT_YDL(address(DAO), address(GBL));

        OCY_CVX_A = new OCY_Convex_A(address(DAO), address(GBL), address(TreasuryYDL));

        zvl.try_updateIsLocker(address(GBL), address(TreasuryDAO), true);
        zvl.try_updateIsLocker(address(GBL), address(TreasuryYDL), true);
        zvl.try_updateIsLocker(address(GBL), address(OCY_CVX_A), true);

    }
    
    event UpdatedOCTYDL(address indexed newOCT, address indexed oldOCT);

    // Validate intial state of OCY_Convex_A

    function test_OCY_Convex_A_init() public {

        assertEq(OCY_CVX_A.GBL(), address(GBL));
        assertEq(OCY_CVX_A.OCT_YDL(), address(TreasuryYDL));

        assertEq(OCY_CVX_A.FRAX(), 0x853d955aCEf822Db058eb8505911ED77F175b99e);
        assertEq(OCY_CVX_A.USDC(), 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        assertEq(OCY_CVX_A.alUSD(), 0xBC6DA0FE9aD5f3b0d58160288917AA56653660E9);
        assertEq(OCY_CVX_A.CRV(), 0xD533a949740bb3306d119CC777fa900bA034cd52);
        assertEq(OCY_CVX_A.CVX(), 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);

        assertEq(OCY_CVX_A.convexPoolToken(), 0xB30dA2376F63De30b42dC055C93fa474F31330A5);
        assertEq(OCY_CVX_A.convexDeposit(), 0xF403C135812408BFbE8713b5A23a04b3D48AAE31);
        assertEq(OCY_CVX_A.convexRewards(), 0x26598e3E511ADFadefD70ab2C3475Ff741741104);
        assertEq(OCY_CVX_A.convexPoolID(), 106);

        assertEq(OCY_CVX_A.curveBasePool(), 0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2);
        assertEq(OCY_CVX_A.curveBasePoolToken(), 0x3175Df0976dFA876431C2E9eE6Bc45b65d3473CC);
        assertEq(OCY_CVX_A.curveMetaPool(), 0xB30dA2376F63De30b42dC055C93fa474F31330A5);

    }

    // Validate pushToLocker() state changes.
    // Validate pushToLocker() restrictions.
    // This includes:
    //   - onlyOwner() modifier
    //   - asset must be FRAX, USDC, or alUSD

    function test_OCY_Convex_A_pushToLocker_restrictions_msgSender() public {

        // Can't push to contract if _msgSender() != owner()
        hevm.startPrank(address(bob));
        hevm.expectRevert("Ownable: caller is not the owner");
        OCY_CVX_A.pushToLocker(address(DAI), 100 ether, "");
        hevm.stopPrank();
    }

    function test_OCY_Convex_A_pushToLocker_restrictions_asset() public {
        
        deal(USDT, address(DAO), 100 ether);

        // Can't push to contract if asset != FRAX && asset != USDC && asset != alUSD
        hevm.startPrank(address(god));
        hevm.expectRevert("OCY_Convex_A::pushToLocker() asset != FRAX && asset != USDC && asset != alUSD");
        DAO.push(address(OCY_CVX_A), USDT, 100 ether, "");
        hevm.stopPrank();
    }

    function test_OCY_Convex_A_pushToLocker_state_FRAX(uint96 amountFRAX) public {

        hevm.assume(amountFRAX > 1_000 ether && amountFRAX < 10_000_000 ether);

        // pushToLocker().
        deal(FRAX, address(DAO), amountFRAX);
        assert(god.try_push(address(DAO), address(OCY_CVX_A), FRAX, amountFRAX, abi.encode(0, 0)));

        // Post-state.
        assertGt(IERC20(OCY_CVX_A.convexRewards()).balanceOf(address(OCY_CVX_A)), 0);

    }

    function test_OCY_Convex_A_pushToLocker_state_USDC(uint96 amountUSDC) public {

        hevm.assume(amountUSDC > 1_000 * 10**6 && amountUSDC < 10_000_000 * 10**6);

        // pushToLocker().
        deal(USDC, address(DAO), amountUSDC);
        assert(god.try_push(address(DAO), address(OCY_CVX_A), USDC, amountUSDC, abi.encode(0, 0)));

        // Post-state.
        assertGt(IERC20(OCY_CVX_A.convexRewards()).balanceOf(address(OCY_CVX_A)), 0);

    }

    function test_OCY_Convex_A_pushToLocker_state_alUSD(uint96 amountalUSD) public {

        hevm.assume(amountalUSD > 1_000 ether && amountalUSD < 10_000_000 ether);

        // pushToLocker().
        deal(alUSD, address(DAO), amountalUSD);
        assert(god.try_push(address(DAO), address(OCY_CVX_A), alUSD, amountalUSD, abi.encode(0, 0)));

        // Post-state.
        assertGt(IERC20(OCY_CVX_A.convexRewards()).balanceOf(address(OCY_CVX_A)), 0);

    }

    // Validate pullFromLocker() state changes.
    // Validate pullFromLocker() restrictions.
    // This includes:
    //   - asset must be convexPoolToken
    //   - onlyOwner() modifier

    function test_OCY_Convex_A_pullFromLocker_restrictions_msgSender() public {

        // Can't push to contract if _msgSender() != owner()
        hevm.startPrank(address(bob));
        hevm.expectRevert("Ownable: caller is not the owner");
        DAO.pull(address(OCY_CVX_A), USDT, "");
        hevm.stopPrank();
    }

    function test_OCY_Convex_A_pullFromLocker_restrictions_asset() public {
        
        // Can't pull if asset != convexPoolToken
        hevm.startPrank(address(god));
        hevm.expectRevert("OCY_Convex_A::pullFromLocker() asset != convexPoolToken");
        DAO.pull(address(OCY_CVX_A), USDT, "");
        hevm.stopPrank();
    }

    function test_OCY_Convex_A_pullFromLocker_state_alUSD(uint96 amountalUSD) public {

        hevm.assume(amountalUSD > 1_000 ether && amountalUSD < 10_000_000 ether);

        // pushToLocker().
        deal(alUSD, address(DAO), amountalUSD);
        assert(god.try_push(address(DAO), address(OCY_CVX_A), alUSD, amountalUSD, abi.encode(0, 0)));

        // pullFromLocker().
        hevm.startPrank(address(god));
        DAO.pull(address(OCY_CVX_A), OCY_CVX_A.convexPoolToken(), abi.encode(0, 0, 0, 0));
        hevm.stopPrank();

        assertEq(IERC20(OCY_CVX_A.convexRewards()).balanceOf(address(OCY_CVX_A)), 0);
    }

    function test_OCY_Convex_A_pullFromLocker_state_FRAX(uint96 amountFRAX) public {

        hevm.assume(amountFRAX > 1_000 ether && amountFRAX < 10_000_000 ether);

        // pushToLocker().
        deal(FRAX, address(DAO), amountFRAX);
        assert(god.try_push(address(DAO), address(OCY_CVX_A), FRAX, amountFRAX, abi.encode(0, 0)));

        // pullFromLocker().
        hevm.startPrank(address(god));
        DAO.pull(address(OCY_CVX_A), OCY_CVX_A.convexPoolToken(), abi.encode(0, 0, 0, 0));
        hevm.stopPrank();

        assertEq(IERC20(OCY_CVX_A.convexRewards()).balanceOf(address(OCY_CVX_A)), 0);
    }

    function test_OCY_Convex_A_pullFromLocker_state_USDC(uint96 amountUSDC) public {

        hevm.assume(amountUSDC > 1_000 * 10**6 && amountUSDC < 10_000_000 * 10**6);

        // pushToLocker().
        deal(USDC, address(DAO), amountUSDC);
        assert(god.try_push(address(DAO), address(OCY_CVX_A), USDC, amountUSDC, abi.encode(0, 0)));

        // pullFromLocker().
        hevm.startPrank(address(god));
        DAO.pull(address(OCY_CVX_A), OCY_CVX_A.convexPoolToken(), abi.encode(0, 0, 0, 0));
        hevm.stopPrank();

        assertEq(IERC20(OCY_CVX_A.convexRewards()).balanceOf(address(OCY_CVX_A)), 0);
    }

    // Validate pullFromLockerPartial() state changes.
    // Validate pullFromLockerPartial() restrictions.
    // This includes:
    //   - asset must be convexPoolToken
    //   - onlyOwner() modifier

    function test_OCY_Convex_A_pullFromLockerPartial_restrictions_msgSender() public {

        // Can't push to contract if _msgSender() != owner()
        hevm.startPrank(address(bob));
        hevm.expectRevert("Ownable: caller is not the owner");
        DAO.pullPartial(address(OCY_CVX_A), USDT, 5, "");
        hevm.stopPrank();
    }

    function test_OCY_Convex_A_pullFromLockerPartial_restrictions_asset() public {
        
        // Can't pull if asset != convexPoolToken
        hevm.startPrank(address(god));
        hevm.expectRevert("OCY_Convex_A::pullFromLockerPartial() asset != convexPoolToken");
        DAO.pullPartial(address(OCY_CVX_A), USDT, 5, "");
        hevm.stopPrank();
    }

    function test_OCY_Convex_A_pullFromLockerPartial_state_alUSD(uint96 amountalUSD, uint96 amountPull) public {

        hevm.assume(amountalUSD > 1_000 ether && amountalUSD < 10_000_000 ether);
        hevm.assume(amountPull > 100 ether);

        // pushToLocker().
        deal(alUSD, address(DAO), amountalUSD);
        assert(god.try_push(address(DAO), address(OCY_CVX_A), alUSD, amountalUSD, abi.encode(0, 0)));

        uint256 preRewardsTokens = IERC20(OCY_CVX_A.convexRewards()).balanceOf(address(OCY_CVX_A));

        // pullFromLocker().
        hevm.startPrank(address(god));
        DAO.pullPartial(address(OCY_CVX_A), OCY_CVX_A.convexPoolToken(), amountPull % preRewardsTokens, abi.encode(0, 0, 0, 0));
        hevm.stopPrank();

        assertLt(IERC20(OCY_CVX_A.convexRewards()).balanceOf(address(OCY_CVX_A)), preRewardsTokens);
        
    }

    function test_OCY_Convex_A_pullFromLockerPartial_state_FRAX(uint96 amountFRAX, uint96 amountPull) public {

        hevm.assume(amountFRAX > 1_000 ether && amountFRAX < 10_000_000 ether);
        hevm.assume(amountPull > 100 ether);

        // pushToLocker().
        deal(FRAX, address(DAO), amountFRAX);
        assert(god.try_push(address(DAO), address(OCY_CVX_A), FRAX, amountFRAX, abi.encode(0, 0)));

        uint256 preRewardsTokens = IERC20(OCY_CVX_A.convexRewards()).balanceOf(address(OCY_CVX_A));

        // pullFromLocker().
        hevm.startPrank(address(god));
        DAO.pullPartial(address(OCY_CVX_A), OCY_CVX_A.convexPoolToken(), amountPull % preRewardsTokens, abi.encode(0, 0, 0, 0));
        hevm.stopPrank();

        assertLt(IERC20(OCY_CVX_A.convexRewards()).balanceOf(address(OCY_CVX_A)), preRewardsTokens);
        
    }

    function test_OCY_Convex_A_pullFromLockerPartial_state_USDC(uint96 amountUSDC, uint96 amountPull) public {

        hevm.assume(amountUSDC > 1_000 * 10**6 && amountUSDC < 10_000_000 * 10**6);
        hevm.assume(amountPull > 100 * 10**6);

        // pushToLocker().
        deal(USDC, address(DAO), amountUSDC);
        assert(god.try_push(address(DAO), address(OCY_CVX_A), USDC, amountUSDC, abi.encode(0, 0)));

        uint256 preRewardsTokens = IERC20(OCY_CVX_A.convexRewards()).balanceOf(address(OCY_CVX_A));

        // pullFromLocker().
        hevm.startPrank(address(god));
        DAO.pullPartial(address(OCY_CVX_A), OCY_CVX_A.convexPoolToken(), amountPull % preRewardsTokens, abi.encode(0, 0, 0, 0));
        hevm.stopPrank();

        assertLt(IERC20(OCY_CVX_A.convexRewards()).balanceOf(address(OCY_CVX_A)), preRewardsTokens);
        
    }

    // Validate claimRewards() state changes.
    
    function test_OCY_Convex_A_claimRewards_state(uint96 amountFRAX) public {

        hevm.assume(amountFRAX > 1_000 ether && amountFRAX < 10_000_000 ether);

        // pushToLocker().
        deal(FRAX, address(DAO), amountFRAX);
        assert(god.try_push(address(DAO), address(OCY_CVX_A), FRAX, amountFRAX, abi.encode(0, 0)));

        // Post-state.
        assertGt(IERC20(OCY_CVX_A.convexRewards()).balanceOf(address(OCY_CVX_A)), 0);

        hevm.warp(block.timestamp + 7 days);

        uint256 preCRV = IERC20(CRV).balanceOf(address(TreasuryYDL));
        uint256 preCVX = IERC20(CVX).balanceOf(address(TreasuryYDL));

        OCY_CVX_A.claimRewards(true);

        assertGt(IERC20(CRV).balanceOf(address(TreasuryYDL)), preCRV);
        assertGt(IERC20(CVX).balanceOf(address(TreasuryYDL)), preCVX);

    }

    // Validate updateOCTYDL() state changes.
    // Validate updateOCTYDL() restrictions.
    // This includes:
    //   - _msgSender() must be ZVL

    function test_OCY_Convex_A_updateOCTYDL_restrictions_msgSender() public {

        // Can't call if _msgSender() is not ZVL.
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCY_Convex_A::updateOCTYDL() _msgSender() != IZivoeGlobals_OCY_Convex_A(GBL).ZVL()");
        OCY_CVX_A.updateOCTYDL(address(bob));
        hevm.stopPrank();
    }

    function test_OCY_Convex_A_updateOCTYDLL_state(address fuzzed) public {
        
        // Pre-state.
        assertEq(OCY_CVX_A.OCT_YDL(), address(TreasuryYDL));

        // updateOCTYDL().
        hevm.expectEmit(true, true, false, false, address(OCY_CVX_A));
        emit UpdatedOCTYDL(address(fuzzed), address(TreasuryYDL));
        hevm.startPrank(address(zvl));
        OCY_CVX_A.updateOCTYDL(address(fuzzed));
        hevm.stopPrank();

        // Post-state.
        assertEq(OCY_CVX_A.OCT_YDL(), address(fuzzed));

    }

}