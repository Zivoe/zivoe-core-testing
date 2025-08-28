// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../Utility/Utility.sol";

import "../../lib/zivoe-core-foundry/src/lockers/OCC/OCC_Modular.sol";
import "../../lib/zivoe-core-foundry/src/misc/MockStablecoin.sol";

contract Test_OCC_Quick is Utility {

    using SafeERC20 for IERC20;

    // Mainnet addresses
    address public m_DAO = address(0xB65a66621D7dE34afec9b9AC0755133051550dD7);
    address public m_USDC = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address public m_GBL = address(0xEa537eB0bBcC7783bDF7c595bF9371984583dA66);
    address public m_zVLT = address(0x94BaBe9Ee75C38034920bC6ed42748E8eEFbedd4);
    address public m_zSTT = address(0x7aA5Bf30042b2145B9F0629ea68De55B42ad3BB6);
    address public m_ZVL = address(0x0C03592375ed4Aa105C0C19249297bD7c65fb731);
    address public m_TLC = address(0xE1A68a0404426d6BBc459794e576640dEE3FC916);

    address public m_Underwriter = 0x1FA2700AA0544716D4597d094f4adaCF67D47ab6;
    address public m_Borrower = 0xC8d6248fFbc59BFD51B23E69b962C60590d5f026;

    OCC_Modular public OCC;

    bool live = true;

    function setUp() public {

        setUpTokens();

        // OCR_Instant Initialization & Whitelist

        if (live) {
            
            // Fund Borrower with some USDC to make repayments
            deal(m_USDC, m_Borrower, 10_000_000 * 10**6);

            OCC = OCC_Modular(0xfAb4e880467e26ED46F00c669C28fEaC58262698);

        }
        else {
            
            
        }

    }

    // -----------
    //    Tests
    // -----------

    // Validate OCR_Instant initial state.

    function test_OCC_Payment_quick() public {

        if (live) {
            
            // Step 1 - Convert the loan to amortization (underwrite approves, borrower accepts)
            hevm.startPrank(m_Underwriter);
            OCC.approveConversionToAmortization(0);
            hevm.stopPrank();

            hevm.startPrank(m_Borrower);
            OCC.applyConversionToAmortization(0);
            hevm.stopPrank();

            // Step 2 - Experiment with extensions (1->6) (underwriter approves, borrower accepts)
            uint amountOfExtension = 3;

            hevm.startPrank(m_Underwriter);
            OCC.approveExtension(0, amountOfExtension);
            hevm.stopPrank();

            hevm.startPrank(m_Borrower);
            OCC.applyExtension(0);
            hevm.stopPrank();

            // Step 3 - Check the amountOwed() on the loan after changes made:
            /*
                function amountOwed(uint256 id) public view returns (
                    uint256 principal, uint256 interest, uint256 lateFee, uint256 total
                )
            */

            (uint principal, uint interest, uint lateFee, uint total) = OCC.amountOwed(0);

            // Emit the amount owed on the loan after each extension
            emit log_named_uint('Principal', principal / 10**6);
            emit log_named_uint('Interest', interest / 10**6);
            emit log_named_uint('Late fee', lateFee / 10**6);
            emit log_named_uint('Total', total / 10**6);

        }

    }

} 