// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.17;

import "../TESTS_Utility/Utility.sol";

import "../../lib/zivoe-core-foundry/src/lockers/OCT/OCT_DAO.sol";
import "../../lib/zivoe-core-foundry/src/lockers/OCT/OCT_YDL.sol";
import "../../lib/zivoe-core-foundry/src/lockers/OCY/OCY_OUSD.sol";

import "../../lib/zivoe-core-foundry/lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

interface IVault {
    function rebase() external;
}


interface IOUSD {
    function rebaseOptIn() external;
}


contract Test_OCY_OUSD is Utility {

    using SafeERC20 for IERC20;

    OCY_OUSD OCY_A;
    OCT_DAO OCT_A;
    OCT_YDL OCT_B;

    address OUSD_VAULT = 0xE75D77B1865Ae93c7eaa3040B038D7aA7BC02F70;

    function setUp() public {

        deployCore(false);

        OCT_A = new OCT_DAO(address(DAO), address(GBL));
        OCT_B = new OCT_YDL(address(DAO), address(GBL));

        OCY_A = new OCY_OUSD(address(DAO), address(GBL), address(OCT_B));

    }

    event Logger(address);

    function test_OCT_DAO_ConvertAndForward() public {

        address assetIn = USDC;
        address assetOut = OUSD;
        uint256 amountIn = 2000000 * 10**6;

        // 200,000 USDC -> OUSD
        bytes memory dataSwap =
        hex"12aa3caf0000000000000000000000001136b25047e142fa3018184793aec68fbb173ce4000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000002a8e1e676ec238d8a992307b495b45b3feaa5e860000000000000000000000001136b25047e142fa3018184793aec68fbb173ce4000000000000000000000000883816205341a6ba3c32ae8dadcebdd9d59bc2c4000000000000000000000000000000000000000000000000000001d1a94a200000000000000000000000000000000000000000000001a6651513ddf098f969a00000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000014000000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000018a00000000000000000000000000000000000000000000016c00013e0000f400a007e5c0d20000000000000000000000000000000000000000000000d00000b600000600a0fd53121f512087650d7bbfc3a9f10587d7778206671719d9910d6b175474e89094c44da98b954eedeac495271d0f0044a6417ed600000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001a36ddf857a09de8316760020d6bdbf782a8e1e676ec238d8a992307b495b45b3feaa5e8600a0f2fa6b662a8e1e676ec238d8a992307b495b45b3feaa5e8600000000000000000000000000000000000000000001a7aa752c51e5c450b1d70000000000000000459b9f61774d029980a06c4eca272a8e1e676ec238d8a992307b495b45b3feaa5e861111111254eeb25477b68fb85ed929f73a96058200000000000000000000000000000000000000000000cfee7c08";
        
        // fund contract with the right amount of tokens to swap.
        deal(assetIn, address(OCT_A), amountIn);

        emit log_named_uint("OCT_A assetIn pre-swap balance:", IERC20(assetIn).balanceOf(address(OCT_A)));
        emit log_named_uint("OCT_A assetOut pre-swap balance:", IERC20(assetOut).balanceOf(address(OCT_A)));
        emit Logger(address(OCT_A));
        
        assert(zvl.try_updateIsKeeper(address(GBL), address(this), true));
        OCT_A.convertAndForward(assetIn, assetOut, dataSwap);

        emit log_named_uint("OCT_A assetIn after-swap balance:", IERC20(assetIn).balanceOf(address(OCT_A)));
        emit log_named_uint("OCT_A assetOut after-swap balance:", IERC20(assetOut).balanceOf(address(DAO)));

        // assert balances after swap are correct.
        assertEq(0, IERC20(assetIn).balanceOf(address(OCT_A)));
        assert(IERC20(assetOut).balanceOf(address(DAO)) > 0);

        assert(zvl.try_updateIsLocker(address(GBL), address(OCY_A), true));
        assert(god.try_push(address(DAO), address(OCY_A), OUSD, IERC20(OUSD).balanceOf(address(DAO)), ""));

        OCY_A.rebase();

        hevm.warp(block.timestamp + 1 days);
        emit log_named_uint("OUSD balance:", IERC20(OUSD).balanceOf(address(OCY_A)));
        deal(DAI, address(OUSD_VAULT), 100_000 ether);
        deal(USDC, address(OUSD_VAULT), 100_000 * 10**6);
        deal(FRAX, address(OUSD_VAULT), 100_000 ether);
        deal(USDT, address(OUSD_VAULT), 100_000 * 10**6);
        IVault(OUSD_VAULT).rebase();
        hevm.warp(block.timestamp + 1 days);
        emit log_named_uint("OUSD balance:", IERC20(OUSD).balanceOf(address(OCY_A)));
        deal(DAI, address(OUSD_VAULT), 100_000 ether);
        deal(USDC, address(OUSD_VAULT), 100_000 * 10**6);
        deal(FRAX, address(OUSD_VAULT), 100_000 ether);
        deal(USDT, address(OUSD_VAULT), 100_000 * 10**6);
        IVault(OUSD_VAULT).rebase();
        hevm.warp(block.timestamp + 14 days);
        emit log_named_uint("OUSD balance:", IERC20(OUSD).balanceOf(address(OCY_A)));

        OCY_A.swipeBasis();
    }

}