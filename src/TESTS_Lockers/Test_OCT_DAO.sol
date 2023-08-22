// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../Utility/Utility.sol";

import "../../lib/zivoe-core-foundry/src/lockers/OCT/OCT_DAO.sol";

import "../../lib/zivoe-core-foundry/lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract Test_OCT_DAO is Utility {

    using SafeERC20 for IERC20;

    OCT_DAO TreasuryDAO;

    function setUp() public {

        deployCore(false);

        TreasuryDAO = new OCT_DAO(address(DAO), address(GBL));

        zvl.try_updateIsLocker(address(GBL), address(TreasuryDAO), true);

    }
    
    event AssetConvertedForwarded(address indexed asset, address indexed toAsset, uint256 amountFrom, uint256 amountTo);

    event Logger(address);

    // ----------------
    //    Unit Tests
    // ----------------

    // Validate initial state of OCT_DAO.

    function test_OCT_DAO_init() public {

        assertEq(TreasuryDAO.owner(), address(DAO));

        assertEq(TreasuryDAO.GBL(), address(GBL));

        assert(TreasuryDAO.canPush());
        assert(TreasuryDAO.canPushMulti());
        assert(TreasuryDAO.canPull());
        assert(TreasuryDAO.canPullMulti());
        assert(TreasuryDAO.canPullPartial());
        assert(TreasuryDAO.canPullMultiPartial());
    }

    // Validate convertAndForward() state changes.
    // Validate convertAndForward() restrictions.
    // This includes:
    //  - _msgSener() is whitelisted as keeper

    function test_OCT_DAO_convertAndForward_msgSender() public {

        address assetIn = USDC;
        address assetOut = OUSD;
        uint256 amountIn = 2000000 * 10**6;

        // 200,000 USDC -> OUSD
        bytes memory dataSwap =
        hex"12aa3caf0000000000000000000000001136b25047e142fa3018184793aec68fbb173ce4000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000002a8e1e676ec238d8a992307b495b45b3feaa5e860000000000000000000000001136b25047e142fa3018184793aec68fbb173ce4000000000000000000000000883816205341a6ba3c32ae8dadcebdd9d59bc2c4000000000000000000000000000000000000000000000000000001d1a94a200000000000000000000000000000000000000000000001a6651513ddf098f969a00000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000014000000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000018a00000000000000000000000000000000000000000000016c00013e0000f400a007e5c0d20000000000000000000000000000000000000000000000d00000b600000600a0fd53121f512087650d7bbfc3a9f10587d7778206671719d9910d6b175474e89094c44da98b954eedeac495271d0f0044a6417ed600000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001a36ddf857a09de8316760020d6bdbf782a8e1e676ec238d8a992307b495b45b3feaa5e8600a0f2fa6b662a8e1e676ec238d8a992307b495b45b3feaa5e8600000000000000000000000000000000000000000001a7aa752c51e5c450b1d70000000000000000459b9f61774d029980a06c4eca272a8e1e676ec238d8a992307b495b45b3feaa5e861111111254eeb25477b68fb85ed929f73a96058200000000000000000000000000000000000000000000cfee7c08";
        
        // fund contract with the right amount of tokens to swap.
        deal(assetIn, address(TreasuryDAO), amountIn);

        emit log_named_uint("TreasuryDAO assetIn pre-swap balance:", IERC20(assetIn).balanceOf(address(TreasuryDAO)));
        emit log_named_uint("TreasuryDAO assetOut pre-swap balance:", IERC20(assetOut).balanceOf(address(TreasuryDAO)));
        emit log_named_uint("DAO assetOut pre-swap balance:", IERC20(assetOut).balanceOf(address(DAO)));
        emit Logger(address(TreasuryDAO));

        // Can't push to contract if _msgSender() is not whitelisted as keeper
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCT_DAO::convertAndForward !isKeeper(_msgSender())");
        TreasuryDAO.convertAndForward(assetIn, assetOut, dataSwap);
        hevm.stopPrank();
    }

    function test_OCT_DAO_convertAndForward() public {

        address assetIn = USDC;
        address assetOut = OUSD;
        uint256 amountIn = 2000000 * 10**6;

        // 200,000 USDC -> OUSD
        bytes memory dataSwap =
        hex"12aa3caf0000000000000000000000001136b25047e142fa3018184793aec68fbb173ce4000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000002a8e1e676ec238d8a992307b495b45b3feaa5e860000000000000000000000001136b25047e142fa3018184793aec68fbb173ce4000000000000000000000000883816205341a6ba3c32ae8dadcebdd9d59bc2c4000000000000000000000000000000000000000000000000000001d1a94a200000000000000000000000000000000000000000000001a6651513ddf098f969a00000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000014000000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000018a00000000000000000000000000000000000000000000016c00013e0000f400a007e5c0d20000000000000000000000000000000000000000000000d00000b600000600a0fd53121f512087650d7bbfc3a9f10587d7778206671719d9910d6b175474e89094c44da98b954eedeac495271d0f0044a6417ed600000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001a36ddf857a09de8316760020d6bdbf782a8e1e676ec238d8a992307b495b45b3feaa5e8600a0f2fa6b662a8e1e676ec238d8a992307b495b45b3feaa5e8600000000000000000000000000000000000000000001a7aa752c51e5c450b1d70000000000000000459b9f61774d029980a06c4eca272a8e1e676ec238d8a992307b495b45b3feaa5e861111111254eeb25477b68fb85ed929f73a96058200000000000000000000000000000000000000000000cfee7c08";
        
        // fund contract with the right amount of tokens to swap.
        deal(assetIn, address(TreasuryDAO), amountIn);

        emit log_named_uint("TreasuryDAO assetIn pre-swap balance:", IERC20(assetIn).balanceOf(address(TreasuryDAO)));
        emit log_named_uint("TreasuryDAO assetOut pre-swap balance:", IERC20(assetOut).balanceOf(address(TreasuryDAO)));
        emit log_named_uint("DAO assetOut pre-swap balance:", IERC20(assetOut).balanceOf(address(DAO)));
        emit Logger(address(TreasuryDAO));
        
        assert(zvl.try_updateIsKeeper(address(GBL), address(this), true));
        TreasuryDAO.convertAndForward(assetIn, assetOut, dataSwap);

        emit log_named_uint("TreasuryDAO assetIn after-swap balance:", IERC20(assetIn).balanceOf(address(TreasuryDAO)));
        emit log_named_uint("TreasuryDAO assetOut after-swap balance:", IERC20(assetOut).balanceOf(address(TreasuryDAO)));
        emit log_named_uint("DAO assetOut after-swap balance:", IERC20(assetOut).balanceOf(address(DAO)));

        // assert balances after swap are correct.
        assertEq(0, IERC20(assetIn).balanceOf(address(TreasuryDAO)));
        assert(IERC20(assetOut).balanceOf(address(DAO)) > 0);

    }

}