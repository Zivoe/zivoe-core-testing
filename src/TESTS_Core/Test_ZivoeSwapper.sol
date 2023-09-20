// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../Utility/Utility.sol";

import "../../lib/zivoe-core-foundry/src/lockers/Utility/ZivoeSwapper.sol";
import "../../lib/zivoe-core-foundry/lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/// NOTE Expect one test to fail for fillOrderRFQ() as data should be updated.
/// @dev We setup a separate contract in order to be able to call "convertAsset"
///      on the ZivoeSwapper contract as it is an internal function.
contract SwapperTest is ZivoeSwapper {

    using SafeERC20 for IERC20;

    function convertTest(address assetIn, address assetOut, uint256 amountIn, bytes calldata data) public returns (
        bytes4 sig, uint256[] memory poolsV3, uint256[] memory poolsV2
    ) {
        sig = bytes4(data[:4]);

        IERC20(assetIn).safeApprove(router1INCH_V5, IERC20(assetIn).balanceOf(address(this)));
        convertAsset(assetIn, assetOut, amountIn, data);

        if (sig == bytes4(keccak256("uniswapV3Swap(uint256,uint256,uint256[])"))) {
            (,, uint256[] memory _c) = abi.decode(data[4:], (uint256, uint256, uint256[]));
            poolsV3 = _c;
        }
        if (sig == bytes4(keccak256("unoswap(address,uint256,uint256,uint256[])"))) {
            (,,, uint256[] memory _d) = abi.decode(data[4:], (address, uint256, uint256, uint256[]));
            poolsV2 = _d;
        }
    }
}


contract Test_ZivoeSwapper is Utility {

    using SafeERC20 for IERC20;

    uint256 private constant _ONE_FOR_ZERO_MASK = 1 << 255;
    uint256 private constant _REVERSE_MASK = 0x8000000000000000000000000000000000000000000000000000000000000000;

    // Initiate contract variable
    SwapperTest swapper;

    // 1inch data retrieved from API
    // FRAX to USDC for 2_000_000
    bytes dataSwap = hex"7c02520000000000000000000000000053222470cdcfb8081c0e3a50fd106f0d69e63f2000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000180000000000000000000000000853d955acef822db058eb8505911ed77f175b99e000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000053222470cdcfb8081c0e3a50fd106f0d69e63f20000000000000000000000000ce71065d4017f316ec606fe4422e11eb2c47c24600000000000000000000000000000000000000000001a784379d99db42000000000000000000000000000000000000000000000000000000000001cfde9a359a00000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001360000000000000000000000000000000000000000000000f80000ca0000b05120d632f22692fac7611d2aa1c0d552930d43caed3b853d955acef822db058eb8505911ed77f175b99e0044a6417ed6000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001cc9cd8ce430020d6bdbf78a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4880a06c4eca27a0b86991c6218b36c1d19d4a2e9eb0ce3606eb481111111254fb6c44bac0bed2854e76f90643097d00000000000000000000000000000000000000000001a784379d99db4200000000000000000000000000cfee7c08";

    // DAI to FRAX for 20_000
    bytes dataUniswapV3Swap = 
    hex"e449022e00000000000000000000000000000000000000000000043c33c19375648000000000000000000000000000000000000000000000000004399480e39a4a8ad121000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000020000000000000000000000005777d92f208679db4b9778590fa3cab3ac9e21688000000000000000000000009a834b70c07c81a9fcd6f22e842bf002fbffbe4dcfee7c08";
    // DAI -> FRAX, 2k
    // hex"e449022e00000000000000000000000000000000000000000000006c6b935b8bbd40000000000000000000000000000000000000000000000000006be0d10228830e54770000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000100000000000000000000000097e7d56a0408570ba1a7852de36350f7713906eccfee7c08";
    // FRAX -> DAI, 2k
    // hex"e449022e00000000000000000000000000000000000000000000006c6b935b8bbd40000000000000000000000000000000000000000000000000006bc524c46f1a7e5aff0000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000180000000000000000000000097e7d56a0408570ba1a7852de36350f7713906eccfee7c08";

    // USDT to WBTC for 5000
    // NOTE: Data needs to be updated for every call
    bytes dataFillOrderRFQ =
    hex"d0a3b665000000000000000000000000000000000000000063860ef600000184c3a89d900000000000000000000000002260fac5e5542a773aa44fbcfedf7c193bc2c599000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec7000000000000000000000000945bcf562085de2d5875b9e2012ed5fd5cfab927000000000000000000000000ce71065d4017f316ec606fe4422e11eb2c47c2460000000000000000000000000000000000000000000000000000000001d1c076000000000000000000000000000000000000000000000000000000012a05f20000000000000000000000000000000000000000000000000000000000000001400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000012a05f2000000000000000000000000000000000000000000000000000000000000000041735c5f1c4a202c5c3c20ee2f6ab849a2f78676a6cd046daddb83437792e777ea2b8eb23962bf6aea5f468df6882b1c8b8cd5b1b06dd7f088f987348e8eb7116e1b00000000000000000000000000000000000000000000000000000000000000cfee7c08";

    function setUp() public {
        // initiate contract instance
        swapper = new SwapperTest();
        
        // Fund the swapper contract
        deal(address(swapper), 1 ether);
    }


    // ============================ "12aa3caf": swap() ==========================

    event Logger(address);

    function test_ZivoeSwapper_swap_convertAsset() public {

        address assetIn = USDC;
        address assetOut = OUSD;
        uint256 amountIn = 2000000 * 10**6;

        // 2_000_000 USDC -> OUSD
        bytes memory dataSwap =
        hex"12aa3caf0000000000000000000000001136b25047e142fa3018184793aec68fbb173ce4000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000002a8e1e676ec238d8a992307b495b45b3feaa5e860000000000000000000000001136b25047e142fa3018184793aec68fbb173ce40000000000000000000000005615deb798bb3e4dfa0139dfa1b3d433cc23b72f000000000000000000000000000000000000000000000000000001d1a94a200000000000000000000000000000000000000000000001a678e5dbe9976d93c09e000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000001400000000000000000000000000000000000000000000000000000000000000160000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002500000000000000000000000000000000000000002320002040001ba0001a000a007e5c0d200000000000000000000000000000000000000000000000000017c00004f02a0000000000000000000000000000000000000000000000000000001ccab7ad5fcee63c1e5013416cf6c708da44db2624d63ea0aaef7113527c6a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800a0c9e75c4800000000000000002f030000000000000000000000000000000000000000000000000000ff00004f02a000000000000000000000000000000000000000000000192d27ea2b5f19b1681fee63c1e500129360c964e2e13910d603043f6287e5e9383374dac17f958d2ee523a2206206994597c13d831ec7512087650d7bbfc3a9f10587d7778206671719d9910ddac17f958d2ee523a2206206994597c13d831ec70044a6417ed6000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000018a5464c5933d6d4e2dcd0020d6bdbf782a8e1e676ec238d8a992307b495b45b3feaa5e8600a0f2fa6b662a8e1e676ec238d8a992307b495b45b3feaa5e8600000000000000000000000000000000000000000001a7be5537fc02f4f7d2ea000000000000000045bc69b2132ba2c780a06c4eca272a8e1e676ec238d8a992307b495b45b3feaa5e861111111254eeb25477b68fb85ed929f73a96058200000000000000000000000000000000cfee7c08";
        
        // fund contract with the right amount of tokens to swap.
        deal(assetIn, address(swapper), amountIn);

        // assert initial balances are correct.
        assertEq(amountIn, IERC20(assetIn).balanceOf(address(swapper)));
        assertEq(0, IERC20(assetOut).balanceOf(address(swapper)));

        emit log_named_uint("swapper assetIn pre-swap balance:", IERC20(assetIn).balanceOf(address(swapper)));
        emit Logger(address(swapper));
        (bytes4 sig,,) = swapper.convertTest(assetIn, assetOut, amountIn, dataSwap);

        emit log_named_uint("swapper assetIn after-swap balance:", IERC20(assetIn).balanceOf(address(swapper)));
        emit log_named_uint("swapper assetOut after-swap balance:", IERC20(assetOut).balanceOf(address(swapper)));

        // ensure we go through the right validation function.
        assert(sig == bytes4(keccak256("swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)")));

        // assert balances after swap are correct.
        assertEq(0, IERC20(assetIn).balanceOf(address(swapper)));
        assert(IERC20(assetOut).balanceOf(address(swapper)) > 0);
    }

    function test_ZivoeSwapper_swap_restrictions_assetIn() public {

        // We provide the wrong assetIn (USDT instead of FRAX)
        address assetIn = USDT; 
        address assetOut = USDC;
        uint256 amountIn = 2_000_000 ether;

        // We expect the following call to revert due to assetIn != FRAX
        hevm.expectRevert("ZivoeSwapper::handle_validation_7c025200() address(_b.srcToken) != assetIn");

        swapper.convertTest(
            assetIn,
            assetOut,
            amountIn,
            dataSwap
        );
    }

    function test_ZivoeSwapper_swap_restrictions_assetOut() public {
        // We provide the wrong assetOut (DAI instead of USDC)
        address assetIn = FRAX; 
        address assetOut = DAI;
        uint256 amountIn = 2_000_000 ether;

        // We expect the following call to revert due to assetOut != USDC
        hevm.expectRevert("ZivoeSwapper::handle_validation_7c025200() address(_b.dstToken) != assetOut");

        swapper.convertTest(
            assetIn,
            assetOut,
            amountIn,
            dataSwap
        );
    }

    function test_ZivoeSwapper_swap_restrictions_amountIn() public {
        // We provide the wrong amountIn (2000 instead of 2_000_000)
        address assetIn = FRAX; 
        address assetOut = USDC;
        uint256 amountIn = 2_000 ether;

        // We expect the following call to revert due to amountIn != 2_000_000
        hevm.expectRevert("ZivoeSwapper::handle_validation_7c025200() _b.amount != amountIn");

        swapper.convertTest(
            assetIn,
            assetOut,
            amountIn,
            dataSwap
        );

    }

    function test_ZivoeSwapper_swap_restrictions_receiver() public {
        // We provide the wrong "fromAddress" when calling the API
        bytes memory dataOtherReceiver =
        hex"7c02520000000000000000000000000053222470cdcfb8081c0e3a50fd106f0d69e63f2000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000180000000000000000000000000853d955acef822db058eb8505911ed77f175b99e000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000053222470cdcfb8081c0e3a50fd106f0d69e63f20000000000000000000000000972ea38d8ceb5811b144afcce5956a279e47ac4600000000000000000000000000000000000000000001a784379d99db42000000000000000000000000000000000000000000000000000000000001cfeb14895200000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001360000000000000000000000000000000000000000000000f80000ca0000b05120d632f22692fac7611d2aa1c0d552930d43caed3b853d955acef822db058eb8505911ed77f175b99e0044a6417ed6000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001cca93cb4850020d6bdbf78a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4880a06c4eca27a0b86991c6218b36c1d19d4a2e9eb0ce3606eb481111111254fb6c44bac0bed2854e76f90643097d00000000000000000000000000000000000000000001a784379d99db4200000000000000000000000000cfee7c08";
        address assetIn = FRAX; 
        address assetOut = USDC;
        uint256 amountIn = 2_000_000 ether;

        // We expect the following call to revert due to assetIn != FRAX
        hevm.expectRevert("ZivoeSwapper::handle_validation_7c025200() _b.dstReceiver != address(this)");

        swapper.convertTest(
            assetIn,
            assetOut,
            amountIn,
            dataOtherReceiver
        );
    }


    // ==================== "e449022e": uniswapV3Swap() ==========================


    function test_ZivoeSwapper_uniswapV3Swap_convertAsset() public {
        
        address assetIn = FRAX;
        address assetOut = USDT;
        uint256 amountIn = 200 ether;

        // 200 FRAX -> USDT
        bytes memory dataUniswapV3Swap =
        hex"e449022e00000000000000000000000000000000000000000000000ad78ebc5ac6200000000000000000000000000000000000000000000000000000000000000bdf547e00000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000001000000000000000000000000c2a856c3aff2110c1171b8f942256d40e980c726cfee7c08";

        // fund address(swapper) with the right amount of tokens to swap.
        deal(assetIn, address(swapper), amountIn);

        // assert initial balances are correct.
        assertEq(amountIn, IERC20(assetIn).balanceOf(address(swapper)));
        assertEq(0, IERC20(assetOut).balanceOf(address(swapper)));

        emit log_named_uint("swapper assetIn pre-swap balance:", IERC20(assetIn).balanceOf(address(swapper)));
        emit log_named_uint("swapper assetOut pre-swap balance:", IERC20(assetOut).balanceOf(address(swapper)));
        
        (
            bytes4 sig, uint256[] memory pools,
        ) = swapper.convertTest(assetIn, assetOut, amountIn, dataUniswapV3Swap);

        bool zeroForOne_0 = pools[0] & _ONE_FOR_ZERO_MASK == 0;
        bool zeroForOne_CLENGTH = pools[pools.length - 1] & _ONE_FOR_ZERO_MASK == 0;

        if (zeroForOne_0 == true) {
            emit log_string("zeroForOne_0 TRUE");
        }
        else {
            emit log_string("zeroForONE_0 FALSE");
        }
        if (zeroForOne_CLENGTH == true) {
            emit log_string("zeroForOne_CLENGTH TRUE");
        }
        else {
            emit log_string("zeroForOne_CLENGTH FALSE");
        }

        // ensure we go through the right validation function.
        assert(sig == bytes4(keccak256("uniswapV3Swap(uint256,uint256,uint256[])")));

        emit log_named_uint("swapper assetIn after-swap balance:", IERC20(assetIn).balanceOf(address(swapper)));
        emit log_named_uint("swapper assetOut after-swap balance:", IERC20(assetOut).balanceOf(address(swapper)));

        // assert balances after swap are correct.
        assertEq(0, IERC20(assetIn).balanceOf(address(swapper)));
        assert(IERC20(assetOut).balanceOf(address(swapper)) > 0);
    }

    function test_ZivoeSwapper_uniswapV3Swap_restrictions_assetIn_token0() public {
        // Case with zeroForOne_0 = true
        // We provide the wrong assetIn (USDT instead of DAI)
        address assetIn = USDT; 
        address assetOut = FRAX;
        uint256 amountIn = 20_000 ether;

        // We expect the following call to revert due to assetIn != DAI and zeroForOne_0 = true
        hevm.expectRevert("ZivoeSwapper::handle_validation_e449022e() IUniswapV3Pool_ZivoeSwapper(address(uint160(uint256(_c[0])))).token0() != assetIn");

        swapper.convertTest(
            assetIn,
            assetOut,
            amountIn,
            dataUniswapV3Swap
        );
    }

    function test_ZivoeSwapper_uniswapV3Swap_restrictions_assetIn_token1() public {
        // Case with zeroForOne_0 = false
        // We provide the wrong assetIn (USDT instead of USDC)
        address assetIn = USDT; 
        address assetOut = DAI;
        uint256 amountIn = 20_000 * 10**6;

        bytes memory data = hex"e449022e00000000000000000000000000000000000000000000000000000004a817c800000000000000000000000000000000000000000000000438d5d5c6fa2cf2abe4000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000018000000000000000000000005777d92f208679db4b9778590fa3cab3ac9e2168cfee7c08";

        // We expect the following call to revert due to assetIn != USDC and zeroForOne_0 = false
        hevm.expectRevert("ZivoeSwapper::handle_validation_e449022e() IUniswapV3Pool_ZivoeSwapper(address(uint160(uint256(_c[0])))).token1() != assetIn");

        swapper.convertTest(
            assetIn,
            assetOut,
            amountIn,
            data
        );
    }

    function test_ZivoeSwapper_uniswapV3Swap_restrictions_assetOut_token0() public {
        // Case with zeroForOne_CLENGTH = false
        // We provide the wrong assetOut (USDT instead of FRAX)
        address assetIn = DAI; 
        address assetOut = USDT;
        uint256 amountIn = 20_000 ether;
 
        // We expect the following call to revert due to assetOut != FRAX and zeroForOne_CLENGTH = false
        hevm.expectRevert("ZivoeSwapper::handle_validation_e449022e() IUniswapV3Pool_ZivoeSwapper(address(uint160(uint256(_c[_c.length - 1])))).token0() != assetOut");

        swapper.convertTest(
            assetIn,
            assetOut,
            amountIn,
            dataUniswapV3Swap
        );
    }

    function test_ZivoeSwapper_uniswapV3Swap_restrictions_assetOut_token1() public {
        // Case with zeroForOne_CLENGTH = true
        // We provide the wrong assetOut (USDT instead of FRAX)
        address assetIn = DAI; 
        address assetOut = USDT;
        uint256 amountIn = 1_000 ether;

        bytes memory data =
        hex"e449022e00000000000000000000000000000000000000000000003635c9adc5dea00000000000000000000000000000000000000000000000000035f00a792102ac9e810000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000100000000000000000000000097e7d56a0408570ba1a7852de36350f7713906eccfee7c08";

        // We expect the following call to revert due to assetOut != USDT and zeroForOne_CLENGTH = true
        hevm.expectRevert("ZivoeSwapper::handle_validation_e449022e() IUniswapV3Pool_ZivoeSwapper(address(uint160(uint256(_c[_c.length - 1])))).token1() != assetOut");

        swapper.convertTest(
            assetIn,
            assetOut,
            amountIn,
            data
        );
    }

    function test_ZivoeSwapper_uniswapV3Swap_restrictions_amountIn() public {
        // We provide the wrong amountIn (2_000 instead of 20_000)
        address assetIn = DAI; 
        address assetOut = FRAX;
        uint256 amountIn = 2_000 ether;

        // We expect the following call to revert due to amountIn != 20_000
        hevm.expectRevert("ZivoeSwapper::handle_validation_e449022e() _a != amountIn");

        swapper.convertTest(
            assetIn,
            assetOut,
            amountIn,
            dataUniswapV3Swap
        );
    }


    // ======================== "0502b1c5": unoswap() ============================


    function test_ZivoeSwapper_unoswap_convertAsset() public {

        // 200 CRV -> DAI (true zeroForOne_0 / zeroForOne_DLENGTH)
        bytes memory dataUnoSwap =
        hex"0502b1c50000000000000000000000004e3fbd56cd56c3e72c1403e103b45db9da5b9d2b00000000000000000000000000000000000000000000000ad78ebc5ac62000000000000000000000000000000000000000000000000000412c20de35110a330d0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000200000000000000003b6d034005767d9ef41dc40689678ffca0608878fb3de90600000000000000003b6d034058dc5a51fe44589beb22e8ce67720b5bc53780098b1ccac8";
    
        address assetIn = 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B;
        address assetOut = CRV;
        uint256 amountIn = 200 ether;

        // Fund swapper with 200 CRV
        deal(assetIn, address(swapper), amountIn);

        // Pre-state checks
        assertEq(amountIn, IERC20(assetIn).balanceOf(address(swapper)));
        assertEq(0, IERC20(assetOut).balanceOf(address(swapper)));

        emit log_named_uint("swapper assetIn pre-swap balance:", IERC20(assetIn).balanceOf(address(swapper)));
        emit log_named_uint("swapper assetOut pre-swap balance:", IERC20(assetOut).balanceOf(address(swapper)));

        (bytes4 sig,, uint256[] memory pools) = swapper.convertTest(assetIn, assetOut, amountIn, dataUnoSwap);

        bool zeroForOne_0;
        bool zeroForOne_DLENGTH;
        uint256 info_0 = pools[0];
        uint256 info_DLENGTH = pools[pools.length - 1];
        assembly {
            zeroForOne_0 := and(info_0, _REVERSE_MASK)
            zeroForOne_DLENGTH := and(info_DLENGTH, _REVERSE_MASK)
        }

        if (zeroForOne_0 == true) {
            emit log_string("zeroForOne_0 TRUE");
        }
        else {
            emit log_string("zeroForONE_0 FALSE");
        }
        if (zeroForOne_DLENGTH == true) {
            emit log_string("zeroForOne_DLENGTH TRUE");
        }
        else {
            emit log_string("zeroForOne_DLENGTH FALSE");
        }

        // ensure we go through the right validation function.
        assert(sig == bytes4(keccak256("unoswap(address,uint256,uint256,uint256[])")));

        emit log_named_uint("swapper assetIn after-swap balance:", IERC20(assetIn).balanceOf(address(swapper)));
        emit log_named_uint("swapper assetOut after-swap balance:", IERC20(assetOut).balanceOf(address(swapper)));

        // assert balances after swap are correct.
        assertEq(0, IERC20(assetIn).balanceOf(address(swapper)));
        assert(IERC20(assetOut).balanceOf(address(swapper)) > 0);
    }

    function test_ZivoeSwapper_unoswap_restrictions_assetIn() public {
        
        address assetIn = FRAX;     // Wrong assetIn provided
        address assetOut = DAI;
        uint256 amountIn = 200 ether;

        // 200 CRV -> DAI (true zeroForOne_0 / zeroForOne_DLENGTH)
        bytes memory dataUnoSwap = 
        hex"0502b1c5000000000000000000000000d533a949740bb3306d119cc777fa900ba034cd5200000000000000000000000000000000000000000000000ad78ebc5ac6200000000000000000000000000000000000000000000000000009cf68d88c9abaa0620000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000280000000000000003b6d03403da1313ae46132a397d90d95b1424a9a7e3e0fce80000000000000003b6d0340a478c2975ab1ea89e8196811f51a7b7ade33eb11cfee7c08";

        // We expect the following call to revert due to assetIn != CRV
        hevm.expectRevert("ZivoeSwapper::handle_validation_0502b1c5() _a != assetIn");

        swapper.convertTest(
            assetIn,
            assetOut,
            amountIn,
            dataUnoSwap
        );
    }

    function test_ZivoeSwapper_unoswap_restrictions_amountIn() public {

        address assetIn = CRV;
        address assetOut = DAI;
        uint256 amountIn = 300 ether;   // Wrong amountIn provided

        // 200 CRV -> DAI (true zeroForOne_0 / zeroForOne_DLENGTH)
        bytes memory dataUnoSwap = 
        hex"0502b1c5000000000000000000000000d533a949740bb3306d119cc777fa900ba034cd5200000000000000000000000000000000000000000000000ad78ebc5ac6200000000000000000000000000000000000000000000000000009cf68d88c9abaa0620000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000280000000000000003b6d03403da1313ae46132a397d90d95b1424a9a7e3e0fce80000000000000003b6d0340a478c2975ab1ea89e8196811f51a7b7ade33eb11cfee7c08";

        // We expect the following call to revert due to amountIn != 200
        hevm.expectRevert("ZivoeSwapper::handle_validation_0502b1c5() _b != amountIn");

        swapper.convertTest(
            assetIn,
            assetOut,
            amountIn,
            dataUnoSwap
        );
    }

    // TODO: Update the four following tests with proper imprecisions/bugs to validate

    function test_ZivoeSwapper_unoswap_restrictions_assetIn_token0() public {

        address assetIn = CRV; 
        address assetOut = DAI;
        uint256 amountIn = 200 ether;

        // 200 CRV -> DAI (true zeroForOne_0 / zeroForOne_DLENGTH)
        bytes memory dataUnoSwap = 
        hex"0502b1c5000000000000000000000000d533a949740bb3306d119cc777fa900ba034cd5200000000000000000000000000000000000000000000000ad78ebc5ac6200000000000000000000000000000000000000000000000000009cf68d88c9abaa0620000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000280000000000000003b6d03403da1313ae46132a397d90d95b1424a9a7e3e0fce80000000000000003b6d0340a478c2975ab1ea89e8196811f51a7b7ade33eb11cfee7c08";

        // Fund swapper with 200 CRV
        deal(assetIn, address(swapper), amountIn);


        // We expect the following call to revert as "dataUnoSwap" has CRV as assetIn, but our input parameter is FRAX for assetIn
        hevm.expectRevert("ZivoeSwapper::handle_validation_0502b1c5() IUniswapV2Pool_ZivoeSwapper(address(uint160(uint256(_d[0])))).token1() != assetIn");

        (bytes4 sig,, uint256[] memory pools) = swapper.convertTest(assetIn, assetOut, amountIn, dataUnoSwap);

        // swapper.convertTest(
        //     assetIn,
        //     assetOut,
        //     amountIn,
        //     dataUnoSwap
        // );
    }

    function test_ZivoeSwapper_unoswap_restrictions_assetIn_token1() public {
        // Case with zeroForOne_0 = true
        // "data" below is for a CRV to WETH swap for amount = 200 * 10**18
        // We provide the wrong assetIn (FRAX instead of CRV)
        address assetIn = FRAX; 
        address assetOut = WETH;
        uint256 amountIn = 200 ether;

        // in below data we modified the first address to be equal to FRAX otherwise 2 errors are thrown
        bytes memory data = 
        hex"2e95b6c8000000000000000000000000853d955acef822db058eb8505911ed77f175b99e00000000000000000000000000000000000000000000000ad78ebc5ac62000000000000000000000000000000000000000000000000000000185b5941251fda60000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000180000000000000003b6d03403da1313ae46132a397d90d95b1424a9a7e3e0fcecfee7c08";

        // We expect the following call to revert due to assetIn != CRV and zeroForOne_0 = true
        hevm.expectRevert("ZivoeSwapper::handle_validation_0502b1c5() IUniswapV2Pool_ZivoeSwapper(address(uint160(uint256(_d[0])))).token1() != assetIn");

        swapper.convertTest(
            assetIn,
            assetOut,
            amountIn,
            data
        );
    }

    function test_ZivoeSwapper_unoswap_restrictions_assetOut_token0() public {
        // Case with zeroForOne_DLENGTH = true
        // "data" below is for a FRAX to AAVE swap for amount = 1 * 10**18
        // We provide the wrong assetOut (CRV instead of AAVE)
        address assetIn = FRAX; 
        address assetOut = CRV;
        uint256 amountIn = 1 ether;


        // FRAX -> AAVE, 1 ether
        bytes memory data = 
        hex"2e95b6c8000000000000000000000000853d955acef822db058eb8505911ed77f175b99e0000000000000000000000000000000000000000000000000de0b6b3a7640000000000000000000000000000000000000000000000000000003918d7d597ef5e0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000200000000000000003b6d0340fd0a40bc83c5fae4203dec7e5929b446b07d1c7680000000000000003b6d03409909d09656fce21d1904f662b99382b887a9c5dacfee7c08";


        // We expect the following call to revert due to assetOut != WETH and zeroForOne_DLENGTH = true
        hevm.expectRevert("ZivoeSwapper::handle_validation_0502b1c5() IUniswapV2Pool_ZivoeSwapper(address(uint160(uint256(_d[_d.length - 1])))).token0() != assetOut");

        swapper.convertTest(
            assetIn,
            assetOut,
            amountIn,
            data
        );
    }

    function test_ZivoeSwapper_unoswap_restrictions_assetOut_token1() public {
        // Case with zeroForOne_DLENGTH = false
        // We provide the wrong assetOut (FRAX instead of CRV)
        address assetIn = DAI; 
        address assetOut = FRAX;
        uint256 amountIn = 200 ether;


        // We expect the following call to revert due to assetIn != DAI and zeroForOne_0 = false
        hevm.expectRevert("ZivoeSwapper::handle_validation_0502b1c5() IUniswapV2Pool_ZivoeSwapper(address(uint160(uint256(_d[_d.length - 1])))).token1() != assetOut");

        // swapper.convertTest(
        //     assetIn,
        //     assetOut,
        //     amountIn,
        //     dataUnoSwap
        // );
    }


    // ===================== "3eca9c0a": fillOrderRFQ() ==========================


    function test_ZivoeSwapper_fillOrderRFQ_convertAsset() public {
 
        address assetIn = USDT;
        address assetOut = WBTC;
        uint256 amountIn = 5_000 * 10**6;

        // fund contract with the right amount of tokens to swap.
        deal(assetIn, address(swapper), amountIn);

        // assert initial balances are correct.
        assertEq(amountIn, IERC20(assetIn).balanceOf(address(swapper)));
        assertEq(0, IERC20(assetOut).balanceOf(address(swapper)));

        emit log_named_uint("swapper assetIn pre-swap balance:", IERC20(assetIn).balanceOf(address(swapper)));

        (bytes4 sig,,) = swapper.convertTest(
                        assetIn,
                        assetOut,
                        amountIn,
                        dataFillOrderRFQ
                    );

        emit log_named_uint("swapper assetIn after-swap balance:", IERC20(assetIn).balanceOf(address(swapper)));

        // ensure we go through the right validation function.
        assert(sig == bytes4(keccak256("fillOrderRFQ((uint256,address,address,address,address,uint256,uint256),bytes,uint256,uint256)")));

        // assert balances after swap are correct.
        assertEq(0, IERC20(assetIn).balanceOf(address(swapper)));
        assert(IERC20(assetOut).balanceOf(address(swapper)) > 0);
    }

    function test_ZivoeSwapper_fillOrderRFQ_restrictions_assetIn() public {
        // We provide the wrong assetIn (USDC instead of USDT)
        address assetIn = USDC; 
        address assetOut = WBTC;
        uint256 amountIn = 5_000 * 10**6;


        // We expect the following call to revert due to amountIn != 200
        hevm.expectRevert("ZivoeSwapper::handle_validation_d0a3b665() address(_a.takerAsset) != assetIn");

        swapper.convertTest(
            assetIn,
            assetOut,
            amountIn,
            dataFillOrderRFQ
        );
    }

    function test_ZivoeSwapper_fillOrderRFQ_restrictions_assetOut() public {
        // We provide the wrong assetOut (DAI instead of WBTC)
        address assetIn = USDT; 
        address assetOut = DAI;
        uint256 amountIn = 5_000 * 10**6;


        // We expect the following call to revert due to assetOut != WBTC
        hevm.expectRevert("ZivoeSwapper::handle_validation_d0a3b665() address(_a.makerAsset) != assetOut");

        swapper.convertTest(
            assetIn,
            assetOut,
            amountIn,
            dataFillOrderRFQ
        );
    }

    function test_ZivoeSwapper_fillOrderRFQ_restrictions_amountInToStruct() public {
        // We provide the wrong amountIn (500 instead of 5_000)
        address assetIn = USDT; 
        address assetOut = WBTC;
        uint256 amountIn = 500 * 10**6;


        // We expect the following call to revert due to assetOut != WBTC
        hevm.expectRevert("ZivoeSwapper::handle_validation_d0a3b665() _a.takingAmount != amountIn");

        swapper.convertTest(
            assetIn,
            assetOut,
            amountIn,
            dataFillOrderRFQ
        );     
    }


    // ====================== helper testing ==========================

    function test_ZivoeSwapper_extra_log() public {
        emit log_named_address("swapper testing address", address(swapper));
    }
}