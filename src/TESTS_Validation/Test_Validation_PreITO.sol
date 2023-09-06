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
        }

    }

    function test_Validation_PreITO_Balance() public {
        
        // ZivoeToken - 35% DAO, 65% vestZVE.
        assertEq(ZVE.totalSupply(), 25_000_000 ether);
        assertEq(ZVE.balanceOf(address(DAO)), 25_000_000 ether * 35 / 100);
        assertEq(ZVE.balanceOf(address(vestZVE)), 25_000_000 ether * 65 / 100);

        // ZivoeTrancheToken - 0 zJTT, 0 zSTT.
        assertEq(zJTT.totalSupply(), 0);
        assertEq(zJTT.totalSupply(), 0);

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
        if (MAINNET) {
            assertEq(OCC_USDC.owner(), address(DAO));
        }
        else {
            assertEq(OCC_DAI.owner(), address(DAO));
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

        // TODO: Deploy these contracts.
        // OCY_Convex_A::ZivoeLocker::OwnableLocked , owner == DAO
        // OCY_Convex_B::ZivoeLocker::OwnableLocked , owner == DAO
        // OCY_OUSD::ZivoeLocker::OwnableLocked , owner == DAO

    }

    function test_Validation_PreITO_Settings() public {

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

        if (MAINNET) {
            assertEq(GBL.ZVL(), address(0));
        }
        else {
            assertEq(GBL.ZVL(), address(gZVL));
        }

        assertEq(GBL.ZVT(), address(ZVT));
        assertEq(GBL.GOV(), address(GOV));
        assertEq(GBL.TLC(), address(TLC));
        assertEq(GBL.proposedZVL(), address(0));
        assertEq(GBL.defaults(), 0);

        // TODO: Add keepers to whitelist, document keepers, check below.
        // ZivoeGlobals keepers whitelist.

        // TODO: Add in OCYs to this check.
        // ZivoeGlobals lockers whitelist.
        assert(GBL.isLocker(address(ZVT)));
        assert(GBL.isLocker(address(OCE)));
        assert(GBL.isLocker(address(OCL)));
        assert(GBL.isLocker(address(OCR)));
        assert(GBL.isLocker(address(daoOCT)));
        assert(GBL.isLocker(address(ydlOCT)));
        assert(GBL.isLocker(address(zvlOCT)));

        if (MAINNET) {
            assert(GBL.isLocker(address(OCC_USDC)));
        }
        else {
            assert(GBL.isLocker(address(OCC_DAI)));
            assert(GBL.isLocker(address(OCC_FRAX)));
            assert(GBL.isLocker(address(OCC_USDC)));
            assert(GBL.isLocker(address(OCC_USDT)));
        }

        // ZivoeGlobals stablecoin whitelist, via initializeGlobals().
        if (MAINNET) {

        }
        else {
            // NOTE: FRAX not included
            assert(GBL.stablecoinWhitelist(address(gDAI)));
            assert(GBL.stablecoinWhitelist(address(gUSDC)));
            assert(GBL.stablecoinWhitelist(address(gUSDT)));
        }

        // ZivoeGovernorV2 initial governance settings.
        // (Governor, GovernorSettings, GovernorVotes, GovernorVotesQuorumFraction, ZivoeGTC)
        assertEq(GOV.GBL(), address(GBL));
        assertEq(GOV.name(), "ZivoeGovernorV2");

        if (MAINNET) {

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
        
        // ZivoeRewards state (x3).
        
        // ZivoeRewardsVesting state.

        // ZivoeToken state.

        // ZivoeTranches state.

        // ZivoeTrancheToken state (x2).

        // ZivoeYDL state.

        // OCC_Modular state.

        // OCE_ZVE state.
    
        // OCL_ZVE state.

        // OCR_Modular state.

        // OCT_DAO, OCT_YDL, OCT_ZVL state.

        // OCY_Convex_A, OCY_Convex_B, OCY_OUSD state.

    }

    function test_Validation_PreITO_Vesting() public {
        
        // ZivoeRewardsVesting vesting schedules (pre-ITO).

    }

}