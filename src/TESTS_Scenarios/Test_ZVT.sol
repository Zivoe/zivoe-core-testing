// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../Utility/Utility.sol";

import "../../lib/zivoe-core-foundry/src/Misc/MockStablecoin.sol";

contract Test_ZVT is Utility {

    uint minZVEPerJTTMint;
    uint maxZVEPerJTTMint = 90000000000000000;
    uint lowerRatioIncentiveBIPS = 3400;
    uint upperRatioIncentiveBIPS = 3500;

    function setUp() public {

    }

    function test_ZVT_Error() public {

        ZVT = ZivoeTranches(0xc02FE7B001634d56055DB85bab8A7725C7DAf388);
        GBL = ZivoeGlobals(0xf0Afc2A38Db679fc3FaD99AD2b3Df2532d2C16EC);
        ZVE = ZivoeToken(0x0dBf52928DBBfCE096C39944ABd49cF412c84919);

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

    function test_ZVT_Error_2() public {

        ZVT = ZivoeTranches(0xc02FE7B001634d56055DB85bab8A7725C7DAf388);
        GBL = ZivoeGlobals(0xf0Afc2A38Db679fc3FaD99AD2b3Df2532d2C16EC);
        ZVE = ZivoeToken(0x0dBf52928DBBfCE096C39944ABd49cF412c84919);

        ZivoeTranches APPLE = new ZivoeTranches(0xf0Afc2A38Db679fc3FaD99AD2b3Df2532d2C16EC);

        // Mint DAI/USDC for deposit
        MockStablecoin MOCK_DAI = MockStablecoin(0x70bFe748C66B48B0ae0109637806959e45E486e5);
        MockStablecoin MOCK_USDC = MockStablecoin(0x64ea78674f607A913ef033834dF4a57306aEE2C2);

        MOCK_DAI.mint(address(this), 10_000 ether);
        MOCK_USDC.mint(address(this), 10_000 * 10**6);

        // Approve
        MOCK_DAI.approve(address(ZVT), 10_000 ether);
        MOCK_USDC.approve(address(ZVT), 10_000 * 10**6);

        // Deposit
        // ZVT.depositJunior(10_000 ether, 0x70bFe748C66B48B0ae0109637806959e45E486e5);
        // APPLE.rewardZVEJuniorDeposit(100_000_000_000 ether);
        ZVT.rewardZVEJuniorDeposit(10_000 ether);

    }

}