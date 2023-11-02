// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../Utility/Utility.sol";

contract Test_ZVT is Utility {

    uint minZVEPerJTTMint;
    uint maxZVEPerJTTMint = 90000000000000000;
    uint lowerRatioIncentiveBIPS = 3400;
    uint upperRatioIncentiveBIPS = 3500;

    function setUp() public {

    }

    function test_ZVT_Error() public {

        ZVT = ZivoeTranches(0x42882a9d01E857A30E211DdCde18aCB252CFE96c);
        GBL = ZivoeGlobals(0xd88984dD7887a835F142ff4067Bf7D7d5B167931);
        ZVE = ZivoeToken(0xAFaf4eb0D74A478e50c4f4a2f82CA56c6F965357);

        // Error (overflow / underflow)
        // rewardZVEJuniorDeposit(), rewardsSeniorDeposit()
        // ZVT.rewardZVEJuniorDeposit(10000);

        uint deposit = 1000 ether;

        (uint256 seniorSupp, uint256 juniorSupp) = GBL.adjustedSupplies();

        uint256 avgRate;    // The avg ZVE per stablecoin deposit reward, used for reward calculation.

        uint256 diffRate = maxZVEPerJTTMint - minZVEPerJTTMint;

        uint256 startRatio = juniorSupp * 10000 / seniorSupp;
        uint256 finalRatio = (juniorSupp + deposit) * 10000 / seniorSupp;
        uint256 avgRatio = (startRatio + finalRatio) / 2;

        emit log_named_uint('maxZVEPerJTTMint', maxZVEPerJTTMint);
        emit log_named_uint('diffRate * (avgRatio - 1000) / (1500)', diffRate * (avgRatio - 1000) / (1500));

        if (avgRatio <= lowerRatioIncentiveBIPS) {
            avgRate = maxZVEPerJTTMint;
        } else if (avgRatio >= upperRatioIncentiveBIPS) {
            avgRate = minZVEPerJTTMint;
        } else {
            // avgRate = maxZVEPerJTTMint - diffRate * (avgRatio - lowerRatioIncentiveBIPS) / (upperRatioIncentiveBIPS - lowerRatioIncentiveBIPS);
            avgRate = maxZVEPerJTTMint - diffRate * (avgRatio - 1000) / (1500);
        }

        uint reward = avgRate * deposit / 1 ether;

        // Reduce if ZVE balance < reward.
        if (ZVE.balanceOf(address(ZVT)) < reward) {
            reward = ZVE.balanceOf(address(ZVT));
        }

        emit log_named_uint('reward', reward);

    }

}