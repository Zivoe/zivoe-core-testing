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

contract Test_Validation_Live is Utility {

    /**
        {
            "DAI": "0x48C8F62Ccd07Fd876a4e08b520B154a6f1Bbe02F",
            "FRAX": "0x721d91B3C03663aD72431D9D2c32Efc4Fe75AA9F",
            "USDC": "0xcEFE5BD01F9181294607ddd288B682A5338470b8",
            "USDT": "0x439D9960138fdE567e133884920217998Ba8d3f4",
            "GBL": "0xA79906743d1A7b8E45B143dacD76b616f7d568d1",
            "ZVE": "0xc8D9C4c1277A7f46BB2C98Bd59fbC7A4a9c8fA04",
            "TLC": "0xE27dA5e2d68fE7d15F9A87c574520326aD7f6765",
            "GOV": "0xa2B85a4A6c7B7688cDB1aE0905Cd02F2587CB64e",
            "DAO": "0xdB3768C06E3a9977B1E80A24EFBB4705d57080E6",
            "zJTT": "0x7461df25620d861710e85eD8497535a619343DAd",
            "zSTT": "0xac5438191fb884610819CD708942e61A6FB3baEa",
            "ITO": "0x8DFBA952296Ab97e8Df57d44e9DA0C1194375f65",
            "ZVT": "0x9970A2eE06fEDd398aef2efD8D99497B9A8792BE",
            "stZVE": "0x48230506d00310aE3674B876Cfed4fa0b10dff34",
            "stJTT": "0x4D902c165dc69E144819b115eE1dCA6Ef36eB3De",
            "stSTT": "0x8A16b214D76Bd3EFF7194572855d7d9e6960655f",
            "YDL": "0xF78eC7f4E756099575aF53Abd238c67b7B478fd4",
            "vestZVE": "0x3851da7Aa69e29AE2189AD566498325ec396669a",
            "OctYDL": "0xc72F2ec12825Cf593acD06eFcACF09BeAAE00090",
            "OctDAO": "0x1819a301565F823270503e47D923859BF69C1362",
            "OctZVL": "0x32E02877cCd4926E8EB4afec22EA58c584425E49",
            "OCR": "0x25cbaDEd5673c0Cf7F3459F28755894a2B2d4425",
            "OclZVE": "0x310e0Cb6e42B215AF7BcFe33Dcbcd2855DD703c8",
            "OCC_DAI": "0xD45ABc444989B851f3a54A3d572f1675D184Fb7B",
            "OCC_FRAX": "0x61008A55738F1E44Dc9A0375Cce1C4ff66159e7D",
            "OCC_USDC": "0x47476770Fc77A2B4e3DA114B322e3aedbbC6EB58",
            "OCC_USDT": "0xB4D31C9a7bB8651d05386061E3f5877fe858C4bF"
        }
    */

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

    function setUp() public {
        
        // Core
        DAO = ZivoeDAO(0xdB3768C06E3a9977B1E80A24EFBB4705d57080E6);
        GBL = ZivoeGlobals(0xA79906743d1A7b8E45B143dacD76b616f7d568d1);
        GOV = ZivoeGovernorV2(0xa2B85a4A6c7B7688cDB1aE0905Cd02F2587CB64e);
        ITO = ZivoeITO(0x8DFBA952296Ab97e8Df57d44e9DA0C1194375f65);
        ZVE = ZivoeToken(0xc8D9C4c1277A7f46BB2C98Bd59fbC7A4a9c8fA04);
        ZVT = ZivoeTranches(0x9970A2eE06fEDd398aef2efD8D99497B9A8792BE);
        zSTT = ZivoeTrancheToken(0xac5438191fb884610819CD708942e61A6FB3baEa);
        zJTT = ZivoeTrancheToken(0x7461df25620d861710e85eD8497535a619343DAd);
        YDL = ZivoeYDL(0xF78eC7f4E756099575aF53Abd238c67b7B478fd4);
        TLC = ZivoeTLC(0xE27dA5e2d68fE7d15F9A87c574520326aD7f6765);

        // Periphery
        MATH = ZivoeMath(YDl.ZivoeMath());
        stJTT = ZivoeRewards(0x4D902c165dc69E144819b115eE1dCA6Ef36eB3De);
        stSTT = ZivoeRewards(0x8A16b214D76Bd3EFF7194572855d7d9e6960655f);
        stZVE = ZivoeRewards(0x48230506d00310aE3674B876Cfed4fa0b10dff34);
        vestZVE = ZivoeRewardsVesting(0x3851da7Aa69e29AE2189AD566498325ec396669a);

        // Lockers
        OCC_Modular OCC_DAI = OCC_Modular(0xD45ABc444989B851f3a54A3d572f1675D184Fb7B);
        OCC_Modular OCC_FRAX = OCC_Modular(0x61008A55738F1E44Dc9A0375Cce1C4ff66159e7D);
        OCC_Modular OCC_USDC = OCC_Modular(0x47476770Fc77A2B4e3DA114B322e3aedbbC6EB58);
        OCC_Modular OCC_USDT = OCC_Modular(0xB4D31C9a7bB8651d05386061E3f5877fe858C4bF);

        OCE_ZVE OCE = OCE_ZVE();
        OCL_ZVE OCL = OCL_ZVE(0x310e0Cb6e42B215AF7BcFe33Dcbcd2855DD703c8);
        OCR_Modular OCR = OCR_Modular();
        OCT_DAO daoOCT = OCT_DAO();
        OCT_YDL ydlOCT = OCT_YDL();
        OCT_ZVL zvlOCT = OCT_ZVL();

    }

    function test_Validation_Balance() public {

    }

    function test_Validation_Ownership() public {

    }

    function test_Validation_Settings() public {

    }

}