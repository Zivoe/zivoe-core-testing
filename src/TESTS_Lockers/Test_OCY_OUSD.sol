// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.17;

import "../Utility/Utility.sol";

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

    OCY_OUSD OUSDLocker;

    OCT_DAO TreasuryDAO;
    OCT_YDL TreasuryYDL;

    address OUSD_VAULT = 0xE75D77B1865Ae93c7eaa3040B038D7aA7BC02F70;

    function setUp() public {

        deployCore(false);

        TreasuryDAO = new OCT_DAO(address(DAO), address(GBL));
        TreasuryYDL = new OCT_YDL(address(DAO), address(GBL));

        OUSDLocker = new OCY_OUSD(address(DAO), address(GBL), address(TreasuryYDL));

        // This test suite assumes someone has called the rebase() function.
        OUSDLocker.rebase();

    }

    function helper_getAndDepositOUSD() public {

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
        emit Logger(address(TreasuryDAO));
        
        assert(zvl.try_updateIsKeeper(address(GBL), address(this), true));
        TreasuryDAO.convertAndForward(assetIn, assetOut, dataSwap);

        emit log_named_uint("TreasuryDAO assetIn after-swap balance:", IERC20(assetIn).balanceOf(address(TreasuryDAO)));
        emit log_named_uint("TreasuryDAO assetOut after-swap balance:", IERC20(assetOut).balanceOf(address(DAO)));

        // assert balances after swap are correct.
        assertEq(0, IERC20(assetIn).balanceOf(address(TreasuryDAO)));
        assert(IERC20(assetOut).balanceOf(address(DAO)) > 0);

        assert(zvl.try_updateIsLocker(address(GBL), address(OUSDLocker), true));
        assert(god.try_push(address(DAO), address(OUSDLocker), OUSD, IERC20(OUSD).balanceOf(address(DAO)), ""));

    }

    event OCTYDLSetZVL(address indexed newOCT, address indexed oldOCT);

    event Logger(address);

    // Validate intial state of OUSDLocker

    function test_OCY_OUSD_init() public {

        assertEq(OUSDLocker.OUSD(), 0x2A8e1E676Ec238d8A992307B495b45B3fEAa5e86);
        assertEq(OUSDLocker.GBL(), address(GBL));
        assertEq(OUSDLocker.distributionLast(), block.timestamp);
        assertEq(OUSDLocker.basis(), 0);
        assertEq(OUSDLocker.INTERVAL(), 14 days);

    }

    // Validate pushToLocker() state changes.
    // Validate pushToLocker() restrictions.
    // This includes:
    //   - asset must be OUSD
    //   - onlyOwner() modifier

    function test_OCY_OUSD_pushToLocker_restrictions_msgSender() public {

    }

    function test_OCY_OUSD_pushToLocker_restrictions_asset() public {
        
    }

    function test_OCY_OUSD_pushToLocker_state() public {
        
    }

    // Validate pullFromLocker() state changes.
    // Validate pullFromLocker() restrictions.
    // This includes:
    //   - asset must be OUSD
    //   - onlyOwner() modifier

    function test_OCY_OUSD_pullFromLocker_restrictions_msgSender() public {

    }

    function test_OCY_OUSD_pullFromLocker_restrictions_asset() public {
        
    }

    function test_OCY_OUSD_pullFromLocker_state() public {
        
    }

    // Validate pullFromLockerPartial() state changes.
    // Validate pullFromLockerPartial() restrictions.
    // This includes:
    //   - asset must be OUSD
    //   - onlyOwner() modifier

    function test_OCY_OUSD_pullFromLockerPartial_restrictions_msgSender() public {

    }

    function test_OCY_OUSD_pullFromLockerPartial_restrictions_asset() public {
        
    }

    function test_OCY_OUSD_pullFromLockerPartial_state() public {
        
    }

    // Validate forwardYield() state changes.
    // Validate forwardYield() restrictions.
    // This includes:
    //   - asset must be OUSD
    //   - onlyOwner() modifier

    function test_OCY_OUSD_forwardYield() public {

        helper_getAndDepositOUSD();

        hevm.warp(block.timestamp + 1 days);
        emit log_named_uint("OUSD balance:", IERC20(OUSD).balanceOf(address(OUSDLocker)));
        deal(DAI, address(OUSD_VAULT), 100_000 ether);
        deal(USDC, address(OUSD_VAULT), 100_000 * 10**6);
        deal(FRAX, address(OUSD_VAULT), 100_000 ether);
        deal(USDT, address(OUSD_VAULT), 100_000 * 10**6);
        IVault(OUSD_VAULT).rebase();
        hevm.warp(block.timestamp + 1 days);
        emit log_named_uint("OUSD balance:", IERC20(OUSD).balanceOf(address(OUSDLocker)));
        deal(DAI, address(OUSD_VAULT), 100_000 ether);
        deal(USDC, address(OUSD_VAULT), 100_000 * 10**6);
        deal(FRAX, address(OUSD_VAULT), 100_000 ether);
        deal(USDT, address(OUSD_VAULT), 100_000 * 10**6);
        IVault(OUSD_VAULT).rebase();
        hevm.warp(block.timestamp + 14 days);
        emit log_named_uint("OUSD balance:", IERC20(OUSD).balanceOf(address(OUSDLocker)));

        OUSDLocker.forwardYield();
    }

    // Validate setOCTYDL() state changes.
    // Validate setOCTYDL() restrictions.
    // This includes:
    //   - _msgSender() must be ZVL

    function test_OCY_OUSD_setOCTYDL_restrictions_msgSender() public {
        // Can't call if _msgSender() is not ZVL.
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCY_OUSD::setOCTYDL() _msgSender() != IZivoeGlobals_OCY_OUSD(GBL).ZVL()");
        OUSDLocker.setOCTYDL(address(bob));
        hevm.stopPrank();
    }

    function test_OCY_OUSD_setOCTYDL_state(address fuzzed) public {
        
        // Pre-state.
        assertEq(OUSDLocker.OCT_YDL(), address(TreasuryYDL));

        // setOCTYDL().
        hevm.expectEmit(true, true, false, false, address(OUSDLocker));
        emit OCTYDLSetZVL(address(fuzzed), address(TreasuryYDL));
        hevm.startPrank(address(zvl));
        OUSDLocker.setOCTYDL(address(fuzzed));
        hevm.stopPrank();

        // Post-state.
        assertEq(OUSDLocker.OCT_YDL(), address(fuzzed));

    }

}