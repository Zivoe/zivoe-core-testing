// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.17;

import "../Utility/Utility.sol";

import "../../lib/zivoe-core-foundry/src/lockers/OCR/OCR_Modular.sol";
import "../../lib/zivoe-core-foundry/src/lockers/OCG/OCG_Defaults.sol";

contract Test_OCR_Modular is Utility {

    using SafeERC20 for IERC20;

    OCR_Modular OCR_DAI;
    OCR_Modular OCR_USDC;

    OCG_Defaults OCG_Defaults_Test;

    function setUp() public {

        deployCore(false);

        simulateITO_byTranche_stakeTokens(25_000_000 ether, 4_000_000 ether);

        // OCR_Modular Initialization & Whitelist
        OCR_DAI = new OCR_Modular(address(DAO), address(DAI), address(GBL), 1000);
        OCR_USDC = new OCR_Modular(address(DAO), address(USDC), address(GBL), 1000);
        zvl.try_updateIsLocker(address(GBL), address(OCR_DAI), true);
        zvl.try_updateIsLocker(address(GBL), address(OCR_USDC), true);

        // OCG_Defaults Initialization
        OCG_Defaults_Test = new OCG_Defaults(address(DAO), address(GBL));
        zvl.try_updateIsLocker(address(GBL), address(OCG_Defaults_Test), true);

    }
    


    event EpochTicked(
        uint256 epoch, 
        uint256 redemptionsAllowedJunior, 
        uint256 redemptionsAllowedSenior,
        uint256 epochDiscountJunior, 
        uint256 epochDiscountSenior
    );

    event RequestCreated(uint256 indexed id, address indexed account, uint256 amount, bool indexed seniorElseJunior);

    event RequestDestroyed(uint256 indexed id, address indexed account, uint256 amount, bool indexed seniorElseJunior);

    event RequestProcessed
        (uint256 indexed id, 
        address indexed account, 
        uint256 burnAmount, 
        uint256 redeemAmount, 
        bool indexed seniorElseJunior
    );

    event UpdatedRedemptionsFee(uint256 oldFee, uint256 newFee);



    // Validate OCR_Modular initial state.

    function test_OCR_init_state() public {

        // OCR_DAI
        assertEq(OCR_DAI.owner(),           address(DAO));
        assertEq(OCR_DAI.stablecoin(),      DAI);
        assertEq(OCR_DAI.GBL(),             address(GBL));
        assertEq(OCR_DAI.redemptionsFee(),  1000);
        assertEq(OCR_DAI.epoch(),           block.timestamp);

        // OCR_USDC
        assertEq(OCR_USDC.owner(),          address(DAO));
        assertEq(OCR_USDC.stablecoin(),     USDC);
        assertEq(OCR_USDC.GBL(),            address(GBL));
        assertEq(OCR_USDC.redemptionsFee(), 1000);
        assertEq(OCR_USDC.epoch(),          block.timestamp);

    }

    // Validate pushToLocker() state changes.
    // Validate pushToLocker() restrictions.
    // This includes:
    //  - asset must be stablecoin
    //  - onlyOwner can call

    function test_OCR_pushToLocker_restrictions_asset() public {

    }

    function test_OCR_pushToLocker_restrictions_onlyOwner() public {

    }

    function test_OCR_pushToLocker_state() public {
        
    }

    // Validate pullFromLocker() state changes.
    // Validate pullFromLocker() restrictions.
    // This includes:
    //  - asset must NOT be $zJTT or $zSTT
    //  - onlyOwner can call

    function test_OCR_pullFromLocker_restrictions_asset() public {

    }

    function test_OCR_pullFromLocker_restrictions_onlyOwner() public {

    }

    function test_OCR_pullFromLocker_state() public {
        
    }

    // Validate pullFromLockerPartial() state changes.
    // Validate pullFromLockerPartial() restrictions.
    // This includes:
    //  - asset must NOT be $zJTT or $zSTT
    //  - onlyOwner can call

    function test_OCR_pullFromLockerPartial_restrictions_asset() public {

    }

    function test_OCR_pullFromLockerPartial_restrictions_onlyOwner() public {

    }

    function test_OCR_pullFromLockerPartial_state() public {
        
    }

    // Validate createRequest() state changes.

    function test_OCR_createRequest_state() public {

    }

    // Validate destroyRequest() state changes.
    // Validate destroyRequest() restrictions.
    // This includes:
    //  - _msgSender() must be requests[id].account
    //  - requests[id].amount > 0

    function test_OCR_destroyRequest_restrictions_msgSender() public {
        
    }

    function test_OCR_destroyRequest_restrictions_requests() public {
        
    }

    function test_OCR_destroyRequest_state() public {
        
    }

    // Validate processRequest() state changes.
    // Validate processRequest() restrictions.
    // This includes:
    //  - _msgSender() must be requests[id].account
    //  - requests[id].amount > 0

    function test_OCR_processRequest_restrictions_msgSender() public {
        
    }

    function test_OCR_processRequest_restrictions_unlocks() public {
        
    }

    function test_OCR_processRequest_state() public {
        
    }

    // Validate tickEpoch() state changes.

    function test_OCR_tickEpoch_state() public {
        
    }

    function test_OCR_tickEpoch_state_recursive() public {
        
    }

    // Validate updateRedemptionsFee() state changes.
    // Validate updateRedemptionsFee() restrictions.
    // This includes:
    //  - _msgSender() must be TLC
    //  - _redemptionsFee must be in range [250, 2000]

    function test_OCR_updateRedemptionsFee_restrictions_msgSender() public {
        
        // Can't call if _msgSender() != TLC
        hevm.startPrank(address(tim));
        hevm.expectRevert("OCR_Modular::updateRedemptionsFee() _msgSender() != TLC()");
        OCR_DAI.updateRedemptionsFee(500);
        hevm.stopPrank();
    }

    function test_OCR_updateRedemptionsFee_restrictions_range(uint16 fee) public {
        
        // Can't update if fee < 250 || fee > 2000
        hevm.startPrank(address(god));
        if (fee < 250 || fee > 2000) {
            hevm.expectRevert("OCR_Modular::updateRedemptionsFee() _redemptionsFee > 2000 && _redemptionsFee < 250");
        }
        OCR_DAI.updateRedemptionsFee(fee);
        hevm.stopPrank();
    }

    function test_OCR_updateRedemptionsFee_state(uint16 fee) public {

        hevm.assume(fee >= 250 && fee <= 2000);

        // Pre-state.
        assertEq(OCR_DAI.redemptionsFee(), 1000);

        // updateRedemptionsFee().
        hevm.startPrank(address(god));
        hevm.expectEmit(false, false, false, true, address(OCR_DAI));
        emit UpdatedRedemptionsFee(1000, fee);
        OCR_DAI.updateRedemptionsFee(fee);
        hevm.stopPrank();

        // Post-state.
        assertEq(OCR_DAI.redemptionsFee(), fee);   
    }

}