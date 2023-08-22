// SPDX-License-Identifier: UNLICENSED
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
    // enum RebaseOptions {
    //     NotSet,
    //     OptOut,
    //     OptIn
    // }
    function rebaseOptIn() external;
    function rebaseState(address) external returns (uint8); // Returns RebaseOptions enum (see above).
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
        // OUSDLocker.rebase();

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
    
    event BasisAdjusted(uint256 priorBasis, uint256 newBasis);
    
    event UpdatedOCTYDL(address indexed newOCT, address indexed oldOCT);
    
    event YieldForwarded(uint256 amount, uint256 newBasis);

    event Logger(address);

    // Validate intial state of OUSDLocker

    function test_OCY_OUSD_init() public {

        assertEq(OUSDLocker.OUSD(), 0x2A8e1E676Ec238d8A992307B495b45B3fEAa5e86);
        assertEq(OUSDLocker.GBL(), address(GBL));
        assertEq(OUSDLocker.basis(), 0);

    }

    // Validate rebase() state changes.

    function test_OCY_OUSD_rebase() public {

        // enum RebaseOptions {
        //     NotSet,
        //     OptOut,
        //     OptIn
        // }

        // Pre-state.
        uint8 rebaseSetting = IOUSD(OUSD).rebaseState(address(OUSDLocker));
        assertEq(rebaseSetting, 0);

        // rebase().
        OUSDLocker.rebase();
        
        // Post-state.
        rebaseSetting = IOUSD(OUSD).rebaseState(address(OUSDLocker));
        assertEq(rebaseSetting, 2);

    }

    // Validate pushToLocker() state changes.
    // Validate pushToLocker() restrictions.
    // This includes:
    //   - asset must be OUSD
    //   - onlyOwner() modifier

    function test_OCY_OUSD_pushToLocker_restrictions_msgSender() public {

        // Can't push to contract if _msgSender() != owner()
        hevm.startPrank(address(bob));
        hevm.expectRevert("Ownable: caller is not the owner");
        OUSDLocker.pushToLocker(address(OUSD), 100 ether, "");
        hevm.stopPrank();
    }

    function test_OCY_OUSD_pushToLocker_restrictions_asset() public {
        
        assert(zvl.try_updateIsLocker(address(GBL), address(OUSDLocker), true));
        
        // Can't push to contract if asset != OUSD
        hevm.startPrank(address(god));
        hevm.expectRevert("OCY_OUSD::pushToLocker() asset != OUSD");
        DAO.push(address(OUSDLocker), address(ZVE), 100 ether, "");
        hevm.stopPrank();
    }

    function test_OCY_OUSD_pushToLocker_state() public {
        
        address assetIn = USDC;
        address assetOut = OUSD;
        uint256 amountIn = 2000000 * 10**6;

        // 200,000 USDC -> OUSD
        bytes memory dataSwap =
        hex"12aa3caf0000000000000000000000001136b25047e142fa3018184793aec68fbb173ce4000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000002a8e1e676ec238d8a992307b495b45b3feaa5e860000000000000000000000001136b25047e142fa3018184793aec68fbb173ce4000000000000000000000000883816205341a6ba3c32ae8dadcebdd9d59bc2c4000000000000000000000000000000000000000000000000000001d1a94a200000000000000000000000000000000000000000000001a6651513ddf098f969a00000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000014000000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000018a00000000000000000000000000000000000000000000016c00013e0000f400a007e5c0d20000000000000000000000000000000000000000000000d00000b600000600a0fd53121f512087650d7bbfc3a9f10587d7778206671719d9910d6b175474e89094c44da98b954eedeac495271d0f0044a6417ed600000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001a36ddf857a09de8316760020d6bdbf782a8e1e676ec238d8a992307b495b45b3feaa5e8600a0f2fa6b662a8e1e676ec238d8a992307b495b45b3feaa5e8600000000000000000000000000000000000000000001a7aa752c51e5c450b1d70000000000000000459b9f61774d029980a06c4eca272a8e1e676ec238d8a992307b495b45b3feaa5e861111111254eeb25477b68fb85ed929f73a96058200000000000000000000000000000000000000000000cfee7c08";
        deal(assetIn, address(TreasuryDAO), amountIn);
        assert(zvl.try_updateIsKeeper(address(GBL), address(this), true));
        TreasuryDAO.convertAndForward(assetIn, assetOut, dataSwap);
        assert(zvl.try_updateIsLocker(address(GBL), address(OUSDLocker), true));

        // DAO now owns OUSD via conversion of USDC -> OUSD in the OCT_DAO.
        uint256 balanceOUSD = IERC20(OUSD).balanceOf(address(DAO));

        // pushToLocker().
        hevm.expectEmit(false, false, false, true, address(OUSDLocker));
        emit BasisAdjusted(0, balanceOUSD);
        assert(god.try_push(address(DAO), address(OUSDLocker), OUSD, balanceOUSD, ""));

        // Post-state.
        assertEq(balanceOUSD, IERC20(OUSD).balanceOf(address(OUSDLocker)));
        assertEq(OUSDLocker.basis(), IERC20(OUSD).balanceOf(address(OUSDLocker)));

    }

    // Validate pullFromLocker() state changes.
    // Validate pullFromLocker() restrictions.
    // This includes:
    //   - asset must be OUSD
    //   - onlyOwner() modifier

    function test_OCY_OUSD_pullFromLocker_restrictions_msgSender() public {

        // Can't push to contract if _msgSender() != owner()
        hevm.startPrank(address(bob));
        hevm.expectRevert("Ownable: caller is not the owner");
        OUSDLocker.pullFromLocker(address(OUSD), "");
        hevm.stopPrank();

    }

    function test_OCY_OUSD_pullFromLocker_restrictions_asset() public {
        
        // Can't push to contract if asset != OUSD
        hevm.startPrank(address(god));
        hevm.expectRevert("OCY_OUSD::pullFromLocker() asset != OUSD");
        DAO.pull(address(OUSDLocker), address(ZVE), "");
        hevm.stopPrank();
    }

    function test_OCY_OUSD_pullFromLocker_state() public {
        
        address assetIn = USDC;
        address assetOut = OUSD;
        uint256 amountIn = 2000000 * 10**6;

        // 200,000 USDC -> OUSD
        bytes memory dataSwap =
        hex"12aa3caf0000000000000000000000001136b25047e142fa3018184793aec68fbb173ce4000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000002a8e1e676ec238d8a992307b495b45b3feaa5e860000000000000000000000001136b25047e142fa3018184793aec68fbb173ce4000000000000000000000000883816205341a6ba3c32ae8dadcebdd9d59bc2c4000000000000000000000000000000000000000000000000000001d1a94a200000000000000000000000000000000000000000000001a6651513ddf098f969a00000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000014000000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000018a00000000000000000000000000000000000000000000016c00013e0000f400a007e5c0d20000000000000000000000000000000000000000000000d00000b600000600a0fd53121f512087650d7bbfc3a9f10587d7778206671719d9910d6b175474e89094c44da98b954eedeac495271d0f0044a6417ed600000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001a36ddf857a09de8316760020d6bdbf782a8e1e676ec238d8a992307b495b45b3feaa5e8600a0f2fa6b662a8e1e676ec238d8a992307b495b45b3feaa5e8600000000000000000000000000000000000000000001a7aa752c51e5c450b1d70000000000000000459b9f61774d029980a06c4eca272a8e1e676ec238d8a992307b495b45b3feaa5e861111111254eeb25477b68fb85ed929f73a96058200000000000000000000000000000000000000000000cfee7c08";
        deal(assetIn, address(TreasuryDAO), amountIn);
        assert(zvl.try_updateIsKeeper(address(GBL), address(this), true));
        TreasuryDAO.convertAndForward(assetIn, assetOut, dataSwap);
        assert(zvl.try_updateIsLocker(address(GBL), address(OUSDLocker), true));

        // DAO now owns OUSD via conversion of USDC -> OUSD in the OCT_DAO.
        uint256 balanceOUSD = IERC20(OUSD).balanceOf(address(DAO));

        // pushToLocker().
        hevm.expectEmit(false, false, false, true, address(OUSDLocker));
        emit BasisAdjusted(0, balanceOUSD);
        assert(god.try_push(address(DAO), address(OUSDLocker), OUSD, balanceOUSD, ""));

        // Post-state.
        assertEq(balanceOUSD, IERC20(OUSD).balanceOf(address(OUSDLocker)));
        assertEq(OUSDLocker.basis(), IERC20(OUSD).balanceOf(address(OUSDLocker)));

        // pullFromLocker().
        hevm.expectEmit(false, false, false, true, address(OUSDLocker));
        emit BasisAdjusted(balanceOUSD, 0);
        assert(god.try_pull(address(DAO), address(OUSDLocker), OUSD, ""));

        // Post-state.
        assertEq(balanceOUSD, IERC20(OUSD).balanceOf(address(DAO)));
        assertEq(OUSDLocker.basis(), 0);

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

    function test_OCY_OUSD_pullFromLockerPartial_state(uint96 random) public {
        
        address assetIn = USDC;
        address assetOut = OUSD;
        uint256 amountIn = 2000000 * 10**6;

        // 200,000 USDC -> OUSD
        bytes memory dataSwap =
        hex"12aa3caf0000000000000000000000001136b25047e142fa3018184793aec68fbb173ce4000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000002a8e1e676ec238d8a992307b495b45b3feaa5e860000000000000000000000001136b25047e142fa3018184793aec68fbb173ce4000000000000000000000000883816205341a6ba3c32ae8dadcebdd9d59bc2c4000000000000000000000000000000000000000000000000000001d1a94a200000000000000000000000000000000000000000000001a6651513ddf098f969a00000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000014000000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000018a00000000000000000000000000000000000000000000016c00013e0000f400a007e5c0d20000000000000000000000000000000000000000000000d00000b600000600a0fd53121f512087650d7bbfc3a9f10587d7778206671719d9910d6b175474e89094c44da98b954eedeac495271d0f0044a6417ed600000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001a36ddf857a09de8316760020d6bdbf782a8e1e676ec238d8a992307b495b45b3feaa5e8600a0f2fa6b662a8e1e676ec238d8a992307b495b45b3feaa5e8600000000000000000000000000000000000000000001a7aa752c51e5c450b1d70000000000000000459b9f61774d029980a06c4eca272a8e1e676ec238d8a992307b495b45b3feaa5e861111111254eeb25477b68fb85ed929f73a96058200000000000000000000000000000000000000000000cfee7c08";
        deal(assetIn, address(TreasuryDAO), amountIn);
        assert(zvl.try_updateIsKeeper(address(GBL), address(this), true));
        TreasuryDAO.convertAndForward(assetIn, assetOut, dataSwap);
        assert(zvl.try_updateIsLocker(address(GBL), address(OUSDLocker), true));

        // DAO now owns OUSD via conversion of USDC -> OUSD in the OCT_DAO.
        uint256 balanceOUSD = IERC20(OUSD).balanceOf(address(DAO));

        // pushToLocker().
        hevm.expectEmit(false, false, false, true, address(OUSDLocker));
        emit BasisAdjusted(0, balanceOUSD);
        assert(god.try_push(address(DAO), address(OUSDLocker), OUSD, balanceOUSD, ""));

        // Post-state.
        assertEq(balanceOUSD, IERC20(OUSD).balanceOf(address(OUSDLocker)));
        assertEq(OUSDLocker.basis(), IERC20(OUSD).balanceOf(address(OUSDLocker)));

        // pullFromLockerPartial().
        uint256 pullAmount = random % balanceOUSD;
        hevm.expectEmit(false, false, false, true, address(OUSDLocker));
        emit BasisAdjusted(balanceOUSD, balanceOUSD - pullAmount);
        assert(god.try_pullPartial(address(DAO), address(OUSDLocker), OUSD, pullAmount, ""));

        // Post-state.
        assertEq(pullAmount, IERC20(OUSD).balanceOf(address(DAO)));
        assertEq(OUSDLocker.basis(), balanceOUSD - pullAmount);

    }

    // Validate forwardYield() state changes.
    // Validate forwardYield() restrictions.

    function test_OCY_OUSD_forwardYield_state(uint96 random) public {

        uint256 randomIncrease = uint256(random) + 100_000 ether;

        // NOTE: Must ensure rebase() is called in OUSDLocker.
        OUSDLocker.rebase();
        helper_getAndDepositOUSD();

        // Simulate OUSD protocol generating yield and rebasing it's overall protocol token (OUSD).

        hevm.warp(block.timestamp + 1 days);
        uint snapshotA = IERC20(OUSD).balanceOf(address(OUSDLocker));
        deal(DAI, address(OUSD_VAULT), randomIncrease);
        deal(FRAX, address(OUSD_VAULT), randomIncrease);
        IVault(OUSD_VAULT).rebase();
        hevm.warp(block.timestamp + 1 days);
        uint snapshotB = IERC20(OUSD).balanceOf(address(OUSDLocker));
        deal(DAI, address(OUSD_VAULT), randomIncrease);
        deal(FRAX, address(OUSD_VAULT), randomIncrease);
        IVault(OUSD_VAULT).rebase();
        hevm.warp(block.timestamp + 14 days);
        uint snapshotC = IERC20(OUSD).balanceOf(address(OUSDLocker));

        hevm.warp(block.timestamp + 30 days);
        hevm.roll(block.number + 1);
        IVault(OUSD_VAULT).rebase();

        emit log_named_uint("OUSD snapshotA:", snapshotA);
        emit log_named_uint("OUSD snapshotB:", snapshotB);
        emit log_named_uint("OUSD snapshotC:", snapshotC);
        emit log_named_uint("OUSD balance:", IERC20(OUSD).balanceOf(address(OUSDLocker)));

        // Pre-state.
        uint256 amountOUSD = IERC20(OUSD).balanceOf(address(OUSDLocker));
        uint256 preBasis = OUSDLocker.basis();
        uint256 amountOUSD_OCT_YDL = IERC20(OUSD).balanceOf(address(TreasuryYDL));

        assert(amountOUSD > preBasis);  // Assuming this, but initiating capital injection into OUSD fails in this test

        hevm.expectEmit(false, false, false, true, address(OUSDLocker));
        emit YieldForwarded(amountOUSD - preBasis, preBasis);
        OUSDLocker.forwardYield();

        // Post-state.
        assertEq(OUSDLocker.basis(), preBasis);
    }

    // Validate updateOCTYDL() state changes.
    // Validate updateOCTYDL() restrictions.
    // This includes:
    //   - _msgSender() must be ZVL

    function test_OCY_OUSD_updateOCTYDL_restrictions_msgSender() public {
        // Can't call if _msgSender() is not ZVL.
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCY_OUSD::updateOCTYDL() _msgSender() != IZivoeGlobals_OCY_OUSD(GBL).ZVL()");
        OUSDLocker.updateOCTYDL(address(bob));
        hevm.stopPrank();
    }

    function test_OCY_OUSD_updateOCTYDL_state(address fuzzed) public {
        
        // Pre-state.
        assertEq(OUSDLocker.OCT_YDL(), address(TreasuryYDL));

        // updateOCTYDL().
        hevm.expectEmit(true, true, false, false, address(OUSDLocker));
        emit UpdatedOCTYDL(address(fuzzed), address(TreasuryYDL));
        hevm.startPrank(address(zvl));
        OUSDLocker.updateOCTYDL(address(fuzzed));
        hevm.stopPrank();

        // Post-state.
        assertEq(OUSDLocker.OCT_YDL(), address(fuzzed));

    }

}