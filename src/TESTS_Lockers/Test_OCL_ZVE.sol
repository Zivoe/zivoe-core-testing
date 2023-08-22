// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../Utility/Utility.sol";

import "../../lib/zivoe-core-foundry/src/lockers/OCL/OCL_ZVE.sol";
import "../../lib/zivoe-core-foundry/src/lockers/OCT/OCT_YDL.sol";

import "../../lib/zivoe-core-foundry/src/lockers/OCG/OCG_ERC20_FreeClaim.sol";

contract Test_OCL_ZVE is Utility {

    using SafeERC20 for IERC20;

    OCL_ZVE OCL_ZVE_SUSHI_DAI;
    OCL_ZVE OCL_ZVE_SUSHI_FRAX;
    OCL_ZVE OCL_ZVE_SUSHI_USDC;
    OCL_ZVE OCL_ZVE_SUSHI_USDT;

    OCL_ZVE OCL_ZVE_UNIV2_DAI;
    OCL_ZVE OCL_ZVE_UNIV2_FRAX;
    OCL_ZVE OCL_ZVE_UNIV2_USDC;
    OCL_ZVE OCL_ZVE_UNIV2_USDT;

    OCT_YDL Treasury;

    OCG_ERC20_FreeClaim ZVEClaimer;

    function setUp() public {

        deployCore(false);

        Treasury = new OCT_YDL(address(DAO), address(GBL));

        // Simulate ITO (10mm * 8 * 4), DAI/FRAX/USDC/USDT.
        simulateITO(10_000_000 ether, 10_000_000 ether, 10_000_000 * USD, 10_000_000 * USD);

        // Initialize and whitelist OCL_ZVE Uniswap v2 locker's.
        OCL_ZVE_UNIV2_DAI = new OCL_ZVE(address(DAO), address(GBL), DAI, UNISWAP_V2_ROUTER_02, UNISWAP_V2_FACTORY, address(Treasury));
        OCL_ZVE_UNIV2_FRAX = new OCL_ZVE(address(DAO), address(GBL), FRAX, UNISWAP_V2_ROUTER_02, UNISWAP_V2_FACTORY, address(Treasury));
        OCL_ZVE_UNIV2_USDC = new OCL_ZVE(address(DAO), address(GBL), USDC, UNISWAP_V2_ROUTER_02, UNISWAP_V2_FACTORY, address(Treasury));
        OCL_ZVE_UNIV2_USDT = new OCL_ZVE(address(DAO), address(GBL), USDT, UNISWAP_V2_ROUTER_02, UNISWAP_V2_FACTORY, address(Treasury));

        zvl.try_updateIsLocker(address(GBL), address(OCL_ZVE_UNIV2_DAI), true);
        zvl.try_updateIsLocker(address(GBL), address(OCL_ZVE_UNIV2_FRAX), true);
        zvl.try_updateIsLocker(address(GBL), address(OCL_ZVE_UNIV2_USDC), true);
        zvl.try_updateIsLocker(address(GBL), address(OCL_ZVE_UNIV2_USDT), true);

        // Initialize and whitelist OCL_ZVE Sushi locker's.
        OCL_ZVE_SUSHI_DAI = new OCL_ZVE(address(DAO), address(GBL), DAI, SUSHI_V2_ROUTER, SUSHI_V2_FACTORY, address(Treasury));
        OCL_ZVE_SUSHI_FRAX = new OCL_ZVE(address(DAO), address(GBL), FRAX, SUSHI_V2_ROUTER, SUSHI_V2_FACTORY, address(Treasury));
        OCL_ZVE_SUSHI_USDC = new OCL_ZVE(address(DAO), address(GBL), USDC, SUSHI_V2_ROUTER, SUSHI_V2_FACTORY, address(Treasury));
        OCL_ZVE_SUSHI_USDT = new OCL_ZVE(address(DAO), address(GBL), USDT, SUSHI_V2_ROUTER, SUSHI_V2_FACTORY, address(Treasury));

        zvl.try_updateIsLocker(address(GBL), address(OCL_ZVE_SUSHI_DAI), true);
        zvl.try_updateIsLocker(address(GBL), address(OCL_ZVE_SUSHI_FRAX), true);
        zvl.try_updateIsLocker(address(GBL), address(OCL_ZVE_SUSHI_USDC), true);
        zvl.try_updateIsLocker(address(GBL), address(OCL_ZVE_SUSHI_USDT), true);

        // Create an OCG locker which moves ZVE from DAO -> OCG ... allows another account to claim.
        // We need ZVE accessible by someone to test the ZivoeRewards functionality contract (generic $ZVE staking contract).
        ZVEClaimer = new OCG_ERC20_FreeClaim(address(DAO));
        assert(zvl.try_updateIsLocker(address(GBL), address(ZVEClaimer), true));
        assert(god.try_push(address(DAO), address(ZVEClaimer), address(ZVE), 100_000 ether, ""));
        ZVEClaimer.forward(address(ZVE), 100_000 ether, address(this));

    }
    
    event LiquidityTokensBurned(uint256 amountBurned, uint256 claimedZVE, uint256 claimedPairAsset);

    event LiquidityTokensMinted(uint256 amountMinted, uint256 depositedZVE, uint256 depositedPairAsset);

    event UpdatedOCTYDL(address indexed newOCT, address indexed oldOCT);

    event UpdatedCompoundingRateBIPS(uint256 oldValue, uint256 newValue);

    event YieldForwarded(address indexed asset, uint256 amount);

    // ----------------------
    //    Helper Functions
    // ----------------------

    function buyZVE_Sushi(uint256 amount, address pairAsset) public {
        
        address SUSHI_ROUTER = OCL_ZVE_SUSHI_DAI.router();
        address[] memory path = new address[](2);
        path[1] = address(ZVE);

        if (pairAsset == DAI) {
            mint("DAI", address(this), amount);
            IERC20(DAI).safeApprove(SUSHI_ROUTER, amount);
            path[0] = DAI;
        }
        else if (pairAsset == FRAX) {
            mint("FRAX", address(this), amount);
            IERC20(FRAX).safeApprove(SUSHI_ROUTER, amount);
            path[0] = FRAX;
        }
        else if (pairAsset == USDC) {
            mint("USDC", address(this), amount);
            IERC20(USDC).safeApprove(SUSHI_ROUTER, amount);
            path[0] = USDC;
        }
        else if (pairAsset == USDT) {
            mint("USDT", address(this), amount);
            IERC20(USDT).safeApprove(SUSHI_ROUTER, amount);
            path[0] = USDT;
        }
        else { revert(); }

        // function swapExactTokensForTokens(
        //     uint256 amountIn,
        //     uint256 amountOutMin,
        //     address[] calldata path,
        //     address to,
        //     uint256 deadline
        // ) external returns (uint256[] memory amounts);
        ISushiRouter(SUSHI_ROUTER).swapExactTokensForTokens(
            amount, 
            0, 
            path, 
            address(this), 
            block.timestamp + 5 days
        );
    }

    function sellZVE_Sushi(uint256 amount, address pairAsset) public {
        
        address SUSHI_ROUTER = OCL_ZVE_SUSHI_DAI.router();
        address[] memory path = new address[](2);
        path[0] = address(ZVE);

        IERC20(address(ZVE)).safeApprove(SUSHI_ROUTER, amount);

        if (pairAsset == DAI) {
            path[1] = DAI;
        }
        else if (pairAsset == FRAX) {
            path[1] = FRAX;
        }
        else if (pairAsset == USDC) {
            path[1] = USDC;
        }
        else if (pairAsset == USDT) {
            path[1] = USDT;
        }
        else { revert(); }

        // function swapExactTokensForTokens(
        //     uint256 amountIn,
        //     uint256 amountOutMin,
        //     address[] calldata path,
        //     address to,
        //     uint256 deadline
        // ) external returns (uint256[] memory amounts);
        ISushiRouter(SUSHI_ROUTER).swapExactTokensForTokens(
            amount, 
            0, 
            path, 
            address(this), 
            block.timestamp + 5 days
        );
    }

    function buyZVE_Uni(uint256 amount, address pairAsset) public {
        
        address UNIV2_ROUTER = OCL_ZVE_UNIV2_DAI.router();
        address[] memory path = new address[](2);
        path[1] = address(ZVE);

        if (pairAsset == DAI) {
            mint("DAI", address(this), amount);
            IERC20(DAI).safeApprove(UNIV2_ROUTER, amount);
            path[0] = DAI;
        }
        else if (pairAsset == FRAX) {
            mint("FRAX", address(this), amount);
            IERC20(FRAX).safeApprove(UNIV2_ROUTER, amount);
            path[0] = FRAX;
        }
        else if (pairAsset == USDC) {
            mint("USDC", address(this), amount);
            IERC20(USDC).safeApprove(UNIV2_ROUTER, amount);
            path[0] = USDC;
        }
        else if (pairAsset == USDT) {
            mint("USDT", address(this), amount);
            IERC20(USDT).safeApprove(UNIV2_ROUTER, amount);
            path[0] = USDT;
        }
        else { revert(); }

        // function swapExactTokensForTokens(
        //     uint256 amountIn,
        //     uint256 amountOutMin,
        //     address[] calldata path,
        //     address to,
        //     uint256 deadline
        // ) external returns (uint256[] memory amounts);
        IUniswapV2Router01(UNIV2_ROUTER).swapExactTokensForTokens(
            amount, 
            0, 
            path, 
            address(this), 
            block.timestamp + 5 days
        );
    }

    function sellZVE_Uni(uint256 amount, address pairAsset) public {
        
        address UNIV2_ROUTER = OCL_ZVE_UNIV2_DAI.router();
        address[] memory path = new address[](2);
        path[0] = address(ZVE);

        IERC20(address(ZVE)).safeApprove(UNIV2_ROUTER, amount);

        if (pairAsset == DAI) {
            path[1] = DAI;
        }
        else if (pairAsset == FRAX) {
            path[1] = FRAX;
        }
        else if (pairAsset == USDC) {
            path[1] = USDC;
        }
        else if (pairAsset == USDT) {
            path[1] = USDT;
        }
        else { revert(); }

        // function swapExactTokensForTokens(
        //     uint256 amountIn,
        //     uint256 amountOutMin,
        //     address[] calldata path,
        //     address to,
        //     uint256 deadline
        // ) external returns (uint256[] memory amounts);
        IUniswapV2Router01(UNIV2_ROUTER).swapExactTokensForTokens(
            amount, 
            0, 
            path, 
            address(this), 
            block.timestamp + 5 days
        );
    }


    function pushToLockerInitial_Sushi(uint256 amountA, uint256 amountB, uint256 modularity) public {
        
        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[1] = address(ZVE);
        amounts[0] = amountA;
        amounts[1] = amountB;

        if (modularity == 0) {
            assets[0] = DAI;

            // Pre-state.
            assertEq(OCL_ZVE_SUSHI_DAI.basis(), 0);
            assertEq(OCL_ZVE_SUSHI_DAI.nextYieldDistribution(), 0);
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_SUSHI_DAI), assets, amounts, new bytes[](2)));

            // Post-state.
            (uint256 basis, uint256 lpTokens) = OCL_ZVE_SUSHI_DAI.fetchBasis();
            assertGt(lpTokens, 0);
            assertEq(OCL_ZVE_SUSHI_DAI.basis(), basis);
            assertEq(OCL_ZVE_SUSHI_DAI.nextYieldDistribution(), block.timestamp + 30 days);
            
        }
        else if (modularity == 1) {
            assets[0] = FRAX;

            // Pre-state.
            assertEq(OCL_ZVE_SUSHI_FRAX.basis(), 0);
            assertEq(OCL_ZVE_SUSHI_FRAX.nextYieldDistribution(), 0);
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_SUSHI_FRAX), assets, amounts, new bytes[](2)));

            // Post-state.
            (uint256 basis, uint256 lpTokens) = OCL_ZVE_SUSHI_FRAX.fetchBasis();
            assertGt(lpTokens, 0);
            assertEq(OCL_ZVE_SUSHI_FRAX.basis(), basis);
            assertEq(OCL_ZVE_SUSHI_FRAX.nextYieldDistribution(), block.timestamp + 30 days);
        }
        else if (modularity == 2) {
            assets[0] = USDC;

            // Pre-state.
            assertEq(OCL_ZVE_SUSHI_USDC.basis(), 0);
            assertEq(OCL_ZVE_SUSHI_USDC.nextYieldDistribution(), 0);
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_SUSHI_USDC), assets, amounts, new bytes[](2)));

            // Post-state.
            (uint256 basis, uint256 lpTokens) = OCL_ZVE_SUSHI_USDC.fetchBasis();
            assertGt(lpTokens, 0);
            assertEq(OCL_ZVE_SUSHI_USDC.basis(), basis);
            assertEq(OCL_ZVE_SUSHI_USDC.nextYieldDistribution(), block.timestamp + 30 days);
        }
        else if (modularity == 3) {
            assets[0] = USDT;

            // Pre-state.
            assertEq(OCL_ZVE_SUSHI_USDT.basis(), 0);
            assertEq(OCL_ZVE_SUSHI_USDT.nextYieldDistribution(), 0);
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_SUSHI_USDT), assets, amounts, new bytes[](2)));

            // Post-state.
            (uint256 basis, uint256 lpTokens) = OCL_ZVE_SUSHI_USDT.fetchBasis();
            assertGt(lpTokens, 0);
            assertEq(OCL_ZVE_SUSHI_USDT.basis(), basis);
            assertEq(OCL_ZVE_SUSHI_USDT.nextYieldDistribution(), block.timestamp + 30 days);
        }
        else { revert(); }
    }


    function pushToLockerInitial_Uni(uint256 amountA, uint256 amountB, uint256 modularity) public {
        
        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[1] = address(ZVE);
        amounts[0] = amountA;
        amounts[1] = amountB;

        if (modularity == 0) {
            assets[0] = DAI;

            // Pre-state.
            assertEq(OCL_ZVE_UNIV2_DAI.basis(), 0);
            assertEq(OCL_ZVE_UNIV2_DAI.nextYieldDistribution(), 0);
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_UNIV2_DAI), assets, amounts, new bytes[](2)));

            // Post-state.
            (uint256 basis, uint256 lpTokens) = OCL_ZVE_UNIV2_DAI.fetchBasis();
            assertGt(lpTokens, 0);
            assertEq(OCL_ZVE_UNIV2_DAI.basis(), basis);
            assertEq(OCL_ZVE_UNIV2_DAI.nextYieldDistribution(), block.timestamp + 30 days);
            
        }
        else if (modularity == 1) {
            assets[0] = FRAX;

            // Pre-state.
            assertEq(OCL_ZVE_UNIV2_FRAX.basis(), 0);
            assertEq(OCL_ZVE_UNIV2_FRAX.nextYieldDistribution(), 0);
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_UNIV2_FRAX), assets, amounts, new bytes[](2)));

            // Post-state.
            (uint256 basis, uint256 lpTokens) = OCL_ZVE_UNIV2_FRAX.fetchBasis();
            assertGt(lpTokens, 0);
            assertEq(OCL_ZVE_UNIV2_FRAX.basis(), basis);
            assertEq(OCL_ZVE_UNIV2_FRAX.nextYieldDistribution(), block.timestamp + 30 days);
        }
        else if (modularity == 2) {
            assets[0] = USDC;

            // Pre-state.
            assertEq(OCL_ZVE_UNIV2_USDC.basis(), 0);
            assertEq(OCL_ZVE_UNIV2_USDC.nextYieldDistribution(), 0);
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_UNIV2_USDC), assets, amounts, new bytes[](2)));

            // Post-state.
            (uint256 basis, uint256 lpTokens) = OCL_ZVE_UNIV2_USDC.fetchBasis();
            assertGt(lpTokens, 0);
            assertEq(OCL_ZVE_UNIV2_USDC.basis(), basis);
            assertEq(OCL_ZVE_UNIV2_USDC.nextYieldDistribution(), block.timestamp + 30 days);
        }
        else if (modularity == 3) {
            assets[0] = USDT;

            // Pre-state.
            assertEq(OCL_ZVE_UNIV2_USDT.basis(), 0);
            assertEq(OCL_ZVE_UNIV2_USDT.nextYieldDistribution(), 0);
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_UNIV2_USDT), assets, amounts, new bytes[](2)));

            // Post-state.
            (uint256 basis, uint256 lpTokens) = OCL_ZVE_UNIV2_USDT.fetchBasis();
            assertGt(lpTokens, 0);
            assertEq(OCL_ZVE_UNIV2_USDT.basis(), basis);
            assertEq(OCL_ZVE_UNIV2_USDT.nextYieldDistribution(), block.timestamp + 30 days);
        }
        else { revert(); }
    }


    // ------------------------
    //    Unit Tests (Sushi)
    // ------------------------

    function test_OCL_ZVE_SUSHI_init() public {
        
        // Adjustable variables based on constructor().
        assertEq(OCL_ZVE_SUSHI_DAI.pairAsset(), DAI);
        assertEq(OCL_ZVE_SUSHI_FRAX.pairAsset(), FRAX);
        assertEq(OCL_ZVE_SUSHI_USDC.pairAsset(), USDC);
        assertEq(OCL_ZVE_SUSHI_USDT.pairAsset(), USDT);

        assertEq(OCL_ZVE_SUSHI_DAI.owner(), address(DAO));
        assertEq(OCL_ZVE_SUSHI_FRAX.owner(), address(DAO));
        assertEq(OCL_ZVE_SUSHI_USDC.owner(), address(DAO));
        assertEq(OCL_ZVE_SUSHI_USDT.owner(), address(DAO));

        assertEq(OCL_ZVE_SUSHI_DAI.GBL(), address(GBL));
        assertEq(OCL_ZVE_SUSHI_FRAX.GBL(), address(GBL));
        assertEq(OCL_ZVE_SUSHI_USDC.GBL(), address(GBL));
        assertEq(OCL_ZVE_SUSHI_USDT.GBL(), address(GBL));

        // Constants check, only need to check one instance.
        assertEq(OCL_ZVE_SUSHI_DAI.router(), 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
        assertEq(OCL_ZVE_SUSHI_DAI.factory(), 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac);
        assertEq(OCL_ZVE_SUSHI_DAI.basis(), 0);
        assertEq(OCL_ZVE_SUSHI_DAI.nextYieldDistribution(), 0);
        assertEq(OCL_ZVE_SUSHI_DAI.compoundingRateBIPS(), 5000);

        assert(OCL_ZVE_SUSHI_DAI.canPushMulti());
        assert(OCL_ZVE_SUSHI_DAI.canPull());
        assert(OCL_ZVE_SUSHI_DAI.canPullPartial());
    }


    // Validate pushToLockerMulti() state changes (initial call).
    // Validate pushToLockerMulti() state changes (subsequent calls).
    // Validate pushToLockerMulti() restrictions.
    // This includes:
    //  - Only the owner() of contract may call this.
    //  - Only callable if assets[0] == pairAsset && assets[1] == $ZVE
    //  - Only callable if amounts[0]  >= 10 * 10**6 && amounts[1] >= 10 * 10**6

    function test_OCL_ZVE_SUSHI_pushToLockerMulti_restriction_msgSender() public {

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = address(ZVE);
        assets[1] = DAI;
        amounts[0] = 0;
        amounts[1] = 0;

        // Can't push to contract if _msgSender() != OCL_ZVE_SUSHI.owner()
        hevm.startPrank(address(bob));
        hevm.expectRevert("Ownable: caller is not the owner");
        OCL_ZVE_SUSHI_DAI.pushToLockerMulti(assets, amounts, new bytes[](1));
        hevm.stopPrank();
    }

    function test_OCL_ZVE_SUSHI_pushToLockerMulti_restrictions_minAmount0() public {

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = DAI;
        assets[1] = address(ZVE);
        amounts[0] = 0;
        amounts[1] = 0;

        // Can't push if amounts[0] || amounts[1] < 10 * 10**6.
        hevm.startPrank(address(god));
        hevm.expectRevert("OCL_ZVE::pushToLockerMulti() amounts[i] < 10 * 10**6");
        DAO.pushMulti(address(OCL_ZVE_SUSHI_DAI), assets, amounts, new bytes[](2));
        hevm.stopPrank();
    }

    function test_OCL_ZVE_SUSHI_pushToLockerMulti_restriction_minAmount1() public {

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = DAI;
        assets[1] = address(ZVE);
        amounts[0] = 0;
        amounts[1] = 0;

        // Can't push if amounts[0] || amounts[1] < 10 * 10**6.
        amounts[0] = 10 * 10**6;
        hevm.startPrank(address(god));
        hevm.expectRevert("OCL_ZVE::pushToLockerMulti() amounts[i] < 10 * 10**6");
        DAO.pushMulti(address(OCL_ZVE_SUSHI_DAI), assets, amounts, new bytes[](2));
        hevm.stopPrank();

        amounts[1] = 10 * 10**6;
        assets[0] = DAI;
        assets[1] = address(ZVE);

        // Acceptable inputs now.
        hevm.startPrank(address(god));
        DAO.pushMulti(address(OCL_ZVE_SUSHI_DAI), assets, amounts, new bytes[](2));
        hevm.stopPrank();
    }

    function test_OCL_ZVE_SUSHI_pushToLockerMulti_restrictions_wrongAsset_0() public {

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = address(ZVE);
        assets[1] = DAI;
        amounts[0] = 0;
        amounts[1] = 0;

        // Can't push if assets[0] != pairAsset and assets[1] != ZVE;
        hevm.startPrank(address(god));
        hevm.expectRevert("OCL_ZVE::pushToLockerMulti() assets[0] != pairAsset || assets[1] != ZVE");
        DAO.pushMulti(address(OCL_ZVE_SUSHI_DAI), assets, amounts, new bytes[](2));
        hevm.stopPrank();
    }

    function test_OCL_ZVE_SUSHI_pushToLockerMulti_restrictions_wrongAsset_1() public {

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = DAI;
        assets[1] = USDC;
        amounts[0] = 100 * 10**6;
        amounts[1] = 100 * 10**6;

        // Can't push if assets[0] != pairAsset and assets[1] != ZVE;
        hevm.startPrank(address(god));
        hevm.expectRevert("OCL_ZVE::pushToLockerMulti() assets[0] != pairAsset || assets[1] != ZVE");
        DAO.pushMulti(address(OCL_ZVE_SUSHI_DAI), assets, amounts, new bytes[](2));
        hevm.stopPrank();
    }

    function test_OCL_ZVE_SUSHI_pushToLockerMulti_state_initial(uint96 randomA, uint96 randomB) public {

        uint256 amountA = uint256(randomA) % (10_000_000 * USD) + 10 * USD;
        uint256 amountB = uint256(randomB) % (10_000_000 * USD) + 10 * USD;
        uint256 modularity = randomA % 4;

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[1] = address(ZVE);
        amounts[0] = amountA;
        amounts[1] = amountB;

        if (modularity == 0) {
            assets[0] = DAI;

            // Pre-state.
            assertEq(OCL_ZVE_SUSHI_DAI.basis(), 0);
            assertEq(OCL_ZVE_SUSHI_DAI.nextYieldDistribution(), 0);
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_SUSHI_DAI), assets, amounts, new bytes[](2)));

            // Post-state.
            (uint256 basis, uint256 lpTokens) = OCL_ZVE_SUSHI_DAI.fetchBasis();
            assertGt(basis, 0);
            assertGt(lpTokens, 0);
            assertEq(IERC20(DAI).balanceOf(address(OCL_ZVE_SUSHI_DAI)), 0);
            assertEq(IERC20(address(ZVE)).balanceOf(address(OCL_ZVE_SUSHI_DAI)), 0);
            assertEq(OCL_ZVE_SUSHI_DAI.basis(), basis);
            assertEq(OCL_ZVE_SUSHI_DAI.nextYieldDistribution(), block.timestamp + 30 days);
            
        }
        else if (modularity == 1) {
            assets[0] = FRAX;

            // Pre-state.
            assertEq(OCL_ZVE_SUSHI_FRAX.basis(), 0);
            assertEq(OCL_ZVE_SUSHI_FRAX.nextYieldDistribution(), 0);
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_SUSHI_FRAX), assets, amounts, new bytes[](2)));

            // Post-state.
            (uint256 basis, uint256 lpTokens) = OCL_ZVE_SUSHI_FRAX.fetchBasis();
            assertGt(basis, 0);
            assertGt(lpTokens, 0);
            assertEq(IERC20(FRAX).balanceOf(address(OCL_ZVE_SUSHI_FRAX)), 0);
            assertEq(IERC20(address(ZVE)).balanceOf(address(OCL_ZVE_SUSHI_FRAX)), 0);
            assertEq(OCL_ZVE_SUSHI_FRAX.basis(), basis);
            assertEq(OCL_ZVE_SUSHI_FRAX.nextYieldDistribution(), block.timestamp + 30 days);
        }
        else if (modularity == 2) {
            assets[0] = USDC;

            // Pre-state.
            assertEq(OCL_ZVE_SUSHI_USDC.basis(), 0);
            assertEq(OCL_ZVE_SUSHI_USDC.nextYieldDistribution(), 0);
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_SUSHI_USDC), assets, amounts, new bytes[](2)));

            // Post-state.
            (uint256 basis, uint256 lpTokens) = OCL_ZVE_SUSHI_USDC.fetchBasis();
            assertGt(basis, 0);
            assertGt(lpTokens, 0);
            assertEq(IERC20(USDC).balanceOf(address(OCL_ZVE_SUSHI_USDC)), 0);
            assertEq(IERC20(address(ZVE)).balanceOf(address(OCL_ZVE_SUSHI_USDC)), 0);
            assertEq(OCL_ZVE_SUSHI_USDC.basis(), basis);
            assertEq(OCL_ZVE_SUSHI_USDC.nextYieldDistribution(), block.timestamp + 30 days);
        }
        else if (modularity == 3) {
            assets[0] = USDT;

            // Pre-state.
            assertEq(OCL_ZVE_SUSHI_USDT.basis(), 0);
            assertEq(OCL_ZVE_SUSHI_USDT.nextYieldDistribution(), 0);
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_SUSHI_USDT), assets, amounts, new bytes[](2)));

            // Post-state.
            (uint256 basis, uint256 lpTokens) = OCL_ZVE_SUSHI_USDT.fetchBasis();
            assertGt(basis, 0);
            assertGt(lpTokens, 0);
            assertEq(IERC20(USDT).balanceOf(address(OCL_ZVE_SUSHI_USDT)), 0);
            assertEq(IERC20(address(ZVE)).balanceOf(address(OCL_ZVE_SUSHI_USDT)), 0);
            assertEq(OCL_ZVE_SUSHI_USDT.basis(), basis);
            assertEq(OCL_ZVE_SUSHI_USDT.nextYieldDistribution(), block.timestamp + 30 days);
        }
        else { revert(); }

    }

    function test_OCL_ZVE_SUSHI_pushToLockerMulti_state_subsequent(uint96 randomA, uint96 randomB) public {
        
        uint256 amountA = uint256(randomA) % (10_000_000 * USD) + 10 * USD;
        uint256 amountB = uint256(randomB) % (10_000_000 * USD) + 10 * USD;
        uint256 modularity = randomA % 4;

        pushToLockerInitial_Sushi(amountA, amountB, modularity);

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[1] = address(ZVE);
        amounts[0] = amountA;
        amounts[1] = amountB;

        if (modularity == 0) {
            assets[0] = DAI;

            // Pre-state.
            (uint256 _preBasis, uint256 _preLPTokens) = OCL_ZVE_SUSHI_DAI.fetchBasis();
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_SUSHI_DAI), assets, amounts, new bytes[](2)));

            // Post-state.
            (uint256 _postBasis, uint256 _postLPTokens) = OCL_ZVE_SUSHI_DAI.fetchBasis();
            assertGt(_postLPTokens, _preLPTokens);
            assertGt(_postBasis, _preBasis);
            
        }
        else if (modularity == 1) {
            assets[0] = FRAX;

            // Pre-state.
            (uint256 _preBasis, uint256 _preLPTokens) = OCL_ZVE_SUSHI_FRAX.fetchBasis();
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_SUSHI_FRAX), assets, amounts, new bytes[](2)));

            // Post-state.
            (uint256 _postBasis, uint256 _postLPTokens) = OCL_ZVE_SUSHI_FRAX.fetchBasis();
            assertGt(_postLPTokens, _preLPTokens);
            assertGt(_postBasis, _preBasis);
        }
        else if (modularity == 2) {
            assets[0] = USDC;

            // Pre-state.
            (uint256 _preBasis, uint256 _preLPTokens) = OCL_ZVE_SUSHI_USDC.fetchBasis();
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_SUSHI_USDC), assets, amounts, new bytes[](2)));

            // Post-state.
            (uint256 _postBasis, uint256 _postLPTokens) = OCL_ZVE_SUSHI_USDC.fetchBasis();
            assertGt(_postLPTokens, _preLPTokens);
            assertGt(_postBasis, _preBasis);
        }
        else if (modularity == 3) {
            assets[0] = USDT;

            // Pre-state.
            (uint256 _preBasis, uint256 _preLPTokens) = OCL_ZVE_SUSHI_USDT.fetchBasis();
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_SUSHI_USDT), assets, amounts, new bytes[](2)));

            // Post-state.
            (uint256 _postBasis, uint256 _postLPTokens) = OCL_ZVE_SUSHI_USDT.fetchBasis();
            assertGt(_postLPTokens, _preLPTokens);
            assertGt(_postBasis, _preBasis);
        }
        else { revert(); }

    }

    // Validate pullFromLocker() state changes.
    // This includes:
    //  - Only the owner() of contract may call this.

    function test_OCL_ZVE_SUSHI_pullFromLocker_restrictions_owner(uint96 randomA, uint96 randomB) public {

        uint256 amountA = uint256(randomA) % (10_000_000 * USD) + 10 * USD;
        uint256 amountB = uint256(randomB) % (10_000_000 * USD) + 10 * USD;
        uint256 modularity = randomA % 4;

        pushToLockerInitial_Sushi(amountA, amountB, modularity);

        // Can't pull if not owner().
        if (modularity == 0) {
            hevm.startPrank(address(bob));
            hevm.expectRevert("Ownable: caller is not the owner");
            OCL_ZVE_SUSHI_DAI.pullFromLocker(DAI, "");
            hevm.stopPrank();
        }
        else if (modularity == 1) {
            hevm.startPrank(address(bob));
            hevm.expectRevert("Ownable: caller is not the owner");
            OCL_ZVE_SUSHI_FRAX.pullFromLocker(FRAX, "");
            hevm.stopPrank();
        }
        else if (modularity == 2) {
            hevm.startPrank(address(bob));
            hevm.expectRevert("Ownable: caller is not the owner");
            OCL_ZVE_SUSHI_USDC.pullFromLocker(USDC, "");
            hevm.stopPrank();
        }
        else if (modularity == 3) {
            hevm.startPrank(address(bob));
            hevm.expectRevert("Ownable: caller is not the owner");
            OCL_ZVE_SUSHI_USDT.pullFromLocker(USDT, "");
            hevm.stopPrank();
        }
        else { revert(); }
    }

    // Note: This does not test the else branch.

    function test_OCL_ZVE_SUSHI_pullFromLocker_pair_state(uint96 randomA, uint96 randomB) public {

        uint256 amountA = uint256(randomA) % (10_000_000 * USD) + 10 * USD;
        uint256 amountB = uint256(randomB) % (10_000_000 * USD) + 10 * USD;
        uint256 modularity = randomA % 4;

        pushToLockerInitial_Sushi(amountA, amountB, modularity);

        bytes memory data = abi.encodePacked(amountA * 99 / 100, amountB * 99 / 100);
        
        if (modularity == 0) {
            
            address pair = ISushiFactory(OCL_ZVE_SUSHI_DAI.factory()).getPair(DAI, address(ZVE));

            // Pre-state.
            (uint256 _preBasis, uint256 _preLPTokens) = OCL_ZVE_SUSHI_DAI.fetchBasis();
            assertGt(_preBasis, 0);
            assertGt(_preLPTokens, 0);
            
            assert(god.try_pull(address(DAO), address(OCL_ZVE_SUSHI_DAI), pair, data));

            // Post-state.
            (uint256 _postBasis, uint256 _postLPTokens) = OCL_ZVE_SUSHI_DAI.fetchBasis();
            assertEq(_postBasis, 0);
            assertEq(_postLPTokens, 0);
            
        }
        else if (modularity == 1) {
            address pair = ISushiFactory(OCL_ZVE_SUSHI_FRAX.factory()).getPair(FRAX, address(ZVE));

            // Pre-state.
            (uint256 _preBasis, uint256 _preLPTokens) = OCL_ZVE_SUSHI_FRAX.fetchBasis();
            assertGt(_preBasis, 0);
            assertGt(_preLPTokens, 0);
            
            assert(god.try_pull(address(DAO), address(OCL_ZVE_SUSHI_FRAX), pair, data));

            // Post-state.
            (uint256 _postBasis, uint256 _postLPTokens) = OCL_ZVE_SUSHI_FRAX.fetchBasis();
            assertEq(_postBasis, 0);
            assertEq(_postLPTokens, 0);
        }
        else if (modularity == 2) {
            address pair = ISushiFactory(OCL_ZVE_SUSHI_USDC.factory()).getPair(USDC, address(ZVE));

            // Pre-state.
            (uint256 _preBasis, uint256 _preLPTokens) = OCL_ZVE_SUSHI_USDC.fetchBasis();
            assertGt(_preBasis, 0);
            assertGt(_preLPTokens, 0);
            
            assert(god.try_pull(address(DAO), address(OCL_ZVE_SUSHI_USDC), pair, data));

            // Post-state.
            (uint256 _postBasis, uint256 _postLPTokens) = OCL_ZVE_SUSHI_USDC.fetchBasis();
            assertEq(_postBasis, 0);
            assertEq(_postLPTokens, 0);
        }
        else if (modularity == 3) {
            address pair = ISushiFactory(OCL_ZVE_SUSHI_USDT.factory()).getPair(USDT, address(ZVE));

            // Pre-state.
            (uint256 _preBasis, uint256 _preLPTokens) = OCL_ZVE_SUSHI_USDT.fetchBasis();
            assertGt(_preBasis, 0);
            assertGt(_preLPTokens, 0);
            
            assert(god.try_pull(address(DAO), address(OCL_ZVE_SUSHI_USDT), pair, data));

            // Post-state.
            (uint256 _postBasis, uint256 _postLPTokens) = OCL_ZVE_SUSHI_USDT.fetchBasis();
            assertEq(_postBasis, 0);
            assertEq(_postLPTokens, 0);
        }
        else { revert(); }

    }


    // Validate pullFromLockerPartial() state changes.
    // Validate pullFromLockerPartial() restrictions.
    // This includes:
    //  - Only the owner() of contract may call this.

    function test_OCL_ZVE_SUSHI_pullFromLockerPartial_restrictions_owner(uint96 randomA, uint96 randomB) public {

        uint256 amountA = uint256(randomA) % (10_000_000 * USD) + 10 * USD;
        uint256 amountB = uint256(randomB) % (10_000_000 * USD) + 10 * USD;
        uint256 modularity = randomA % 4;

        pushToLockerInitial_Sushi(amountA, amountB, modularity);

        // Can't pull if not owner().
        if (modularity == 0) {
            hevm.startPrank(address(bob));
            hevm.expectRevert("Ownable: caller is not the owner");
            OCL_ZVE_SUSHI_DAI.pullFromLockerPartial(DAI, 10 * USD, "");
            hevm.stopPrank();
        }
        else if (modularity == 1) {
            hevm.startPrank(address(bob));
            hevm.expectRevert("Ownable: caller is not the owner");
            OCL_ZVE_SUSHI_FRAX.pullFromLockerPartial(FRAX, 10 * USD, "");
            hevm.stopPrank();
        }
        else if (modularity == 2) {
            hevm.startPrank(address(bob));
            hevm.expectRevert("Ownable: caller is not the owner");
            OCL_ZVE_SUSHI_USDC.pullFromLockerPartial(USDC, 10 * USD, "");
            hevm.stopPrank();
        }
        else if (modularity == 3) {
            hevm.startPrank(address(bob));
            hevm.expectRevert("Ownable: caller is not the owner");
            OCL_ZVE_SUSHI_USDT.pullFromLockerPartial(USDT, 10 * USD, "");
            hevm.stopPrank();
        }
        else { revert(); }

    }

    // Note: This does not test the else case.

    function test_OCL_ZVE_SUSHI_pullFromLockerPartial_state(uint96 randomA, uint96 randomB) public {

        uint256 amountA = uint256(randomA) % (10_000_000 * USD) + 10 * USD;
        uint256 amountB = uint256(randomB) % (10_000_000 * USD) + 10 * USD;
        uint256 modularity = randomA % 4;

        pushToLockerInitial_Sushi(amountA, amountB, modularity);

        if (modularity == 0) {
            address pair = ISushiFactory(OCL_ZVE_SUSHI_DAI.factory()).getPair(DAI, address(ZVE));

            uint256 partialAmount = IERC20(pair).balanceOf(address(OCL_ZVE_SUSHI_DAI)) * (randomA % 100 + 1) / 100;

            bytes memory data = abi.encodePacked(
                amountA * 99 / 100 * (randomA % 100 + 1) / 100, 
                amountB * 99 / 100 * (randomA % 100 + 1) / 100
            );

            emit log_named_bytes('data', data);

            // Pre-state.
            (uint256 _preBasis, uint256 _preLPTokens) = OCL_ZVE_SUSHI_DAI.fetchBasis();
            assertGt(_preBasis, 0);
            assertEq(_preLPTokens, IERC20(pair).balanceOf(address(OCL_ZVE_SUSHI_DAI)));
            
            assert(god.try_pullPartial(address(DAO), address(OCL_ZVE_SUSHI_DAI), pair, partialAmount, data));

            // Post-state.
            (uint256 _postBasis, uint256 _postLPTokens) = OCL_ZVE_SUSHI_DAI.fetchBasis();
            assertGt(_preBasis - _postBasis, 0);
            assertEq(_postLPTokens, _preLPTokens - partialAmount);
            
        }
        else if (modularity == 1) {
            address pair = ISushiFactory(OCL_ZVE_SUSHI_FRAX.factory()).getPair(FRAX, address(ZVE));

            uint256 partialAmount = IERC20(pair).balanceOf(address(OCL_ZVE_SUSHI_FRAX)) * (randomA % 100 + 1) / 100;

            bytes memory data = abi.encodePacked(
                amountA * 99 / 100 * (randomA % 100 + 1) / 100, 
                amountB * 99 / 100 * (randomA % 100 + 1) / 100
            );

            emit log_named_bytes('data', data);

            // Pre-state.
            (uint256 _preBasis, uint256 _preLPTokens) = OCL_ZVE_SUSHI_FRAX.fetchBasis();
            assertGt(_preBasis, 0);
            assertEq(_preLPTokens, IERC20(pair).balanceOf(address(OCL_ZVE_SUSHI_FRAX)));
            
            assert(god.try_pullPartial(address(DAO), address(OCL_ZVE_SUSHI_FRAX), pair, partialAmount, data));

            // Post-state.
            (uint256 _postBasis, uint256 _postLPTokens) = OCL_ZVE_SUSHI_FRAX.fetchBasis();
            assertGt(_preBasis - _postBasis, 0);
            assertEq(_postLPTokens, _preLPTokens - partialAmount);
        }
        else if (modularity == 2) {
            address pair = ISushiFactory(OCL_ZVE_SUSHI_USDC.factory()).getPair(USDC, address(ZVE));

            uint256 partialAmount = IERC20(pair).balanceOf(address(OCL_ZVE_SUSHI_USDC)) * (randomA % 100 + 1) / 100;

            bytes memory data = abi.encodePacked(
                amountA * 99 / 100 * (randomA % 100 + 1) / 100, 
                amountB * 99 / 100 * (randomA % 100 + 1) / 100
            );

            emit log_named_bytes('data', data);

            // Pre-state.
            (uint256 _preBasis, uint256 _preLPTokens) = OCL_ZVE_SUSHI_USDC.fetchBasis();
            assertGt(_preBasis, 0);
            assertEq(_preLPTokens, IERC20(pair).balanceOf(address(OCL_ZVE_SUSHI_USDC)));
            
            assert(god.try_pullPartial(address(DAO), address(OCL_ZVE_SUSHI_USDC), pair, partialAmount, data));

            // Post-state.
            (uint256 _postBasis, uint256 _postLPTokens) = OCL_ZVE_SUSHI_USDC.fetchBasis();
            assertGt(_preBasis - _postBasis, 0);
            assertEq(_postLPTokens, _preLPTokens - partialAmount);
        }
        else if (modularity == 3) {
            address pair = ISushiFactory(OCL_ZVE_SUSHI_USDT.factory()).getPair(USDT, address(ZVE));

            uint256 partialAmount = IERC20(pair).balanceOf(address(OCL_ZVE_SUSHI_USDT)) * (randomA % 100 + 1) / 100;

            bytes memory data = abi.encodePacked(
                amountA * 99 / 100 * (randomA % 100 + 1) / 100, 
                amountB * 99 / 100 * (randomA % 100 + 1) / 100
            );

            emit log_named_bytes('data', data);

            // Pre-state.
            (uint256 _preBasis, uint256 _preLPTokens) = OCL_ZVE_SUSHI_USDT.fetchBasis();
            assertGt(_preBasis, 0);
            assertEq(_preLPTokens, IERC20(pair).balanceOf(address(OCL_ZVE_SUSHI_USDT)));
            
            assert(god.try_pullPartial(address(DAO), address(OCL_ZVE_SUSHI_USDT), pair, partialAmount, data));

            // Post-state.
            (uint256 _postBasis, uint256 _postLPTokens) = OCL_ZVE_SUSHI_USDT.fetchBasis();
            assertGt(_preBasis - _postBasis, 0);
            assertEq(_postLPTokens, _preLPTokens - partialAmount);
        }
        else { revert(); }

    }

    // Validate updateCompoundingRateBIPS() state changes.
    // Validate updateCompoundingRateBIPS() restrictions.
    // This includes:
    //  - Only governance contract (TLC / "god") may call this function.
    //  - _compoundingRateBIPS <= 10000

    function test_OCL_ZVE_SUSHI_updateCompoundingRateBIPS_restrictions_msgSender() public {
        
        // Can't call if not governance contract.
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCL_ZVE::updateCompoundingRateBIPS() _msgSender() != IZivoeGlobals_OCL_ZVE(GBL).TLC()");
        OCL_ZVE_SUSHI_DAI.updateCompoundingRateBIPS(10000);
        hevm.stopPrank();

        // Example success.
        assert(god.try_updateCompoundingRateBIPS(address(OCL_ZVE_SUSHI_DAI), 10000));

    }

    function test_OCL_ZVE_SUSHI_updateCompoundingRateBIPS_restrictions_maxBIPS() public {
        
        // Can't call if > 10000 (BIPS = 10000).
        hevm.startPrank(address(god));
        hevm.expectRevert("OCL_ZVE::updateCompoundingRateBIPS() ratio > BIPS");
        OCL_ZVE_SUSHI_DAI.updateCompoundingRateBIPS(10001);
        hevm.stopPrank();

    }

    function test_OCL_ZVE_SUSHI_updateCompoundingRateBIPS_state(uint96 random) public {

        uint256 val = uint256(random) % 10000;
        
        // Pre-state.
        assertEq(OCL_ZVE_SUSHI_DAI.compoundingRateBIPS(), 5000);

        assert(god.try_updateCompoundingRateBIPS(address(OCL_ZVE_SUSHI_DAI), val));

        // Pre-state.
        assertEq(OCL_ZVE_SUSHI_DAI.compoundingRateBIPS(), val);

    }

    // Validate forwardYield() state changes.
    // Validate forwardYield() restrictions.
    // This includes:
    //  - Time constraints based on isKeeper(_msgSender()) status.

    function test_OCL_ZVE_SUSHI_forwardYield_restrictions_timelock(uint96 randomA, uint96 randomB) public {
        
        uint256 amountA = uint256(randomA) % (10_000_000 * USD) + 10 * USD;
        uint256 amountB = uint256(randomB) % (10_000_000 * USD) + 10 * USD;
        uint256 modularity = randomA % 4;

        pushToLockerInitial_Sushi(amountA, amountB, modularity);

        if (modularity == 0) {
            buyZVE_Sushi(amountA / 5, DAI); // ~ 20% price increase via pairAsset trade

            // Can't call forwardYield() before nextYieldDistribution() if not keeper.
            hevm.startPrank(address(bob));
            hevm.expectRevert("OCL_ZVE::forwardYield() block.timestamp <= nextYieldDistribution");
            OCL_ZVE_SUSHI_DAI.forwardYield();
            hevm.stopPrank();

        }
        else if (modularity == 1) {
            buyZVE_Sushi(amountA / 5, FRAX); // ~ 20% price increase via pairAsset trade

            // Can't call forwardYield() before nextYieldDistribution() if not keeper.
            hevm.startPrank(address(bob));
            hevm.expectRevert("OCL_ZVE::forwardYield() block.timestamp <= nextYieldDistribution");
            OCL_ZVE_SUSHI_FRAX.forwardYield();
            hevm.stopPrank();

        }
        else if (modularity == 2) {
            buyZVE_Sushi(amountA / 5, USDC); // ~ 20% price increase via pairAsset trade

            // Can't call forwardYield() before nextYieldDistribution() if not keeper.
            hevm.startPrank(address(bob));
            hevm.expectRevert("OCL_ZVE::forwardYield() block.timestamp <= nextYieldDistribution");
            OCL_ZVE_SUSHI_USDC.forwardYield();
            hevm.stopPrank();

        }
        else if (modularity == 3) {
            buyZVE_Sushi(amountA / 5, USDT); // ~ 20% price increase via pairAsset trade

            // Can't call forwardYield() before nextYieldDistribution() if not keeper.
            hevm.startPrank(address(bob));
            hevm.expectRevert("OCL_ZVE::forwardYield() block.timestamp <= nextYieldDistribution");
            OCL_ZVE_SUSHI_USDT.forwardYield();
            hevm.stopPrank();

        }
        else { revert(); }

    }

    function test_OCL_ZVE_SUSHI_forwardYield_restrictions_timelockAtDistribution(uint96 randomA, uint96 randomB) public {
        
        uint256 amountA = uint256(randomA) % (10_000_000 * USD) + 10 * USD;
        uint256 amountB = uint256(randomB) % (10_000_000 * USD) + 10 * USD;
        uint256 modularity = randomA % 4;

        pushToLockerInitial_Sushi(amountA, amountB, modularity);

        if (modularity == 0) {
            buyZVE_Sushi(amountA / 5, DAI); // ~ 20% price increase via pairAsset trade

            // Can't call forwardYield() before nextYieldDistribution() if not keeper.
            hevm.warp(OCL_ZVE_SUSHI_DAI.nextYieldDistribution());
            hevm.startPrank(address(bob));
            hevm.expectRevert("OCL_ZVE::forwardYield() block.timestamp <= nextYieldDistribution");
            OCL_ZVE_SUSHI_DAI.forwardYield();
            hevm.stopPrank();

            // Success call
            hevm.warp(OCL_ZVE_SUSHI_DAI.nextYieldDistribution() + 1 seconds);
            assert(bob.try_forwardYield(address(OCL_ZVE_SUSHI_DAI)));

        }
        else if (modularity == 1) {
            buyZVE_Sushi(amountA / 5, FRAX); // ~ 20% price increase via pairAsset trade

            // Can't call forwardYield() before nextYieldDistribution() if not keeper.
            hevm.warp(OCL_ZVE_SUSHI_FRAX.nextYieldDistribution());
            hevm.startPrank(address(bob));
            hevm.expectRevert("OCL_ZVE::forwardYield() block.timestamp <= nextYieldDistribution");
            OCL_ZVE_SUSHI_FRAX.forwardYield();
            hevm.stopPrank();

            // Success call
            hevm.warp(OCL_ZVE_SUSHI_FRAX.nextYieldDistribution() + 1 seconds);
            assert(bob.try_forwardYield(address(OCL_ZVE_SUSHI_FRAX)));

        }
        else if (modularity == 2) {
            buyZVE_Sushi(amountA / 5, USDC); // ~ 20% price increase via pairAsset trade

            // Can't call forwardYield() before nextYieldDistribution() if not keeper.
            hevm.warp(OCL_ZVE_SUSHI_USDC.nextYieldDistribution());
            hevm.startPrank(address(bob));
            hevm.expectRevert("OCL_ZVE::forwardYield() block.timestamp <= nextYieldDistribution");
            OCL_ZVE_SUSHI_USDC.forwardYield();
            hevm.stopPrank();

            // Success call
            hevm.warp(OCL_ZVE_SUSHI_USDC.nextYieldDistribution() + 1 seconds);
            assert(bob.try_forwardYield(address(OCL_ZVE_SUSHI_USDC)));

        }
        else if (modularity == 3) {
            buyZVE_Sushi(amountA / 5, USDT); // ~ 20% price increase via pairAsset trade

            // Can't call forwardYield() before nextYieldDistribution() if not keeper.
            hevm.warp(OCL_ZVE_SUSHI_USDT.nextYieldDistribution());
            hevm.startPrank(address(bob));
            hevm.expectRevert("OCL_ZVE::forwardYield() block.timestamp <= nextYieldDistribution");
            OCL_ZVE_SUSHI_USDT.forwardYield();
            hevm.stopPrank();

            // Success call
            hevm.warp(OCL_ZVE_SUSHI_USDT.nextYieldDistribution() + 1 seconds);
            assert(bob.try_forwardYield(address(OCL_ZVE_SUSHI_USDT)));

        }
        else { revert(); }

    }

    function test_OCL_ZVE_SUSHI_forwardYield_state(uint96 randomA, uint96 randomB) public {

        uint256 amountA = uint256(randomA) % (10_000_000 * USD) + 10 * USD;
        uint256 amountB = uint256(randomB) % (10_000_000 * USD) + 10 * USD;
        uint256 modularity = randomA % 4;

        assert(zvl.try_updateIsKeeper(address(GBL), address(bob), true));

        pushToLockerInitial_Sushi(amountA, amountB, modularity);

        if (modularity == 0) {
            // Pre-state.
            (uint256 _PAC_DAI,) = OCL_ZVE_SUSHI_DAI.fetchBasis();
            uint256 _preZVE = IERC20(address(ZVE)).balanceOf(address(DAO));
            uint256 _prePair = IERC20(DAI).balanceOf(address(YDL));
            uint256 _preNYD = OCL_ZVE_SUSHI_DAI.nextYieldDistribution();
            assertEq(_prePair, 0);
 
            buyZVE_Sushi(amountA / 5, DAI); // ~ 20% price increase via pairAsset trade

            hevm.warp(OCL_ZVE_SUSHI_DAI.nextYieldDistribution() - 12 hours + 1 seconds);
            assert(bob.try_forwardYield(address(OCL_ZVE_SUSHI_DAI)));
            
            // Post-state.
            assertEq(IERC20(DAI).balanceOf(address(OCL_ZVE_SUSHI_DAI)), 0);
            assertGt(IERC20(DAI).balanceOf(address(YDL)), _prePair); // Note: YDL.distributedAsset() == DAI
            assertGt(IERC20(address(ZVE)).balanceOf(address(DAO)), _preZVE);
            assertEq(OCL_ZVE_SUSHI_DAI.nextYieldDistribution(), _preNYD + 30 days);
            (_PAC_DAI,) = OCL_ZVE_SUSHI_DAI.fetchBasis();
        }
        else if (modularity == 1) {
            // Pre-state.
            (uint256 _PAC_FRAX,) = OCL_ZVE_SUSHI_FRAX.fetchBasis();
            uint256 _preZVE = IERC20(address(ZVE)).balanceOf(address(DAO));
            uint256 _prePair = IERC20(FRAX).balanceOf(address(Treasury));
            uint256 _preNYD = OCL_ZVE_SUSHI_FRAX.nextYieldDistribution();
            assertEq(_prePair, 0);

            buyZVE_Sushi(amountA / 5, FRAX); // ~ 20% price increase via pairAsset trade

            hevm.warp(OCL_ZVE_SUSHI_FRAX.nextYieldDistribution() - 12 hours + 1 seconds);
            assert(bob.try_forwardYield(address(OCL_ZVE_SUSHI_FRAX)));

            // Post-state.
            assertGt(IERC20(FRAX).balanceOf(address(Treasury)), 0);
            assertGt(IERC20(address(ZVE)).balanceOf(address(DAO)), _preZVE);
            assertEq(OCL_ZVE_SUSHI_FRAX.nextYieldDistribution(), _preNYD + 30 days);
            (_PAC_FRAX,) = OCL_ZVE_SUSHI_FRAX.fetchBasis();
        }
        else if (modularity == 2) {
            // Pre-state.
            (uint256 _PAC_USDC,) = OCL_ZVE_SUSHI_USDC.fetchBasis();
            uint256 _preZVE = IERC20(address(ZVE)).balanceOf(address(DAO));
            uint256 _prePair = IERC20(USDC).balanceOf(address(Treasury));
            uint256 _preNYD = OCL_ZVE_SUSHI_USDC.nextYieldDistribution();
            assertEq(_prePair, 0);

            buyZVE_Sushi(amountA / 5, USDC); // ~ 20% price increase via pairAsset trade

            hevm.warp(OCL_ZVE_SUSHI_USDC.nextYieldDistribution() - 12 hours + 1 seconds);
            assert(bob.try_forwardYield(address(OCL_ZVE_SUSHI_USDC)));

            // Post-state.
            assertGt(IERC20(USDC).balanceOf(address(Treasury)), 0);
            assertGt(IERC20(address(ZVE)).balanceOf(address(DAO)), _preZVE);
            assertEq(OCL_ZVE_SUSHI_USDC.nextYieldDistribution(), _preNYD + 30 days);
            (_PAC_USDC,) = OCL_ZVE_SUSHI_USDC.fetchBasis();
        }
        else if (modularity == 3) {
            // Pre-state.
            (uint256 _PAC_USDT,) = OCL_ZVE_SUSHI_USDT.fetchBasis();
            uint256 _preZVE = IERC20(address(ZVE)).balanceOf(address(DAO));
            uint256 _prePair = IERC20(USDT).balanceOf(address(Treasury));
            uint256 _preNYD = OCL_ZVE_SUSHI_USDT.nextYieldDistribution();
            assertEq(_prePair, 0);

            buyZVE_Sushi(amountA / 5, USDT); // ~ 20% price increase via pairAsset trade

            hevm.warp(OCL_ZVE_SUSHI_USDT.nextYieldDistribution() - 12 hours + 1 seconds);
            assert(bob.try_forwardYield(address(OCL_ZVE_SUSHI_USDT)));

            // Post-state.
            assertGt(IERC20(USDT).balanceOf(address(Treasury)), 0);
            assertGt(IERC20(address(ZVE)).balanceOf(address(DAO)), _preZVE);
            assertEq(OCL_ZVE_SUSHI_USDT.nextYieldDistribution(), _preNYD + 30 days);
            (_PAC_USDT,) = OCL_ZVE_SUSHI_USDT.fetchBasis();
        }
        else { revert(); }

    }

    // Check that fetchBasis() return goes up when buying $ZVE (or selling).

    function test_OCL_ZVE_SUSHI_fetchBasis_check(uint96 randomA, uint96 randomB) public {

        uint256 amountA = uint256(randomA) % (10_000_000 * USD) + 10 * USD;
        uint256 amountB = uint256(randomB) % (10_000_000 * USD) + 10 * USD;
        uint256 modularity = randomA % 4;

        pushToLockerInitial_Sushi(amountA, amountB, modularity);

        if (modularity == 0) {
            (uint256 _preAmt,) = OCL_ZVE_SUSHI_DAI.fetchBasis();
            
            buyZVE_Sushi(amountA / 5, DAI); // ~ 20% price increase via pairAsset trade
            (uint256 _postAmt,) = OCL_ZVE_SUSHI_DAI.fetchBasis();
            
            assertGt(_postAmt, _preAmt);

            sellZVE_Sushi(IERC20(address(ZVE)).balanceOf(address(this)) / 2, DAI); // Sell 50% of ZVE
            (uint256 _postAmt2,) = OCL_ZVE_SUSHI_DAI.fetchBasis();
            
            assertLt(_postAmt2, _postAmt);
        }
        else if (modularity == 1) {
            (uint256 _preAmt,) = OCL_ZVE_SUSHI_FRAX.fetchBasis();

            buyZVE_Sushi(amountA / 5, FRAX); // ~ 20% price increase via pairAsset trade
            (uint256 _postAmt,) = OCL_ZVE_SUSHI_FRAX.fetchBasis();
            
            assertGt(_postAmt, _preAmt);

            sellZVE_Sushi(IERC20(address(ZVE)).balanceOf(address(this)) / 2, FRAX); // Sell 50% of ZVE
            (uint256 _postAmt2,) = OCL_ZVE_SUSHI_FRAX.fetchBasis();
            
            assertLt(_postAmt2, _postAmt);
        }
        else if (modularity == 2) {
            (uint256 _preAmt,) = OCL_ZVE_SUSHI_USDC.fetchBasis();

            buyZVE_Sushi(amountA / 5, USDC); // ~ 20% price increase via pairAsset trade
            (uint256 _postAmt,) = OCL_ZVE_SUSHI_USDC.fetchBasis();
            
            assertGt(_postAmt, _preAmt);

            sellZVE_Sushi(IERC20(address(ZVE)).balanceOf(address(this)) / 2, USDC); // Sell 50% of ZVE
            (uint256 _postAmt2,) = OCL_ZVE_SUSHI_USDC.fetchBasis();
            
            assertLt(_postAmt2, _postAmt);
        }
        else if (modularity == 3) {
            (uint256 _preAmt,) = OCL_ZVE_SUSHI_USDT.fetchBasis();

            buyZVE_Sushi(amountA / 5, USDT); // ~ 20% price increase via pairAsset trade
            (uint256 _postAmt,) = OCL_ZVE_SUSHI_USDT.fetchBasis();
            
            assertGt(_postAmt, _preAmt);

            sellZVE_Sushi(IERC20(address(ZVE)).balanceOf(address(this)) / 2, USDT); // Sell 50% of ZVE
            (uint256 _postAmt2,) = OCL_ZVE_SUSHI_USDT.fetchBasis();
            
            assertLt(_postAmt2, _postAmt);
        }
        else { revert(); }

    }

    
    // ----------------------
    //    Unit Tests (Uni)
    // ----------------------

    function test_OCL_ZVE_UNIV2_init() public {
        
        // Adjustable variables based on constructor().
        assertEq(OCL_ZVE_UNIV2_DAI.pairAsset(), DAI);
        assertEq(OCL_ZVE_UNIV2_FRAX.pairAsset(), FRAX);
        assertEq(OCL_ZVE_UNIV2_USDC.pairAsset(), USDC);
        assertEq(OCL_ZVE_UNIV2_USDT.pairAsset(), USDT);

        assertEq(OCL_ZVE_UNIV2_DAI.owner(), address(DAO));
        assertEq(OCL_ZVE_UNIV2_FRAX.owner(), address(DAO));
        assertEq(OCL_ZVE_UNIV2_USDC.owner(), address(DAO));
        assertEq(OCL_ZVE_UNIV2_USDT.owner(), address(DAO));

        assertEq(OCL_ZVE_UNIV2_DAI.GBL(), address(GBL));
        assertEq(OCL_ZVE_UNIV2_FRAX.GBL(), address(GBL));
        assertEq(OCL_ZVE_UNIV2_USDC.GBL(), address(GBL));
        assertEq(OCL_ZVE_UNIV2_USDT.GBL(), address(GBL));

        // Constants check, only need to check one instance.
        assertEq(OCL_ZVE_UNIV2_DAI.router(), 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        assertEq(OCL_ZVE_UNIV2_DAI.factory(), 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
        assertEq(OCL_ZVE_UNIV2_DAI.basis(), 0);
        assertEq(OCL_ZVE_UNIV2_DAI.nextYieldDistribution(), 0);
        assertEq(OCL_ZVE_UNIV2_DAI.compoundingRateBIPS(), 5000);

        assert(OCL_ZVE_UNIV2_DAI.canPushMulti());
        assert(OCL_ZVE_UNIV2_DAI.canPull());
        assert(OCL_ZVE_UNIV2_DAI.canPullPartial());
    }


    // Validate pushToLockerMulti() state changes (initial call).
    // Validate pushToLockerMulti() state changes (subsequent calls).
    // Validate pushToLockerMulti() restrictions.
    // This includes:
    //  - Only the owner() of contract may call this.
    //  - Only callable if assets[0] == pairAsset && assets[1] == $ZVE

    function test_OCL_ZVE_UNIV2_pushToLockerMulti_restrictions() public {

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[0] = address(ZVE);
        assets[1] = DAI;
        amounts[0] = 0;
        amounts[1] = 0;

        // Can't push to contract if _msgSender() != OCL_ZVE_UNIV2.owner()
        assert(!bob.try_pushToLockerMulti_DIRECT(address(OCL_ZVE_UNIV2_DAI), assets, amounts, new bytes[](1)));

        // Can't push if amounts[0] || amounts[1] < 10 * 10**6.
        assert(!god.try_pushMulti(address(DAO), address(OCL_ZVE_UNIV2_DAI), assets, amounts, new bytes[](2)));
        amounts[0] = 10 * 10**6;
        assert(!god.try_pushMulti(address(DAO), address(OCL_ZVE_UNIV2_DAI), assets, amounts, new bytes[](2)));

        amounts[1] = 10 * 10**6;
        assets[0] = DAI;
        assets[1] = address(ZVE);

        // Acceptable inputs now.
        assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_UNIV2_DAI), assets, amounts, new bytes[](2)));

    }

    function test_OCL_ZVE_UNIV2_pushToLockerMulti_state_initial(uint96 randomA, uint96 randomB) public {

        uint256 amountA = uint256(randomA) % (10_000_000 * USD) + 10 * USD;
        uint256 amountB = uint256(randomB) % (10_000_000 * USD) + 10 * USD;
        uint256 modularity = randomA % 4;

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[1] = address(ZVE);
        amounts[0] = amountA;
        amounts[1] = amountB;

        if (modularity == 0) {
            assets[0] = DAI;

            // Pre-state.
            assertEq(OCL_ZVE_UNIV2_DAI.basis(), 0);
            assertEq(OCL_ZVE_UNIV2_DAI.nextYieldDistribution(), 0);
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_UNIV2_DAI), assets, amounts, new bytes[](2)));

            // Post-state.
            (uint256 basis, uint256 lpTokens) = OCL_ZVE_UNIV2_DAI.fetchBasis();
            assertGt(basis, 0);
            assertGt(lpTokens, 0);
            assertEq(IERC20(DAI).balanceOf(address(OCL_ZVE_UNIV2_DAI)), 0);
            assertEq(IERC20(address(ZVE)).balanceOf(address(OCL_ZVE_UNIV2_DAI)), 0);
            assertEq(OCL_ZVE_UNIV2_DAI.basis(), basis);
            assertEq(OCL_ZVE_UNIV2_DAI.nextYieldDistribution(), block.timestamp + 30 days);
            
        }
        else if (modularity == 1) {
            assets[0] = FRAX;

            // Pre-state.
            assertEq(OCL_ZVE_UNIV2_FRAX.basis(), 0);
            assertEq(OCL_ZVE_UNIV2_FRAX.nextYieldDistribution(), 0);
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_UNIV2_FRAX), assets, amounts, new bytes[](2)));

            // Post-state.
            (uint256 basis, uint256 lpTokens) = OCL_ZVE_UNIV2_FRAX.fetchBasis();
            assertGt(basis, 0);
            assertGt(lpTokens, 0);
            assertEq(IERC20(FRAX).balanceOf(address(OCL_ZVE_UNIV2_FRAX)), 0);
            assertEq(IERC20(address(ZVE)).balanceOf(address(OCL_ZVE_UNIV2_FRAX)), 0);
            assertEq(OCL_ZVE_UNIV2_FRAX.basis(), basis);
            assertEq(OCL_ZVE_UNIV2_FRAX.nextYieldDistribution(), block.timestamp + 30 days);
        }
        else if (modularity == 2) {
            assets[0] = USDC;

            // Pre-state.
            assertEq(OCL_ZVE_UNIV2_USDC.basis(), 0);
            assertEq(OCL_ZVE_UNIV2_USDC.nextYieldDistribution(), 0);
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_UNIV2_USDC), assets, amounts, new bytes[](2)));

            // Post-state.
            (uint256 basis, uint256 lpTokens) = OCL_ZVE_UNIV2_USDC.fetchBasis();
            assertGt(basis, 0);
            assertGt(lpTokens, 0);
            assertEq(IERC20(USDC).balanceOf(address(OCL_ZVE_UNIV2_USDC)), 0);
            assertEq(IERC20(address(ZVE)).balanceOf(address(OCL_ZVE_UNIV2_USDC)), 0);
            assertEq(OCL_ZVE_UNIV2_USDC.basis(), basis);
            assertEq(OCL_ZVE_UNIV2_USDC.nextYieldDistribution(), block.timestamp + 30 days);
        }
        else if (modularity == 3) {
            assets[0] = USDT;

            // Pre-state.
            assertEq(OCL_ZVE_UNIV2_USDT.basis(), 0);
            assertEq(OCL_ZVE_UNIV2_USDT.nextYieldDistribution(), 0);
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_UNIV2_USDT), assets, amounts, new bytes[](2)));

            // Post-state.
            (uint256 basis, uint256 lpTokens) = OCL_ZVE_UNIV2_USDT.fetchBasis();
            assertGt(basis, 0);
            assertGt(lpTokens, 0);
            assertEq(IERC20(USDT).balanceOf(address(OCL_ZVE_UNIV2_USDT)), 0);
            assertEq(IERC20(address(ZVE)).balanceOf(address(OCL_ZVE_UNIV2_USDT)), 0);
            assertEq(OCL_ZVE_UNIV2_USDT.basis(), basis);
            assertEq(OCL_ZVE_UNIV2_USDT.nextYieldDistribution(), block.timestamp + 30 days);
        }
        else { revert(); }

    }

    function test_OCL_ZVE_UNIV2_pushToLockerMulti_state_subsequent(uint96 randomA, uint96 randomB) public {
        
        uint256 amountA = uint256(randomA) % (10_000_000 * USD) + 10 * USD;
        uint256 amountB = uint256(randomB) % (10_000_000 * USD) + 10 * USD;
        uint256 modularity = randomA % 4;

        pushToLockerInitial_Uni(amountA, amountB, modularity);

        address[] memory assets = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        assets[1] = address(ZVE);
        amounts[0] = amountA;
        amounts[1] = amountB;

        if (modularity == 0) {
            assets[0] = DAI;

            // Pre-state.
            (uint256 _preBasis, uint256 _preLPTokens) = OCL_ZVE_UNIV2_DAI.fetchBasis();
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_UNIV2_DAI), assets, amounts, new bytes[](2)));

            // Post-state.
            (uint256 _postBasis, uint256 _postLPTokens) = OCL_ZVE_UNIV2_DAI.fetchBasis();
            assertGt(_postLPTokens, _preLPTokens);
            assertGt(_postBasis, _preBasis);
            
        }
        else if (modularity == 1) {
            assets[0] = FRAX;

            // Pre-state.
            (uint256 _preBasis, uint256 _preLPTokens) = OCL_ZVE_UNIV2_FRAX.fetchBasis();
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_UNIV2_FRAX), assets, amounts, new bytes[](2)));

            // Post-state.
            (uint256 _postBasis, uint256 _postLPTokens) = OCL_ZVE_UNIV2_FRAX.fetchBasis();
            assertGt(_postLPTokens, _preLPTokens);
            assertGt(_postBasis, _preBasis);
        }
        else if (modularity == 2) {
            assets[0] = USDC;

            // Pre-state.
            (uint256 _preBasis, uint256 _preLPTokens) = OCL_ZVE_UNIV2_USDC.fetchBasis();
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_UNIV2_USDC), assets, amounts, new bytes[](2)));

            // Post-state.
            (uint256 _postBasis, uint256 _postLPTokens) = OCL_ZVE_UNIV2_USDC.fetchBasis();
            assertGt(_postLPTokens, _preLPTokens);
            assertGt(_postBasis, _preBasis);
        }
        else if (modularity == 3) {
            assets[0] = USDT;

            // Pre-state.
            (uint256 _preBasis, uint256 _preLPTokens) = OCL_ZVE_UNIV2_USDT.fetchBasis();
            
            assert(god.try_pushMulti(address(DAO), address(OCL_ZVE_UNIV2_USDT), assets, amounts, new bytes[](2)));

            // Post-state.
            (uint256 _postBasis, uint256 _postLPTokens) = OCL_ZVE_UNIV2_USDT.fetchBasis();
            assertGt(_postLPTokens, _preLPTokens);
            assertGt(_postBasis, _preBasis);
        }
        else { revert(); }

    }

    // Validate pullFromLocker() state changes.
    // This includes:
    //  - Only the owner() of contract may call this.

    function test_OCL_ZVE_UNIV2_pullFromLocker_restrictions(uint96 randomA, uint96 randomB) public {

        uint256 amountA = uint256(randomA) % (10_000_000 * USD) + 10 * USD;
        uint256 amountB = uint256(randomB) % (10_000_000 * USD) + 10 * USD;
        uint256 modularity = randomA % 4;

        pushToLockerInitial_Uni(amountA, amountB, modularity);

        // Can't pull if not owner().
        if (modularity == 0) {
            assert(!bob.try_pullFromLocker_DIRECT(address(OCL_ZVE_UNIV2_DAI), DAI, ""));
        }
        else if (modularity == 1) {
            assert(!bob.try_pullFromLocker_DIRECT(address(OCL_ZVE_UNIV2_FRAX), FRAX, ""));
        }
        else if (modularity == 2) {
            assert(!bob.try_pullFromLocker_DIRECT(address(OCL_ZVE_UNIV2_USDC), USDC, ""));
        }
        else if (modularity == 3) {
            assert(!bob.try_pullFromLocker_DIRECT(address(OCL_ZVE_UNIV2_USDT), USDT, ""));
        }
        else { revert(); }
        
    }

    // Note: This does not test the else-if or else branches.

    function test_OCL_ZVE_UNIV2_pullFromLocker_pair_state(uint96 randomA, uint96 randomB) public {

        uint256 amountA = uint256(randomA) % (10_000_000 * USD) + 10 * USD;
        uint256 amountB = uint256(randomB) % (10_000_000 * USD) + 10 * USD;
        uint256 modularity = randomA % 4;

        pushToLockerInitial_Uni(amountA, amountB, modularity);

        bytes memory data = abi.encodePacked(amountA * 99 / 100, amountB * 99 / 100);

        if (modularity == 0) {
            
            address pair = IUniswapV2Factory(OCL_ZVE_UNIV2_DAI.factory()).getPair(DAI, address(ZVE));

            // Pre-state.
            (uint256 _preBasis, uint256 _preLPTokens) = OCL_ZVE_UNIV2_DAI.fetchBasis();
            assertGt(_preBasis, 0);
            assertGt(_preLPTokens, 0);
            
            assert(god.try_pull(address(DAO), address(OCL_ZVE_UNIV2_DAI), pair, data));

            // Post-state.
            (uint256 _postBasis, uint256 _postLPTokens) = OCL_ZVE_UNIV2_DAI.fetchBasis();
            assertEq(_postBasis, 0);
            assertEq(_postLPTokens, 0);
            
        }
        else if (modularity == 1) {
            address pair = IUniswapV2Factory(OCL_ZVE_UNIV2_FRAX.factory()).getPair(FRAX, address(ZVE));

            // Pre-state.
            (uint256 _preBasis, uint256 _preLPTokens) = OCL_ZVE_UNIV2_FRAX.fetchBasis();
            assertGt(_preBasis, 0);
            assertGt(_preLPTokens, 0);
            
            assert(god.try_pull(address(DAO), address(OCL_ZVE_UNIV2_FRAX), pair, data));

            // Post-state.
            (uint256 _postBasis, uint256 _postLPTokens) = OCL_ZVE_UNIV2_FRAX.fetchBasis();
            assertEq(_postBasis, 0);
            assertEq(_postLPTokens, 0);
        }
        else if (modularity == 2) {
            address pair = IUniswapV2Factory(OCL_ZVE_UNIV2_USDC.factory()).getPair(USDC, address(ZVE));

            // Pre-state.
            (uint256 _preBasis, uint256 _preLPTokens) = OCL_ZVE_UNIV2_USDC.fetchBasis();
            assertGt(_preBasis, 0);
            assertGt(_preLPTokens, 0);
            
            assert(god.try_pull(address(DAO), address(OCL_ZVE_UNIV2_USDC), pair, data));

            // Post-state.
            (uint256 _postBasis, uint256 _postLPTokens) = OCL_ZVE_UNIV2_USDC.fetchBasis();
            assertEq(_postBasis, 0);
            assertEq(_postLPTokens, 0);
        }
        else if (modularity == 3) {
            address pair = IUniswapV2Factory(OCL_ZVE_UNIV2_USDT.factory()).getPair(USDT, address(ZVE));

            // Pre-state.
            (uint256 _preBasis, uint256 _preLPTokens) = OCL_ZVE_UNIV2_USDT.fetchBasis();
            assertGt(_preBasis, 0);
            assertGt(_preLPTokens, 0);
            
            assert(god.try_pull(address(DAO), address(OCL_ZVE_UNIV2_USDT), pair, data));

            // Post-state.
            (uint256 _postBasis, uint256 _postLPTokens) = OCL_ZVE_UNIV2_USDT.fetchBasis();
            assertEq(_postBasis, 0);
            assertEq(_postLPTokens, 0);
        }
        else { revert(); }

    }


    // Validate pullFromLockerPartial() state changes.
    // Validate pullFromLockerPartial() restrictions.
    // This includes:
    //  - Only the owner() of contract may call this.

    function test_OCL_ZVE_UNIV2_pullFromLockerPartial_restrictions(uint96 randomA, uint96 randomB) public {

        uint256 amountA = uint256(randomA) % (10_000_000 * USD) + 10 * USD;
        uint256 amountB = uint256(randomB) % (10_000_000 * USD) + 10 * USD;
        uint256 modularity = randomA % 4;

        pushToLockerInitial_Uni(amountA, amountB, modularity);

        // Can't pull if not owner().
        if (modularity == 0) {
            assert(!bob.try_pullFromLockerPartial_DIRECT(address(OCL_ZVE_UNIV2_DAI), DAI, 10 * USD, ""));
        }
        else if (modularity == 1) {
            assert(!bob.try_pullFromLockerPartial_DIRECT(address(OCL_ZVE_UNIV2_FRAX), FRAX, 10 * USD, ""));
        }
        else if (modularity == 2) {
            assert(!bob.try_pullFromLockerPartial_DIRECT(address(OCL_ZVE_UNIV2_USDC), USDC, 10 * USD, ""));
        }
        else if (modularity == 3) {
            assert(!bob.try_pullFromLockerPartial_DIRECT(address(OCL_ZVE_UNIV2_USDT), USDT, 10 * USD, ""));
        }
        else { revert(); }

    }

    // Note: This does not test the else-if or else branches.

    function test_OCL_ZVE_UNIV2_pullFromLockerPartial_state(uint96 randomA, uint96 randomB) public {

        uint256 amountA = uint256(randomA) % (10_000_000 * USD) + 10 * USD;
        uint256 amountB = uint256(randomB) % (10_000_000 * USD) + 10 * USD;
        uint256 modularity = randomA % 4;

        pushToLockerInitial_Uni(amountA, amountB, modularity);
        

        if (modularity == 0) {
            address pair = IUniswapV2Factory(OCL_ZVE_UNIV2_DAI.factory()).getPair(DAI, address(ZVE));

            uint256 partialAmount = IERC20(pair).balanceOf(address(OCL_ZVE_UNIV2_DAI)) * (randomA % 100 + 1) / 100;

            bytes memory data = abi.encodePacked(
                amountA * 99 / 100 * (randomA % 100 + 1) / 100, 
                amountB * 99 / 100 * (randomA % 100 + 1) / 100
            );

            // Pre-state.
            (uint256 _preBasis, uint256 _preLPTokens) = OCL_ZVE_UNIV2_DAI.fetchBasis();
            assertGt(_preBasis, 0);
            assertEq(_preLPTokens, IERC20(pair).balanceOf(address(OCL_ZVE_UNIV2_DAI)));
            
            assert(god.try_pullPartial(address(DAO), address(OCL_ZVE_UNIV2_DAI), pair, partialAmount, data));

            // Post-state.
            (uint256 _postBasis, uint256 _postLPTokens) = OCL_ZVE_UNIV2_DAI.fetchBasis();
            assertGt(_preBasis - _postBasis, 0);
            assertEq(_postLPTokens, _preLPTokens - partialAmount);
            
        }
        else if (modularity == 1) {
            address pair = IUniswapV2Factory(OCL_ZVE_UNIV2_FRAX.factory()).getPair(FRAX, address(ZVE));

            uint256 partialAmount = IERC20(pair).balanceOf(address(OCL_ZVE_UNIV2_FRAX)) * (randomA % 100 + 1) / 100;

            bytes memory data = abi.encodePacked(
                amountA * 99 / 100 * (randomA % 100 + 1) / 100, 
                amountB * 99 / 100 * (randomA % 100 + 1) / 100
            );

            // Pre-state.
            (uint256 _preBasis, uint256 _preLPTokens) = OCL_ZVE_UNIV2_FRAX.fetchBasis();
            assertGt(_preBasis, 0);
            assertEq(_preLPTokens, IERC20(pair).balanceOf(address(OCL_ZVE_UNIV2_FRAX)));
            
            assert(god.try_pullPartial(address(DAO), address(OCL_ZVE_UNIV2_FRAX), pair, partialAmount, data));

            // Post-state.
            (uint256 _postBasis, uint256 _postLPTokens) = OCL_ZVE_UNIV2_FRAX.fetchBasis();
            assertGt(_preBasis - _postBasis, 0);
            assertEq(_postLPTokens, _preLPTokens - partialAmount);
        }
        else if (modularity == 2) {
            address pair = IUniswapV2Factory(OCL_ZVE_UNIV2_USDC.factory()).getPair(USDC, address(ZVE));

            uint256 partialAmount = IERC20(pair).balanceOf(address(OCL_ZVE_UNIV2_USDC)) * (randomA % 100 + 1) / 100;

            bytes memory data = abi.encodePacked(
                amountA * 99 / 100 * (randomA % 100 + 1) / 100, 
                amountB * 99 / 100 * (randomA % 100 + 1) / 100
            );

            // Pre-state.
            (uint256 _preBasis, uint256 _preLPTokens) = OCL_ZVE_UNIV2_USDC.fetchBasis();
            assertGt(_preBasis, 0);
            assertEq(_preLPTokens, IERC20(pair).balanceOf(address(OCL_ZVE_UNIV2_USDC)));
            
            assert(god.try_pullPartial(address(DAO), address(OCL_ZVE_UNIV2_USDC), pair, partialAmount, data));

            // Post-state.
            (uint256 _postBasis, uint256 _postLPTokens) = OCL_ZVE_UNIV2_USDC.fetchBasis();
            assertGt(_preBasis - _postBasis, 0);
            assertEq(_postLPTokens, _preLPTokens - partialAmount);
        }
        else if (modularity == 3) {
            address pair = IUniswapV2Factory(OCL_ZVE_UNIV2_USDT.factory()).getPair(USDT, address(ZVE));

            uint256 partialAmount = IERC20(pair).balanceOf(address(OCL_ZVE_UNIV2_USDT)) * (randomA % 100 + 1) / 100;

            bytes memory data = abi.encodePacked(
                amountA * 99 / 100 * (randomA % 100 + 1) / 100, 
                amountB * 99 / 100 * (randomA % 100 + 1) / 100
            );

            // Pre-state.
            (uint256 _preBasis, uint256 _preLPTokens) = OCL_ZVE_UNIV2_USDT.fetchBasis();
            assertGt(_preBasis, 0);
            assertEq(_preLPTokens, IERC20(pair).balanceOf(address(OCL_ZVE_UNIV2_USDT)));
            
            assert(god.try_pullPartial(address(DAO), address(OCL_ZVE_UNIV2_USDT), pair, partialAmount, data));

            // Post-state.
            (uint256 _postBasis, uint256 _postLPTokens) = OCL_ZVE_UNIV2_USDT.fetchBasis();
            assertGt(_preBasis - _postBasis, 0);
            assertEq(_postLPTokens, _preLPTokens - partialAmount);
        }
        else { revert(); }

    }

    // Validate updateCompoundingRateBIPS() state changes.
    // Validate updateCompoundingRateBIPS() restrictions.
    // This includes:
    //  - Only governance contract (TLC / "god") may call this function.
    //  - _compoundingRateBIPS <= 10000

    function test_OCL_ZVE_UNIV2_updateCompoundingRateBIPS_restrictions() public {
        
        // Can't call if not governance contract.
        assert(!bob.try_updateCompoundingRateBIPS(address(OCL_ZVE_UNIV2_DAI), 10000));
        
        // Can't call if > 10000.
        assert(!god.try_updateCompoundingRateBIPS(address(OCL_ZVE_UNIV2_DAI), 10001));

        // Example success.
        assert(god.try_updateCompoundingRateBIPS(address(OCL_ZVE_UNIV2_DAI), 10000));

    }

    function test_OCL_ZVE_UNIV2_updateCompoundingRateBIPS_state(uint96 random) public {

        uint256 val = uint256(random) % 10000;
        
        // Pre-state.
        assertEq(OCL_ZVE_UNIV2_DAI.compoundingRateBIPS(), 5000);

        assert(god.try_updateCompoundingRateBIPS(address(OCL_ZVE_UNIV2_DAI), val));

        // Pre-state.
        assertEq(OCL_ZVE_UNIV2_DAI.compoundingRateBIPS(), val);

    }

    // Validate forwardYield() state changes.
    // Validate forwardYield() restrictions.
    // This includes:
    //  - Time constraints based on isKeeper(_msgSender()) status.

    function test_OCL_ZVE_UNIV2_forwardYield_restrictions(uint96 randomA, uint96 randomB) public {
        
        uint256 amountA = uint256(randomA) % (10_000_000 * USD) + 10 * USD;
        uint256 amountB = uint256(randomB) % (10_000_000 * USD) + 10 * USD;
        uint256 modularity = randomA % 4;

        pushToLockerInitial_Uni(amountA, amountB, modularity);

        if (modularity == 0) {
            buyZVE_Uni(amountA / 5, DAI); // ~ 20% price increase via pairAsset trade

            // Can't call forwardYield() before nextYieldDistribution() if not keeper.
            assert(!bob.try_forwardYield(address(OCL_ZVE_UNIV2_DAI)));

            hevm.warp(OCL_ZVE_UNIV2_DAI.nextYieldDistribution());
            assert(!bob.try_forwardYield(address(OCL_ZVE_UNIV2_DAI)));

            hevm.warp(OCL_ZVE_UNIV2_DAI.nextYieldDistribution() + 1 seconds);
            assert(bob.try_forwardYield(address(OCL_ZVE_UNIV2_DAI)));
        }
        else if (modularity == 1) {
            buyZVE_Uni(amountA / 5, FRAX); // ~ 20% price increase via pairAsset trade

            // Can't call forwardYield() before nextYieldDistribution() if not keeper.
            assert(!bob.try_forwardYield(address(OCL_ZVE_UNIV2_FRAX)));

            hevm.warp(OCL_ZVE_UNIV2_FRAX.nextYieldDistribution());
            assert(!bob.try_forwardYield(address(OCL_ZVE_UNIV2_FRAX)));

            hevm.warp(OCL_ZVE_UNIV2_FRAX.nextYieldDistribution() + 1 seconds);
            assert(bob.try_forwardYield(address(OCL_ZVE_UNIV2_FRAX)));
        }
        else if (modularity == 2) {
            buyZVE_Uni(amountA / 5, USDC); // ~ 20% price increase via pairAsset trade

            // Can't call forwardYield() before nextYieldDistribution() if not keeper.
            assert(!bob.try_forwardYield(address(OCL_ZVE_UNIV2_USDC)));

            hevm.warp(OCL_ZVE_UNIV2_USDC.nextYieldDistribution());
            assert(!bob.try_forwardYield(address(OCL_ZVE_UNIV2_USDC)));

            hevm.warp(OCL_ZVE_UNIV2_USDC.nextYieldDistribution() + 1 seconds);
            assert(bob.try_forwardYield(address(OCL_ZVE_UNIV2_USDC)));
        }
        else if (modularity == 3) {
            buyZVE_Uni(amountA / 5, USDT); // ~ 20% price increase via pairAsset trade

            // Can't call forwardYield() before nextYieldDistribution() if not keeper.
            assert(!bob.try_forwardYield(address(OCL_ZVE_UNIV2_USDT)));

            hevm.warp(OCL_ZVE_UNIV2_USDT.nextYieldDistribution());
            assert(!bob.try_forwardYield(address(OCL_ZVE_UNIV2_USDT)));

            hevm.warp(OCL_ZVE_UNIV2_USDT.nextYieldDistribution() + 1 seconds);
            assert(bob.try_forwardYield(address(OCL_ZVE_UNIV2_USDT)));
        }
        else { revert(); }

    }

    function test_OCL_ZVE_UNIV2_forwardYield_state(uint96 randomA, uint96 randomB) public {

        uint256 amountA = uint256(randomA) % (10_000_000 * USD) + 10 * USD;
        uint256 amountB = uint256(randomB) % (10_000_000 * USD) + 10 * USD;
        uint256 modularity = randomA % 4;

        assert(zvl.try_updateIsKeeper(address(GBL), address(bob), true));

        pushToLockerInitial_Uni(amountA, amountB, modularity);

        if (modularity == 0) {
            // Pre-state.
            (uint256 _PAC_DAI,) = OCL_ZVE_UNIV2_DAI.fetchBasis();
            uint256 _preZVE = IERC20(address(ZVE)).balanceOf(address(DAO));
            uint256 _prePair = IERC20(DAI).balanceOf(address(YDL));
            uint256 _preNYD = OCL_ZVE_UNIV2_DAI.nextYieldDistribution();
            assertEq(_prePair, 0);
            // assertEq(OCL_ZVE_UNIV2_DAI.amountForConversion(), 0);
 
            buyZVE_Uni(amountA / 5, DAI); // ~ 20% price increase via pairAsset trade

            hevm.warp(OCL_ZVE_UNIV2_DAI.nextYieldDistribution() - 12 hours + 1 seconds);
            assert(bob.try_forwardYield(address(OCL_ZVE_UNIV2_DAI)));
            
            // Post-state.
            assertEq(IERC20(DAI).balanceOf(address(OCL_ZVE_UNIV2_DAI)), 0);
            assertGt(IERC20(DAI).balanceOf(address(YDL)), _prePair); // Note: YDL.distributedAsset() == DAI
            assertGt(IERC20(address(ZVE)).balanceOf(address(DAO)), _preZVE);
            // assertEq(OCL_ZVE_UNIV2_DAI.amountForConversion(), 0);
            assertEq(OCL_ZVE_UNIV2_DAI.nextYieldDistribution(), _preNYD + 30 days);
            (_PAC_DAI,) = OCL_ZVE_UNIV2_DAI.fetchBasis();
        }
        else if (modularity == 1) {
            // Pre-state.
            (uint256 _PAC_FRAX,) = OCL_ZVE_UNIV2_FRAX.fetchBasis();
            uint256 _preZVE = IERC20(address(ZVE)).balanceOf(address(DAO));
            uint256 _prePair = IERC20(FRAX).balanceOf(address(Treasury));
            uint256 _preNYD = OCL_ZVE_UNIV2_FRAX.nextYieldDistribution();
            assertEq(_prePair, 0);
            // assertEq(OCL_ZVE_UNIV2_FRAX.amountForConversion(), 0);

            buyZVE_Uni(amountA / 5, FRAX); // ~ 20% price increase via pairAsset trade

            hevm.warp(OCL_ZVE_UNIV2_FRAX.nextYieldDistribution() - 12 hours + 1 seconds);
            assert(bob.try_forwardYield(address(OCL_ZVE_UNIV2_FRAX)));

            // Post-state.
            assertGt(IERC20(FRAX).balanceOf(address(Treasury)), 0);
            assertGt(IERC20(address(ZVE)).balanceOf(address(DAO)), _preZVE);
            // assertEq(OCL_ZVE_UNIV2_FRAX.amountForConversion(), IERC20(FRAX).balanceOf(address(OCL_ZVE_UNIV2_FRAX)));
            assertEq(OCL_ZVE_UNIV2_FRAX.nextYieldDistribution(), _preNYD + 30 days);
            (_PAC_FRAX,) = OCL_ZVE_UNIV2_FRAX.fetchBasis();
        }
        else if (modularity == 2) {
            // Pre-state.
            (uint256 _PAC_USDC,) = OCL_ZVE_UNIV2_USDC.fetchBasis();
            uint256 _preZVE = IERC20(address(ZVE)).balanceOf(address(DAO));
            uint256 _prePair = IERC20(USDC).balanceOf(address(Treasury));
            uint256 _preNYD = OCL_ZVE_UNIV2_USDC.nextYieldDistribution();
            assertEq(_prePair, 0);
            // assertEq(OCL_ZVE_UNIV2_USDC.amountForConversion(), 0);

            buyZVE_Uni(amountA / 5, USDC); // ~ 20% price increase via pairAsset trade

            hevm.warp(OCL_ZVE_UNIV2_USDC.nextYieldDistribution() - 12 hours + 1 seconds);
            assert(bob.try_forwardYield(address(OCL_ZVE_UNIV2_USDC)));

            // Post-state.
            assertGt(IERC20(USDC).balanceOf(address(Treasury)), 0);
            assertGt(IERC20(address(ZVE)).balanceOf(address(DAO)), _preZVE);
            // assertEq(OCL_ZVE_UNIV2_USDC.amountForConversion(), IERC20(USDC).balanceOf(address(OCL_ZVE_UNIV2_USDC)));
            assertEq(OCL_ZVE_UNIV2_USDC.nextYieldDistribution(), _preNYD + 30 days);
            (_PAC_USDC,) = OCL_ZVE_UNIV2_USDC.fetchBasis();
        }
        else if (modularity == 3) {
            // Pre-state.
            (uint256 _PAC_USDT,) = OCL_ZVE_UNIV2_USDT.fetchBasis();
            uint256 _preZVE = IERC20(address(ZVE)).balanceOf(address(DAO));
            uint256 _prePair = IERC20(USDT).balanceOf(address(Treasury));
            uint256 _preNYD = OCL_ZVE_UNIV2_USDT.nextYieldDistribution();
            assertEq(_prePair, 0);
            // assertEq(OCL_ZVE_UNIV2_USDT.amountForConversion(), 0);

            buyZVE_Uni(amountA / 5, USDT); // ~ 20% price increase via pairAsset trade

            hevm.warp(OCL_ZVE_UNIV2_USDT.nextYieldDistribution() - 12 hours + 1 seconds);
            assert(bob.try_forwardYield(address(OCL_ZVE_UNIV2_USDT)));

            // Post-state.
            assertGt(IERC20(USDT).balanceOf(address(Treasury)), 0);
            assertGt(IERC20(address(ZVE)).balanceOf(address(DAO)), _preZVE);
            // assertEq(OCL_ZVE_UNIV2_USDT.amountForConversion(), IERC20(USDT).balanceOf(address(OCL_ZVE_UNIV2_USDT)));
            assertEq(OCL_ZVE_UNIV2_USDT.nextYieldDistribution(), _preNYD + 30 days);
            (_PAC_USDT,) = OCL_ZVE_UNIV2_USDT.fetchBasis();
        }
        else { revert(); }

    }

    // Check that fetchBasis() return goes up when buying $ZVE (or selling).

    function test_OCL_ZVE_UNIV2_fetchBasis_check(uint96 randomA, uint96 randomB) public {

        uint256 amountA = uint256(randomA) % (10_000_000 * USD) + 10 * USD;
        uint256 amountB = uint256(randomB) % (10_000_000 * USD) + 10 * USD;
        uint256 modularity = randomA % 4;

        pushToLockerInitial_Uni(amountA, amountB, modularity);

        if (modularity == 0) {
            (uint256 _preAmt,) = OCL_ZVE_UNIV2_DAI.fetchBasis();
            emit log_named_uint("_preAmt", _preAmt);
            
            buyZVE_Uni(amountA / 5, DAI); // ~ 20% price increase via pairAsset trade
            (uint256 _postAmt,) = OCL_ZVE_UNIV2_DAI.fetchBasis();
            emit log_named_uint("_postAmt", _postAmt);
            
            assertGt(_postAmt, _preAmt);

            address pool = IFactory_OCL_ZVE(OCL_ZVE_UNIV2_DAI.factory()).getPair(OCL_ZVE_UNIV2_DAI.pairAsset(), IZivoeGlobals_OCL_ZVE(OCL_ZVE_UNIV2_DAI.GBL()).ZVE());

            sellZVE_Uni(IERC20(address(ZVE)).balanceOf(address(pool)) / 2, DAI); // Sell 50% of ZVE
            (uint256 _postAmt2,) = OCL_ZVE_UNIV2_DAI.fetchBasis();
            emit log_named_uint("_postAmt2", _postAmt2);
            
            assertLt(_postAmt2, _postAmt);
        }
        else if (modularity == 1) {
            (uint256 _preAmt,) = OCL_ZVE_UNIV2_FRAX.fetchBasis();
            emit log_named_uint("_preAmt", _preAmt);

            buyZVE_Uni(amountA / 5, FRAX); // ~ 20% price increase via pairAsset trade
            (uint256 _postAmt,) = OCL_ZVE_UNIV2_FRAX.fetchBasis();
            emit log_named_uint("_postAmt", _postAmt);
            
            assertGt(_postAmt, _preAmt);

            address pool = IFactory_OCL_ZVE(OCL_ZVE_UNIV2_FRAX.factory()).getPair(OCL_ZVE_UNIV2_FRAX.pairAsset(), IZivoeGlobals_OCL_ZVE(OCL_ZVE_UNIV2_FRAX.GBL()).ZVE());

            sellZVE_Uni(IERC20(address(ZVE)).balanceOf(address(pool)) / 2, FRAX); // Sell 50% of ZVE
            (uint256 _postAmt2,) = OCL_ZVE_UNIV2_FRAX.fetchBasis();
            emit log_named_uint("_postAmt2", _postAmt2);
            
            assertLt(_postAmt2, _postAmt);
        }
        else if (modularity == 2) {
            (uint256 _preAmt,) = OCL_ZVE_UNIV2_USDC.fetchBasis();
            emit log_named_uint("_preAmt", _preAmt);

            buyZVE_Uni(amountA / 5, USDC); // ~ 20% price increase via pairAsset trade
            (uint256 _postAmt,) = OCL_ZVE_UNIV2_USDC.fetchBasis();
            emit log_named_uint("_postAmt", _postAmt);
            
            assertGt(_postAmt, _preAmt);

            address pool = IFactory_OCL_ZVE(OCL_ZVE_UNIV2_USDC.factory()).getPair(OCL_ZVE_UNIV2_USDC.pairAsset(), IZivoeGlobals_OCL_ZVE(OCL_ZVE_UNIV2_USDC.GBL()).ZVE());

            sellZVE_Uni(IERC20(address(ZVE)).balanceOf(address(pool)) / 2, USDC); // Sell 50% of ZVE
            (uint256 _postAmt2,) = OCL_ZVE_UNIV2_USDC.fetchBasis();
            emit log_named_uint("_postAmt2", _postAmt2);
            
            assertLt(_postAmt2, _postAmt);
        }
        else if (modularity == 3) {
            (uint256 _preAmt,) = OCL_ZVE_UNIV2_USDT.fetchBasis();
            emit log_named_uint("_preAmt", _preAmt);

            buyZVE_Uni(amountA / 5, USDT); // ~ 20% price increase via pairAsset trade
            (uint256 _postAmt,) = OCL_ZVE_UNIV2_USDT.fetchBasis();
            emit log_named_uint("_postAmt", _postAmt);
            
            assertGt(_postAmt, _preAmt);

            address pool = IFactory_OCL_ZVE(OCL_ZVE_UNIV2_USDT.factory()).getPair(OCL_ZVE_UNIV2_USDT.pairAsset(), IZivoeGlobals_OCL_ZVE(OCL_ZVE_UNIV2_USDT.GBL()).ZVE());

            sellZVE_Uni(IERC20(address(ZVE)).balanceOf(address(pool)) / 2, USDT); // Sell 50% of ZVE
            (uint256 _postAmt2,) = OCL_ZVE_UNIV2_USDT.fetchBasis();
            emit log_named_uint("_postAmt2", _postAmt2);
            
            assertLt(_postAmt2, _postAmt);
        }
        else { revert(); }

    }

    // Validate updateOCTYDL() state changes.
    // Validate updateOCTYDL() restrictions.
    // This includes:
    //   - _msgSender() must be ZVL

    function test_OCL_ZVE_SUSHI_DAI_updateOCTYDL_restrictions_msgSender() public {
        // Can't call if _msgSender() is not ZVL.
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCL_ZVE::updateOCTYDL() _msgSender() != IZivoeGlobals_OCL_ZVE(GBL).ZVL()");
        OCL_ZVE_SUSHI_DAI.updateOCTYDL(address(bob));
        hevm.stopPrank();
    }

    function test_OCL_ZVE_SUSHI_DAI_updateOCTYDL_state(address fuzzed) public {
        
        hevm.assume(fuzzed != address(0));

        // Pre-state.
        assertEq(OCL_ZVE_SUSHI_DAI.OCT_YDL(), address(Treasury));

        // updateOCTYDL().
        hevm.expectEmit(true, true, false, false, address(OCL_ZVE_SUSHI_DAI));
        emit UpdatedOCTYDL(address(fuzzed), address(Treasury));
        hevm.startPrank(address(zvl));
        OCL_ZVE_SUSHI_DAI.updateOCTYDL(address(fuzzed));
        hevm.stopPrank();

        // Post-state.
        assertEq(OCL_ZVE_SUSHI_DAI.OCT_YDL(), address(fuzzed));

    }

}
