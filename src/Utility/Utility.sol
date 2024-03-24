// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

// User imports.
import "./users/Admin.sol";
import "./users/Blackhat.sol";
import "./users/Borrower.sol";
import "./users/Deployer.sol";
import "./users/Manager.sol";
import "./users/Investor.sol";
import "./users/Vester.sol";

// Core imports.
import "../../lib/zivoe-core-foundry/src/ZivoeDAO.sol";
import "../../lib/zivoe-core-foundry/src/ZivoeGlobals.sol";
import "../../lib/zivoe-core-foundry/src/ZivoeGovernorV2.sol";
import "../../lib/zivoe-core-foundry/src/ZivoeITO.sol";
import "../../lib/zivoe-core-foundry/src/ZivoeMath.sol";
import "../../lib/zivoe-core-foundry/src/ZivoeToken.sol";
import "../../lib/zivoe-core-foundry/src/ZivoeTranches.sol";
import "../../lib/zivoe-core-foundry/src/ZivoeTrancheToken.sol";
import "../../lib/zivoe-core-foundry/src/ZivoeYDL.sol";


// External-protocol imports.
import "../../lib/zivoe-core-foundry/src/libraries/ZivoeTLC.sol";
import { ZivoeRewards } from "../../lib/zivoe-core-foundry/src/ZivoeRewards.sol";
import { ZivoeRewardsVesting } from "../../lib/zivoe-core-foundry/src/ZivoeRewardsVesting.sol";

// Interfaces full imports.
import "../../lib/zivoe-core-foundry/src/misc/InterfacesAggregated.sol";

// Test (foundry-rs) imports.
import "../../lib/forge-std/src/Test.sol";

// Interface imports.
interface Hevm {
    function roll(uint256) external;
    function warp(uint256) external;
    function store(address,bytes32,bytes32) external;
    function expectRevert(bytes calldata) external;
    function prank(address) external;
    function startPrank(address) external;
    function stopPrank() external;
    function expectEmit(bool, bool, bool, bool, address) external;
    function assume(bool) external;
}

interface User {
    function approve(address, uint256) external;
}


/// @notice This is the primary Utility contract for testing and debugging.
contract Utility is Test {

    Hevm hevm;      /// @dev The core import of Hevm from Test.sol to support simulations.

    // ------------
    //    Actors
    // ------------

    Admin       god;    /// @dev    Represents "governing" contract of the system, could be individual 
                        ///         (for debugging) or ZivoeTLC (for live governance simulations).
    Admin       zvl;    /// @dev    Represents GnosisSafe multi-sig, handled by ZVL.

    Blackhat    bob;    /// @dev    Bob is a malicious actor that tries to attack the system for profit/mischief.

    Borrower    tim;    /// @dev    Tim borrows money through an OCC_Modular locker.
    
    Deployer    jay;    /// @dev    Jay is responsible handling initial administrative tasks during 
                        ///         deployment, otherwise post-deployment Jay is not utilized.

    Manager     roy;    /// @dev    Roy manages an OCC_Modular locker.

    Investor    sam;    /// @dev    Provides liquidity to the tranches (generally senior tranche).
    Investor    sue;    /// @dev    Provides liquidity to the tranches (generally senior tranche).
    Investor    sal;    /// @dev    Provides liquidity to the tranches (generally senior tranche).
    Investor    sid;    /// @dev    Provides liquidity to the tranches (generally senior tranche).
    Investor    jim;    /// @dev    Provides liquidity to the tranches (generally junior tranche).
    Investor    joe;    /// @dev    Provides liquidity and stakes.
    Investor    jon;    /// @dev    Provides liquidity and stakes.
    Investor    jen;    /// @dev    Provides liquidity and stakes.

    Vester      poe;    /// @dev    Internal (revokable) vester.
    Vester      qcp;    /// @dev    External (non-revokable) vester.
    Vester      moe;    /// @dev    Additional vester.
    Vester      pam;    /// @dev    Additional vester.
    Vester      tia;    /// @dev    Additional vester.



    // --------------------------------
    //    Mainnet Contract Addresses   
    // --------------------------------

    /// @notice Stablecoin contracts.
    address constant DAI   = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant FRAX  = 0x853d955aCEf822Db058eb8505911ED77F175b99e;
    address constant TUSD  = 0x0000000000085d4780B73119b644AE5ecd22b376;    /// TrueUSD.
    address constant USDC  = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;    
    address constant USDT  = 0xdAC17F958D2ee523a2206206994597C13D831ec7;    /// Tether.
    address constant OUSD  = 0x2A8e1E676Ec238d8A992307B495b45B3fEAa5e86;    /// Origin.
    address constant alUSD = 0xBC6DA0FE9aD5f3b0d58160288917AA56653660E9;    /// Alchemix.
    address constant sUSD  = 0x57Ab1ec28D129707052df4dF418D58a2D46d5f51;    /// Synthetix.

    address constant AAVE  = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;    /// AAVE(v3).
    address constant CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52;      /// Curve.
    address constant CVX = 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B;      /// Convex.
    address constant WETH  = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;    /// WrappedETH.
    address constant WBTC  = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;    /// WrappedBTC.

    address constant UNISWAP_V2_ROUTER_02 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; // Uniswap V2 router.
    address constant UNISWAP_V2_FACTORY   = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f; // Uniswap V2 factory.

    address constant SUSHI_V2_ROUTER = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F; // Sushi router.
    address constant SUSHI_V2_FACTORY   = 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac; // Sushi factory.

    address constant CHAINLINK_ETH = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419; // Chainlink ETH oracle.

    
    // --------------------------
    //    Zivoe Core Contracts
    // --------------------------

    ZivoeDAO            DAO;
    ZivoeGlobals        GBL;
    ZivoeGovernorV2     GOV;
    ZivoeITO            ITO;
    ZivoeMath           MATH;
    ZivoeToken          ZVE;
    ZivoeTranches       ZVT;
    ZivoeTrancheToken   zSTT;
    ZivoeTrancheToken   zJTT;
    ZivoeYDL            YDL;

    ZivoeTLC  TLC;
    


    // -------------------------------
    //    Zivoe Periphery Contracts
    // -------------------------------

    ZivoeRewards    stJTT;
    ZivoeRewards    stSTT;
    ZivoeRewards    stZVE;
    
    ZivoeRewardsVesting    vestZVE;



    // -----------------------
    //    Zivoe DAO Lockers
    // -----------------------



    // ---------------
    //    Constants
    // ---------------

    uint256 constant BIPS = 10 ** 4;    // BIPS = Basis Points (1 = 0.01%, 100 = 1.00%, 10000 = 100.00%)
    uint256 constant USD = 10 ** 6;     // USDC / USDT precision
    uint256 constant BTC = 10 ** 8;     // wBTC precision
    uint256 constant WAD = 10 ** 18;
    uint256 constant RAY = 10 ** 27;

    uint256 constant MAX_UINT = 2**256 - 1;



    // ---------------
    //    Utilities
    // ---------------

    struct Token {
        address addr; // ERC20 Mainnet address
        uint256 slot; // Balance storage slot
        address orcl; // Chainlink oracle address
    }
 
    mapping (bytes32 => Token) tokens;

    struct TestObj {
        uint256 pre;
        uint256 post;
    }

    event Debug(string, address);
    event Debug(string, bytes);
    event Debug(string, bool);
    event Debug(string, uint256);

    constructor() { hevm = Hevm(address(bytes20(uint160(uint256(keccak256("hevm cheat code")))))); }

    /// @notice Creates protocol actors.
    function createActors() public {
        // 2 Admins.
        god = new Admin();
        zvl = new Admin();
        
        // 1 Blackhat.
        bob = new Blackhat();

        // 1 Borrower.
        tim = new Borrower();

        // 1 Deployer.
        jay = new Deployer();

        // 1 Manager.
        roy = new Manager();

        // 8 Investors.
        sam = new Investor();
        sue = new Investor();
        sal = new Investor();
        sid = new Investor();
        jim = new Investor();
        joe = new Investor();
        jon = new Investor();
        jen = new Investor();

        // 5 Vesters.
        poe = new Vester();
        qcp = new Vester();
        moe = new Vester();
        pam = new Vester();
        tia = new Vester();
    }

    /// @notice Creates mintable tokens via mint().
    function setUpTokens() public {

        tokens["USDC"].addr = USDC;
        tokens["USDC"].slot = 9;

        tokens["DAI"].addr = DAI;
        tokens["DAI"].slot = 2;

        tokens["FRAX"].addr = FRAX;
        tokens["FRAX"].slot = 0;

        tokens["USDT"].addr = USDT;
        tokens["USDT"].slot = 2;

        tokens["WETH"].addr = WETH;
        tokens["WETH"].slot = 3;

        tokens["WBTC"].addr = WBTC;
        tokens["WBTC"].slot = 0;
    }

    /// @notice Simulates an ITO and calls migrateDeposits()/
    /// @dev    Does not claim / stake tokens.
    function simulateITO_byTranche_optionalStake(
        uint256 amountSenior,
        bool stake
    ) public {

        // mint().
        mint("DAI", address(sam), amountSenior);
        mint("DAI", address(jim), amountSenior / 5);

        // Warp to start of ITO.
        zvl.try_commence(address(ITO));
        hevm.warp(ITO.end() - 30 days + 1 seconds);

        // approve().
        assert(sam.try_approveToken(DAI, address(ITO), amountSenior));
        assert(jim.try_approveToken(DAI, address(ITO), amountSenior / 5));

        // depositSenior() / depositJunior().
        assert(sam.try_depositSenior(address(ITO), amountSenior, DAI));
        assert(jim.try_depositJunior(address(ITO), amountSenior / 5, DAI));
        
        hevm.warp(ITO.end() + 1 seconds);
        
        ITO.migrateDeposits();
    
        assert(sam.try_claimAirdrop(address(ITO), address(sam)));
        assert(jim.try_claimAirdrop(address(ITO), address(jim)));

        // assert(sam.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam))));
        // assert(jim.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(jim))));
        // assert(sam.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam))));
        // assert(jim.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(jim))));
        
        if (stake) {
            assert(sam.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(sam))));
            assert(sam.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(sam))));

            assert(jim.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(jim))));
            assert(jim.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(jim))));
        }

    }

    /// @notice Simulates an ITO and calls migrateDeposits()/
    /// @dev    Does not claim / stake tokens.
    function simulateITO(
        uint256 amount_DAI,
        uint256 amount_FRAX,
        uint256 amount_USDC,
        uint256 amount_USDT
    ) public {
        
        // Mint investor's stablecoins.
        mint("DAI", address(sam), amount_DAI);
        mint("DAI", address(sue), amount_DAI);
        mint("DAI", address(sal), amount_DAI);
        mint("DAI", address(sid), amount_DAI);
        mint("DAI", address(jim), amount_DAI);
        mint("DAI", address(joe), amount_DAI);
        mint("DAI", address(jon), amount_DAI);
        mint("DAI", address(jen), amount_DAI);
        
        mint("FRAX", address(sam), amount_FRAX);
        mint("FRAX", address(sue), amount_FRAX);
        mint("FRAX", address(sal), amount_FRAX);
        mint("FRAX", address(sid), amount_FRAX);
        mint("FRAX", address(jim), amount_FRAX);
        mint("FRAX", address(joe), amount_FRAX);
        mint("FRAX", address(jon), amount_FRAX);
        mint("FRAX", address(jen), amount_FRAX);
        
        mint("USDC", address(sam), amount_USDC);
        mint("USDC", address(sue), amount_USDC);
        mint("USDC", address(sal), amount_USDC);
        mint("USDC", address(sid), amount_USDC);
        mint("USDC", address(jim), amount_USDC);
        mint("USDC", address(joe), amount_USDC);
        mint("USDC", address(jon), amount_USDC);
        mint("USDC", address(jen), amount_USDC);
        
        mint("USDT", address(sam), amount_USDT);
        mint("USDT", address(sue), amount_USDT);
        mint("USDT", address(sal), amount_USDT);
        mint("USDT", address(sid), amount_USDT);
        mint("USDT", address(jim), amount_USDT);
        mint("USDT", address(joe), amount_USDT);
        mint("USDT", address(jon), amount_USDT);
        mint("USDT", address(jen), amount_USDT);

        // Warp to start of ITO.
        zvl.try_commence(address(ITO));
        hevm.warp(ITO.end() - 30 days + 1 seconds);

        // Approve ITO for stablecoins.
        assert(sam.try_approveToken(DAI, address(ITO), amount_DAI));
        assert(sue.try_approveToken(DAI, address(ITO), amount_DAI));
        assert(sal.try_approveToken(DAI, address(ITO), amount_DAI));
        assert(sid.try_approveToken(DAI, address(ITO), amount_DAI));
        assert(jim.try_approveToken(DAI, address(ITO), amount_DAI));
        assert(joe.try_approveToken(DAI, address(ITO), amount_DAI));
        assert(jon.try_approveToken(DAI, address(ITO), amount_DAI));
        assert(jen.try_approveToken(DAI, address(ITO), amount_DAI));

        assert(sam.try_approveToken(FRAX, address(ITO), amount_FRAX));
        assert(sue.try_approveToken(FRAX, address(ITO), amount_FRAX));
        assert(sal.try_approveToken(FRAX, address(ITO), amount_FRAX));
        assert(sid.try_approveToken(FRAX, address(ITO), amount_FRAX));
        assert(jim.try_approveToken(FRAX, address(ITO), amount_FRAX));
        assert(joe.try_approveToken(FRAX, address(ITO), amount_FRAX));
        assert(jon.try_approveToken(FRAX, address(ITO), amount_FRAX));
        assert(jen.try_approveToken(FRAX, address(ITO), amount_FRAX));

        assert(sam.try_approveToken(USDC, address(ITO), amount_USDC));
        assert(sue.try_approveToken(USDC, address(ITO), amount_USDC));
        assert(sal.try_approveToken(USDC, address(ITO), amount_USDC));
        assert(sid.try_approveToken(USDC, address(ITO), amount_USDC));
        assert(jim.try_approveToken(USDC, address(ITO), amount_USDC));
        assert(joe.try_approveToken(USDC, address(ITO), amount_USDC));
        assert(jon.try_approveToken(USDC, address(ITO), amount_USDC));
        assert(jen.try_approveToken(USDC, address(ITO), amount_USDC));

        assert(sam.try_approveToken(USDT, address(ITO), amount_USDT));
        assert(sue.try_approveToken(USDT, address(ITO), amount_USDT));
        assert(sal.try_approveToken(USDT, address(ITO), amount_USDT));
        assert(sid.try_approveToken(USDT, address(ITO), amount_USDT));
        assert(jim.try_approveToken(USDT, address(ITO), amount_USDT));
        assert(joe.try_approveToken(USDT, address(ITO), amount_USDT));
        assert(jon.try_approveToken(USDT, address(ITO), amount_USDT));
        assert(jen.try_approveToken(USDT, address(ITO), amount_USDT));

        // Deposit stablecoins.

        // 2 ("sam", "sue") into only senior tranche.
        assert(sam.try_depositSenior(address(ITO), amount_DAI, DAI));
        assert(sam.try_depositSenior(address(ITO), amount_FRAX, FRAX));
        assert(sam.try_depositSenior(address(ITO), amount_USDC, USDC));
        assert(sam.try_depositSenior(address(ITO), amount_USDT, USDT));
        assert(sue.try_depositSenior(address(ITO), amount_DAI, DAI));
        assert(sue.try_depositSenior(address(ITO), amount_FRAX, FRAX));
        assert(sue.try_depositSenior(address(ITO), amount_USDC, USDC));
        assert(sue.try_depositSenior(address(ITO), amount_USDT, USDT));

        // 4 ("sal", "sid", "jon", "jen") into both tranches.
        assert(jen.try_depositSenior(address(ITO), amount_FRAX, FRAX));
        assert(jen.try_depositSenior(address(ITO), amount_USDC, USDC));

        assert(sal.try_depositSenior(address(ITO), amount_DAI, DAI));
        assert(sal.try_depositSenior(address(ITO), amount_USDC, USDC));

        assert(sid.try_depositSenior(address(ITO), amount_FRAX, FRAX));
        assert(sid.try_depositSenior(address(ITO), amount_USDT, USDT));

        assert(jon.try_depositSenior(address(ITO), amount_DAI, DAI));
        assert(jon.try_depositSenior(address(ITO), amount_USDT, USDT));

        // 2 ("jim", "joe") into only junior tranche.
        assert(jim.try_depositJunior(address(ITO), amount_DAI / 5, DAI));
        assert(jim.try_depositJunior(address(ITO), amount_FRAX / 5, FRAX));
        assert(jim.try_depositJunior(address(ITO), amount_USDC / 5, USDC));
        assert(jim.try_depositJunior(address(ITO), amount_USDT / 5, USDT));
        assert(joe.try_depositJunior(address(ITO), amount_DAI / 5, DAI));
        assert(joe.try_depositJunior(address(ITO), amount_FRAX / 5, FRAX));
        assert(joe.try_depositJunior(address(ITO), amount_USDC / 5, USDC));
        assert(joe.try_depositJunior(address(ITO), amount_USDT / 5, USDT));

        assert(sal.try_depositJunior(address(ITO), amount_FRAX / 5, FRAX));
        assert(sal.try_depositJunior(address(ITO), amount_USDT / 5, USDT));
        
        assert(sid.try_depositJunior(address(ITO), amount_DAI / 5, DAI));
        assert(sid.try_depositJunior(address(ITO), amount_USDC / 5, USDC));
        
        assert(jon.try_depositJunior(address(ITO), amount_FRAX / 5, FRAX));
        assert(jon.try_depositJunior(address(ITO), amount_USDC / 5, USDC));
        
        assert(jen.try_depositJunior(address(ITO), amount_DAI / 5, DAI));
        assert(jen.try_depositJunior(address(ITO), amount_USDT / 5, USDT));

        hevm.warp(ITO.end() + 1 seconds);
        
        ITO.migrateDeposits();

    }

    /// @notice Stakes all tokens possible.
    function stakeTokens() public {
        
        assert(sam.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam))));
        assert(sue.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(sue))));
        assert(sal.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(sal))));
        assert(sid.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(sid))));
        assert(jim.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(jim))));
        assert(joe.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(joe))));
        assert(jon.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(jon))));
        assert(jen.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(jen))));

        assert(sam.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(sam))));
        assert(sue.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(sue))));
        assert(sal.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(sal))));
        assert(sid.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(sid))));
        assert(jim.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(jim))));
        assert(joe.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(joe))));
        assert(jon.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(jon))));
        assert(jen.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(jen))));

        assert(sam.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(sam))));
        assert(sue.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(sue))));
        assert(sal.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(sal))));
        assert(sid.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(sid))));
        assert(jim.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(jim))));
        assert(joe.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(joe))));
        assert(jon.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(jon))));
        assert(jen.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(jen))));
    
        // assert(sam.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam))));
        // assert(sue.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(sue))));
        // assert(sal.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(sal))));
        // assert(sid.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(sid))));
        // assert(jim.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(jim))));
        // assert(joe.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(joe))));
        // assert(jon.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(jon))));
        // assert(jen.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(jen))));
        
        assert(sam.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(sam))));
        assert(sue.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(sue))));
        assert(sal.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(sal))));
        assert(sid.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(sid))));
        // Note: "jim", "joe" did not invest into Senior tranche.
        // assert(jim.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(jim))));
        // assert(joe.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(joe))));
        assert(jon.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(jon))));
        assert(jen.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(jen))));

        // Note: "sam", "sue" did not invest into Junior tranche.
        // assert(sam.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(sam))));
        // assert(sue.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(sue))));
        assert(sal.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(sal))));
        assert(sid.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(sid))));
        assert(jim.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(jim))));
        assert(joe.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(joe))));
        assert(jon.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(jon))));
        assert(jen.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(jen))));
    }

    /// @notice All participants claim tokens from ITO ($ZVE, $zJTT, $zSTT) and stakes them.
    function claimITO_and_approveTokens_and_stakeTokens(bool stake) public {

        require(ITO.migrated());

        assert(sam.try_claimAirdrop(address(ITO), address(sam)));
        assert(sue.try_claimAirdrop(address(ITO), address(sue)));
        assert(sal.try_claimAirdrop(address(ITO), address(sal)));
        assert(sid.try_claimAirdrop(address(ITO), address(sid)));
        assert(jim.try_claimAirdrop(address(ITO), address(jim)));
        assert(joe.try_claimAirdrop(address(ITO), address(joe)));
        assert(jon.try_claimAirdrop(address(ITO), address(jon)));
        assert(jen.try_claimAirdrop(address(ITO), address(jen)));

        assert(sam.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam))));
        assert(sue.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(sue))));
        assert(sal.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(sal))));
        assert(sid.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(sid))));
        assert(jim.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(jim))));
        assert(joe.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(joe))));
        assert(jon.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(jon))));
        assert(jen.try_approveToken(address(ZVE), address(stZVE), IERC20(address(ZVE)).balanceOf(address(jen))));

        assert(sam.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(sam))));
        assert(sue.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(sue))));
        assert(sal.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(sal))));
        assert(sid.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(sid))));
        assert(jim.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(jim))));
        assert(joe.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(joe))));
        assert(jon.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(jon))));
        assert(jen.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(jen))));

        assert(sam.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(sam))));
        assert(sue.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(sue))));
        assert(sal.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(sal))));
        assert(sid.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(sid))));
        assert(jim.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(jim))));
        assert(joe.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(joe))));
        assert(jon.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(jon))));
        assert(jen.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(jen))));

        if (stake) {
            // assert(sam.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam))));
            // assert(sue.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(sue))));
            // assert(sal.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(sal))));
            // assert(sid.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(sid))));
            // assert(jim.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(jim))));
            // assert(joe.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(joe))));
            // assert(jon.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(jon))));
            // assert(jen.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(jen))));
            
            assert(sam.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(sam))));
            assert(sue.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(sue))));
            assert(sal.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(sal))));
            assert(sid.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(sid))));
            // Note: "jim", "joe" did not invest into Senior tranche.
            // assert(jim.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(jim))));
            // assert(joe.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(joe))));
            assert(jon.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(jon))));
            assert(jen.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(jen))));

            // Note: "sam", "sue" did not invest into Junior tranche.
            // assert(sam.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(sam))));
            // assert(sue.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(sue))));
            assert(sal.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(sal))));
            assert(sid.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(sid))));
            assert(jim.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(jim))));
            assert(joe.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(joe))));
            assert(jon.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(jon))));
            assert(jen.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(jen))));
        }
        
    }

    /// @notice Deploys the core protocol.
    /// @dev    Set input param to true for using TLC as governance contract, otherwise
    ///         set input param to false for using "gov" (account) as governance contract
    ///         for more simplistic control over governance-based actions (and testing).
    function deployCore(bool live) public {

        // Step #0 --- Run initial setup functions for simulations.

        createActors();
        setUpTokens();


        // Step #1 --- Deploy ZivoeGlobals.sol.
        
        GBL = new ZivoeGlobals();


        // Step #2 --- Deploy ZivoeToken.sol.
       
        ZVE = new ZivoeToken(
            "Zivoe",
            "ZVE",
            address(jay)       // Note: "jay" receives all $ZVE tokens initially.
        );

        // Step #3 --- Deploy governance contracts, ZivoeTLC.sol and ZivoeGovernorV2.sol.

        address[] memory proposers;
        address[] memory executors;

        TLC = new ZivoeTLC(
            12 hours,
            proposers,
            executors,
            address(GBL)
        );

        GOV = new ZivoeGovernorV2(
            IVotes(address(ZVE)),
            TLC,
            address(GBL)
        );

        // TLC.owner() MUST grant "EXECUTOR_ROLE" to address(0) for public execution of proposals.
        TLC.grantRole(TLC.EXECUTOR_ROLE(), address(0));

        // TLC.owner() MUST grant "PROPOSE_ROLE" to GOV for handling pass-through of proposals.
        TLC.grantRole(TLC.PROPOSER_ROLE(), address(GOV));

        // TLC.owner() MUST grant "CANCELLER_ROLE" to zvl for handling cancellation.
        TLC.grantRole(TLC.CANCELLER_ROLE(), address(zvl));

        // TLC.owner() MUST revoke role as "TIMELOCK_ADMIN_ROLE" after completing both grantRole() commands above.
        TLC.revokeRole(TLC.TIMELOCK_ADMIN_ROLE(), address(this));


        // Step #4 --- Deploy ZivoeDAO.sol,

        DAO = new ZivoeDAO(address(GBL));

        // "jay" MUST transfer 35% of ZVE tokens to DAO.
        jay.transferToken(address(ZVE), address(DAO), ZVE.totalSupply() * 35 / 100);

        // DAO.owner() MUST transfer ownership to governance contract.
        DAO.transferOwnershipAndLock(live ? address(TLC) : address(god));


        // Step #5 --- Deploy Senior/Junior tranche token, through ZivoeTrancheToken.sol.

        zSTT = new ZivoeTrancheToken(
            "Zivoe Senior Tranche",
            "zSTT"
        );

        zJTT = new ZivoeTrancheToken(
            "Zivoe Junior Tranche",
            "zJTT"
        );


        // Step #6 --- Deploy ZivoeITO.sol.

        address[] memory _stablesITO = new address[](4);
        _stablesITO[0] = DAI;
        _stablesITO[1] = FRAX;
        _stablesITO[2] = USDC;
        _stablesITO[3] = USDT;

        ITO = new ZivoeITO(
            address(GBL),
            _stablesITO
        );

        // zJTT.owner() MUST give ITO minting priviliges.
        // zSTT.owner() MUST give ITO minting priviliges.
        zJTT.changeMinterRole(address(ITO), true);
        zSTT.changeMinterRole(address(ITO), true);


        // Step #7 --- Deploy ZivoeTranches.sol.

        ZVT = new ZivoeTranches(
            address(GBL)
        );

        // ZVT.owner() MUST transfer ownership to the DAO (it is a ZivoeLocker).
        ZVT.transferOwnershipAndLock(address(DAO));

        // "jay" MUST transfer 5% of ZVE tokens to ZVT.
        jay.transferToken(address(ZVE), address(ZVT), ZVE.totalSupply() * 5 / 100);

        // zJTT.owner() MUST give ZVT minting priviliges.
        // zSTT.owner() MUST give ZVT minting priviliges.
        zJTT.changeMinterRole(address(ZVT), true);
        zSTT.changeMinterRole(address(ZVT), true);

        // Note: At this point, zJTT / zSTT MUST not give minting priviliges to any other contract (ever).
        
        // zJTT.owner() MUST renounce ownership.
        // zSTT.owner() MUST renounce onwership.
        zJTT.renounceOwnership();
        zSTT.renounceOwnership();


        // Step #8 --- Deploy zSTT/zJTT/ZVE staking contracts, through ZivoeRewards.sol.

        stSTT = new ZivoeRewards(
            address(zSTT),
            address(GBL)
        );

        stJTT = new ZivoeRewards(
            address(zJTT),
            address(GBL)
        );

        stZVE = new ZivoeRewards(
            address(ZVE),
            address(GBL)
        );

        // Step #9 --- Deploy ZivoeYDL.sol.

        YDL = new ZivoeYDL(
            address(GBL),
            DAI
        );

        MATH = YDL.MATH();


        // Step #10 --- Deploy ZivoeRewardsVesting.sol.

        vestZVE = new ZivoeRewardsVesting(
            address(ZVE),
            address(GBL)
        );

        // "jay" MUST transfer 60% of ZVE tokens to vestZVE.
        jay.transferToken(address(ZVE), address(vestZVE), ZVE.totalSupply() * 6 / 10);
        
        // Step #11 - Update the ZivoeGlobals.sol contract.

        address[] memory _wallets = new address[](14);

        _wallets[0] = address(DAO);      // _wallets[0]  == DAO     == ZivoeDAO.sol
        _wallets[1] = address(ITO);      // _wallets[1]  == ITO     == ZivoeITO.sol
        _wallets[2] = address(stJTT);    // _wallets[2]  == stJTT   == ZivoeRewards.sol
        _wallets[3] = address(stSTT);    // _wallets[3]  == stSTT   == ZivoeRewards.sol
        _wallets[4] = address(stZVE);    // _wallets[4]  == stZVE   == ZivoeRewards.sol
        _wallets[5] = address(vestZVE);  // _wallets[5]  == vestZVE == ZivoeRewardsVesting.sol
        _wallets[6] = address(YDL);      // _wallets[6]  == YDL     == ZivoeYDL.sol
        _wallets[7] = address(zJTT);     // _wallets[7]  == zJTT    == ZivoeTranchesToken.sol
        _wallets[8] = address(zSTT);     // _wallets[8]  == zSTT    == ZivoeTranchesToken.sol
        _wallets[9] = address(ZVE);      // _wallets[9]  == ZVE     == ZivoeToken.sol
        _wallets[10] = address(zvl);     // _wallets[10] == ZVL     == address(zvl) "Multi-Sig"
        _wallets[11] = address(GOV);     // _wallets[11] == GOV     == ZivoeGovernorV2.sol
                                         // _wallets[12] == TLC     == ZivoeTLC.sol
        _wallets[12] = live ? address(TLC) : address(god);     
        _wallets[13] = address(ZVT);     // _wallets[13] == ZVT     == ZivoeTranches.sol

        // GBL.owner() MUST call initializeGlobals() with the above address array.

        address[] memory _stablesGlobals = new address[](3);
        _stablesGlobals[0] = DAI;
        _stablesGlobals[1] = USDC;
        _stablesGlobals[2] = USDT;

        GBL.initializeGlobals(_wallets, _stablesGlobals);

        // GBL.owner() SHOULD renounce ownership.
        GBL.renounceOwnership();
        
        // stSTT.owner() must add DAI and ZVE as rewardToken's with "30 days" rewardDuration's.
        // stJTT.owner() must add DAI and ZVE as rewardToken's with "30 days" rewardDuration's.
        // stZVE.owner() must add DAI and ZVE as rewardToken's with "30 days" rewardDuration's.
        hevm.startPrank(address(zvl));
        stSTT.addReward(DAI, 30 days);
        stSTT.addReward(address(ZVE), 30 days);
        stJTT.addReward(DAI, 30 days);
        stJTT.addReward(address(ZVE), 30 days);
        stZVE.addReward(DAI, 30 days);
        stZVE.addReward(address(ZVE), 30 days);
        hevm.stopPrank();

        // vestZVE.owner() MUST add DAI as a rewardToken with "30 days" for rewardsDuration.
        hevm.startPrank(address(zvl));
        vestZVE.addReward(DAI, 30 days);
        hevm.stopPrank();

        // "zvl" MUST add ZVT to the isLocker whitelist.
        assert(zvl.try_updateIsLocker(address(GBL), address(ZVT), true));

        // Note: This completes the deployment of the core-protocol and facilitates
        //       the addition of a single locker (ZVT) to the whitelist.
        //       From here, the ITO will commence in 3 days (approx.) and last for
        //       exactly 30 days. To simulate this, we use simulateITO().

        // simulateDepositsCoreUtility(1000000, 1000000);

    }

    function stakeTokensHalf() public {

        // "jim" added to Junior tranche.
        jim.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(jim)));
        jim.try_approveToken(address(ZVE),  address(stZVE), IERC20(address(ZVE)).balanceOf(address(jim)));
        jim.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(jim)) / 2);
        // jim.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(jim)) / 2);

        // "sam" added to Senior tranche.
        sam.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(sam)));
        sam.try_approveToken(address(ZVE),  address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam)));
        sam.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(sam)) / 2);
        // sam.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam)) / 2);
    }

    function stakeTokensFull() public {

        // "jim" added to Junior tranche.
        jim.try_approveToken(address(zJTT), address(stJTT), IERC20(address(zJTT)).balanceOf(address(jim)));
        jim.try_approveToken(address(ZVE),  address(stZVE), IERC20(address(ZVE)).balanceOf(address(jim)));
        jim.try_stake(address(stJTT), IERC20(address(zJTT)).balanceOf(address(jim)));
        // jim.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(jim)));

        // "sam" added to Senior tranche.
        sam.try_approveToken(address(zSTT), address(stSTT), IERC20(address(zSTT)).balanceOf(address(sam)));
        sam.try_approveToken(address(ZVE),  address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam)));
        sam.try_stake(address(stSTT), IERC20(address(zSTT)).balanceOf(address(sam)));
        // sam.try_stake(address(stZVE), IERC20(address(ZVE)).balanceOf(address(sam)));
    }


    // Simulates deposits for a junior and a senior tranche depositor.

    function simulateDepositsCoreUtility(uint256 seniorDeposit, uint256 juniorDeposit) public {

        // Warp to ITO start unix.
        hevm.warp(ITO.end() - 30 days);

        // ------------------------
        // "sam" => depositSenior()
        // ------------------------

        mint("DAI",  address(sam), seniorDeposit * 1 ether);
        mint("USDC", address(sam), seniorDeposit * USD);
        mint("USDT", address(sam), seniorDeposit * USD);

        assert(sam.try_approveToken(DAI,  address(ITO), seniorDeposit * 1 ether));
        assert(sam.try_approveToken(USDC, address(ITO), seniorDeposit * USD));
        assert(sam.try_approveToken(USDT, address(ITO), seniorDeposit * USD));

        assert(sam.try_depositSenior(address(ITO), seniorDeposit * 1 ether, address(DAI)));
        assert(sam.try_depositSenior(address(ITO), seniorDeposit * USD, address(USDC)));
        assert(sam.try_depositSenior(address(ITO), seniorDeposit * USD, address(USDT)));

        // ------------------------
        // "jim" => depositJunior()
        // ------------------------

        mint("DAI",  address(jim), seniorDeposit * 1 ether / 5);
        mint("USDC", address(jim), seniorDeposit * USD / 5);
        mint("USDT", address(jim), seniorDeposit * USD / 5);

        assert(jim.try_approveToken(DAI,  address(ITO), seniorDeposit * 1 ether / 5));
        assert(jim.try_approveToken(USDC, address(ITO), seniorDeposit * USD / 5));
        assert(jim.try_approveToken(USDT, address(ITO), seniorDeposit * USD / 5));

        assert(jim.try_depositJunior(address(ITO), seniorDeposit * 1 ether / 5, address(DAI)));
        assert(jim.try_depositJunior(address(ITO), seniorDeposit * USD / 5, address(USDC)));
        assert(jim.try_depositJunior(address(ITO), seniorDeposit * USD / 5, address(USDT)));

        // Warp to end of ITO, call migrateDeposits() to ensure ZivoeDAO.sol receives capital.
        hevm.warp(ITO.end() + 1);
        ITO.migrateDeposits();

        // Have "jim" and "sam" claim their tokens from the contract.
        jim.try_claimAirdrop(address(ITO), address(jim));
        sam.try_claimAirdrop(address(ITO), address(sam));
    }

    // Manipulate mainnet ERC20 balance
    function mint(bytes32 symbol, address account, uint256 amount) public {
        address addr = tokens[symbol].addr;
        uint256 slot  = tokens[symbol].slot;
        uint256 bal = IERC20(addr).balanceOf(account);

        hevm.store(
            addr,
            keccak256(abi.encode(account, slot)), // Mint tokens
            bytes32(bal + amount)
        );

        assertEq(IERC20(addr).balanceOf(account), bal + amount); // Assert new balance
    }

    // Verify equality within accuracy decimals
    function withinPrecision(uint256 val0, uint256 val1, uint256 accuracy) public {
        uint256 diff  = val0 > val1 ? val0 - val1 : val1 - val0;
        if (diff == 0) return;

        uint256 denominator = val0 == 0 ? val1 : val0;
        bool check = ((diff * RAY) / denominator) < (RAY / 10 ** accuracy);

        if (!check){
            emit log_named_uint("Error: approx a == b not satisfied, accuracy digits ", accuracy);
            emit log_named_uint("  Expected", val0);
            emit log_named_uint("    Actual", val1);
            fail();
        }
    }

    // Verify equality within difference
    function withinDiff(uint256 val0, uint256 val1, uint256 expectedDiff) public {
        uint256 actualDiff = val0 > val1 ? val0 - val1 : val1 - val0;
        bool check = actualDiff <= expectedDiff;

        if (!check) {
            emit log_named_uint("Error: approx a == b not satisfied, accuracy difference ", expectedDiff);
            emit log_named_uint("  Expected", val1);
            emit log_named_uint("    Actual", val0);
            fail();
        }
    }

    function constrictToRange(uint256 val, uint256 min, uint256 max) public pure returns (uint256) {
        return constrictToRange(val, min, max, false);
    }

    function constrictToRange(uint256 val, uint256 min, uint256 max, bool nonZero) public pure returns (uint256) {
        if      (val == 0 && !nonZero) return 0;
        else if (max == min)           return max;
        else                           return val % (max - min) + min;
    }
    
}
