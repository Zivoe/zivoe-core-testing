// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../Utility/Utility.sol";

import "../../lib/zivoe-core-foundry/src/lockers/OCT/OCT_YDL.sol";

import "../../lib/zivoe-core-foundry/lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract Test_OCT_YDL is Utility {

    using SafeERC20 for IERC20;

    OCT_YDL TreasuryYDL;

    function setUp() public {

        deployCore(false);

        TreasuryYDL = new OCT_YDL(address(DAO), address(GBL));

        zvl.try_updateIsLocker(address(GBL), address(TreasuryYDL), true);

    }
    
    event AssetConvertedForwarded(address indexed asset, address indexed toAsset, uint256 amountFrom, uint256 amountTo);

    event Logger(address);

    // ----------------
    //    Unit Tests
    // ----------------

    // Validate initial state of OCT_YDL.

    function test_OCT_YDL_init() public {

        assertEq(TreasuryYDL.owner(), address(DAO));

        assertEq(TreasuryYDL.GBL(), address(GBL));

        assert(TreasuryYDL.canPull());
        assert(TreasuryYDL.canPullMulti());
        assert(TreasuryYDL.canPullPartial());
        assert(TreasuryYDL.canPullMultiPartial());
    }

    // Validate convertAndForward() state changes.
    // Validate convertAndForward() restrictions.
    // This includes:
    //  - _msgSener() is whitelisted as keeper

    function test_OCT_DAO_convertAndForward_msgSender() public {

        address assetIn = USDC;
        address assetOut = YDL.distributedAsset();
        uint256 amountIn = 200000 * 10**6;

        // 200,000 USDC -> DAI
        bytes memory dataSwap =
        hex"e449022e0000000000000000000000000000000000000000000000000000002e90edd000000000000000000000000000000000000000000000002a38a1fad65992048015000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000018000000000000000000000005777d92f208679db4b9778590fa3cab3ac9e2168cfee7c08";
        
        // fund contract with the right amount of tokens to swap.
        deal(assetIn, address(TreasuryYDL), amountIn);

        emit log_named_uint("TreasuryYDL assetIn pre-swap balance:", IERC20(assetIn).balanceOf(address(TreasuryYDL)));
        emit log_named_uint("TreasuryYDL assetOut pre-swap balance:", IERC20(assetOut).balanceOf(address(TreasuryYDL)));
        emit log_named_uint("YDL assetOut pre-swap balance:", IERC20(assetOut).balanceOf(address(YDL)));
        emit Logger(address(TreasuryYDL));
        
        // Can't push to contract if _msgSender() is not whitelisted as keeper
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCT_YDL::convertAndForward !isKeeper(_msgSender())");
        TreasuryYDL.convertAndForward(assetIn, dataSwap);
        hevm.stopPrank();
    }

    function test_OCT_YDL_convertAndForward() public {

        address assetIn = USDC;
        address assetOut = YDL.distributedAsset();
        uint256 amountIn = 200000 * 10**6;

        // 200,000 USDC -> DAI
        bytes memory dataSwap =
        hex"e449022e0000000000000000000000000000000000000000000000000000002e90edd000000000000000000000000000000000000000000000002a38a1fad65992048015000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000018000000000000000000000005777d92f208679db4b9778590fa3cab3ac9e2168cfee7c08";
        
        // fund contract with the right amount of tokens to swap.
        deal(assetIn, address(TreasuryYDL), amountIn);

        emit log_named_uint("TreasuryYDL assetIn pre-swap balance:", IERC20(assetIn).balanceOf(address(TreasuryYDL)));
        emit log_named_uint("TreasuryYDL assetOut pre-swap balance:", IERC20(assetOut).balanceOf(address(TreasuryYDL)));
        emit log_named_uint("YDL assetOut pre-swap balance:", IERC20(assetOut).balanceOf(address(YDL)));
        emit Logger(address(TreasuryYDL));
        
        assert(zvl.try_updateIsKeeper(address(GBL), address(this), true));
        TreasuryYDL.convertAndForward(assetIn, dataSwap);

        emit log_named_uint("TreasuryYDL assetIn after-swap balance:", IERC20(assetIn).balanceOf(address(TreasuryYDL)));
        emit log_named_uint("TreasuryYDL assetOut after-swap balance:", IERC20(assetOut).balanceOf(address(TreasuryYDL)));
        emit log_named_uint("YDL assetOut after-swap balance:", IERC20(assetOut).balanceOf(address(YDL)));

        // assert balances after swap are correct.
        assertEq(0, IERC20(assetIn).balanceOf(address(TreasuryYDL)));
        assert(IERC20(assetOut).balanceOf(address(YDL)) > 0);

    }

}