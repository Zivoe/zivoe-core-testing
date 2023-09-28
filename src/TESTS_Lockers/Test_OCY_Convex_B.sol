// SPDX-License-Identifier: UNLICENSED
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

    // Events.

    event Logger(address);
    
    event UpdatedOCTYDL(address indexed newOCT, address indexed oldOCT);

    // Helper function.

    function acquire_sUSD_DAO() public {

        address assetIn = USDC;
        address assetOut = sUSD;
        uint256 amountIn = 1_000_000 * 10**6;

        // 1,000,000 USDC -> sUSD
        bytes memory dataSwap =
        hex"12aa3caf000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd09000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000057ab1ec28d129707052df4df418d58a2d46d5f51000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd09000000000000000000000000883816205341a6ba3c32ae8dadcebdd9d59bc2c4000000000000000000000000000000000000000000000000000000e8d4a5100000000000000000000000000000000000000000000000268fa5bb84562a2d981a000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000001400000000000000000000000000000000000000000000000000000000000000160000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b800000000000000000000000000000000000000000000000000029a00026c00a007e5c0d200000000000000000000000000000000000000000000000000024800012400a0c9e75c48000000000000000029090000000000000000000000000000000000000000000000000000f600007b0c20a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48397ff1542f962076d0bfe58ea045ffa2d347aca06ae4071198002dc6c0397ff1542f962076d0bfe58ea045ffa2d347aca0000000000000000000000000000000000000000000000005e31f9953baa21da5a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480c20a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48b4e16d0168e52d35cacd2c6185b44281ec28c9dc6ae4071198002dc6c0b4e16d0168e52d35cacd2c6185b44281ec28c9dc00000000000000000000000000000000000000000000001ac9da32ae7ffc44d6a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800a0c9e75c4800000000000000001c160000000000000000000000000000000000000000000000000000f600007b0c20c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2f80758ab42c3b07da84053fd88804bcb6baa4b5c6ae4071118002dc6c0f80758ab42c3b07da84053fd88804bcb6baa4b5c0000000000000000000000000000000000000000000010c0da94d0029a03a57bc02aaa39b223fe8d0a0e5c4f27ead9083c756cc20c20c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2f1f85b2c54a2bd284b1cf4141d64fd171bd855396ae4071118002dc6c0f1f85b2c54a2bd284b1cf4141d64fd171bd855390000000000000000000000000000000000000000000015cecb26b4539029f29ec02aaa39b223fe8d0a0e5c4f27ead9083c756cc280a06c4eca2757ab1ec28d129707052df4df418d58a2d46d5f511111111254eeb25477b68fb85ed929f73a96058200000000000000008b1ccac8";
        
        // fund contract with the right amount of tokens to swap.
        deal(assetIn, address(TreasuryDAO), amountIn);

        emit log_named_uint("TreasuryDAO assetIn pre-swap balance:", IERC20(assetIn).balanceOf(address(TreasuryDAO)));
        emit log_named_uint("TreasuryDAO assetOut pre-swap balance:", IERC20(assetOut).balanceOf(address(TreasuryDAO)));
        emit Logger(address(TreasuryDAO));
        
        assert(zvl.try_updateIsKeeper(address(GBL), address(this), true));
        TreasuryDAO.convertAndForward(assetIn, assetOut, dataSwap);

        emit log_named_uint("TreasuryDAO assetIn after-swap balance:", IERC20(assetIn).balanceOf(address(TreasuryDAO)));
        emit log_named_uint("TreasuryDAO assetOut after-swap balance:", IERC20(assetOut).balanceOf(address(DAO)));

        // assert balances after swap are correct.
        assertEq(0, IERC20(assetIn).balanceOf(address(TreasuryDAO)));
        assert(IERC20(assetOut).balanceOf(address(DAO)) > 0);

    }


    // Validate intial state of OCY_Convex_B

    function test_OCY_Convex_B_init() public {

        assertEq(OCY_CVX_B.GBL(), address(GBL));
        assertEq(OCY_CVX_B.OCT_YDL(), address(TreasuryYDL));

        assertEq(OCY_CVX_B.DAI(), 0x6B175474E89094C44Da98b954EedeAC495271d0F);
        assertEq(OCY_CVX_B.USDC(), 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        assertEq(OCY_CVX_B.USDT(), 0xdAC17F958D2ee523a2206206994597C13D831ec7);
        assertEq(OCY_CVX_B.sUSD(), 0x57Ab1ec28D129707052df4dF418D58a2D46d5f51);
        assertEq(OCY_CVX_B.CRV(), 0xD533a949740bb3306d119CC777fa900bA034cd52);
        assertEq(OCY_CVX_B.CVX(), 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);

        assertEq(OCY_CVX_B.convexPoolToken(), 0xC25a3A3b969415c80451098fa907EC722572917F);
        assertEq(OCY_CVX_B.convexDeposit(), 0xF403C135812408BFbE8713b5A23a04b3D48AAE31);
        assertEq(OCY_CVX_B.convexRewards(), 0x22eE18aca7F3Ee920D01F25dA85840D12d98E8Ca);
        assertEq(OCY_CVX_B.convexPoolID(), 4);

        assertEq(OCY_CVX_B.curveBasePool(), 0xA5407eAE9Ba41422680e2e00537571bcC53efBfD);
        assertEq(OCY_CVX_B.curveBasePoolToken(), 0xC25a3A3b969415c80451098fa907EC722572917F);

    }

    // Validate pushToLocker() state changes.
    // Validate pushToLocker() restrictions.
    // This includes:
    //   - asset must be DAI, USDC, USDT, or sUSD
    //   - onlyOwner() modifier

    function test_OCY_Convex_B_pushToLocker_restrictions_msgSender() public {

        // Can't push to contract if _msgSender() != owner()
        hevm.startPrank(address(bob));
        hevm.expectRevert("Ownable: caller is not the owner");
        OCY_CVX_B.pushToLocker(address(DAI), 100 ether, "");
        hevm.stopPrank();
    }

    function test_OCY_Convex_B_pushToLocker_restrictions_asset() public {
        
        deal(FRAX, address(DAO), 100 ether);

        // Can't push to contract if asset != DAI && asset != USDC && asset != USDT && asset != sUSD
        hevm.startPrank(address(god));
        hevm.expectRevert("OCY_Convex_B::pushToLocker() asset != DAI && asset != USDC && asset != USDT && asset != sUSD");
        DAO.push(address(OCY_CVX_B), FRAX, 100 ether, abi.encode(0));
        hevm.stopPrank();
    }

    function test_OCY_Convex_B_pushToLocker_state_DAI(uint96 amountDAI) public {

        hevm.assume(amountDAI > 1_000 ether && amountDAI < 10_000_000 ether);

        // pushToLocker().
        deal(DAI, address(DAO), amountDAI);
        assert(god.try_push(address(DAO), address(OCY_CVX_B), DAI, amountDAI, abi.encode(0)));

        // Post-state.
        assertGt(IERC20(OCY_CVX_B.convexRewards()).balanceOf(address(OCY_CVX_B)), 0);

    }

    function test_OCY_Convex_B_pushToLocker_state_USDC(uint96 amountUSDC) public {

        hevm.assume(amountUSDC > 1_000 * 10**6 && amountUSDC < 10_000_000 * 10**6);

        // pushToLocker().
        deal(USDC, address(DAO), amountUSDC);
        assert(god.try_push(address(DAO), address(OCY_CVX_B), USDC, amountUSDC, abi.encode(0)));

        // Post-state.
        assertGt(IERC20(OCY_CVX_B.convexRewards()).balanceOf(address(OCY_CVX_B)), 0);

    }

    function test_OCY_Convex_B_pushToLocker_state_USDT(uint96 amountUSDT) public {

        hevm.assume(amountUSDT > 1_000 * 10**6 && amountUSDT < 10_000_000 * 10**6);

        // pushToLocker().
        deal(USDT, address(DAO), amountUSDT);
        assert(god.try_push(address(DAO), address(OCY_CVX_B), USDT, amountUSDT, abi.encode(0)));

        // Post-state.
        assertGt(IERC20(OCY_CVX_B.convexRewards()).balanceOf(address(OCY_CVX_B)), 0);

    }

    function test_OCY_Convex_B_pushToLocker_state_sUSD(uint96 amountsUSD) public {

        acquire_sUSD_DAO();

        hevm.assume(amountsUSD > 1_000 ether && amountsUSD < IERC20(sUSD).balanceOf(address(DAO)));

        // pushToLocker().
        assert(god.try_push(address(DAO), address(OCY_CVX_B), sUSD, amountsUSD, abi.encode(0)));

        // Post-state.
        assertGt(IERC20(OCY_CVX_B.convexRewards()).balanceOf(address(OCY_CVX_B)), 0);

    }

    // Validate pullFromLocker() state changes.
    // Validate pullFromLocker() restrictions.
    // This includes:
    //   - onlyOwner() modifier
    //   - asset must be convexPoolToken

    function test_OCY_Convex_B_pullFromLocker_restrictions_msgSender() public {

        // Can't push to contract if _msgSender() != owner()
        hevm.startPrank(address(bob));
        hevm.expectRevert("Ownable: caller is not the owner");
        DAO.pull(address(OCY_CVX_B), USDT, abi.encode(0, 0, 0, 0));
        hevm.stopPrank();
    }

    function test_OCY_Convex_B_pullFromLocker_restrictions_asset() public {
        
        // Can't pull if asset != convexPoolToken
        hevm.startPrank(address(god));
        hevm.expectRevert("OCY_Convex_B::pullFromLocker() asset != convexPoolToken");
        DAO.pull(address(OCY_CVX_B), USDT, abi.encode(0, 0, 0, 0));
        hevm.stopPrank();
    }

    function test_OCY_Convex_B_pullFromLocker_state_DAI(uint96 amountDAI) public {

        hevm.assume(amountDAI > 1_000 ether && amountDAI < 10_000_000 ether);

        // pushToLocker().
        deal(DAI, address(DAO), amountDAI);
        assert(god.try_push(address(DAO), address(OCY_CVX_B), DAI, amountDAI, abi.encode(0)));

        // pullFromLocker().
        hevm.startPrank(address(god));
        DAO.pull(address(OCY_CVX_B), OCY_CVX_B.convexPoolToken(), abi.encode(0, 0, 0, 0));
        hevm.stopPrank();

        assertEq(IERC20(OCY_CVX_B.convexRewards()).balanceOf(address(OCY_CVX_B)), 0);
    }

    function test_OCY_Convex_B_pullFromLocker_state_USDT(uint96 amountUSDT) public {

        hevm.assume(amountUSDT > 1_000 * 10**6 && amountUSDT < 10_000_000 * 10**6);

        // pushToLocker().
        deal(USDT, address(DAO), amountUSDT);
        assert(god.try_push(address(DAO), address(OCY_CVX_B), USDT, amountUSDT, abi.encode(0)));

        // pullFromLocker().
        hevm.startPrank(address(god));
        DAO.pull(address(OCY_CVX_B), OCY_CVX_B.convexPoolToken(), abi.encode(0, 0, 0, 0));
        hevm.stopPrank();

        assertEq(IERC20(OCY_CVX_B.convexRewards()).balanceOf(address(OCY_CVX_B)), 0);
    }

    function test_OCY_Convex_B_pullFromLocker_state_USDC(uint96 amountUSDC) public {

        hevm.assume(amountUSDC > 1_000 * 10**6 && amountUSDC < 10_000_000 * 10**6);

        // pushToLocker().
        deal(USDC, address(DAO), amountUSDC);
        assert(god.try_push(address(DAO), address(OCY_CVX_B), USDC, amountUSDC, abi.encode(0)));

        // pullFromLocker().
        hevm.startPrank(address(god));
        DAO.pull(address(OCY_CVX_B), OCY_CVX_B.convexPoolToken(), abi.encode(0, 0, 0, 0));
        hevm.stopPrank();

        assertEq(IERC20(OCY_CVX_B.convexRewards()).balanceOf(address(OCY_CVX_B)), 0);
    }

    function test_OCY_Convex_B_pullFromLocker_state_sUSD(uint96 amountsUSD) public {

        acquire_sUSD_DAO();

        hevm.assume(amountsUSD > 1_000 ether && amountsUSD < IERC20(sUSD).balanceOf(address(DAO)));

        // pushToLocker().
        assert(god.try_push(address(DAO), address(OCY_CVX_B), sUSD, amountsUSD, abi.encode(0)));

        // pullFromLocker().
        hevm.startPrank(address(god));
        DAO.pull(address(OCY_CVX_B), OCY_CVX_B.convexPoolToken(), abi.encode(0, 0, 0, 0));
        hevm.stopPrank();

        assertEq(IERC20(OCY_CVX_B.convexRewards()).balanceOf(address(OCY_CVX_B)), 0);
    }

    // Validate pullFromLockerPartial() state changes.
    // Validate pullFromLockerPartial() restrictions.
    // This includes:
    //   - asset must be convexPoolToken
    //   - onlyOwner() modifier

    function test_OCY_Convex_B_pullFromLockerPartial_restrictions_msgSender() public {

        // Can't push to contract if _msgSender() != owner()
        hevm.startPrank(address(bob));
        hevm.expectRevert("Ownable: caller is not the owner");
        DAO.pullPartial(address(OCY_CVX_B), USDT, 5, abi.encode(0, 0, 0, 0));
        hevm.stopPrank();
    }

    function test_OCY_Convex_B_pullFromLockerPartial_restrictions_asset() public {
        
        // Can't pull if asset != convexPoolToken
        hevm.startPrank(address(god));
        hevm.expectRevert("OCY_Convex_B::pullFromLockerPartial() asset != convexPoolToken");
        DAO.pullPartial(address(OCY_CVX_B), USDT, 5, abi.encode(0, 0, 0, 0));
        hevm.stopPrank();
    }

    function test_OCY_Convex_B_pullFromLockerPartial_state_DAI(uint96 amountDAI, uint96 amountPull) public {

        hevm.assume(amountDAI > 1_000 ether && amountDAI < 10_000_000 ether);
        hevm.assume(amountPull > 100 ether);

        // pushToLocker().
        deal(DAI, address(DAO), amountDAI);
        assert(god.try_push(address(DAO), address(OCY_CVX_B), DAI, amountDAI, abi.encode(0)));

        uint256 preRewardsTokens = IERC20(OCY_CVX_B.convexRewards()).balanceOf(address(OCY_CVX_B));

        // pullFromLocker().
        hevm.startPrank(address(god));
        DAO.pullPartial(address(OCY_CVX_B), OCY_CVX_B.convexPoolToken(), amountPull % preRewardsTokens, abi.encode(0, 0, 0, 0));
        hevm.stopPrank();

        assertLt(IERC20(OCY_CVX_B.convexRewards()).balanceOf(address(OCY_CVX_B)), preRewardsTokens);
        
    }

    function test_OCY_Convex_B_pullFromLockerPartial_state_USDC(uint96 amountUSDC, uint96 amountPull) public {

        hevm.assume(amountUSDC > 1_000 * 10**6 && amountUSDC < 10_000_000 * 10**6);
        hevm.assume(amountPull > 100 * 10**6);

        // pushToLocker().
        deal(USDC, address(DAO), amountUSDC);
        assert(god.try_push(address(DAO), address(OCY_CVX_B), USDC, amountUSDC, abi.encode(0)));

        uint256 preRewardsTokens = IERC20(OCY_CVX_B.convexRewards()).balanceOf(address(OCY_CVX_B));

        // pullFromLocker().
        hevm.startPrank(address(god));
        DAO.pullPartial(address(OCY_CVX_B), OCY_CVX_B.convexPoolToken(), amountPull % preRewardsTokens, abi.encode(0, 0, 0, 0));
        hevm.stopPrank();

        assertLt(IERC20(OCY_CVX_B.convexRewards()).balanceOf(address(OCY_CVX_B)), preRewardsTokens);
        
    }

    function test_OCY_Convex_B_pullFromLockerPartial_state_USDT(uint96 amountUSDT, uint96 amountPull) public {

        hevm.assume(amountUSDT > 1_000 * 10**6 && amountUSDT < 10_000_000 * 10**6);
        hevm.assume(amountPull > 100 * 10**6);

        // pushToLocker().
        deal(USDT, address(DAO), amountUSDT);
        assert(god.try_push(address(DAO), address(OCY_CVX_B), USDT, amountUSDT, abi.encode(0)));

        uint256 preRewardsTokens = IERC20(OCY_CVX_B.convexRewards()).balanceOf(address(OCY_CVX_B));

        // pullFromLocker().
        hevm.startPrank(address(god));
        DAO.pullPartial(address(OCY_CVX_B), OCY_CVX_B.convexPoolToken(), amountPull % preRewardsTokens, abi.encode(0, 0, 0, 0));
        hevm.stopPrank();

        assertLt(IERC20(OCY_CVX_B.convexRewards()).balanceOf(address(OCY_CVX_B)), preRewardsTokens);
        
    }

    function test_OCY_Convex_B_pullFromLockerPartial_state_sUSD(uint96 amountsUSD, uint96 amountPull) public {

        acquire_sUSD_DAO();

        hevm.assume(amountsUSD > 1_000 ether && amountsUSD < IERC20(sUSD).balanceOf(address(DAO)));
        hevm.assume(amountPull > 100 ether);

        // pushToLocker().
        assert(god.try_push(address(DAO), address(OCY_CVX_B), sUSD, amountsUSD, abi.encode(0)));

        uint256 preRewardsTokens = IERC20(OCY_CVX_B.convexRewards()).balanceOf(address(OCY_CVX_B));

        // pullFromLocker().
        hevm.startPrank(address(god));
        DAO.pullPartial(address(OCY_CVX_B), OCY_CVX_B.convexPoolToken(), amountPull % preRewardsTokens, abi.encode(0, 0, 0, 0));
        hevm.stopPrank();

        assertLt(IERC20(OCY_CVX_B.convexRewards()).balanceOf(address(OCY_CVX_B)), preRewardsTokens);
        
    }

    // Validate claimRewards() state changes.

    function test_OCY_Convex_B_claimRewards_state(uint96 amountDAI) public {

        hevm.assume(amountDAI > 1_000 ether && amountDAI < 10_000_000 ether);

        // pushToLocker().
        deal(DAI, address(DAO), amountDAI);
        assert(god.try_push(address(DAO), address(OCY_CVX_B), DAI, amountDAI, abi.encode(0)));

        // Post-state.
        assertGt(IERC20(OCY_CVX_B.convexRewards()).balanceOf(address(OCY_CVX_B)), 0);

        hevm.warp(block.timestamp + 7 days);

        uint256 preCRV = IERC20(CRV).balanceOf(address(TreasuryYDL));
        uint256 preCVX = IERC20(CVX).balanceOf(address(TreasuryYDL));

        OCY_CVX_B.claimRewards(true);

        assertGt(IERC20(CRV).balanceOf(address(TreasuryYDL)), preCRV);
        assertGt(IERC20(CVX).balanceOf(address(TreasuryYDL)), preCVX);

    }

    // Validate updateOCTYDL() state changes.
    // Validate updateOCTYDL() restrictions.
    // This includes:
    //   - _msgSender() must be ZVL

    function test_OCY_Convex_B_updateOCTYDL_restrictions_msgSender() public {

        // Can't call if _msgSender() is not ZVL.
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCY_Convex_B::updateOCTYDL() _msgSender() != IZivoeGlobals_OCY_Convex_B(GBL).ZVL()");
        OCY_CVX_B.updateOCTYDL(address(bob));
        hevm.stopPrank();
    }

    function test_OCY_Convex_B_updateOCTYDL_state(address fuzzed) public {
        
        // Pre-state.
        assertEq(OCY_CVX_B.OCT_YDL(), address(TreasuryYDL));

        // updateOCTYDL().
        hevm.expectEmit(true, true, false, false, address(OCY_CVX_B));
        emit UpdatedOCTYDL(address(fuzzed), address(TreasuryYDL));
        hevm.startPrank(address(zvl));
        OCY_CVX_B.updateOCTYDL(address(fuzzed));
        hevm.stopPrank();

        // Post-state.
        assertEq(OCY_CVX_B.OCT_YDL(), address(fuzzed));

    }

}