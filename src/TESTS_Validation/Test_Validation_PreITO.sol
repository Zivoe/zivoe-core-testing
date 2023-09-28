// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../Utility/Utility.sol";

import "../../lib/zivoe-core-foundry/src/lockers/OCC/OCC_Modular.sol";
import "../../lib/zivoe-core-foundry/src/lockers/OCE/OCE_ZVE.sol";
import "../../lib/zivoe-core-foundry/src/lockers/OCL/OCL_ZVE.sol";
import "../../lib/zivoe-core-foundry/src/lockers/OCR/OCR_Modular.sol";
import "../../lib/zivoe-core-foundry/src/lockers/OCT/OCT_DAO.sol";
import "../../lib/zivoe-core-foundry/src/lockers/OCT/OCT_YDL.sol";
import "../../lib/zivoe-core-foundry/src/lockers/OCT/OCT_ZVL.sol";
import "../../lib/zivoe-core-foundry/src/lockers/OCY/OCY_Convex_A.sol";
import "../../lib/zivoe-core-foundry/src/lockers/OCY/OCY_Convex_B.sol";
import "../../lib/zivoe-core-foundry/src/lockers/OCY/OCY_OUSD.sol";

contract Test_Validation_PreITO is Utility {

    /**

        Branch: goerli/test

        {
            "DAI": "0x2EC870eEdA64899d4a51690122eCB8fd2f49443a",
            "FRAX": "0x3a7EC61b07D503FD46D2298c2a96E1E97ba41d32",
            "USDC": "0xee5f77E6C43Ba7cC1fB14fbC53Ba8A51A96e4a31",
            "USDT": "0x0A5Ad4fD85732c885bF29710138cBe19E9bf415a",
            "GBL": "0xd88984dD7887a835F142ff4067Bf7D7d5B167931",
            "ZVE": "0xAFaf4eb0D74A478e50c4f4a2f82CA56c6F965357",
            "TLC": "0x9A74A402bC83Df050e41054Bf44d76A8e02C761E",
            "GOV": "0xaEBCD99d97A0B2958c83D15be126D6cc769024cA",
            "DAO": "0x5598Ce1617978Af594EbAD8DCFa75e7f0A486C19",
            "zJTT": "0x490A703a36315c77568DD1A44E773305a2940c3C",
            "zSTT": "0xf4FFe22f0408DdCC4521238d517FEb5F435Ab4D2",
            "ITO": "0x65fd9CA2e5C85A598141749EC6E8E78F30c494c9",
            "ZVT": "0x42882a9d01E857A30E211DdCde18aCB252CFE96c",
            "stZVE": "0x09890B4Be1523e22cc2E378AeD76c4f368eCfa18",
            "stJTT": "0xd58222f8a6b253879913cBc1862879843BcA64b6",
            "stSTT": "0x2E21Ba1Aed5515817888B4a278e4dB28066D4C8f",
            "YDL": "0x81272056Ec18ab57E98ee05F1771421Ca960161c",
            "VestZVE": "0x2Dc1A430B53Caa6b847733a01631395541D9B5A0",
            "OctYDL": "0x0602A9fa52B2f026658A1e379Dc15cFCFe9fC054",
            "OctDAO": "0x02DE00bCDe9cDa53AAe0135bb71e9cD792339DE3",
            "OctZVL": "0x6e801f0Acf00A1c4317F41A9126F98F7147Ae218",
            "OCR": "0x1958F93eD36C3B506Bb2B61B85Fb867FcF93bC60",
            "OclZVE": "0x09bE564b3c5F9c372cb0b934B6fFbE4a329e65cf",
            "OceZVE": "0xfF2A8537E9B816f681969E156650ed022315057C",
            "OCC_DAI": "0xcFb43e26205c2B0458FBda2758E7f5f26895b9b1",
            "OCC_FRAX": "0x008c0e3811A0DBe2Bc21F505f7fa53922e3106D3",
            "OCC_USDC": "0x056eFc66730961aa6262e5cc6D41535544A3e898",
            "OCC_USDT": "0x7eb1aB26EC89e791e6fba1d3e79c649a7b3977F2",
            "OCY_Convex_A": "0x66b52b4Bb1Ab4BE2f7ba6a406d553d0fC5787dee",
            "OCY_Convex_B": "0x2F25234A111E89e7f7A59bE9Fe6B462E17C69375",
            "OCY_OUSD": "0x978b2fb253883f6d8d074Eb4adCcC059fe2cdd9A"
        }

    */

    // Flags.
    bool MAINNET = false;

    // Goerli stablecoins.
    address gDAI = 0x2EC870eEdA64899d4a51690122eCB8fd2f49443a;
    address gFRAX = 0x3a7EC61b07D503FD46D2298c2a96E1E97ba41d32;
    address gUSDC = 0xee5f77E6C43Ba7cC1fB14fbC53Ba8A51A96e4a31;
    address gUSDT = 0x0A5Ad4fD85732c885bF29710138cBe19E9bf415a;
    
    // Goerli multi-signature SAFEs.
    address gZVL = 0xC7894D17340D2167fF5CF18d1E90f09F2f9e401e;
    address gCANCEL = 0x6050dE8AAb0f657c7164fa9a751e839FC64aeF5C;
    address gLENDER = 0xce7a64C508bdB47Df1846D1cD4334f865E80b87b;
    address gBORROW = 0xF067D8197BEA22f06662BCb61b231Cd4EEF3F256;

    address mZVL = 0xC7894D17340D2167fF5CF18d1E90f09F2f9e401e;
    address mCANCEL = 0x6050dE8AAb0f657c7164fa9a751e839FC64aeF5C;
    address mLENDER = 0xce7a64C508bdB47Df1846D1cD4334f865E80b87b;
    address mBORROW = 0xF067D8197BEA22f06662BCb61b231Cd4EEF3F256;

    // Holders.
    OCC_Modular OCC_DAI;
    OCC_Modular OCC_FRAX;
    OCC_Modular OCC_USDC;
    OCC_Modular OCC_USDT;

    OCE_ZVE OCE;
    OCL_ZVE OCL;
    OCR_Modular OCR;
    OCT_DAO daoOCT;
    OCT_YDL ydlOCT;
    OCT_ZVL zvlOCT;
    OCY_Convex_A OCY_A;
    OCY_Convex_B OCY_B;
    OCY_OUSD OCY_O;

    function setUp() public {
        
        if (MAINNET) {

        }
        else {
            // Core
            DAO = ZivoeDAO(0x5598Ce1617978Af594EbAD8DCFa75e7f0A486C19);
            GBL = ZivoeGlobals(0xd88984dD7887a835F142ff4067Bf7D7d5B167931);
            GOV = ZivoeGovernorV2(payable(0xaEBCD99d97A0B2958c83D15be126D6cc769024cA));
            ITO = ZivoeITO(0x65fd9CA2e5C85A598141749EC6E8E78F30c494c9);
            ZVE = ZivoeToken(0xAFaf4eb0D74A478e50c4f4a2f82CA56c6F965357);
            ZVT = ZivoeTranches(0x42882a9d01E857A30E211DdCde18aCB252CFE96c);
            zJTT = ZivoeTrancheToken(0x490A703a36315c77568DD1A44E773305a2940c3C);
            zSTT = ZivoeTrancheToken(0xf4FFe22f0408DdCC4521238d517FEb5F435Ab4D2);
            YDL = ZivoeYDL(0x81272056Ec18ab57E98ee05F1771421Ca960161c);
            TLC = ZivoeTLC(payable(0x9A74A402bC83Df050e41054Bf44d76A8e02C761E));

            // Periphery
            MATH = ZivoeMath(address(YDL.MATH()));
            stJTT = ZivoeRewards(0xd58222f8a6b253879913cBc1862879843BcA64b6);
            stSTT = ZivoeRewards(0x2E21Ba1Aed5515817888B4a278e4dB28066D4C8f);
            stZVE = ZivoeRewards(0x09890B4Be1523e22cc2E378AeD76c4f368eCfa18);
            vestZVE = ZivoeRewardsVesting(0x2Dc1A430B53Caa6b847733a01631395541D9B5A0);

            // Lockers
            OCC_DAI = OCC_Modular(0xcFb43e26205c2B0458FBda2758E7f5f26895b9b1);
            OCC_FRAX = OCC_Modular(0x008c0e3811A0DBe2Bc21F505f7fa53922e3106D3);
            OCC_USDC = OCC_Modular(0x056eFc66730961aa6262e5cc6D41535544A3e898);
            OCC_USDT = OCC_Modular(0x7eb1aB26EC89e791e6fba1d3e79c649a7b3977F2);

            OCE = OCE_ZVE(0xfF2A8537E9B816f681969E156650ed022315057C);
            OCL = OCL_ZVE(0x09bE564b3c5F9c372cb0b934B6fFbE4a329e65cf);
            OCR = OCR_Modular(0x1958F93eD36C3B506Bb2B61B85Fb867FcF93bC60);
            daoOCT = OCT_DAO(0x02DE00bCDe9cDa53AAe0135bb71e9cD792339DE3);
            ydlOCT = OCT_YDL(0x0602A9fa52B2f026658A1e379Dc15cFCFe9fC054);
            zvlOCT = OCT_ZVL(0x6e801f0Acf00A1c4317F41A9126F98F7147Ae218);
            OCY_A = OCY_Convex_A(0x66b52b4Bb1Ab4BE2f7ba6a406d553d0fC5787dee);
            OCY_B = OCY_Convex_B(0x2F25234A111E89e7f7A59bE9Fe6B462E17C69375);
            OCY_O = OCY_OUSD(0x978b2fb253883f6d8d074Eb4adCcC059fe2cdd9A);
        }

    }

    function test_Validation_PreITO_Balance() public {
        
        // ZivoeToken - 35% DAO, 65% vestZVE.
        assertEq(ZVE.totalSupply(), 25_000_000 ether);
        assertEq(ZVE.balanceOf(address(DAO)), 25_000_000 ether * 35 / 100);
        assertEq(ZVE.balanceOf(address(vestZVE)), 25_000_000 ether * 65 / 100);

        // ZivoeTrancheToken - 0 zJTT, 0 zSTT.
        assertEq(zJTT.totalSupply(), 0);
        assertEq(zSTT.totalSupply(), 0);

        // ZivoeRewards - 0 stJTT, 0 stSTT, 0 stZVE.
        assertEq(stJTT.totalSupply(), 0);
        assertEq(stSTT.totalSupply(), 0);
        assertEq(stZVE.totalSupply(), 0);

        // TODO: Basecase assumption gathering.
        // ZivoeRewardsVesting (token balances, assuming unclaimed vesting).

    }

    function test_Validation_PreITO_Ownership() public {
        
        // ZivoeGovernorV2 - No ownership.
        // ZivoeITO - No ownership.
        // ZivoeLocker - No ownership (abstract).
        // ZivoeMath - No ownership.
        // ZivoeRewards - No onwership.
        // ZivoeRewardsVesting - No ownership.
        // ZivoeToken - No ownership.
        // ZivoeYDL - No ownership.

        // ZivoeDAO::OwnableLocked , owner == TLC
        assertEq(DAO.owner(), address(TLC));

        // ZivoeGlobals::Ownable , ownership renounced , owner == address(0)
        assertEq(GBL.owner(), address(0));

        // ZivoeTranches::ZivoeLocker::OwnableLocked , owner == DAO
        assertEq(ZVT.owner(), address(DAO));

        // ZivoeTrancheToken::Ownable , ownership renounced , owner == address(0) , x2 (zJTT, zSTT)
        assertEq(zJTT.owner(), address(0));
        assertEq(zSTT.owner(), address(0));

        // OCC_Modular::ZivoeLocker::OwnableLocked , owner == DAO , x1 (OCC_USDC)
        assertEq(OCC_USDC.owner(), address(DAO));

        if (!MAINNET) {
            assertEq(OCC_FRAX.owner(), address(DAO));
            assertEq(OCC_USDT.owner(), address(DAO));
            assertEq(OCC_USDC.owner(), address(DAO));
        }

        // OCE_ZVE::ZivoeLocker::OwnableLocked , owner == DAO
        assertEq(OCE.owner(), address(DAO));

        // OCL_ZVE::ZivoeLocker::OwnableLocked , owner == DAO
        assertEq(OCL.owner(), address(DAO));

        // OCR_Modular::ZivoeLocker::OwnableLocked , owner == DAO
        assertEq(OCR.owner(), address(DAO));

        // OCT_DAO::ZivoeLocker::OwnableLocked , owner == DAO
        assertEq(daoOCT.owner(), address(DAO));

        // OCT_YDL::ZivoeLocker::OwnableLocked , owner == DAO
        assertEq(ydlOCT.owner(), address(DAO));

        // OCT_ZVL::ZivoeLocker::OwnableLocked , owner == DAO
        assertEq(zvlOCT.owner(), address(DAO));

        // OCY_Convex_A::ZivoeLocker::OwnableLocked , owner == DAO
        assertEq(OCY_A.owner(), address(DAO));

        // OCY_Convex_B::ZivoeLocker::OwnableLocked , owner == DAO
        assertEq(OCY_B.owner(), address(DAO));

        // OCY_OUSD::ZivoeLocker::OwnableLocked , owner == DAO
        assertEq(OCY_O.owner(), address(DAO));

    }

    function test_Validation_PreITO_Core_Settings() public {

        // ZivoeDAO state.
        assertEq(DAO.GBL(), address(GBL));

        // ZivoeGlobals state, via initializeGlobals().
        assertEq(GBL.DAO(), address(DAO));
        assertEq(GBL.ITO(), address(ITO));
        assertEq(GBL.stJTT(), address(stJTT));
        assertEq(GBL.stSTT(), address(stSTT));
        assertEq(GBL.stZVE(), address(stZVE));
        assertEq(GBL.vestZVE(), address(vestZVE));
        assertEq(GBL.YDL(), address(YDL));
        assertEq(GBL.zJTT(), address(zJTT));
        assertEq(GBL.zSTT(), address(zSTT));
        assertEq(GBL.ZVE(), address(ZVE));
        assertEq(GBL.ZVL(), MAINNET ? mZVL : gZVL);
        assertEq(GBL.ZVT(), address(ZVT));
        assertEq(GBL.GOV(), address(GOV));
        assertEq(GBL.TLC(), address(TLC));
        assertEq(GBL.proposedZVL(), address(0));
        assertEq(GBL.defaults(), 0);
        
        // ZivoeGlobals keepers whitelist.
        if (!MAINNET) {
            assert(GBL.isKeeper(0x2a600051745a9c6dF749224C3b49f3d1571A075F));
        }

        // ZivoeGlobals lockers whitelist.
        assert(GBL.isLocker(address(ZVT)));
        assert(GBL.isLocker(address(OCE)));
        assert(GBL.isLocker(address(OCL)));
        assert(GBL.isLocker(address(OCR)));
        assert(GBL.isLocker(address(daoOCT)));
        assert(GBL.isLocker(address(ydlOCT)));
        assert(GBL.isLocker(address(zvlOCT)));
        assert(GBL.isLocker(address(OCY_A)));
        assert(GBL.isLocker(address(OCY_B)));
        assert(GBL.isLocker(address(OCY_O)));
        assert(GBL.isLocker(address(OCC_USDC)));

        if (!MAINNET) {
            assert(GBL.isLocker(address(OCC_DAI)));
            assert(GBL.isLocker(address(OCC_FRAX)));
            assert(GBL.isLocker(address(OCC_USDT)));
        }

        // ZivoeGlobals stablecoin whitelist, via initializeGlobals().
        assert(MAINNET ? GBL.stablecoinWhitelist(DAI) : GBL.stablecoinWhitelist(gDAI));
        assert(MAINNET ? GBL.stablecoinWhitelist(USDC) : GBL.stablecoinWhitelist(gUSDC));
        assert(MAINNET ? GBL.stablecoinWhitelist(USDT) : GBL.stablecoinWhitelist(gUSDT));

        // ZivoeGovernorV2 initial governance settings.
        // (Governor, GovernorSettings, GovernorVotes, GovernorVotesQuorumFraction, ZivoeGTC)
        assertEq(GOV.GBL(), address(GBL));
        assertEq(GOV.name(), "ZivoeGovernorV2");

        if (MAINNET) {
            // TODO: Determine mainnet settings.
        }
        else {
            assertEq(GOV.votingDelay(), 1);
            assertEq(GOV.votingPeriod(), 100);
            assertEq(GOV.proposalThreshold(), 50_000 ether);
            assertEq(address(GOV.token()), address(ZVE));
            assertEq(GOV.quorumNumerator(), 5);
            assertEq(GOV.timelock(), address(TLC));
        }

        // ZivoeITO state.
        assertEq(ITO.GBL(), address(GBL));
        assertEq(ITO.end(), 0);
        assert(!ITO.migrated());

        assertEq(ITO.stables(0), MAINNET ? DAI : gDAI);
        assertEq(ITO.stables(1), MAINNET ? FRAX : gFRAX);
        assertEq(ITO.stables(2), MAINNET ? USDC : gUSDC);
        assertEq(ITO.stables(3), MAINNET ? USDT : gUSDT);
        
        // ZivoeRewards state (x3).
        assertEq(stJTT.GBL(), address(GBL));
        assertEq(stSTT.GBL(), address(GBL));
        assertEq(stZVE.GBL(), address(GBL));

        assertEq(stJTT.rewardTokens(0), address(ZVE));
        assertEq(stJTT.rewardTokens(1), MAINNET ? USDC : gUSDC);
        assertEq(stSTT.rewardTokens(0), address(ZVE));
        assertEq(stSTT.rewardTokens(1), MAINNET ? USDC : gUSDC);
        assertEq(stZVE.rewardTokens(0), address(ZVE));
        assertEq(stZVE.rewardTokens(1), MAINNET ? USDC : gUSDC);

        (
            uint256 rewardsDuration, 
            uint256 periodFinish, 
            uint256 rewardRate, 
            uint256 lastUpdateTime, 
            uint256 rewardPerTokenStored
        ) = stJTT.rewardData(MAINNET ? USDC : gUSDC);

        assertEq(rewardsDuration, MAINNET ? 30 days : 7 days);
        assertEq(periodFinish, 0);
        assertEq(rewardRate, 0);
        assertEq(lastUpdateTime, 0);
        assertEq(rewardPerTokenStored, 0);

        (
            rewardsDuration, 
            periodFinish, 
            rewardRate, 
            lastUpdateTime, 
            rewardPerTokenStored
        ) = stJTT.rewardData(address(ZVE));

        assertEq(rewardsDuration, MAINNET ? 30 days : 7 days);
        assertEq(periodFinish, 0);
        assertEq(rewardRate, 0);
        assertEq(lastUpdateTime, 0);
        assertEq(rewardPerTokenStored, 0);

        (
            rewardsDuration, 
            periodFinish, 
            rewardRate, 
            lastUpdateTime, 
            rewardPerTokenStored
        ) = stSTT.rewardData(MAINNET ? USDC : gUSDC);

        assertEq(rewardsDuration, MAINNET ? 30 days : 7 days);
        assertEq(periodFinish, 0);
        assertEq(rewardRate, 0);
        assertEq(lastUpdateTime, 0);
        assertEq(rewardPerTokenStored, 0);

        (
            rewardsDuration, 
            periodFinish, 
            rewardRate, 
            lastUpdateTime, 
            rewardPerTokenStored
        ) = stSTT.rewardData(address(ZVE));

        assertEq(rewardsDuration, MAINNET ? 30 days : 7 days);
        assertEq(periodFinish, 0);
        assertEq(rewardRate, 0);
        assertEq(lastUpdateTime, 0);
        assertEq(rewardPerTokenStored, 0);

        (
            rewardsDuration, 
            periodFinish, 
            rewardRate, 
            lastUpdateTime, 
            rewardPerTokenStored
        ) = stZVE.rewardData(MAINNET ? USDC : gUSDC);

        assertEq(rewardsDuration, MAINNET ? 30 days : 7 days);
        assertEq(periodFinish, 0);
        assertEq(rewardRate, 0);
        assertEq(lastUpdateTime, 0);
        assertEq(rewardPerTokenStored, 0);

        (
            rewardsDuration, 
            periodFinish, 
            rewardRate, 
            lastUpdateTime, 
            rewardPerTokenStored
        ) = stZVE.rewardData(address(ZVE));

        assertEq(rewardsDuration, MAINNET ? 30 days : 7 days);
        assertEq(periodFinish, 0);
        assertEq(rewardRate, 0);
        assertEq(lastUpdateTime, 0);
        assertEq(rewardPerTokenStored, 0);

        assertEq(address(stJTT.stakingToken()), address(zJTT));
        assertEq(address(stSTT.stakingToken()), address(zSTT));
        assertEq(address(stZVE.stakingToken()), address(ZVE));

        // ZivoeRewardsVesting state.
        assertEq(vestZVE.GBL(), address(GBL));

        assertEq(vestZVE.vestingToken(), address(ZVE));
        assertEq(vestZVE.rewardTokens(0), MAINNET ? USDC : gUSDC);

        // TODO Determine amount vesting in LIVE/TEST
        // assertEq(vestZVE.vestingTokenAllocated(), 0);
        
        (
            rewardsDuration, 
            periodFinish, 
            rewardRate, 
            lastUpdateTime, 
            rewardPerTokenStored
        ) = vestZVE.rewardData(MAINNET ? USDC : gUSDC);

        assertEq(rewardsDuration, MAINNET ? 30 days : 7 days);
        assertEq(periodFinish, 0);
        assertEq(rewardRate, 0);
        assertEq(lastUpdateTime, 0);
        assertEq(rewardPerTokenStored, 0);

        assertEq(address(vestZVE.stakingToken()), address(ZVE));

        // ZivoeToken state.
        assertEq(ZVE.name(), "Zivoe");
        assertEq(ZVE.symbol(), "ZVE");
        assertEq(ZVE.decimals(), 18);

        // ZivoeTranches state.
        assertEq(ZVT.GBL(), address(GBL));
        assertEq(ZVT.maxTrancheRatioBIPS(), 4500);
        assertEq(ZVT.minZVEPerJTTMint(), 0);
        assertEq(ZVT.maxZVEPerJTTMint(), 0);
        assertEq(ZVT.lowerRatioIncentiveBIPS(), 1000);
        assertEq(ZVT.upperRatioIncentiveBIPS(), 3500);

        assert(!ZVT.tranchesUnlocked());
        assert(!ZVT.paused());
        assert(ZVT.canPush());
        assert(ZVT.canPull());
        assert(ZVT.canPullPartial());

        // ZivoeTrancheToken state (x2).
        assertEq(zJTT.name(), "Zivoe Junior Tranche");
        assertEq(zJTT.symbol(), "zJTT");
        assertEq(zJTT.decimals(), 18);

        assertEq(zSTT.name(), "Zivoe Senior Tranche");
        assertEq(zSTT.symbol(), "zSTT");
        assertEq(zSTT.decimals(), 18);

        assert(zJTT.isMinter(address(ITO)));
        assert(zSTT.isMinter(address(ITO)));

        assert(zJTT.isMinter(address(ZVT)));
        assert(zSTT.isMinter(address(ZVT)));

        // ZivoeYDL state.
        assertEq(YDL.GBL(), address(GBL));
        assertEq(YDL.distributedAsset(), MAINNET ? USDC : gUSDC);
        assertEq(YDL.lastDistribution(), 0);
        assertEq(YDL.targetAPYBIPS(), 800);
        assertEq(YDL.targetRatioBIPS(), 18750);
        assertEq(YDL.protocolEarningsRateBIPS(), 3000);
        assertEq(YDL.daysBetweenDistributions(), MAINNET ? 30 : 7);
        assertEq(YDL.retrospectiveDistributions(), 6);

        assert(!YDL.unlocked());

        // NOTE: This is post-ITO expected state commented out below.
        // (
        //     address[] memory protocolRecipients,
        //     uint256[] memory protocolProportion,
        //     address[] memory residualRecipients,
        //     uint256[] memory residualProportion
        // ) = YDL.viewDistributions();

        // assertEq(protocolRecipients[0], address(stZVE));
        // assertEq(protocolRecipients[1], address(DAO));

        // assertEq(protocolProportion[0], 7500);
        // assertEq(protocolProportion[1], 2500);

        // assertEq(residualRecipients[0], address(stJTT));
        // assertEq(residualRecipients[1], address(stSTT));
        // assertEq(residualRecipients[2], address(stZVE));
        // assertEq(residualRecipients[3], address(DAO));

        // assertEq(residualProportion[0], 2500);
        // assertEq(residualProportion[1], 500);
        // assertEq(residualProportion[2], 4500);
        // assertEq(residualProportion[3], 2500);

    }


    function test_Validation_PreITO_Lockers_Settings() public {

        // OCC_Modular state.
        assertEq(OCC_USDC.GBL(), address(GBL));
        assertEq(OCC_USDC.stablecoin(), MAINNET ? USDC : gUSDC);
        assertEq(OCC_USDC.underwriter(), MAINNET ? mLENDER : gLENDER);
        assertEq(OCC_USDC.OCT_YDL(), address(ydlOCT));
        assertEq(OCC_USDC.combineCounter(), 0);
        assertEq(OCC_USDC.loanCounter(), 0);

        assert(OCC_USDC.canPush());
        assert(OCC_USDC.canPull());
        assert(OCC_USDC.canPullPartial());

        if (!MAINNET) {
            assertEq(OCC_DAI.GBL(), address(GBL));
            assertEq(OCC_DAI.stablecoin(), MAINNET ? DAI : gDAI);
            assertEq(OCC_DAI.underwriter(), MAINNET ? mLENDER : gLENDER);
            assertEq(OCC_DAI.OCT_YDL(), address(ydlOCT));
            assertEq(OCC_DAI.combineCounter(), 0);
            assertEq(OCC_DAI.loanCounter(), 0);

            assert(OCC_DAI.canPush());
            assert(OCC_DAI.canPull());
            assert(OCC_DAI.canPullPartial());

            assertEq(OCC_FRAX.GBL(), address(GBL));
            assertEq(OCC_FRAX.stablecoin(), MAINNET ? FRAX : gFRAX);
            assertEq(OCC_FRAX.underwriter(), MAINNET ? mLENDER : gLENDER);
            assertEq(OCC_FRAX.OCT_YDL(), address(ydlOCT));
            assertEq(OCC_FRAX.combineCounter(), 0);
            assertEq(OCC_FRAX.loanCounter(), 0);

            assert(OCC_FRAX.canPush());
            assert(OCC_FRAX.canPull());
            assert(OCC_FRAX.canPullPartial());

            assertEq(OCC_USDT.GBL(), address(GBL));
            assertEq(OCC_USDT.stablecoin(), MAINNET ? USDT : gUSDT);
            assertEq(OCC_USDT.underwriter(), MAINNET ? mLENDER : gLENDER);
            assertEq(OCC_USDT.OCT_YDL(), address(ydlOCT));
            assertEq(OCC_USDT.combineCounter(), 0);
            assertEq(OCC_USDT.loanCounter(), 0);

            assert(OCC_USDT.canPush());
            assert(OCC_USDT.canPull());
            assert(OCC_USDT.canPullPartial());
        }

        // OCE_ZVE state.
        assertEq(OCE.GBL(), address(GBL));
        assertEq(OCE.exponentialDecayPerSecond(), RAY * 99999999 / 100000000);

        assert(OCE.lastDistribution() > 0);
        assert(OCE.canPush());
        assert(OCE.canPull());
        assert(OCE.canPullPartial());
    
        // OCL_ZVE state.
        assertEq(OCL.GBL(), address(GBL));
        assertEq(OCL.factory(), UNISWAP_V2_FACTORY);
        assertEq(OCL.pairAsset(), MAINNET ? USDC : gUSDC);
        assertEq(OCL.router(), UNISWAP_V2_ROUTER_02);
        assertEq(OCL.OCT_YDL(), address(ydlOCT));
        assertEq(OCL.basis(), 0);
        assertEq(OCL.compoundingRateBIPS(), 5000);
        assertEq(OCL.nextYieldDistribution(), 0);

        assert(OCL.canPushMulti());
        assert(OCL.canPull());
        assert(OCL.canPullPartial());

        // OCR_Modular state.
        assertEq(OCR.stablecoin(), MAINNET ? USDC : gUSDC);
        assertEq(OCR.GBL(), address(GBL));
        assertEq(OCR.epochDiscountJunior(), 0);
        assertEq(OCR.epochDiscountSenior(), 0);
        assertEq(OCR.redemptionsFeeBIPS(), 200);
        assertEq(OCR.redemptionsAllowedJunior(), 0);
        assertEq(OCR.redemptionsAllowedSenior(), 0);
        assertEq(OCR.redemptionsQueuedJunior(), 0);
        assertEq(OCR.redemptionsQueuedSenior(), 0);
        assertEq(OCR.requestCounter(), 0);

        assert(OCR.epoch() > 0);
        assert(OCR.canPush());
        assert(OCR.canPull());
        assert(OCR.canPullPartial());

        // OCT_DAO, OCT_YDL, OCT_ZVL state.
        assertEq(daoOCT.GBL(), address(GBL));
        assertEq(ydlOCT.GBL(), address(GBL));
        assertEq(zvlOCT.GBL(), address(GBL));

        assert(daoOCT.canPush());
        assert(daoOCT.canPushMulti());
        assert(daoOCT.canPull());
        assert(daoOCT.canPullMulti());
        assert(daoOCT.canPullPartial());
        assert(daoOCT.canPullMultiPartial());

        assert(ydlOCT.canPull());
        assert(ydlOCT.canPullMulti());
        assert(ydlOCT.canPullPartial());
        assert(ydlOCT.canPullMultiPartial());

        assert(zvlOCT.canPush());
        assert(zvlOCT.canPushMulti());
        assert(zvlOCT.canPull());
        assert(zvlOCT.canPullMulti());
        assert(zvlOCT.canPullPartial());
        assert(zvlOCT.canPullMultiPartial());

        // OCY_Convex_A, OCY_Convex_B, OCY_OUSD state.
        assertEq(OCY_A.GBL(), address(GBL));
        assertEq(OCY_A.OCT_YDL(), address(ydlOCT));
        assertEq(OCY_A.FRAX(), 0x853d955aCEf822Db058eb8505911ED77F175b99e);
        assertEq(OCY_A.USDC(), 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        assertEq(OCY_A.alUSD(), 0xBC6DA0FE9aD5f3b0d58160288917AA56653660E9);
        assertEq(OCY_A.CRV(), 0xD533a949740bb3306d119CC777fa900bA034cd52);
        assertEq(OCY_A.CVX(), 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);

        assertEq(OCY_A.convexDeposit(), 0xF403C135812408BFbE8713b5A23a04b3D48AAE31);
        assertEq(OCY_A.convexRewards(), 0x26598e3E511ADFadefD70ab2C3475Ff741741104);
        assertEq(OCY_A.convexPoolToken(), 0xB30dA2376F63De30b42dC055C93fa474F31330A5);
        assertEq(OCY_A.convexPoolID(), 106);
        assertEq(OCY_A.curveBasePool(), 0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2);
        assertEq(OCY_A.curveBasePoolToken(), 0x3175Df0976dFA876431C2E9eE6Bc45b65d3473CC);
        assertEq(OCY_A.curveMetaPool(), 0xB30dA2376F63De30b42dC055C93fa474F31330A5);

        assert(OCY_A.canPush());
        assert(OCY_A.canPull());
        assert(OCY_A.canPullPartial());

        assertEq(OCY_B.GBL(), address(GBL));
        assertEq(OCY_B.OCT_YDL(), address(ydlOCT));
        assertEq(OCY_B.DAI(), 0x6B175474E89094C44Da98b954EedeAC495271d0F);
        assertEq(OCY_B.USDC(), 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        assertEq(OCY_B.USDT(), 0xdAC17F958D2ee523a2206206994597C13D831ec7);
        assertEq(OCY_B.sUSD(), 0x57Ab1ec28D129707052df4dF418D58a2D46d5f51);
        assertEq(OCY_B.CRV(), 0xD533a949740bb3306d119CC777fa900bA034cd52);
        assertEq(OCY_B.CVX(), 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);

        assertEq(OCY_B.convexDeposit(), 0xF403C135812408BFbE8713b5A23a04b3D48AAE31);
        assertEq(OCY_B.convexPoolToken(), 0xC25a3A3b969415c80451098fa907EC722572917F);
        assertEq(OCY_B.convexRewards(), 0x22eE18aca7F3Ee920D01F25dA85840D12d98E8Ca);
        assertEq(OCY_B.convexPoolID(), 4);
        assertEq(OCY_B.curveBasePool(), 0xA5407eAE9Ba41422680e2e00537571bcC53efBfD);
        assertEq(OCY_B.curveBasePoolToken(), 0xC25a3A3b969415c80451098fa907EC722572917F);

        assert(OCY_B.canPush());
        assert(OCY_B.canPull());
        assert(OCY_B.canPullPartial());

        assertEq(OCY_O.OUSD(), 0x2A8e1E676Ec238d8A992307B495b45B3fEAa5e86);
        assertEq(OCY_O.GBL(), address(GBL));
        assertEq(OCY_O.OCT_YDL(), address(ydlOCT));
        assertEq(OCY_O.basis(), 0);

        assert(OCY_O.canPush());
        assert(OCY_O.canPull());
        assert(OCY_O.canPullPartial());

    }

    function test_Validation_PreITO_Vesting() public {
        
        // ZivoeRewardsVesting vesting schedules (pre-ITO).

        // 0x01 1200
        // 0x02 750
        // 0x03 750
        // 0x04 400
        // 0x05 300
        // 0x06 200
        // 0x07 100
        // 0x08 100
        // 0x09 62.5
        // 0x10 50
        // 0x11 25
        // 0x12 15
        // 0x13 12.5

        (
            uint256 start,
            uint256 cliff,
            uint256 end,
            uint256 totalVesting,
            uint256 totalWithdrawn,
            uint256 vestingPerSecond,
            bool revokable
        ) = vestZVE.viewSchedule(address(0x01));

        assertEq(totalVesting, ZVE.totalSupply() * 1200 / 10000);

        (
            start,
            cliff,
            end,
            totalVesting,
            totalWithdrawn,
            vestingPerSecond,
            revokable
        ) = vestZVE.viewSchedule(address(0x02));

        assertEq(totalVesting, ZVE.totalSupply() * 750 / 10000);

        (
            start,
            cliff,
            end,
            totalVesting,
            totalWithdrawn,
            vestingPerSecond,
            revokable
        ) = vestZVE.viewSchedule(address(0x03));

        assertEq(totalVesting, ZVE.totalSupply() * 750 / 10000);

        (
            start,
            cliff,
            end,
            totalVesting,
            totalWithdrawn,
            vestingPerSecond,
            revokable
        ) = vestZVE.viewSchedule(address(0x04));

        assertEq(totalVesting, ZVE.totalSupply() * 400 / 10000);

        (
            start,
            cliff,
            end,
            totalVesting,
            totalWithdrawn,
            vestingPerSecond,
            revokable
        ) = vestZVE.viewSchedule(address(0x05));

        assertEq(totalVesting, ZVE.totalSupply() * 300 / 10000);

        (
            start,
            cliff,
            end,
            totalVesting,
            totalWithdrawn,
            vestingPerSecond,
            revokable
        ) = vestZVE.viewSchedule(address(0x06));

        assertEq(totalVesting, ZVE.totalSupply() * 200 / 10000);

        (
            start,
            cliff,
            end,
            totalVesting,
            totalWithdrawn,
            vestingPerSecond,
            revokable
        ) = vestZVE.viewSchedule(address(0x07));

        assertEq(totalVesting, ZVE.totalSupply() * 100 / 10000);

        (
            start,
            cliff,
            end,
            totalVesting,
            totalWithdrawn,
            vestingPerSecond,
            revokable
        ) = vestZVE.viewSchedule(address(0x08));

        assertEq(totalVesting, ZVE.totalSupply() * 100 / 10000);

        (
            start,
            cliff,
            end,
            totalVesting,
            totalWithdrawn,
            vestingPerSecond,
            revokable
        ) = vestZVE.viewSchedule(address(0x09));

        assertEq(totalVesting, ZVE.totalSupply() * 625 / 100000);

        (
            start,
            cliff,
            end,
            totalVesting,
            totalWithdrawn,
            vestingPerSecond,
            revokable
        ) = vestZVE.viewSchedule(address(0x10));

        assertEq(totalVesting, ZVE.totalSupply() * 50 / 10000);

        (
            start,
            cliff,
            end,
            totalVesting,
            totalWithdrawn,
            vestingPerSecond,
            revokable
        ) = vestZVE.viewSchedule(address(0x11));

        assertEq(totalVesting, ZVE.totalSupply() * 25 / 10000);

        (
            start,
            cliff,
            end,
            totalVesting,
            totalWithdrawn,
            vestingPerSecond,
            revokable
        ) = vestZVE.viewSchedule(address(0x12));

        assertEq(totalVesting, ZVE.totalSupply() * 15 / 10000);

        (
            start,
            cliff,
            end,
            totalVesting,
            totalWithdrawn,
            vestingPerSecond,
            revokable
        ) = vestZVE.viewSchedule(address(0x13));

        assertEq(totalVesting, ZVE.totalSupply() * 125 / 100000);

        


    }

}