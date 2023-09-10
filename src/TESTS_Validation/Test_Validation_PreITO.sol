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

        Branch: goerli_v3

        {
            "DAI": "0x48C8F62Ccd07Fd876a4e08b520B154a6f1Bbe02F",
            "FRAX": "0x721d91B3C03663aD72431D9D2c32Efc4Fe75AA9F",
            "USDC": "0xcEFE5BD01F9181294607ddd288B682A5338470b8",
            "USDT": "0x439D9960138fdE567e133884920217998Ba8d3f4",
            "GBL": "0xF5C206f8Da970DF1039538d207146302f2047aDA",
            "ZVE": "0xa7B5d5dF1C9aEA55ee5ccc7b49296bF42e7F439a",
            "TLC": "0x98314D44AbBa2945Bf75685cA2eC5941897095Db",
            "GOV": "0xbd7eB0AE92f7A0224c6958B594DaA4a55D5838e8",
            "DAO": "0x7eef248670F6D90A5E1798108D48BD7BC147b7aF",
            "zJTT": "0x92EF59d06C79DbEE32BD9C4F98A010416500ee0A",
            "zSTT": "0x80c6092B6A93Bad6b610b2B82d79EBeE2DACDdD8",
            "ITO": "0x34712FA2953423006B78df175fafF7cEa42Af407",
            "ZVT": "0xEA607714e5EcA4CD41Ac232266A715e1Fb75cDb6",
            "stZVE": "0x3c992e55AF28362701683B5E4243BdEbc0400a2e",
            "stJTT": "0xe3068d70b71AB87F2f4CFf4acfa528C6c4eDFC86",
            "stSTT": "0x8B4845019A99250f2BbfAAAB99F0C543687Bc5b3",
            "YDL": "0x7b5B414266274Fd2195028ABf65396Bdd9A97218",
            "vestZVE": "0x295816643023e443f0806d75b0B2236051011eDb",
            "OctYDL": "0xE2eF1bfc886BFb37ccF160a691718c3B1d189F9A",
            "OctDAO": "0xAC40A789654251d405d4Bd2956F0516Ea044eCFF",
            "OctZVL": "0x5A09A3E1c7C8aaE19333E43088eC9FDD9e7c30da",
            "OCR": "0xf2d9cba90E5D2e38436fC66DB97688bb9dd0a795",
            "OclZVE": "0xCbC19FA27FfA8D39832481e4AE4a863CF26601f8",
            "OceZVE": "0x8c96FbF9f3c39c9b96B13E54BB84AB9951592644",
            "OCC_DAI": "0xc8Bb3B6Fb84F2FcfC13C8d95C5Ffb476945eb195",
            "OCC_FRAX": "0x11CCd86071479457d9E5aA15bDA6b942fD6A0454",
            "OCC_USDC": "0xB71222A73D09556f4C86661b3a3d087bBD6A3db2",
            "OCC_USDT": "0xfAD0Ba085410412ED58829DA13e32DAD66da898a"
        }
    */

    // Flags.
    bool MAINNET = false;

    // Goerli stablecoins.
    address gDAI = 0x48C8F62Ccd07Fd876a4e08b520B154a6f1Bbe02F;
    address gFRAX = 0x721d91B3C03663aD72431D9D2c32Efc4Fe75AA9F;
    address gUSDC = 0xcEFE5BD01F9181294607ddd288B682A5338470b8;
    address gUSDT = 0x439D9960138fdE567e133884920217998Ba8d3f4;
    
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
            DAO = ZivoeDAO(0x7eef248670F6D90A5E1798108D48BD7BC147b7aF);
            GBL = ZivoeGlobals(0xF5C206f8Da970DF1039538d207146302f2047aDA);
            GOV = ZivoeGovernorV2(payable(0xbd7eB0AE92f7A0224c6958B594DaA4a55D5838e8));
            ITO = ZivoeITO(0x34712FA2953423006B78df175fafF7cEa42Af407);
            ZVE = ZivoeToken(0xa7B5d5dF1C9aEA55ee5ccc7b49296bF42e7F439a);
            ZVT = ZivoeTranches(0xEA607714e5EcA4CD41Ac232266A715e1Fb75cDb6);
            zJTT = ZivoeTrancheToken(0x92EF59d06C79DbEE32BD9C4F98A010416500ee0A);
            zSTT = ZivoeTrancheToken(0x80c6092B6A93Bad6b610b2B82d79EBeE2DACDdD8);
            YDL = ZivoeYDL(0x7b5B414266274Fd2195028ABf65396Bdd9A97218);
            TLC = ZivoeTLC(payable(0x98314D44AbBa2945Bf75685cA2eC5941897095Db));

            // Periphery
            MATH = ZivoeMath(address(YDL.MATH()));
            stJTT = ZivoeRewards(0xe3068d70b71AB87F2f4CFf4acfa528C6c4eDFC86);
            stSTT = ZivoeRewards(0x8B4845019A99250f2BbfAAAB99F0C543687Bc5b3);
            stZVE = ZivoeRewards(0x3c992e55AF28362701683B5E4243BdEbc0400a2e);
            vestZVE = ZivoeRewardsVesting(0x295816643023e443f0806d75b0B2236051011eDb);

            // Lockers
            OCC_DAI = OCC_Modular(0xc8Bb3B6Fb84F2FcfC13C8d95C5Ffb476945eb195);
            OCC_FRAX = OCC_Modular(0x11CCd86071479457d9E5aA15bDA6b942fD6A0454);
            OCC_USDC = OCC_Modular(0xB71222A73D09556f4C86661b3a3d087bBD6A3db2);
            OCC_USDT = OCC_Modular(0xfAD0Ba085410412ED58829DA13e32DAD66da898a);

            OCE = OCE_ZVE(0x8c96FbF9f3c39c9b96B13E54BB84AB9951592644);
            OCL = OCL_ZVE(0xCbC19FA27FfA8D39832481e4AE4a863CF26601f8);
            OCR = OCR_Modular(0xf2d9cba90E5D2e38436fC66DB97688bb9dd0a795);
            daoOCT = OCT_DAO(0xAC40A789654251d405d4Bd2956F0516Ea044eCFF);
            ydlOCT = OCT_YDL(0xE2eF1bfc886BFb37ccF160a691718c3B1d189F9A);
            zvlOCT = OCT_ZVL(0x5A09A3E1c7C8aaE19333E43088eC9FDD9e7c30da);
            OCY_A = OCY_Convex_A(0x7Cf87218F4d4D9A7200A7E924B429d53B6956811);
            OCY_B = OCY_Convex_B(0x4e76809435369e88dCb79F92365bbaD11686Df84);
            OCY_O = OCY_OUSD(0x8f441BFD97efc1B1896E1cb65d187A15Eb2ff7A2);
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

        assertEq(stJTT.rewardTokens(0), MAINNET ? USDC : gUSDC);
        assertEq(stJTT.rewardTokens(1), address(ZVE));
        assertEq(stSTT.rewardTokens(0), MAINNET ? USDC : gUSDC);
        assertEq(stSTT.rewardTokens(1), address(ZVE));
        assertEq(stZVE.rewardTokens(0), MAINNET ? USDC : gUSDC);
        assertEq(stZVE.rewardTokens(1), address(ZVE));

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
        assertEq(vestZVE.vestingTokenAllocated(), 0);
        
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
        assertEq(ZVT.maxTrancheRatioBIPS(), 4250);
        assertEq(ZVT.minZVEPerJTTMint(), 0);
        assertEq(ZVT.maxZVEPerJTTMint(), 0);
        assertEq(ZVT.lowerRatioIncentiveBIPS(), 1000);
        assertEq(ZVT.upperRatioIncentiveBIPS(), 2000);

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

        // TODO: Check minter roles ... 

        // ZivoeYDL state.
        assertEq(YDL.GBL(), address(GBL));
        assertEq(YDL.distributedAsset(), MAINNET ? USDC : gUSDC);
        assertEq(YDL.lastDistribution(), 0);
        assertEq(YDL.targetAPYBIPS(), 800);
        assertEq(YDL.targetRatioBIPS(), 16250);
        assertEq(YDL.protocolEarningsRateBIPS(), 2000);
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

    }

}