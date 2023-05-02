// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.17;

import "../Utility/Utility.sol";

import "../../lib/zivoe-core-foundry/src/lockers/OCC/OCC_Modular.sol";
import "../../lib/zivoe-core-foundry/src/lockers/OCT/OCT_YDL.sol";

contract Test_OCC_Modular is Utility {

    OCC_Modular OCC_Modular_DAI;
    OCC_Modular OCC_Modular_FRAX;
    OCC_Modular OCC_Modular_USDC;
    OCC_Modular OCC_Modular_USDT;

    OCT_YDL Treasury;

    uint32[5] options = [86400 * 7, 86400 * 14, 86400 * 28, 86400 * 91, 86400 * 364];

    function setUp() public {

        deployCore(false);

        Treasury = new OCT_YDL(address(DAO), address(GBL));

        // Initialize and whitelist OCC_Modular lockers.
        OCC_Modular_DAI = new OCC_Modular(address(DAO), address(DAI), address(GBL), address(roy), address(Treasury));
        OCC_Modular_FRAX = new OCC_Modular(address(DAO), address(FRAX), address(GBL), address(roy), address(Treasury));
        OCC_Modular_USDC = new OCC_Modular(address(DAO), address(USDC), address(GBL), address(roy), address(Treasury));
        OCC_Modular_USDT = new OCC_Modular(address(DAO), address(USDT), address(GBL), address(roy), address(Treasury));

        zvl.try_updateIsLocker(address(GBL), address(Treasury), true);
        zvl.try_updateIsLocker(address(GBL), address(OCC_Modular_DAI), true);
        zvl.try_updateIsLocker(address(GBL), address(OCC_Modular_FRAX), true);
        zvl.try_updateIsLocker(address(GBL), address(OCC_Modular_USDC), true);
        zvl.try_updateIsLocker(address(GBL), address(OCC_Modular_USDT), true);

        deal(DAI, address(OCC_Modular_DAI), 100_000_000_000_000_000_000 ether);
        deal(FRAX, address(OCC_Modular_FRAX), 100_000_000_000_000_000_000 ether);
        deal(USDC, address(OCC_Modular_USDC), 100_000_000_000_000_000_000 ether);
        deal(USDT, address(OCC_Modular_USDT), 100_000_000_000_000_000_000 ether);

    }

    // ------------
    //    Events
    // ------------
    
    event CombineApproved(address indexed borrower, uint paymentInterval, uint term);
    
    event CombineUnapproved(address indexed borrower, uint paymentInterval);
    
    event CombineApplied(address indexed borrower, uint paymentInterval, uint term, uint[] ids);

    event CombineLoanCreated(
        address indexed borrower,
        uint256 indexed id,
        uint256 borrowAmount,
        uint256 APR,
        uint256 APRLateFee,
        uint256 paymentDueBy,
        uint256 term,
        uint256 paymentInterval,
        uint256 gracePeriod,
        int8 indexed paymentSchedule
    );

    event ConversionAmortizationApplied(uint indexed id);
    
    event ConversionAmortizationApproved(uint indexed id);
    
    event ConversionAmortizationUnapproved(uint indexed id);
    
    event ConversionBulletApplied(uint indexed id);
    
    event ConversionBulletApproved(uint indexed id);
    
    event ConversionBulletUnapproved(uint indexed id);
    
    event DefaultMarked(uint256 indexed id, uint256 principalDefaulted, uint256 priorNetDefaults, uint256 currentNetDefaults);

    event DefaultResolved(uint256 indexed id, uint256 amount, address indexed payee, bool resolved);
    
    event ExtensionApplied(uint indexed id, uint intervals);
    
    event ExtensionApproved(uint indexed id, uint intervals);
    
    event ExtensionUnapproved(uint indexed id);
    
    event LoanCalled(uint256 indexed id, uint256 amount, uint256 principal, uint256 interest, uint256 lateFee);
    
    event InterestSupplied(uint256 indexed id, uint256 amount, address indexed payee);
    
    event OCTYDLSetZVL(address indexed newOCT, address indexed oldOCT);
    
    event OfferAccepted(uint256 indexed id, uint256 principal, address indexed borrower, uint256 paymentDueBy);

    event OfferCancelled(uint256 indexed id);

    event OfferCreated(
        address indexed borrower,
        uint256 indexed id,
        uint256 borrowAmount,
        uint256 APR,
        uint256 APRLateFee,
        uint256 term,
        uint256 paymentInterval,
        uint256 offerExpiry,
        uint256 gracePeriod,
        int8 indexed paymentSchedule
    );

    event PaymentMade(uint256 indexed id, address indexed payee, uint256 amount, uint256 principal, uint256 interest, uint256 lateFee, uint256 nextPaymentDue);

    event RefinanceApproved(uint indexed id, uint apr);
    
    event RefinanceUnapproved(uint indexed id);
    
    event RefinanceApplied(uint indexed id, uint aprNew, uint aprPrior);
    
    event RepaidMarked(uint256 indexed id);

    // ----------------------
    //    Helper Functions
    // ----------------------

    function createRandomOffer(uint96 random, bool choice, address asset) internal returns (uint256 loanID) {
        
        uint256 borrowAmount = uint256(random) + 1;
        uint256 APR = uint256(random) % 5000;
        uint256 APRLateFee = uint256(random) % 5000;
        uint256 term = uint256(random) % 25 + 1;
        uint256 gracePeriod = uint256(random) % 90 days;
        uint256 option = uint256(random) % 5;
        int8 paymentSchedule = choice ? int8(0) : int8(1);

        if (asset == DAI) {
            loanID = OCC_Modular_DAI.counterID();
            assert(roy.try_createOffer(
                address(OCC_Modular_DAI),
                address(tim),
                borrowAmount,
                APR,
                APRLateFee,
                term,
                uint256(options[option]),
                gracePeriod,
                paymentSchedule
            ));
        }

        else if (asset == FRAX) {
            loanID = OCC_Modular_FRAX.counterID();
            assert(roy.try_createOffer(
                address(OCC_Modular_FRAX),
                address(tim),
                borrowAmount,
                APR,
                APRLateFee,
                term,
                uint256(options[option]),
                gracePeriod,
                paymentSchedule
            ));
        }

        else if (asset == USDC) {
            loanID = OCC_Modular_USDC.counterID();
            assert(roy.try_createOffer(
                address(OCC_Modular_USDC),
                address(tim),
                borrowAmount,
                APR,
                APRLateFee,
                term,
                uint256(options[option]),
                gracePeriod,
                paymentSchedule
            ));
        }

        else if (asset == USDT) {
            loanID = OCC_Modular_USDT.counterID();
            assert(roy.try_createOffer(
                address(OCC_Modular_USDT),
                address(tim),
                borrowAmount,
                APR,
                APRLateFee,
                term,
                uint256(options[option]),
                gracePeriod,
                paymentSchedule
            ));
        }

        else { revert(); }

    }

    function man_acceptOffer(uint256 loanID, address asset) public {

        if (asset == DAI) {
            assert(tim.try_acceptOffer(address(OCC_Modular_DAI), loanID));
        }

        else if (asset == FRAX) {
            assert(tim.try_acceptOffer(address(OCC_Modular_FRAX), loanID));
        }

        else if (asset == USDC) {
            assert(tim.try_acceptOffer(address(OCC_Modular_USDC), loanID));
        }

        else if (asset == USDT) {
            assert(tim.try_acceptOffer(address(OCC_Modular_USDT), loanID));
        }

        else { revert(); }

    }

    function simulateITO_and_createOffers(
        uint96 random, bool choice
    ) public returns (
        uint256 _loanID_DAI, 
        uint256 _loanID_FRAX, 
        uint256 _loanID_USDC, 
        uint256 _loanID_USDT 
    ) {

        uint256 amount = uint256(random);

        simulateITO(amount * WAD, amount * WAD, amount * USD, amount * USD);

        assert(god.try_push(address(DAO), address(OCC_Modular_DAI), DAI, amount, ""));
        assert(god.try_push(address(DAO), address(OCC_Modular_FRAX), FRAX, amount, ""));
        assert(god.try_push(address(DAO), address(OCC_Modular_USDC), USDC, amount, ""));
        assert(god.try_push(address(DAO), address(OCC_Modular_USDT), USDT, amount, ""));

        _loanID_DAI = createRandomOffer(random, choice, DAI);
        _loanID_FRAX = createRandomOffer(random, choice, FRAX);
        _loanID_USDC = createRandomOffer(random, choice, USDC);
        _loanID_USDT = createRandomOffer(random, choice, USDT);

    }

    function simulateITO_and_createOffers_and_acceptOffers(
        uint96 random, bool choice
    ) public returns (
        uint256 _loanID_DAI, 
        uint256 _loanID_FRAX, 
        uint256 _loanID_USDC, 
        uint256 _loanID_USDT 
    ) {

        uint256 amount = uint256(random);

        simulateITO(amount * WAD, amount * WAD, amount * USD, amount * USD);

        assert(god.try_push(address(DAO), address(OCC_Modular_DAI), DAI, amount, ""));
        assert(god.try_push(address(DAO), address(OCC_Modular_FRAX), FRAX, amount, ""));
        assert(god.try_push(address(DAO), address(OCC_Modular_USDC), USDC, amount, ""));
        assert(god.try_push(address(DAO), address(OCC_Modular_USDT), USDT, amount, ""));

        _loanID_DAI = createRandomOffer(random, choice, DAI);
        _loanID_FRAX = createRandomOffer(random, choice, FRAX);
        _loanID_USDC = createRandomOffer(random, choice, USDC);
        _loanID_USDT = createRandomOffer(random, choice, USDT);

        assert(tim.try_acceptOffer(address(OCC_Modular_DAI), _loanID_DAI));
        assert(tim.try_acceptOffer(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(tim.try_acceptOffer(address(OCC_Modular_USDC), _loanID_USDC));
        assert(tim.try_acceptOffer(address(OCC_Modular_USDT), _loanID_USDT));

        // Mint borrower tokens for paying interest, or other purposes.
        mint("DAI", address(tim), MAX_UINT / 2);
        mint("FRAX", address(tim), MAX_UINT / 2);
        mint("USDC", address(tim), MAX_UINT / 2);
        mint("USDT", address(tim), MAX_UINT / 2);

        // Handle pre-approvals here for future convenience.
        assert(tim.try_approveToken(address(DAI), address(OCC_Modular_DAI), MAX_UINT / 2));
        assert(tim.try_approveToken(address(FRAX), address(OCC_Modular_FRAX), MAX_UINT / 2));
        assert(tim.try_approveToken(address(USDC), address(OCC_Modular_USDC), MAX_UINT / 2));
        assert(tim.try_approveToken(address(USDT), address(OCC_Modular_USDT), MAX_UINT / 2));

    }

    function createOffers_and_acceptOffers(
        uint96 random, bool choice
    ) public returns (
        uint256 _loanID_DAI, 
        uint256 _loanID_FRAX, 
        uint256 _loanID_USDC, 
        uint256 _loanID_USDT 
    ) {

        _loanID_DAI = createRandomOffer(random, choice, DAI);
        _loanID_FRAX = createRandomOffer(random, choice, FRAX);
        _loanID_USDC = createRandomOffer(random, choice, USDC);
        _loanID_USDT = createRandomOffer(random, choice, USDT);

        assert(tim.try_acceptOffer(address(OCC_Modular_DAI), _loanID_DAI));
        assert(tim.try_acceptOffer(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(tim.try_acceptOffer(address(OCC_Modular_USDC), _loanID_USDC));
        assert(tim.try_acceptOffer(address(OCC_Modular_USDT), _loanID_USDT));

        // Mint borrower tokens for paying interest, or other purposes.
        mint("DAI", address(tim), MAX_UINT / 2);
        mint("FRAX", address(tim), MAX_UINT / 2);
        mint("USDC", address(tim), MAX_UINT / 2);
        mint("USDT", address(tim), MAX_UINT / 2);

        // Handle pre-approvals here for future convenience.
        assert(tim.try_approveToken(address(DAI), address(OCC_Modular_DAI), MAX_UINT / 2));
        assert(tim.try_approveToken(address(FRAX), address(OCC_Modular_FRAX), MAX_UINT / 2));
        assert(tim.try_approveToken(address(USDC), address(OCC_Modular_USDC), MAX_UINT / 2));
        assert(tim.try_approveToken(address(USDT), address(OCC_Modular_USDT), MAX_UINT / 2));

    }

    function simulateITO_and_createOffers_and_acceptOffers_and_defaultLoans(
        uint96 random, bool choice
    ) public returns (
        uint256 _loanID_DAI, 
        uint256 _loanID_FRAX, 
        uint256 _loanID_USDC, 
        uint256 _loanID_USDT 
    ) {

        uint256 amount = uint256(random);

        simulateITO(amount * WAD, amount * WAD, amount * USD, amount * USD);

        assert(god.try_push(address(DAO), address(OCC_Modular_DAI), DAI, amount, ""));
        assert(god.try_push(address(DAO), address(OCC_Modular_FRAX), FRAX, amount, ""));
        assert(god.try_push(address(DAO), address(OCC_Modular_USDC), USDC, amount, ""));
        assert(god.try_push(address(DAO), address(OCC_Modular_USDT), USDT, amount, ""));

        _loanID_DAI = createRandomOffer(random, choice, DAI);
        _loanID_FRAX = createRandomOffer(random, choice, FRAX);
        _loanID_USDC = createRandomOffer(random, choice, USDC);
        _loanID_USDT = createRandomOffer(random, choice, USDT);

        assert(tim.try_acceptOffer(address(OCC_Modular_DAI), _loanID_DAI));
        assert(tim.try_acceptOffer(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(tim.try_acceptOffer(address(OCC_Modular_USDC), _loanID_USDC));
        assert(tim.try_acceptOffer(address(OCC_Modular_USDT), _loanID_USDT));

        // Mint borrower tokens for paying interest, or other purposes.
        mint("DAI", address(tim), MAX_UINT / 2);
        mint("FRAX", address(tim), MAX_UINT / 2);
        mint("USDC", address(tim), MAX_UINT / 2);
        mint("USDT", address(tim), MAX_UINT / 2);

        // Handle pre-approvals here for future convenience.
        assert(tim.try_approveToken(address(DAI), address(OCC_Modular_DAI), MAX_UINT / 2));
        assert(tim.try_approveToken(address(FRAX), address(OCC_Modular_FRAX), MAX_UINT / 2));
        assert(tim.try_approveToken(address(USDC), address(OCC_Modular_USDC), MAX_UINT / 2));
        assert(tim.try_approveToken(address(USDT), address(OCC_Modular_USDT), MAX_UINT / 2));

        (,, uint256[10] memory loanInfo_DAI) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        (,, uint256[10] memory loanInfo_FRAX) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        (,, uint256[10] memory loanInfo_USDC) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        (,, uint256[10] memory loanInfo_USDT) = OCC_Modular_USDT.loanInfo(_loanID_USDT);

        hevm.warp(loanInfo_DAI[3] + loanInfo_DAI[8] + 1 seconds);
        assert(roy.try_markDefault(address(OCC_Modular_DAI), _loanID_DAI));

        hevm.warp(loanInfo_FRAX[3] + loanInfo_FRAX[8] + 1 seconds);
        assert(roy.try_markDefault(address(OCC_Modular_FRAX), _loanID_FRAX));
        
        hevm.warp(loanInfo_USDC[3] + loanInfo_USDC[8] + 1 seconds);
        assert(roy.try_markDefault(address(OCC_Modular_USDC), _loanID_USDC));
        
        hevm.warp(loanInfo_USDT[3] + loanInfo_USDT[8] + 1 seconds);
        assert(roy.try_markDefault(address(OCC_Modular_USDT), _loanID_USDT));
    }

    function simulateITO_and_createOffers_and_acceptOffers_and_defaultLoans_and_resolveLoans(
        uint96 random, bool choice
    ) public returns (
        uint256 _loanID_DAI, 
        uint256 _loanID_FRAX, 
        uint256 _loanID_USDC, 
        uint256 _loanID_USDT 
    ) {

        uint256 amount = uint256(random);

        simulateITO(amount * WAD, amount * WAD, amount * USD, amount * USD);

        assert(god.try_push(address(DAO), address(OCC_Modular_DAI), DAI, amount, ""));
        assert(god.try_push(address(DAO), address(OCC_Modular_FRAX), FRAX, amount, ""));
        assert(god.try_push(address(DAO), address(OCC_Modular_USDC), USDC, amount, ""));
        assert(god.try_push(address(DAO), address(OCC_Modular_USDT), USDT, amount, ""));

        _loanID_DAI = createRandomOffer(random, choice, DAI);
        _loanID_FRAX = createRandomOffer(random, choice, FRAX);
        _loanID_USDC = createRandomOffer(random, choice, USDC);
        _loanID_USDT = createRandomOffer(random, choice, USDT);

        assert(tim.try_acceptOffer(address(OCC_Modular_DAI), _loanID_DAI));
        assert(tim.try_acceptOffer(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(tim.try_acceptOffer(address(OCC_Modular_USDC), _loanID_USDC));
        assert(tim.try_acceptOffer(address(OCC_Modular_USDT), _loanID_USDT));

        // Mint borrower tokens for paying interest, or other purposes.
        mint("DAI", address(tim), MAX_UINT / 2);
        mint("FRAX", address(tim), MAX_UINT / 2);
        mint("USDC", address(tim), MAX_UINT / 2);
        mint("USDT", address(tim), MAX_UINT / 2);

        // Handle pre-approvals here for future convenience.
        assert(tim.try_approveToken(address(DAI), address(OCC_Modular_DAI), MAX_UINT / 2));
        assert(tim.try_approveToken(address(FRAX), address(OCC_Modular_FRAX), MAX_UINT / 2));
        assert(tim.try_approveToken(address(USDC), address(OCC_Modular_USDC), MAX_UINT / 2));
        assert(tim.try_approveToken(address(USDT), address(OCC_Modular_USDT), MAX_UINT / 2));

        (,, uint256[10] memory loanInfo_DAI) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        (,, uint256[10] memory loanInfo_FRAX) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        (,, uint256[10] memory loanInfo_USDC) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        (,, uint256[10] memory loanInfo_USDT) = OCC_Modular_USDT.loanInfo(_loanID_USDT);

        hevm.warp(loanInfo_DAI[3] + loanInfo_DAI[8] + 1 seconds);
        assert(roy.try_markDefault(address(OCC_Modular_DAI), _loanID_DAI));

        hevm.warp(loanInfo_FRAX[3] + loanInfo_FRAX[8] + 1 seconds);
        assert(roy.try_markDefault(address(OCC_Modular_FRAX), _loanID_FRAX));
        
        hevm.warp(loanInfo_USDC[3] + loanInfo_USDC[8] + 1 seconds);
        assert(roy.try_markDefault(address(OCC_Modular_USDC), _loanID_USDC));
        
        hevm.warp(loanInfo_USDT[3] + loanInfo_USDT[8] + 1 seconds);
        assert(roy.try_markDefault(address(OCC_Modular_USDT), _loanID_USDT));
        
        assert(tim.try_resolveDefault(address(OCC_Modular_DAI), _loanID_DAI, loanInfo_DAI[0]));
        assert(tim.try_resolveDefault(address(OCC_Modular_FRAX), _loanID_FRAX, loanInfo_DAI[0]));
        assert(tim.try_resolveDefault(address(OCC_Modular_USDC), _loanID_USDC, loanInfo_DAI[0]));
        assert(tim.try_resolveDefault(address(OCC_Modular_USDT), _loanID_USDT, loanInfo_DAI[0]));

    }

    // ----------------
    //    Unit Tests
    // ----------------

    // Validate initial state.

    function test_OCC_Modular_init() public {
        
        // Ownership.
        assertEq(OCC_Modular_DAI.owner(), address(DAO));
        assertEq(OCC_Modular_FRAX.owner(), address(DAO));
        assertEq(OCC_Modular_USDC.owner(), address(DAO));
        assertEq(OCC_Modular_USDT.owner(), address(DAO));
        
        // State variables.
        assertEq(OCC_Modular_DAI.stablecoin(), address(DAI));
        assertEq(OCC_Modular_FRAX.stablecoin(), address(FRAX));
        assertEq(OCC_Modular_USDC.stablecoin(), address(USDC));
        assertEq(OCC_Modular_USDT.stablecoin(), address(USDT));
        
        assertEq(OCC_Modular_DAI.GBL(), address(GBL));
        assertEq(OCC_Modular_FRAX.GBL(), address(GBL));
        assertEq(OCC_Modular_USDC.GBL(), address(GBL));
        assertEq(OCC_Modular_USDT.GBL(), address(GBL));
        
        assertEq(OCC_Modular_DAI.underwriter(), address(roy));
        assertEq(OCC_Modular_FRAX.underwriter(), address(roy));
        assertEq(OCC_Modular_USDC.underwriter(), address(roy));
        assertEq(OCC_Modular_USDT.underwriter(), address(roy));

        assert(OCC_Modular_DAI.canPush());
        assert(OCC_Modular_FRAX.canPush());
        assert(OCC_Modular_USDC.canPush());
        assert(OCC_Modular_USDT.canPush());

        assert(OCC_Modular_DAI.canPull());
        assert(OCC_Modular_FRAX.canPull());
        assert(OCC_Modular_USDC.canPull());
        assert(OCC_Modular_USDT.canPull());
        
        assert(OCC_Modular_DAI.canPullPartial());
        assert(OCC_Modular_FRAX.canPullPartial());
        assert(OCC_Modular_USDC.canPullPartial());
        assert(OCC_Modular_USDT.canPullPartial());

    }

    // Validate acceptOffer() state changes.
    // Validate acceptOffer() restrictions.
    // This includes:
    //  - loans[id].state must be LoanState.Initialized
    //  - block.timestamp must be before offerExpiry
    //  - _msgSender() must be borrower

    function test_OCC_Modular_acceptOffer_restrictions_loanState(uint96 random, bool choice) public {

        (
            uint256 _loanID_DAI,, 
            uint256 _loanID_USDC, 
        ) = simulateITO_and_createOffers(random, choice);

        // Cancel two loan offers.
        assert(roy.try_cancelOffer(address(OCC_Modular_DAI), _loanID_DAI));
        assert(roy.try_cancelOffer(address(OCC_Modular_USDC), _loanID_USDC));

        // Can't accept loan offer if state != LoanState.Initialized.
        hevm.startPrank(address(roy));
        hevm.expectRevert("OCC_Modular::acceptOffer() loans[id].state != LoanState.Initialized");
        OCC_Modular_DAI.acceptOffer(_loanID_DAI);
        hevm.stopPrank();

        assert(!tim.try_acceptOffer(address(OCC_Modular_USDC), _loanID_USDC));
    }

    function test_OCC_Modular_acceptOffer_restrictions_expiry(uint96 random, bool choice) public {

        (
            uint256 _loanID_DAI, 
            uint256 _loanID_FRAX, 
            uint256 _loanID_USDC, 
            uint256 _loanID_USDT 
        ) = simulateITO_and_createOffers(random, choice);

        // Cancel two loan offers.
        assert(roy.try_cancelOffer(address(OCC_Modular_DAI), _loanID_DAI));
        assert(roy.try_cancelOffer(address(OCC_Modular_USDC), _loanID_USDC));

        // Warp past expiry time (14 days past loan creation).
        hevm.warp(block.timestamp + 14 days + 1 seconds);

        // Can't accept loan offer loan if block.timestamp > loans[id].offerExpiry.
        hevm.startPrank(address(roy));
        hevm.expectRevert("OCC_Modular::acceptOffer() block.timestamp >= loans[id].offerExpiry");
        OCC_Modular_FRAX.acceptOffer(_loanID_FRAX);
        hevm.stopPrank();
       
        assert(!tim.try_acceptOffer(address(OCC_Modular_USDT), _loanID_USDT));
    }

    function test_OCC_Modular_acceptOffer_restrictions_borrower(uint96 random, bool choice) public {

        (
            , 
            uint256 _loanID_FRAX, 
            , 
             
        ) = simulateITO_and_createOffers(random, choice);

        // Warp slightly ahead of time.
        hevm.warp(block.timestamp + 1 days);

        // Can't accept loan offer if _msgSender() != borrower
        hevm.startPrank(address(roy));
        hevm.expectRevert("OCC_Modular::acceptOffer() _msgSender() != loans[id].borrower");
        OCC_Modular_FRAX.acceptOffer(_loanID_FRAX);
        hevm.stopPrank();
    }

    function test_OCC_Modular_acceptOffer_state(uint96 random, bool choice) public {

        (
            uint256 _loanID_DAI, 
            uint256 _loanID_FRAX, 
            uint256 _loanID_USDC, 
            uint256 _loanID_USDT 
        ) = simulateITO_and_createOffers(random, choice);


        // Pre-state DAI.
        uint256 _preStable_borrower = IERC20(DAI).balanceOf(address(tim));
        uint256 _preStable_occ = IERC20(DAI).balanceOf(address(OCC_Modular_DAI));
        (,, uint256[10] memory _preDetails) = OCC_Modular_DAI.loanInfo(_loanID_DAI);

        hevm.expectEmit(true, true, false, true, address(OCC_Modular_DAI));
        emit OfferAccepted(_loanID_DAI, _preDetails[0], address(tim), block.timestamp - block.timestamp % 7 days + 9 days + _preDetails[6]);
        assert(tim.try_acceptOffer(address(OCC_Modular_DAI), _loanID_DAI));

        // Post-state DAI.
        (,, uint256[10] memory _postDetails) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        uint256 _postStable_borrower = IERC20(DAI).balanceOf(address(tim));
        uint256 _postStable_occ = IERC20(DAI).balanceOf(address(OCC_Modular_DAI));

        // block.timestamp - block.timestamp % 7 days + 9 days + loans[id].paymentInterval
        assertEq(_postDetails[3], block.timestamp - block.timestamp % 7 days + 9 days + _postDetails[6]);
        assertEq(_postDetails[9], 2);
        assertEq(_postStable_borrower - _preStable_borrower, _postDetails[0]);
        assertEq(_preStable_occ - _postStable_occ, _postDetails[0]);

        // Pre-state FRAX.
        _preStable_borrower = IERC20(FRAX).balanceOf(address(tim));
        _preStable_occ = IERC20(FRAX).balanceOf(address(OCC_Modular_FRAX));
        (,, _preDetails) = OCC_Modular_DAI.loanInfo(_loanID_FRAX);

        hevm.expectEmit(true, true, false, true, address(OCC_Modular_FRAX));
        emit OfferAccepted(_loanID_FRAX, _preDetails[0], address(tim), block.timestamp - block.timestamp % 7 days + 9 days + _preDetails[6]);
        assert(tim.try_acceptOffer(address(OCC_Modular_FRAX), _loanID_FRAX));

        // Post-state FRAX
        (,, _postDetails) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        _postStable_borrower = IERC20(FRAX).balanceOf(address(tim));
        _postStable_occ = IERC20(FRAX).balanceOf(address(OCC_Modular_FRAX));
        
        assertEq(_postDetails[3], block.timestamp - block.timestamp % 7 days + 9 days + _postDetails[6]);
        assertEq(_postDetails[9], 2);
        assertEq(_postStable_borrower - _preStable_borrower, _postDetails[0]);
        assertEq(_preStable_occ - _postStable_occ, _postDetails[0]);

        // Pre-state USDC.
        _preStable_borrower = IERC20(USDC).balanceOf(address(tim));
        _preStable_occ = IERC20(USDC).balanceOf(address(OCC_Modular_USDC));
        (,, _preDetails) = OCC_Modular_DAI.loanInfo(_loanID_USDC);

        hevm.expectEmit(true, true, false, true, address(OCC_Modular_USDC));
        emit OfferAccepted(_loanID_USDC, _preDetails[0], address(tim), block.timestamp - block.timestamp % 7 days + 9 days + _preDetails[6]);
        assert(tim.try_acceptOffer(address(OCC_Modular_USDC), _loanID_USDC));

        // Post-state USDC
        (,, _postDetails) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        _postStable_borrower = IERC20(USDC).balanceOf(address(tim));
        _postStable_occ = IERC20(USDC).balanceOf(address(OCC_Modular_USDC));
        
        assertEq(_postDetails[3], block.timestamp - block.timestamp % 7 days + 9 days + _postDetails[6]);
        assertEq(_postDetails[9], 2);
        assertEq(_postStable_borrower - _preStable_borrower, _postDetails[0]);
        assertEq(_preStable_occ - _postStable_occ, _postDetails[0]);

        // Pre-state USDT.
        _preStable_borrower = IERC20(USDT).balanceOf(address(tim));
        _preStable_occ = IERC20(USDT).balanceOf(address(OCC_Modular_USDT));
        (,, _preDetails) = OCC_Modular_DAI.loanInfo(_loanID_USDT);

        hevm.expectEmit(true, true, false, true, address(OCC_Modular_USDT));
        emit OfferAccepted(_loanID_USDT, _preDetails[0], address(tim), block.timestamp - block.timestamp % 7 days + 9 days + _preDetails[6]);
        assert(tim.try_acceptOffer(address(OCC_Modular_USDT), _loanID_USDT));

        // Post-state USDT
        (,, _postDetails) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
        _postStable_borrower = IERC20(USDT).balanceOf(address(tim));
        _postStable_occ = IERC20(USDT).balanceOf(address(OCC_Modular_USDT));
        
        assertEq(_postDetails[3], block.timestamp - block.timestamp % 7 days + 9 days + _postDetails[6]);
        assertEq(_postDetails[9], 2);
        assertEq(_postStable_borrower - _preStable_borrower, _postDetails[0]);
        assertEq(_preStable_occ - _postStable_occ, _postDetails[0]);

    }

    // Validate callLoan() state changes.
    // Validate callLoan() restrictions.
    // This includes:
    //  - _msgSender() must be borrower
    //  - loans[id].state must equal LoanState.Active

    function test_OCC_Modular_callLoan_restrictions_msgSender(uint96 random, bool choice) public {

        (
            uint256 _loanID_DAI,
            uint256 _loanID_FRAX,
            uint256 _loanID_USDC,
            uint256 _loanID_USDT
        ) = simulateITO_and_createOffers_and_acceptOffers(random, choice);

        mint("DAI", address(bob), uint256(random));
        mint("FRAX", address(bob), uint256(random));
        mint("USDC", address(bob), uint256(random));
        mint("USDT", address(bob), uint256(random));

        assert(bob.try_approveToken(DAI, address(OCC_Modular_DAI), uint256(random)));
        assert(bob.try_approveToken(FRAX, address(OCC_Modular_FRAX), uint256(random)));
        assert(bob.try_approveToken(USDC, address(OCC_Modular_USDC), uint256(random)));
        assert(bob.try_approveToken(USDT, address(OCC_Modular_USDT), uint256(random)));

        // Can't callLoan() unless _msgSender() == borrower.
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCC_Modular::callLoan() _msgSender() != loans[id].borrower");
        OCC_Modular_DAI.callLoan(_loanID_DAI);
        hevm.stopPrank();

        assert(!bob.try_callLoan(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(!bob.try_callLoan(address(OCC_Modular_USDC), _loanID_USDC));
        assert(!bob.try_callLoan(address(OCC_Modular_USDT), _loanID_USDT));
    }

    function test_OCC_Modular_callLoan_restrictions_loanState(uint96 random, bool choice) public {

        (
            uint256 _loanID_DAI,
            uint256 _loanID_FRAX,
            uint256 _loanID_USDC,
            uint256 _loanID_USDT
        ) = simulateITO_and_createOffers_and_acceptOffers(random, choice);

        mint("DAI", address(bob), uint256(random));
        mint("FRAX", address(bob), uint256(random));
        mint("USDC", address(bob), uint256(random));
        mint("USDT", address(bob), uint256(random));

        assert(bob.try_approveToken(DAI, address(OCC_Modular_DAI), uint256(random)));
        assert(bob.try_approveToken(FRAX, address(OCC_Modular_FRAX), uint256(random)));
        assert(bob.try_approveToken(USDC, address(OCC_Modular_USDC), uint256(random)));
        assert(bob.try_approveToken(USDT, address(OCC_Modular_USDT), uint256(random)));

        _loanID_DAI = createRandomOffer(random, choice, DAI);
        _loanID_FRAX = createRandomOffer(random, choice, FRAX);
        _loanID_USDC = createRandomOffer(random, choice, USDC);
        _loanID_USDT = createRandomOffer(random, choice, USDT);

        // Can't callLoan() unless state = LoanState.active.
        hevm.startPrank(address(tim));
        hevm.expectRevert("OCC_Modular::callLoan() loans[id].state != LoanState.Active");
        OCC_Modular_DAI.callLoan(_loanID_DAI);
        hevm.stopPrank();

        assert(!tim.try_callLoan(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(!tim.try_callLoan(address(OCC_Modular_USDC), _loanID_USDC));
        assert(!tim.try_callLoan(address(OCC_Modular_USDT), _loanID_USDT));

    }

    function test_OCC_Modular_callLoan_state_DAI(uint96 random, bool choice) public {

        (uint256 _loanID_DAI,,,) = simulateITO_and_createOffers_and_acceptOffers(random, choice);

        // Pre-state DAI.
        (,, uint256[10] memory _preDetails) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        
        uint256 principalOwed = _preDetails[0];

        // 20% chance to make late callLoan() (warp ahead of time).
        if (principalOwed % 5 == 0) {
            hevm.warp(_preDetails[3] + random % 7776000); // Potentially up to 90 days late callLoan().
        }

        (, uint256 interestOwed, uint256 lateFee,) = OCC_Modular_DAI.amountOwed(_loanID_DAI);

        uint256[6] memory balanceData = [
            IERC20(DAI).balanceOf(address(DAO)),    // _preDAO_stable
            IERC20(DAI).balanceOf(address(DAO)),    // _postDAO_stable
            IERC20(DAI).balanceOf(address(YDL)),    // _preYDL_stable
            IERC20(DAI).balanceOf(address(YDL)),    // _postYDL_stable
            IERC20(DAI).balanceOf(address(tim)),    // _preTim_stable
            IERC20(DAI).balanceOf(address(tim))     // _postTim_stable
        ];

        assertEq(_preDetails[9], 2);

        // Check amountOwed() interest ...
        if (block.timestamp > _preDetails[3]) {
            // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS) +
            // loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
            assertEq(
                interestOwed + lateFee, 
                _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS) + 
                _preDetails[0] * (block.timestamp - _preDetails[3]) * (_preDetails[2]) / (86400 * 365 * BIPS)

            );
        }
        else {
            // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS)
            assertEq(
                interestOwed + lateFee, 
                _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS)
            );
        }

        hevm.expectEmit(true, false, false, true, address(OCC_Modular_DAI));
        emit LoanCalled(_loanID_DAI, principalOwed + interestOwed + lateFee, principalOwed, interestOwed, lateFee);
        assert(tim.try_callLoan(address(OCC_Modular_DAI), _loanID_DAI));

        // Post-state.
        (,, uint256[10] memory _postDetails) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        balanceData[1] = IERC20(DAI).balanceOf(address(DAO));
        balanceData[3] = IERC20(DAI).balanceOf(address(YDL));
        balanceData[5] = IERC20(DAI).balanceOf(address(tim));

        assertEq(balanceData[1] - balanceData[0], principalOwed);
        assertEq(balanceData[3] - balanceData[2], interestOwed + lateFee);
        assertEq(balanceData[4] - balanceData[5], principalOwed + interestOwed + lateFee);

        // details[0] = principalOwed
        // details[3] = paymentDueBy
        // details[4] = paymentsRemaining
        // details[6] = paymentInterval
        // details[9] = loanState

        assertEq(_postDetails[0], 0);
        assertEq(_postDetails[3], 0);
        assertEq(_postDetails[4], 0);
        assertEq(_postDetails[9], 3);
        
    }

    function test_OCC_Modular_callLoan_state_FRAX(uint96 random, bool choice) public {

        (, uint256 _loanID_FRAX,,) = simulateITO_and_createOffers_and_acceptOffers(random, choice);

        // Pre-state FRAX.
        (,, uint256[10] memory _preDetails) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        
        uint256 principalOwed = _preDetails[0];

        // 20% chance to make late callLoan() (warp ahead of time).
        if (principalOwed % 5 == 0) {
            hevm.warp(_preDetails[3] + random % 7776000); // Potentially up to 90 days late callLoan().
        }

        (, uint256 interestOwed, uint256 lateFee,) = OCC_Modular_FRAX.amountOwed(_loanID_FRAX);

        uint256[6] memory balanceData = [
            IERC20(FRAX).balanceOf(address(DAO)),               // _preDAO_stable
            IERC20(FRAX).balanceOf(address(DAO)),               // _postDAO_stable
            IERC20(FRAX).balanceOf(address(Treasury)),          // _prcOCT_stable
            IERC20(FRAX).balanceOf(address(Treasury)),          // _postOCT_stable
            IERC20(FRAX).balanceOf(address(tim)),               // _preTim_stable
            IERC20(FRAX).balanceOf(address(tim))                // _postTim_stable
        ];

        assertEq(_preDetails[9], 2);

        // Check amountOwed() interest ...
        if (block.timestamp > _preDetails[3]) {
            // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS) +
            // loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
            assertEq(
                interestOwed + lateFee, 
                _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS) + 
                _preDetails[0] * (block.timestamp - _preDetails[3]) * (_preDetails[2]) / (86400 * 365 * BIPS)

            );
        }
        else {
            // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS)
            assertEq(
                interestOwed + lateFee, 
                _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS)
            );
        }

        hevm.expectEmit(true, false, false, true, address(OCC_Modular_FRAX));
        emit LoanCalled(_loanID_FRAX, principalOwed + interestOwed + lateFee, principalOwed, interestOwed, lateFee);
        assert(tim.try_callLoan(address(OCC_Modular_FRAX), _loanID_FRAX));

        // Post-state.
        (,, uint256[10] memory _postDetails) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        balanceData[1] = IERC20(FRAX).balanceOf(address(DAO));
        balanceData[3] = IERC20(FRAX).balanceOf(address(Treasury));
        balanceData[5] = IERC20(FRAX).balanceOf(address(tim));

        assertEq(balanceData[1] - balanceData[0], principalOwed);
        assertEq(balanceData[3] - balanceData[2], interestOwed + lateFee);
        assertEq(balanceData[4] - balanceData[5], principalOwed + interestOwed + lateFee);

        // details[0] = principalOwed
        // details[3] = paymentDueBy
        // details[4] = paymentsRemaining
        // details[6] = paymentInterval
        // details[9] = loanState

        assertEq(_postDetails[0], 0);
        assertEq(_postDetails[3], 0);
        assertEq(_postDetails[4], 0);
        assertEq(_postDetails[9], 3);
        
    }

    function test_OCC_Modular_callLoan_state_USDC(uint96 random, bool choice) public {

        (,, uint256 _loanID_USDC,) = simulateITO_and_createOffers_and_acceptOffers(random, choice);

        // Pre-state USDC.
        (,, uint256[10] memory _preDetails) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        
        uint256 principalOwed = _preDetails[0];

        // 20% chance to make late callLoan() (warp ahead of time).
        if (principalOwed % 5 == 0) {
            hevm.warp(_preDetails[3] + random % 7776000); // Potentially up to 90 days late callLoan().
        }

        (, uint256 interestOwed, uint256 lateFee,) = OCC_Modular_USDC.amountOwed(_loanID_USDC);

        uint256[6] memory balanceData = [
            IERC20(USDC).balanceOf(address(DAO)),               // _preDAO_stable
            IERC20(USDC).balanceOf(address(DAO)),               // _postDAO_stable
            IERC20(USDC).balanceOf(address(Treasury)),          // _prcOCT_stable
            IERC20(USDC).balanceOf(address(Treasury)),          // _postOCT_stable
            IERC20(USDC).balanceOf(address(tim)),               // _preTim_stable
            IERC20(USDC).balanceOf(address(tim))                // _postTim_stable
        ];

        assertEq(_preDetails[9], 2);

        // Check amountOwed() interest ...
        if (block.timestamp > _preDetails[3]) {
            // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS) +
            // loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
            assertEq(
                interestOwed + lateFee, 
                _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS) + 
                _preDetails[0] * (block.timestamp - _preDetails[3]) * (_preDetails[2]) / (86400 * 365 * BIPS)

            );
        }
        else {
            // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS)
            assertEq(
                interestOwed + lateFee, 
                _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS)
            );
        }

        hevm.expectEmit(true, false, false, true, address(OCC_Modular_USDC));
        emit LoanCalled(_loanID_USDC, principalOwed + interestOwed + lateFee, principalOwed, interestOwed, lateFee);
        assert(tim.try_callLoan(address(OCC_Modular_USDC), _loanID_USDC));

        // Post-state.
        (,, uint256[10] memory _postDetails) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        balanceData[1] = IERC20(USDC).balanceOf(address(DAO));
        balanceData[3] = IERC20(USDC).balanceOf(address(Treasury));
        balanceData[5] = IERC20(USDC).balanceOf(address(tim));

        assertEq(balanceData[1] - balanceData[0], principalOwed);
        assertEq(balanceData[3] - balanceData[2], interestOwed + lateFee);
        assertEq(balanceData[4] - balanceData[5], principalOwed + interestOwed + lateFee);

        // details[0] = principalOwed
        // details[3] = paymentDueBy
        // details[4] = paymentsRemaining
        // details[6] = paymentInterval
        // details[9] = loanState

        assertEq(_postDetails[0], 0);
        assertEq(_postDetails[3], 0);
        assertEq(_postDetails[4], 0);
        assertEq(_postDetails[9], 3);
        
    }

    function test_OCC_Modular_callLoan_state_USDT(uint96 random, bool choice) public {

        (,,, uint256 _loanID_USDT) = simulateITO_and_createOffers_and_acceptOffers(random, choice);

        // Pre-state USDT.
        (,, uint256[10] memory _preDetails) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
        
        uint256 principalOwed = _preDetails[0];

        // 20% chance to make late callLoan() (warp ahead of time).
        if (principalOwed % 5 == 0) {
            hevm.warp(_preDetails[3] + random % 7776000); // Potentially up to 90 days late callLoan().
        }

        (, uint256 interestOwed, uint256 lateFee,) = OCC_Modular_USDT.amountOwed(_loanID_USDT);

        uint256[6] memory balanceData = [
            IERC20(USDT).balanceOf(address(DAO)),               // _preDAO_stable
            IERC20(USDT).balanceOf(address(DAO)),               // _postDAO_stable
            IERC20(USDT).balanceOf(address(Treasury)),          // _prcOCT_stable
            IERC20(USDT).balanceOf(address(Treasury)),          // _postOCT_stable
            IERC20(USDT).balanceOf(address(tim)),               // _preTim_stable
            IERC20(USDT).balanceOf(address(tim))                // _postTim_stable
        ];

        assertEq(_preDetails[9], 2);

        // Check amountOwed() interest ...
        if (block.timestamp > _preDetails[3]) {
            // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS) +
            // loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
            assertEq(
                interestOwed + lateFee, 
                _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS) + 
                _preDetails[0] * (block.timestamp - _preDetails[3]) * (_preDetails[2]) / (86400 * 365 * BIPS)

            );
        }
        else {
            // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS)
            assertEq(
                interestOwed + lateFee, 
                _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS)
            );
        }

        hevm.expectEmit(true, false, false, true, address(OCC_Modular_USDT));
        emit LoanCalled(_loanID_USDT, principalOwed + interestOwed + lateFee, principalOwed, interestOwed, lateFee);
        assert(tim.try_callLoan(address(OCC_Modular_USDT), _loanID_USDT));

        // Post-state.
        (,, uint256[10] memory _postDetails) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
        balanceData[1] = IERC20(USDT).balanceOf(address(DAO));
        balanceData[3] = IERC20(USDT).balanceOf(address(Treasury));
        balanceData[5] = IERC20(USDT).balanceOf(address(tim));

        assertEq(balanceData[1] - balanceData[0], principalOwed);
        assertEq(balanceData[3] - balanceData[2], interestOwed + lateFee);
        assertEq(balanceData[4] - balanceData[5], principalOwed + interestOwed + lateFee);

        // details[0] = principalOwed
        // details[3] = paymentDueBy
        // details[4] = paymentsRemaining
        // details[6] = paymentInterval
        // details[9] = loanState

        assertEq(_postDetails[0], 0);
        assertEq(_postDetails[3], 0);
        assertEq(_postDetails[4], 0);
        assertEq(_postDetails[9], 3);
        
    }

    // Validate cancelOffer() state changes.
    // Validate cancelOffer() restrictions.
    // This includes:
    //  - _msgSender() must equal underwriter
    //  - loans[id].state must equal LoanState.Initialized

    function test_OCC_Modular_cancelOffer_restrictions_msgSender(uint96 random, bool choice) public {

        uint256 amount = uint256(random);

        simulateITO(amount * WAD, amount * WAD, amount * USD, amount * USD);

        assert(god.try_push(address(DAO), address(OCC_Modular_DAI), DAI, amount, ""));
        assert(god.try_push(address(DAO), address(OCC_Modular_FRAX), FRAX, amount, ""));
        assert(god.try_push(address(DAO), address(OCC_Modular_USDC), USDC, amount, ""));
        assert(god.try_push(address(DAO), address(OCC_Modular_USDT), USDT, amount, ""));

        uint256 _loanID_DAI = createRandomOffer(random, choice, DAI);
        uint256 _loanID_FRAX = createRandomOffer(random, choice, FRAX);
        uint256 _loanID_USDC = createRandomOffer(random, choice, USDC);
        uint256 _loanID_USDT = createRandomOffer(random, choice, USDT);

        // Can't cancelOffer() unless _msgSender() == underwriter.
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCC_Modular::isUnderwriter() _msgSender() != underwriter");
        OCC_Modular_DAI.cancelOffer(_loanID_DAI);
        hevm.stopPrank();

        assert(!bob.try_cancelOffer(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(!bob.try_cancelOffer(address(OCC_Modular_USDC), _loanID_USDC));
        assert(!bob.try_cancelOffer(address(OCC_Modular_USDT), _loanID_USDT));
    }

    function test_OCC_Modular_cancelOffer_restrictions_loanState(uint96 random, bool choice) public {

        uint256 amount = uint256(random);

        simulateITO(amount * WAD, amount * WAD, amount * USD, amount * USD);

        assert(god.try_push(address(DAO), address(OCC_Modular_DAI), DAI, amount, ""));
        assert(god.try_push(address(DAO), address(OCC_Modular_FRAX), FRAX, amount, ""));
        assert(god.try_push(address(DAO), address(OCC_Modular_USDC), USDC, amount, ""));
        assert(god.try_push(address(DAO), address(OCC_Modular_USDT), USDT, amount, ""));

        uint256 _loanID_DAI = createRandomOffer(random, choice, DAI);
        uint256 _loanID_FRAX = createRandomOffer(random, choice, FRAX);
        uint256 _loanID_USDC = createRandomOffer(random, choice, USDC);
        uint256 _loanID_USDT = createRandomOffer(random, choice, USDT);

        // Accept two of these loans.
        man_acceptOffer(_loanID_DAI, DAI);
        man_acceptOffer(_loanID_FRAX, FRAX);

        // Cancel two of these loans (in advance) of restrictions check.
        assert(roy.try_cancelOffer(address(OCC_Modular_USDC), _loanID_USDC));
        assert(roy.try_cancelOffer(address(OCC_Modular_USDT), _loanID_USDT));

        // Can't cancelOffer() if state != LoanState.Initialized.
        hevm.startPrank(address(roy));
        hevm.expectRevert("OCC_Modular::cancelOffer() loans[id].state != LoanState.Initialized");
        OCC_Modular_DAI.cancelOffer(_loanID_DAI);
        hevm.stopPrank();   

        assert(!roy.try_cancelOffer(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(!roy.try_cancelOffer(address(OCC_Modular_USDC), _loanID_USDC));
        assert(!roy.try_cancelOffer(address(OCC_Modular_USDT), _loanID_USDT));
    }

    function test_OCC_Modular_cancelOffer_state(uint96 random, bool choice) public {
        
        uint256 _loanID_DAI = createRandomOffer(random, choice, DAI);
        uint256 _loanID_FRAX = createRandomOffer(random, choice, FRAX);
        uint256 _loanID_USDC = createRandomOffer(random, choice, USDC);
        uint256 _loanID_USDT = createRandomOffer(random, choice, USDT);

        // Pre-state.
        (,, uint256[10] memory details_DAI) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        (,, uint256[10] memory details_FRAX) = OCC_Modular_DAI.loanInfo(_loanID_FRAX);
        (,, uint256[10] memory details_USDC) = OCC_Modular_DAI.loanInfo(_loanID_USDC);
        (,, uint256[10] memory details_USDT) = OCC_Modular_DAI.loanInfo(_loanID_USDT);

        assertEq(details_DAI[9], 1);
        assertEq(details_FRAX[9], 1);
        assertEq(details_USDC[9], 1);
        assertEq(details_USDT[9], 1);

        hevm.expectEmit(true, false, false, false, address(OCC_Modular_DAI));
        emit OfferCancelled(_loanID_DAI);
        assert(roy.try_cancelOffer(address(OCC_Modular_DAI), _loanID_DAI));

        hevm.expectEmit(true, false, false, false, address(OCC_Modular_FRAX));
        emit OfferCancelled(_loanID_FRAX);
        assert(roy.try_cancelOffer(address(OCC_Modular_FRAX), _loanID_FRAX));

        hevm.expectEmit(true, false, false, false, address(OCC_Modular_USDC));
        emit OfferCancelled(_loanID_USDC);
        assert(roy.try_cancelOffer(address(OCC_Modular_USDC), _loanID_USDC));

        hevm.expectEmit(true, false, false, false, address(OCC_Modular_USDT));
        emit OfferCancelled(_loanID_USDT);
        assert(roy.try_cancelOffer(address(OCC_Modular_USDT), _loanID_USDT));

        // Post-state.
        (,, details_DAI) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        (,, details_FRAX) = OCC_Modular_DAI.loanInfo(_loanID_FRAX);
        (,, details_USDC) = OCC_Modular_DAI.loanInfo(_loanID_USDC);
        (,, details_USDT) = OCC_Modular_DAI.loanInfo(_loanID_USDT);

        // Post-state.
        assertEq(details_DAI[9], 5);
        assertEq(details_FRAX[9], 5);
        assertEq(details_USDC[9], 5);
        assertEq(details_USDT[9], 5);
    }

    // Validate state changes of createOffer() function.
    // Validate restrictions of createOffer() function.
    // Restrictions include:
    //  - term == 0
    //  - Invalid paymentInterval (only 5 valid options)
    //  - paymentSchedule != (0 || 1)
    //  - _msgSender() must be underwriter
    
    function test_OCC_Modular_createOffer_restrictions_term(uint96 random) public {

        uint256 borrowAmount = uint256(random);
        uint256 APR;
        uint256 APRLateFee;
        uint256 term;
        uint256 paymentInterval;
        uint256 gracePeriod;
        int8 paymentSchedule = 2;
        
        APR = uint256(random) % 5000;

        APRLateFee = uint256(random) % 5000;

        // Can't createOffer with term == 0.
        hevm.startPrank(address(roy));
        hevm.expectRevert("OCC_Modular::createOffer() term == 0");
        OCC_Modular_DAI.createOffer(
            address(tim), borrowAmount, APR, APRLateFee, term, paymentInterval, gracePeriod, paymentSchedule
        );
        hevm.stopPrank();
    }

    function test_OCC_Modular_createOffer_restrictions_underwriter(uint96 random) public {

        uint256 borrowAmount = uint256(random);
        uint256 APR;
        uint256 APRLateFee;
        uint256 term;
        uint256 paymentInterval;
        uint256 gracePeriod;
        int8 paymentSchedule = 2;

        APR = uint256(random) % 5000;
        APRLateFee = uint256(random) % 5000;
        term = uint256(random) % 100 + 1;

        // Can't createOffer with invalid paymentInterval (only 5 valid options).
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCC_Modular::isUnderwriter() _msgSender() != underwriter");
        OCC_Modular_DAI.createOffer(address(tim),
            borrowAmount, APR, APRLateFee, term, paymentInterval, gracePeriod, paymentSchedule
        );
        hevm.stopPrank();
    }

    function test_OCC_Modular_createOffer_restrictions_paymentInterval(uint96 random) public {

        uint256 borrowAmount = uint256(random);
        uint256 APR;
        uint256 APRLateFee;
        uint256 term;
        uint256 paymentInterval;
        uint256 gracePeriod;
        int8 paymentSchedule = 2;

        APR = uint256(random) % 5000;
        APRLateFee = uint256(random) % 5000;
        term = uint256(random) % 100 + 1;

        // Can't createOffer with invalid paymentInterval (only 5 valid options).
        hevm.startPrank(address(roy));
        hevm.expectRevert("OCC_Modular::createOffer() invalid paymentInterval value, try: 86400 * (7 || 14 || 28 || 91 || 364)");
        OCC_Modular_DAI.createOffer(
            address(tim), borrowAmount, APR, APRLateFee, term, paymentInterval, gracePeriod, paymentSchedule
        );
        hevm.stopPrank();
    }

    function test_OCC_Modular_createOffer_restrictions_paymentSchedule(uint96 random, bool choice) public {

        uint256 borrowAmount = uint256(random);
        uint256 APR;
        uint256 APRLateFee;
        uint256 term;
        uint256 paymentInterval;
        uint256 gracePeriod;
        int8 paymentSchedule = 2;
        
        APR = uint256(random) % 3601;
        APRLateFee = uint256(random) % 3601;
        term = uint256(random) % 100 + 1;
        paymentInterval = options[uint256(random) % 5];
        
        // Can't createOffer with invalid paymentSchedule (0 || 1).
        hevm.startPrank(address(roy));
        hevm.expectRevert("OCC_Modular::createOffer() paymentSchedule > 1");
        OCC_Modular_DAI.createOffer(
            address(tim), borrowAmount, APR, APRLateFee, term, paymentInterval, gracePeriod, paymentSchedule
        );
        hevm.stopPrank();

        paymentSchedule = choice ? int8(0) : int8(1);
    }

    function test_OCC_Modular_createOffer_state(uint96 random, bool choice, uint8 modularity) public {

        uint256 borrowAmount = uint256(random);
        uint256 APR = uint256(random) % 5000;
        uint256 APRLateFee = uint256(random) % 5000;
        uint256 term = uint256(random) % 25 + 1;
        uint256 gracePeriod = uint256(random) % 90 days;
        uint256 option = uint256(random) % 5;
        int8 paymentSchedule = choice ? int8(0) : int8(1);
        
        uint256 loanID;

        hevm.startPrank(address(roy));

        if (modularity % 4 == 0) {

            loanID = OCC_Modular_DAI.counterID();
            
            hevm.expectEmit(true, true, true, true, address(OCC_Modular_DAI));
            emit OfferCreated(
                address(this), loanID,
                borrowAmount, APR, APRLateFee, term, uint256(options[option]),
                block.timestamp + 2 weeks, gracePeriod, paymentSchedule
            );
            OCC_Modular_DAI.createOffer(
                address(this),
                borrowAmount,
                APR,
                APRLateFee,
                term,
                uint256(options[option]),
                gracePeriod,
                paymentSchedule
            );

            (
                address _borrower, 
                int8 _paymentSchedule, 
                uint256[10] memory _details
            ) = OCC_Modular_DAI.loanInfo(loanID);

            assertEq(_borrower, address(this));
            assertEq(paymentSchedule, _paymentSchedule);
            assertEq(_details[0], borrowAmount);
            assertEq(_details[1], APR);
            assertEq(_details[2], APRLateFee);
            assertEq(_details[3], 0);
            assertEq(_details[4], term);
            assertEq(_details[5], term);
            assertEq(_details[6], uint256(options[option]));
            assertEq(_details[7], block.timestamp + 14 days);
            assertEq(_details[8], gracePeriod);
            assertEq(_details[9], 1);

            assertEq(OCC_Modular_DAI.counterID(), loanID + 1);

        }

        if (modularity % 4 == 1) {

            loanID = OCC_Modular_FRAX.counterID();

            
            hevm.expectEmit(true, true, true, true, address(OCC_Modular_FRAX));
            emit OfferCreated(
                address(this), loanID,
                borrowAmount, APR, APRLateFee, term, uint256(options[option]),
                block.timestamp + 2 weeks, gracePeriod, paymentSchedule
            );
            OCC_Modular_FRAX.createOffer(
                address(this),
                borrowAmount,
                APR,
                APRLateFee,
                term,
                uint256(options[option]),
                gracePeriod,
                paymentSchedule
            );

            (
                address _borrower, 
                int8 _paymentSchedule, 
                uint256[10] memory _details
            ) = OCC_Modular_FRAX.loanInfo(loanID);

            assertEq(_borrower, address(this));
            assertEq(paymentSchedule, _paymentSchedule);
            assertEq(_details[0], borrowAmount);
            assertEq(_details[1], APR);
            assertEq(_details[2], APRLateFee);
            assertEq(_details[3], 0);
            assertEq(_details[4], term);
            assertEq(_details[5], term);
            assertEq(_details[6], uint256(options[option]));
            assertEq(_details[7], block.timestamp + 14 days);
            assertEq(_details[8], gracePeriod);
            assertEq(_details[9], 1);

            assertEq(OCC_Modular_FRAX.counterID(), loanID + 1);

        }

        if (modularity % 4 == 2) {

            loanID = OCC_Modular_USDC.counterID();

            hevm.expectEmit(true, true, true, true, address(OCC_Modular_USDC));
            emit OfferCreated(
                address(this), loanID,
                borrowAmount, APR, APRLateFee, term, uint256(options[option]),
                block.timestamp + 2 weeks, gracePeriod, paymentSchedule
            );
            OCC_Modular_USDC.createOffer(
                address(this),
                borrowAmount,
                APR,
                APRLateFee,
                term,
                uint256(options[option]),
                gracePeriod,
                paymentSchedule
            );

            (
                address _borrower, 
                int8 _paymentSchedule, 
                uint256[10] memory _details
            ) = OCC_Modular_USDC.loanInfo(loanID);

            assertEq(_borrower, address(this));
            assertEq(paymentSchedule, _paymentSchedule);
            assertEq(_details[0], borrowAmount);
            assertEq(_details[1], APR);
            assertEq(_details[2], APRLateFee);
            assertEq(_details[3], 0);
            assertEq(_details[4], term);
            assertEq(_details[5], term);
            assertEq(_details[6], uint256(options[option]));
            assertEq(_details[7], block.timestamp + 14 days);
            assertEq(_details[8], gracePeriod);
            assertEq(_details[9], 1);

            assertEq(OCC_Modular_USDC.counterID(), loanID + 1);

        }

        if (modularity % 4 == 3) {

            loanID = OCC_Modular_USDT.counterID();

            hevm.expectEmit(true, true, true, true, address(OCC_Modular_USDT));
            emit OfferCreated(
                address(this), loanID,
                borrowAmount, APR, APRLateFee, term, uint256(options[option]),
                block.timestamp + 2 weeks, gracePeriod, paymentSchedule
            );
            OCC_Modular_USDT.createOffer(
                address(this),
                borrowAmount,
                APR,
                APRLateFee,
                term,
                uint256(options[option]),
                gracePeriod,
                paymentSchedule
            );

            (
                address _borrower, 
                int8 _paymentSchedule, 
                uint256[10] memory _details
            ) = OCC_Modular_USDT.loanInfo(loanID);

            assertEq(_borrower, address(this));
            assertEq(paymentSchedule, _paymentSchedule);
            assertEq(_details[0], borrowAmount);
            assertEq(_details[1], APR);
            assertEq(_details[2], APRLateFee);
            assertEq(_details[3], 0);
            assertEq(_details[4], term);
            assertEq(_details[5], term);
            assertEq(_details[6], uint256(options[option]));
            assertEq(_details[7], block.timestamp + 14 days);
            assertEq(_details[8], gracePeriod);
            assertEq(_details[9], 1);

            assertEq(OCC_Modular_USDT.counterID(), loanID + 1);

        }

        hevm.stopPrank();
        
    }

    

    // Validate makePayment() state changes.
    // Validate makePayment() restrictions.
    // This includes:
    //  - loans[id].state must equal LoanState.Active

    function test_OCC_Modular_makePayment_restrictions_loanState(uint96 random, bool choice) public {
        
        (
            uint256 _loanID_DAI, 
            uint256 _loanID_FRAX, 
            uint256 _loanID_USDC, 
            uint256 _loanID_USDT 
        ) = simulateITO_and_createOffers(random, choice);

        uint256 amount = uint256(random);

        mint("DAI", address(tim), amount * 2);
        mint("FRAX", address(tim), amount * 2);
        mint("USDC", address(tim), amount * 2);
        mint("USDT", address(tim), amount * 2);

        assert(tim.try_approveToken(address(DAI), address(OCC_Modular_DAI), amount * 2));
        assert(tim.try_approveToken(address(FRAX), address(OCC_Modular_FRAX), amount * 2));
        assert(tim.try_approveToken(address(USDC), address(OCC_Modular_USDC), amount * 2));
        assert(tim.try_approveToken(address(USDT), address(OCC_Modular_USDT), amount * 2));

        // Can't make payment on loan if state != LoanState.Active (these loans aren't accepted).
        hevm.startPrank(address(tim));
        hevm.expectRevert("OCC_Modular::makePayment() loans[id].state != LoanState.Active");
        OCC_Modular_FRAX.makePayment(_loanID_DAI);
        hevm.stopPrank();

        assert(!tim.try_makePayment(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(!tim.try_makePayment(address(OCC_Modular_USDC), _loanID_USDC));
        assert(!tim.try_makePayment(address(OCC_Modular_USDT), _loanID_USDT));
    }

    function test_OCC_Modular_makePayment_state_DAI(uint96 random, bool choice) public {

        (uint256 _loanID_DAI,,,) = simulateITO_and_createOffers_and_acceptOffers(random, choice);

        (,, uint256[10] memory _preDetails) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        (,, uint256[10] memory _postDetails) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        (, int8 schedule,) = OCC_Modular_DAI.loanInfo(_loanID_DAI);

        uint256[6] memory balanceData = [
            IERC20(DAI).balanceOf(address(DAO)), // _preDAO_stable
            IERC20(DAI).balanceOf(address(DAO)), // _postDAO_stable
            IERC20(DAI).balanceOf(address(YDL)), // _preYDL_stable
            IERC20(DAI).balanceOf(address(YDL)), // _postYDL_stable
            IERC20(DAI).balanceOf(address(tim)), // _preTim_stable
            IERC20(DAI).balanceOf(address(tim))  // _postTim_stable
        ];

        (
            uint256 principalOwed,
            uint256 interestOwed,
            uint256 lateFeeOwed,
            uint256 totalOwed
        ) = OCC_Modular_DAI.amountOwed(_loanID_DAI);

        while(_postDetails[4] > 0) {
            
            // Pre-state.
            (principalOwed, interestOwed, lateFeeOwed, totalOwed) = OCC_Modular_DAI.amountOwed(_loanID_DAI);
            (,, _preDetails) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
            balanceData[0] = IERC20(DAI).balanceOf(address(DAO));
            balanceData[2] = IERC20(DAI).balanceOf(address(YDL));
            balanceData[4] = IERC20(DAI).balanceOf(address(tim));

            // details[0] = principalOwed
            // details[1] = APR
            // details[2] = APRLateFee
            // details[3] = paymentDueBy
            // details[4] = paymentsRemaining
            // details[6] = paymentInterval
            // details[9] = loanState

            // Check amountOwed() data ...
            assertEq(principalOwed + interestOwed + lateFeeOwed, totalOwed);
            if (schedule == int8(0)) {
                // Balloon payment structure.
                if (_preDetails[4] == 1) {
                    assertEq(principalOwed, _preDetails[0]);
                }
            }
            else {
                // Amortization payment structure.
                assertEq(principalOwed, _preDetails[0] / _preDetails[4]);
            }
            if (block.timestamp > _preDetails[3]) {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS) +
                // loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
                assertEq(
                    interestOwed + lateFeeOwed, 
                    _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS) + 
                    _preDetails[0] * (block.timestamp - _preDetails[3]) * (_preDetails[2]) / (86400 * 365 * BIPS)

                );
            }
            else {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS)
                assertEq(
                    interestOwed + lateFeeOwed, 
                    _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS)
                );
            }

            // Make payment.
            hevm.expectEmit(true, true, false, true, address(OCC_Modular_DAI));
            emit PaymentMade(_loanID_DAI, address(tim), totalOwed, principalOwed, interestOwed, lateFeeOwed, _preDetails[3] + _preDetails[6]);
            assert(tim.try_makePayment(address(OCC_Modular_DAI), _loanID_DAI));

            // Post-state.
            (,, _postDetails) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
            balanceData[1] = IERC20(DAI).balanceOf(address(DAO));
            balanceData[3] = IERC20(DAI).balanceOf(address(YDL));
            balanceData[5] = IERC20(DAI).balanceOf(address(tim));

            // details[0] = principalOwed
            // details[3] = paymentDueBy
            // details[4] = paymentsRemaining
            // details[6] = paymentInterval
            // details[9] = loanState

            // Check state changes.
            assertEq(_postDetails[0], _preDetails[0] - principalOwed);

            if (_postDetails[4] == 0) {
                assertEq(_postDetails[0], 0);
                assertEq(_postDetails[3], 0);
                assertEq(_postDetails[4], 0);
                assertEq(_postDetails[9], 3);
            }
            else {
                assertEq(_postDetails[3], _preDetails[3] + _preDetails[6]);
                assertEq(_postDetails[4], _preDetails[4] - 1);
                assertEq(_postDetails[9], 2);
            }

            assertEq(balanceData[1] - balanceData[0], principalOwed);
            assertEq(balanceData[3] - balanceData[2], interestOwed + lateFeeOwed);
            assertEq(balanceData[4] - balanceData[5], totalOwed);
            
            // Warp to next paymentDueBy.
            hevm.warp(_postDetails[3]);

            // 20% chance to make late payment (warp ahead of time).
            if (totalOwed % 5 == 0) {
                hevm.warp(_postDetails[3] + random % 7776000); // Potentially up to 90 days late payment.
            }
        }

    }

    function test_OCC_Modular_makePayment_state_FRAX(uint96 random, bool choice) public {

        (, uint256 _loanID_FRAX,,) = simulateITO_and_createOffers_and_acceptOffers(random, choice);

        (,, uint256[10] memory _preDetails) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        (,, uint256[10] memory _postDetails) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        (, int8 schedule,) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);

        uint256[6] memory balanceData = [
            IERC20(FRAX).balanceOf(address(DAO)),               // _preDAO_stable
            IERC20(FRAX).balanceOf(address(DAO)),               // _postDAO_stable
            IERC20(FRAX).balanceOf(address(Treasury)),          // _prcOCT_stable
            IERC20(FRAX).balanceOf(address(Treasury)),          // _postOCT_stable
            IERC20(FRAX).balanceOf(address(tim)),               // _preTim_stable
            IERC20(FRAX).balanceOf(address(tim))                // _postTim_stable
        ];

        (
            uint256 principalOwed, 
            uint256 interestOwed, 
            uint256 lateFeeOwed,
            uint256 totalOwed
        ) = OCC_Modular_FRAX.amountOwed(_loanID_FRAX);

        while(_postDetails[4] > 0) {
            
            // Pre-state.
            (principalOwed, interestOwed, lateFeeOwed, totalOwed) = OCC_Modular_FRAX.amountOwed(_loanID_FRAX);
            (,, _preDetails) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
            balanceData[0] = IERC20(FRAX).balanceOf(address(DAO));
            balanceData[2] = IERC20(FRAX).balanceOf(address(Treasury));
            balanceData[4] = IERC20(FRAX).balanceOf(address(tim));

            // details[0] = principalOwed
            // details[1] = APR
            // details[2] = APRLateFee
            // details[3] = paymentDueBy
            // details[4] = paymentsRemaining
            // details[6] = paymentInterval
            // details[9] = loanState

            // Check amountOwed() data ...
            assertEq(principalOwed + interestOwed + lateFeeOwed, totalOwed);
            if (schedule == int8(0)) {
                // Balloon payment structure.
                if (_preDetails[4] == 1) {
                    assertEq(principalOwed, _preDetails[0]);
                }
            }
            else {
                // Amortization payment structure.
                assertEq(principalOwed, _preDetails[0] / _preDetails[4]);
            }
            if (block.timestamp > _preDetails[3]) {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS) +
                // loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
                assertEq(
                    interestOwed + lateFeeOwed, 
                    _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS) + 
                    _preDetails[0] * (block.timestamp - _preDetails[3]) * (_preDetails[2]) / (86400 * 365 * BIPS)

                );
            }
            else {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS)
                assertEq(
                    interestOwed + lateFeeOwed, 
                    _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS)
                );
            }

            // Make payment.
            hevm.expectEmit(true, true, false, true, address(OCC_Modular_FRAX));
            emit PaymentMade(_loanID_FRAX, address(tim), totalOwed, principalOwed, interestOwed, lateFeeOwed, _preDetails[3] + _preDetails[6]);
            assert(tim.try_makePayment(address(OCC_Modular_FRAX), _loanID_FRAX));

            // Post-state.
            (,, _postDetails) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
            balanceData[1] = IERC20(FRAX).balanceOf(address(DAO));
            balanceData[3] = IERC20(FRAX).balanceOf(address(Treasury));
            balanceData[5] = IERC20(FRAX).balanceOf(address(tim));

            // details[0] = principalOwed
            // details[3] = paymentDueBy
            // details[4] = paymentsRemaining
            // details[6] = paymentInterval
            // details[9] = loanState

            assertEq(_postDetails[0], _preDetails[0] - principalOwed);

            if (_postDetails[4] == 0) {
                assertEq(_postDetails[0], 0);
                assertEq(_postDetails[3], 0);
                assertEq(_postDetails[4], 0);
                assertEq(_postDetails[9], 3);
            }
            else {
                assertEq(_postDetails[3], _preDetails[3] + _preDetails[6]);
                assertEq(_postDetails[4], _preDetails[4] - 1);
                assertEq(_postDetails[9], 2);
            }

            assertEq(balanceData[1] - balanceData[0], principalOwed);
            assertEq(balanceData[3] - balanceData[2], interestOwed + lateFeeOwed);
            assertEq(balanceData[4] - balanceData[5], totalOwed);
            
            // Warp to next paymentDueBy.
            hevm.warp(_postDetails[3]);

            // 20% chance to make late payment (warp ahead of time).
            if (totalOwed % 5 == 0) {
                hevm.warp(_postDetails[3] + random % 7776000); // Potentially up to 90 days late payment.
            }
        }

    }

    function test_OCC_Modular_makePayment_state_USDC(uint96 random, bool choice) public {

        (,, uint256 _loanID_USDC,) = simulateITO_and_createOffers_and_acceptOffers(random, choice);

        (,, uint256[10] memory _preDetails) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        (,, uint256[10] memory _postDetails) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        (, int8 schedule,) = OCC_Modular_USDC.loanInfo(_loanID_USDC);

        uint256[6] memory balanceData = [
            IERC20(USDC).balanceOf(address(DAO)),               // _preDAO_stable
            IERC20(USDC).balanceOf(address(DAO)),               // _postDAO_stable
            IERC20(USDC).balanceOf(address(Treasury)),          // _prcOCT_stable
            IERC20(USDC).balanceOf(address(Treasury)),          // _postOCT_stable
            IERC20(USDC).balanceOf(address(tim)),               // _preTim_stable
            IERC20(USDC).balanceOf(address(tim))                // _postTim_stable
        ];

        (
            uint256 principalOwed, 
            uint256 interestOwed, 
            uint256 lateFeeOwed,
            uint256 totalOwed
        ) = OCC_Modular_USDC.amountOwed(_loanID_USDC);

        while(_postDetails[4] > 0) {
            
            // Pre-state.
            (principalOwed, interestOwed, lateFeeOwed, totalOwed) = OCC_Modular_USDC.amountOwed(_loanID_USDC);
            (,, _preDetails) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
            balanceData[0] = IERC20(USDC).balanceOf(address(DAO));
            balanceData[2] = IERC20(USDC).balanceOf(address(Treasury));
            balanceData[4] = IERC20(USDC).balanceOf(address(tim));

            // details[0] = principalOwed
            // details[1] = APR
            // details[2] = APRLateFee
            // details[3] = paymentDueBy
            // details[4] = paymentsRemaining
            // details[6] = paymentInterval
            // details[9] = loanState

            // Check amountOwed() data ...
            assertEq(principalOwed + interestOwed + lateFeeOwed, totalOwed);
            if (schedule == int8(0)) {
                // Balloon payment structure.
                if (_preDetails[4] == 1) {
                    assertEq(principalOwed, _preDetails[0]);
                }
            }
            else {
                // Amortization payment structure.
                assertEq(principalOwed, _preDetails[0] / _preDetails[4]);
            }
            if (block.timestamp > _preDetails[3]) {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS) +
                // loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
                assertEq(
                    interestOwed + lateFeeOwed, 
                    _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS) + 
                    _preDetails[0] * (block.timestamp - _preDetails[3]) * (_preDetails[2]) / (86400 * 365 * BIPS)

                );
            }
            else {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS)
                assertEq(
                    interestOwed + lateFeeOwed, 
                    _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS)
                );
            }

            // Make payment.
            hevm.expectEmit(true, true, false, true, address(OCC_Modular_USDC));
            emit PaymentMade(_loanID_USDC, address(tim), totalOwed, principalOwed, interestOwed, lateFeeOwed, _preDetails[3] + _preDetails[6]);
            assert(tim.try_makePayment(address(OCC_Modular_USDC), _loanID_USDC));

            // Post-state.
            (,, _postDetails) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
            balanceData[1] = IERC20(USDC).balanceOf(address(DAO));
            balanceData[3] = IERC20(USDC).balanceOf(address(Treasury));
            balanceData[5] = IERC20(USDC).balanceOf(address(tim));

            // details[0] = principalOwed
            // details[3] = paymentDueBy
            // details[4] = paymentsRemaining
            // details[6] = paymentInterval
            // details[9] = loanState

            assertEq(_postDetails[0], _preDetails[0] - principalOwed);

            if (_postDetails[4] == 0) {
                assertEq(_postDetails[0], 0);
                assertEq(_postDetails[3], 0);
                assertEq(_postDetails[4], 0);
                assertEq(_postDetails[9], 3);
            }
            else {
                assertEq(_postDetails[3], _preDetails[3] + _preDetails[6]);
                assertEq(_postDetails[4], _preDetails[4] - 1);
                assertEq(_postDetails[9], 2);
            }
            
            assertEq(balanceData[1] - balanceData[0], principalOwed);
            assertEq(balanceData[3] - balanceData[2], interestOwed + lateFeeOwed);
            assertEq(balanceData[4] - balanceData[5], totalOwed);
            
            // Warp to next paymentDueBy.
            hevm.warp(_postDetails[3]);

            // 20% chance to make late payment (warp ahead of time).
            if (totalOwed % 5 == 0) {
                hevm.warp(_postDetails[3] + random % 7776000); // Potentially up to 90 days late payment.
            }
        }

    }

    function test_OCC_Modular_makePayment_state_USDT(uint96 random, bool choice) public {

        (,,, uint256 _loanID_USDT) = simulateITO_and_createOffers_and_acceptOffers(random, choice);

        (,, uint256[10] memory _preDetails) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
        (,, uint256[10] memory _postDetails) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
        (, int8 schedule,) = OCC_Modular_USDT.loanInfo(_loanID_USDT);

        uint256[6] memory balanceData = [
            IERC20(USDT).balanceOf(address(DAO)),               // _preDAO_stable
            IERC20(USDT).balanceOf(address(DAO)),               // _postDAO_stable
            IERC20(USDT).balanceOf(address(Treasury)),          // _prcOCT_stable
            IERC20(USDT).balanceOf(address(Treasury)),          // _postOCT_stable
            IERC20(USDT).balanceOf(address(tim)),               // _preTim_stable
            IERC20(USDT).balanceOf(address(tim))                // _postTim_stable
        ];

        (
            uint256 principalOwed, 
            uint256 interestOwed, 
            uint256 lateFeeOwed,
            uint256 totalOwed
        ) = OCC_Modular_USDT.amountOwed(_loanID_USDT);

        while(_postDetails[4] > 0) {
            
            // Pre-state.
            (principalOwed, interestOwed, lateFeeOwed, totalOwed) = OCC_Modular_USDT.amountOwed(_loanID_USDT);
            (,, _preDetails) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
            balanceData[0] = IERC20(USDT).balanceOf(address(DAO));
            balanceData[2] = IERC20(USDT).balanceOf(address(Treasury));
            balanceData[4] = IERC20(USDT).balanceOf(address(tim));

            // details[0] = principalOwed
            // details[1] = APR
            // details[2] = APRLateFee
            // details[3] = paymentDueBy
            // details[4] = paymentsRemaining
            // details[6] = paymentInterval
            // details[9] = loanState

            // Check amountOwed() data ...
            assertEq(principalOwed + interestOwed + lateFeeOwed, totalOwed);
            if (schedule == int8(0)) {
                // Balloon payment structure.
                if (_preDetails[4] == 1) {
                    assertEq(principalOwed, _preDetails[0]);
                }
            }
            else {
                // Amortization payment structure.
                assertEq(principalOwed, _preDetails[0] / _preDetails[4]);
            }
            if (block.timestamp > _preDetails[3]) {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS) +
                // loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
                assertEq(
                    interestOwed + lateFeeOwed, 
                    _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS) + 
                    _preDetails[0] * (block.timestamp - _preDetails[3]) * (_preDetails[2]) / (86400 * 365 * BIPS)

                );
            }
            else {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS)
                assertEq(
                    interestOwed + lateFeeOwed, 
                    _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS)
                );
            }

            // Make payment.
            hevm.expectEmit(true, true, false, true, address(OCC_Modular_USDT));
            emit PaymentMade(_loanID_USDT, address(tim), totalOwed, principalOwed, interestOwed, lateFeeOwed, _preDetails[3] + _preDetails[6]);
            assert(tim.try_makePayment(address(OCC_Modular_USDT), _loanID_USDT));

            // Post-state.
            (,, _postDetails) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
            balanceData[1] = IERC20(USDT).balanceOf(address(DAO));
            balanceData[3] = IERC20(USDT).balanceOf(address(Treasury));
            balanceData[5] = IERC20(USDT).balanceOf(address(tim));
            
            // details[0] = principalOwed
            // details[3] = paymentDueBy
            // details[4] = paymentsRemaining
            // details[6] = paymentInterval
            // details[9] = loanState

            assertEq(_postDetails[0], _preDetails[0] - principalOwed);

            if (_postDetails[4] == 0) {
                assertEq(_postDetails[0], 0);
                assertEq(_postDetails[3], 0);
                assertEq(_postDetails[4], 0);
                assertEq(_postDetails[9], 3);
            }
            else {
                assertEq(_postDetails[3], _preDetails[3] + _preDetails[6]);
                assertEq(_postDetails[4], _preDetails[4] - 1);
                assertEq(_postDetails[9], 2);
            }

            assertEq(balanceData[1] - balanceData[0], principalOwed);
            assertEq(balanceData[3] - balanceData[2], interestOwed + lateFeeOwed);
            assertEq(balanceData[4] - balanceData[5], totalOwed);
            
            // Warp to next paymentDueBy.
            hevm.warp(_postDetails[3]);

            // 20% chance to make late payment (warp ahead of time).
            if (totalOwed % 5 == 0) {
                hevm.warp(_postDetails[3] + random % 7776000); // Potentially up to 90 days late payment.
            }
        }

    }

    // Validate markDefault() state changes.
    // Validate markDefault() restrictions.
    // This includes:
    //  - loans[id].paymentDueBy + gracePeriod must be > block.timestamp
    //  - state of loan must be LoanState.Active
    //  - _msgSender() must be underwriter

    function test_OCC_Modular_markDefault_restrictions_underwriter(uint96 random, bool choice) public {

        (
            uint256 _loanID_DAI,
            uint256 _loanID_FRAX,
            uint256 _loanID_USDC,
            uint256 _loanID_USDT
        ) = simulateITO_and_createOffers(random, choice);

        // Can't call markDefault() if state != LoanState.Active.
        hevm.startPrank(address(tim));
        hevm.expectRevert("OCC_Modular::isUnderwriter() _msgSender() != underwriter");
        OCC_Modular_DAI.markDefault(_loanID_DAI);
        hevm.stopPrank();
        assert(!tim.try_markDefault(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(!tim.try_markDefault(address(OCC_Modular_USDC), _loanID_USDC));
        assert(!tim.try_markDefault(address(OCC_Modular_USDT), _loanID_USDT));

    }

    function test_OCC_Modular_markDefault_restrictions_loanState(uint96 random, bool choice) public {
       
        (
            uint256 _loanID_DAI,
            uint256 _loanID_FRAX,
            uint256 _loanID_USDC,
            uint256 _loanID_USDT
        ) = simulateITO_and_createOffers(random, choice);

        // Can't call markDefault() if state != LoanState.Active.
        hevm.startPrank(address(roy));
        hevm.expectRevert("OCC_Modular::markDefault() loans[id].state != LoanState.Active");
        OCC_Modular_DAI.markDefault(_loanID_DAI);
        hevm.stopPrank();
        assert(!roy.try_markDefault(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(!roy.try_markDefault(address(OCC_Modular_USDC), _loanID_USDC));
        assert(!roy.try_markDefault(address(OCC_Modular_USDT), _loanID_USDT));

    }

    function test_OCC_Modular_markDefault_restrictions_timing(uint96 random, bool choice) public {

        (
            uint256 _loanID_DAI,
            uint256 _loanID_FRAX,
            uint256 _loanID_USDC,
            uint256 _loanID_USDT
        ) = simulateITO_and_createOffers(random, choice);

        (
            _loanID_DAI,
            _loanID_FRAX,
            _loanID_USDC,
            _loanID_USDT
        ) = createOffers_and_acceptOffers(random, choice);

        // Can't call markDefault() if not pass paymentDueBy + gracePeriod.
        hevm.startPrank(address(roy));
        hevm.expectRevert("OCC_Modular::markDefault() loans[id].paymentDueBy + loans[id].gracePeriod >= block.timestamp");
        OCC_Modular_DAI.markDefault(_loanID_DAI);
        hevm.stopPrank();

        assert(!roy.try_markDefault(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(!roy.try_markDefault(address(OCC_Modular_USDC), _loanID_USDC));
        assert(!roy.try_markDefault(address(OCC_Modular_USDT), _loanID_USDT));

        (,, uint256[10] memory loanInfo) = OCC_Modular_DAI.loanInfo(_loanID_DAI);

        // Warp to actual time callable (same data for all loans).
        hevm.warp(loanInfo[3] + loanInfo[8] + 1 seconds);

        assert(roy.try_markDefault(address(OCC_Modular_DAI), _loanID_DAI));
        assert(roy.try_markDefault(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(roy.try_markDefault(address(OCC_Modular_USDC), _loanID_USDC));
        assert(roy.try_markDefault(address(OCC_Modular_USDT), _loanID_USDT));

    }

    function test_OCC_Modular_markDefault_state(uint96 random, bool choice) public {

        uint256 currentDefaults = GBL.defaults();

        (
            uint256 _loanID_DAI,
            uint256 _loanID_FRAX,
            uint256 _loanID_USDC,
            uint256 _loanID_USDT
        ) = simulateITO_and_createOffers_and_acceptOffers(random, choice);

        (,, uint256[10] memory loanInfo) = OCC_Modular_DAI.loanInfo(_loanID_DAI);

        // Warp to actual time callable (same data for all loans).
        hevm.warp(loanInfo[3] + loanInfo[8] + 1 seconds);

        // Pre-state, DAI.
        (,, loanInfo) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        assertEq(currentDefaults, 0);
        assertEq(loanInfo[9], 2);
        
        hevm.expectEmit(true, false, false, true, address(OCC_Modular_DAI));
        emit DefaultMarked(_loanID_DAI, loanInfo[0], currentDefaults, currentDefaults + loanInfo[0]);
        assert(roy.try_markDefault(address(OCC_Modular_DAI), _loanID_DAI));

        // Post-state, DAI.
        (,, loanInfo) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        assertEq(GBL.defaults(), currentDefaults + loanInfo[0]);
        assertEq(loanInfo[9], 4);

        currentDefaults = GBL.defaults();

        // Pre-state, FRAX.
        (,, loanInfo) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        assertEq(loanInfo[9], 2);

        hevm.expectEmit(true, false, false, true, address(OCC_Modular_FRAX));
        emit DefaultMarked(_loanID_FRAX, loanInfo[0], currentDefaults, currentDefaults + loanInfo[0]);
        assert(roy.try_markDefault(address(OCC_Modular_FRAX), _loanID_FRAX));

        // Post-state, FRAX.
        (,, loanInfo) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        assertEq(GBL.defaults(), currentDefaults + loanInfo[0]);
        assertEq(loanInfo[9], 4);

        currentDefaults = GBL.defaults();

        // Pre-state, USDC.
        (,, loanInfo) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        assertEq(loanInfo[9], 2);

        hevm.expectEmit(true, false, false, true, address(OCC_Modular_USDC));
        emit DefaultMarked(_loanID_USDC, loanInfo[0], currentDefaults, currentDefaults + GBL.standardize(loanInfo[0], USDC));
        assert(roy.try_markDefault(address(OCC_Modular_USDC), _loanID_USDC));

        // Post-state, USDC.
        (,, loanInfo) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        assertEq(GBL.defaults(), currentDefaults + GBL.standardize(loanInfo[0], USDC));
        assertEq(loanInfo[9], 4);

        currentDefaults = GBL.defaults();

        // Pre-state, USDT.
        (,, loanInfo) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
        assertEq(loanInfo[9], 2);

        hevm.expectEmit(true, false, false, true, address(OCC_Modular_USDT));
        emit DefaultMarked(_loanID_USDT, loanInfo[0], currentDefaults, currentDefaults + GBL.standardize(loanInfo[0], USDT));
        assert(roy.try_markDefault(address(OCC_Modular_USDT), _loanID_USDT));

        // Post-state, USDT.
        (,, loanInfo) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
        assertEq(GBL.defaults(), currentDefaults + GBL.standardize(loanInfo[0], USDT));
        assertEq(loanInfo[9], 4);

    }

    // Validate markRepaid() state changes.
    // Validate markRepaid() restrictions.
    // This includes:
    //  - _msgSender() must be underwriter
    //  - loans[id].state must equal LoanState.Resolved

    function test_OCC_Modular_markRepaid_restrictions_msgSender(uint96 random, bool choice) public {
        
        (
            uint256 _loanID_DAI,
            uint256 _loanID_FRAX,
            uint256 _loanID_USDC,
            uint256 _loanID_USDT
        ) = simulateITO_and_createOffers_and_acceptOffers_and_defaultLoans_and_resolveLoans(random, choice);

        // Can't call markRepaid() if _msgSender != underwriter.
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCC_Modular::isUnderwriter() _msgSender() != underwriter");
        OCC_Modular_DAI.markRepaid(_loanID_DAI);
        hevm.stopPrank();

        assert(!bob.try_markRepaid(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(!bob.try_markRepaid(address(OCC_Modular_USDC), _loanID_USDC));
        assert(!bob.try_markRepaid(address(OCC_Modular_USDT), _loanID_USDT));
    }

    function test_OCC_Modular_markRepaid_restrictions_loanState(uint96 random, bool choice) public {
        
        (
            uint256 _loanID_DAI,
            uint256 _loanID_FRAX,
            uint256 _loanID_USDC,
            uint256 _loanID_USDT
        ) = simulateITO_and_createOffers_and_acceptOffers_and_defaultLoans_and_resolveLoans(random, choice);

        _loanID_DAI = createRandomOffer(random, choice, DAI);
        _loanID_FRAX = createRandomOffer(random, choice, FRAX);
        _loanID_USDC = createRandomOffer(random, choice, USDC);
        _loanID_USDT = createRandomOffer(random, choice, USDT);

        // Can't call markRepaid() if state != LoanState.Resolved.
        hevm.startPrank(address(roy));
        hevm.expectRevert("OCC_Modular::markRepaid() loans[id].state != LoanState.Resolved");
        OCC_Modular_DAI.markRepaid(_loanID_DAI);
        hevm.stopPrank();

        assert(!roy.try_markRepaid(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(!roy.try_markRepaid(address(OCC_Modular_USDC), _loanID_USDC));
        assert(!roy.try_markRepaid(address(OCC_Modular_USDT), _loanID_USDT));

    }

    function test_OCC_Modular_markRepaid_state(uint96 random, bool choice) public {
        
        (
            uint256 _loanID_DAI,
            uint256 _loanID_FRAX,
            uint256 _loanID_USDC,
            uint256 _loanID_USDT
        ) = simulateITO_and_createOffers_and_acceptOffers_and_defaultLoans_and_resolveLoans(random, choice);

        // Pre-state.
        (,, uint256[10] memory _details_DAI) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        (,, uint256[10] memory _details_FRAX) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        (,, uint256[10] memory _details_USDC) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        (,, uint256[10] memory _details_USDT) = OCC_Modular_USDT.loanInfo(_loanID_USDT);

        assertEq(_details_DAI[9], 6);
        assertEq(_details_FRAX[9], 6);
        assertEq(_details_USDC[9], 6);
        assertEq(_details_USDT[9], 6);

        hevm.expectEmit(true, false, false, false, address(OCC_Modular_DAI));
        emit RepaidMarked(_loanID_DAI);
        assert(roy.try_markRepaid(address(OCC_Modular_DAI), _loanID_DAI));

        hevm.expectEmit(true, false, false, false, address(OCC_Modular_FRAX));
        emit RepaidMarked(_loanID_FRAX);
        assert(roy.try_markRepaid(address(OCC_Modular_FRAX), _loanID_FRAX));

        hevm.expectEmit(true, false, false, false, address(OCC_Modular_USDC));
        emit RepaidMarked(_loanID_USDC);
        assert(roy.try_markRepaid(address(OCC_Modular_USDC), _loanID_USDC));

        hevm.expectEmit(true, false, false, false, address(OCC_Modular_USDT));
        emit RepaidMarked(_loanID_USDT);
        assert(roy.try_markRepaid(address(OCC_Modular_USDT), _loanID_USDT));

        // Post-state.
        (,, _details_DAI) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        (,, _details_FRAX) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        (,, _details_USDC) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        (,, _details_USDT) = OCC_Modular_USDT.loanInfo(_loanID_USDT);

        assertEq(_details_DAI[9], 3);
        assertEq(_details_FRAX[9], 3);
        assertEq(_details_USDC[9], 3);
        assertEq(_details_USDT[9], 3);

    }


    // Validate processPayment() state changes.
    // Validate processPayment() restrictions.
    // This includes:
    //  - Can't call processPayment() unless state == LoanState.Active
    //  - Can't call processPayment() unless block.timestamp > nextPaymentDue

    function test_OCC_Modular_processPayment_restrictions_loanState(uint96 random, bool choice) public {
        
        (
            uint256 _loanID_DAI,
            uint256 _loanID_FRAX,
            uint256 _loanID_USDC,
            uint256 _loanID_USDT
        ) = simulateITO_and_createOffers(random, choice);

        // Can't call processPayment() unless state == LoanState.Active.
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCC_Modular::processPayment() loans[id].state != LoanState.Active");
        OCC_Modular_DAI.processPayment(_loanID_DAI);
        hevm.stopPrank();

        assert(!bob.try_processPayment(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(!bob.try_processPayment(address(OCC_Modular_USDC), _loanID_USDC));
        assert(!bob.try_processPayment(address(OCC_Modular_USDT), _loanID_USDT));
    }

    function test_OCC_Modular_processPayment_restrictions_nextPaymentDue(uint96 random, bool choice) public {
        
        (
            uint256 _loanID_DAI,
            uint256 _loanID_FRAX,
            uint256 _loanID_USDC,
            uint256 _loanID_USDT
        ) = simulateITO_and_createOffers(random, choice);

        (
            _loanID_DAI,
            _loanID_FRAX,
            _loanID_USDC,
            _loanID_USDT
        ) = createOffers_and_acceptOffers(random, choice);

        // Can't call processPayment() unless block.timestamp > nextPaymentDue.
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCC_Modular::processPayment() block.timestamp <= loans[id].paymentDueBy - 3 days");
        OCC_Modular_DAI.processPayment(_loanID_DAI);
        hevm.stopPrank();

        assert(!bob.try_processPayment(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(!bob.try_processPayment(address(OCC_Modular_USDC), _loanID_USDC));
        assert(!bob.try_processPayment(address(OCC_Modular_USDT), _loanID_USDT));
    }

    function test_OCC_Modular_processPayment_state_DAI(uint96 random, bool choice) public {

        (uint256 _loanID_DAI,,,) = simulateITO_and_createOffers_and_acceptOffers(random, choice);

        (,, uint256[10] memory _preDetails) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        (,, uint256[10] memory _postDetails) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        (, int8 schedule,) = OCC_Modular_DAI.loanInfo(_loanID_DAI);

        uint256[6] memory balanceData = [
            IERC20(DAI).balanceOf(address(DAO)), // _preDAO_stable
            IERC20(DAI).balanceOf(address(DAO)), // _postDAO_stable
            IERC20(DAI).balanceOf(address(YDL)), // _preYDL_stable
            IERC20(DAI).balanceOf(address(YDL)), // _postYDL_stable
            IERC20(DAI).balanceOf(address(tim)), // _preTim_stable
            IERC20(DAI).balanceOf(address(tim))  // _postTim_stable
        ];

        (
            uint256 principalOwed, 
            uint256 interestOwed, 
            uint256 lateFeeOwed,
            uint256 totalOwed
        ) = OCC_Modular_DAI.amountOwed(_loanID_DAI);

        hevm.warp(_preDetails[3] + 1 seconds);

        while(_postDetails[4] > 0) {
            
            // Pre-state.
            (principalOwed, interestOwed, lateFeeOwed, totalOwed) = OCC_Modular_DAI.amountOwed(_loanID_DAI);
            (,, _preDetails) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
            balanceData[0] = IERC20(DAI).balanceOf(address(DAO));
            balanceData[2] = IERC20(DAI).balanceOf(address(YDL));
            balanceData[4] = IERC20(DAI).balanceOf(address(tim));

            // details[0] = principalOwed
            // details[1] = APR
            // details[2] = APRLateFee
            // details[3] = paymentDueBy
            // details[4] = paymentsRemaining
            // details[6] = paymentInterval
            // details[9] = loanState

            // Check amountOwed() data ...
            assertEq(principalOwed + interestOwed + lateFeeOwed, totalOwed);
            if (schedule == int8(0)) {
                // Balloon payment structure.
                if (_preDetails[4] == 1) {
                    assertEq(principalOwed, _preDetails[0]);
                }
            }
            else {
                // Amortization payment structure.
                assertEq(principalOwed, _preDetails[0] / _preDetails[4]);
            }
            if (block.timestamp > _preDetails[3]) {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS) +
                // loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
                assertEq(
                    interestOwed + lateFeeOwed, 
                    _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS) + 
                    _preDetails[0] * (block.timestamp - _preDetails[3]) * (_preDetails[2]) / (86400 * 365 * BIPS)

                );
            }
            else {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS)
                assertEq(
                    interestOwed + lateFeeOwed, 
                    _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS)
                );
            }

            // Make payment.
            hevm.expectEmit(true, true, false, true, address(OCC_Modular_DAI));
            emit PaymentMade(_loanID_DAI, address(tim), principalOwed + interestOwed + lateFeeOwed, principalOwed, interestOwed, lateFeeOwed, _preDetails[3] + _preDetails[6]);
            OCC_Modular_DAI.processPayment(_loanID_DAI);

            // Post-state.
            (,, _postDetails) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
            balanceData[1] = IERC20(DAI).balanceOf(address(DAO));
            balanceData[3] = IERC20(DAI).balanceOf(address(YDL));
            balanceData[5] = IERC20(DAI).balanceOf(address(tim));
            
            // details[0] = principalOwed
            // details[3] = paymentDueBy
            // details[4] = paymentsRemaining
            // details[6] = paymentInterval
            // details[9] = loanState

            // Check state changes.
            assertEq(_postDetails[0], _preDetails[0] - principalOwed);

            if (_postDetails[4] == 0) {
                assertEq(_postDetails[0], 0);
                assertEq(_postDetails[3], 0);
                assertEq(_postDetails[4], 0);
                assertEq(_postDetails[9], 3);
            }
            else {
                assertEq(_postDetails[3], _preDetails[3] + _preDetails[6]);
                assertEq(_postDetails[4], _preDetails[4] - 1);
                assertEq(_postDetails[9], 2);
            }

            assertEq(balanceData[1] - balanceData[0], principalOwed);
            assertEq(balanceData[3] - balanceData[2], interestOwed + lateFeeOwed);
            assertEq(balanceData[4] - balanceData[5], totalOwed);
            
            // Warp to next paymentDueBy.
            hevm.warp(_postDetails[3] + 1 seconds);

            // 20% chance to make late payment (warp ahead of time).
            if (totalOwed % 5 == 0) {
                hevm.warp(_postDetails[3] + random % 7776000); // Potentially up to 90 days late payment.
            }
        }

    }

    function test_OCC_Modular_processPayment_state_FRAX(uint96 random, bool choice) public {

        (, uint256 _loanID_FRAX,,) = simulateITO_and_createOffers_and_acceptOffers(random, choice);

        (,, uint256[10] memory _preDetails) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        (,, uint256[10] memory _postDetails) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        (, int8 schedule,) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);

        uint256[6] memory balanceData = [
            IERC20(FRAX).balanceOf(address(DAO)),               // _preDAO_stable
            IERC20(FRAX).balanceOf(address(DAO)),               // _postDAO_stable
            IERC20(FRAX).balanceOf(address(Treasury)),          // _prcOCT_stable
            IERC20(FRAX).balanceOf(address(Treasury)),          // _postOCT_stable
            IERC20(FRAX).balanceOf(address(tim)),               // _preTim_stable
            IERC20(FRAX).balanceOf(address(tim))                // _postTim_stable
        ];

        (
            uint256 principalOwed, 
            uint256 interestOwed, 
            uint256 lateFeeOwed,
            uint256 totalOwed
        ) = OCC_Modular_FRAX.amountOwed(_loanID_FRAX);

        hevm.warp(_preDetails[3] + 1 seconds);

        while(_postDetails[4] > 0) {
            
            // Pre-state.
            (principalOwed, interestOwed, lateFeeOwed, totalOwed) = OCC_Modular_FRAX.amountOwed(_loanID_FRAX);
            (,, _preDetails) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
            balanceData[0] = IERC20(FRAX).balanceOf(address(DAO));
            balanceData[2] = IERC20(FRAX).balanceOf(address(Treasury));
            balanceData[4] = IERC20(FRAX).balanceOf(address(tim));

            // details[0] = principalOwed
            // details[1] = APR
            // details[2] = APRLateFee
            // details[3] = paymentDueBy
            // details[4] = paymentsRemaining
            // details[6] = paymentInterval
            // details[9] = loanState

            // Check amountOwed() data ...
            assertEq(principalOwed + interestOwed + lateFeeOwed, totalOwed);
            if (schedule == int8(0)) {
                // Balloon payment structure.
                if (_preDetails[4] == 1) {
                    assertEq(principalOwed, _preDetails[0]);
                }
            }
            else {
                // Amortization payment structure.
                assertEq(principalOwed, _preDetails[0] / _preDetails[4]);
            }
            if (block.timestamp > _preDetails[3]) {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS) +
                // loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
                assertEq(
                    interestOwed + lateFeeOwed, 
                    _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS) + 
                    _preDetails[0] * (block.timestamp - _preDetails[3]) * (_preDetails[2]) / (86400 * 365 * BIPS)

                );
            }
            else {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS)
                assertEq(
                    interestOwed + lateFeeOwed, 
                    _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS)
                );
            }

            // Make payment.
            hevm.expectEmit(true, true, false, true, address(OCC_Modular_FRAX));
            emit PaymentMade(_loanID_FRAX, address(tim), principalOwed + interestOwed + lateFeeOwed, principalOwed, interestOwed, lateFeeOwed, _preDetails[3] + _preDetails[6]);
            OCC_Modular_FRAX.processPayment(_loanID_FRAX);

            // Post-state.
            (,, _postDetails) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
            balanceData[1] = IERC20(FRAX).balanceOf(address(DAO));
            balanceData[3] = IERC20(FRAX).balanceOf(address(Treasury));
            balanceData[5] = IERC20(FRAX).balanceOf(address(tim));

            // details[0] = principalOwed
            // details[3] = paymentDueBy
            // details[4] = paymentsRemaining
            // details[6] = paymentInterval
            // details[9] = loanState

            assertEq(_postDetails[0], _preDetails[0] - principalOwed);

            if (_postDetails[4] == 0) {
                assertEq(_postDetails[0], 0);
                assertEq(_postDetails[3], 0);
                assertEq(_postDetails[4], 0);
                assertEq(_postDetails[9], 3);
            }
            else {
                assertEq(_postDetails[3], _preDetails[3] + _preDetails[6]);
                assertEq(_postDetails[4], _preDetails[4] - 1);
                assertEq(_postDetails[9], 2);
            }

            assertEq(balanceData[1] - balanceData[0], principalOwed);
            assertEq(balanceData[3] - balanceData[2], interestOwed + lateFeeOwed);
            assertEq(balanceData[4] - balanceData[5], totalOwed);
            
            // Warp to next paymentDueBy.
            hevm.warp(_postDetails[3] + 1 seconds);

            // 20% chance to make late payment (warp ahead of time).
            if (totalOwed % 5 == 0) {
                hevm.warp(_postDetails[3] + random % 7776000); // Potentially up to 90 days late payment.
            }
        }

    }

    function test_OCC_Modular_processPayment_state_USDC(uint96 random, bool choice) public {

        (,, uint256 _loanID_USDC,) = simulateITO_and_createOffers_and_acceptOffers(random, choice);

        (,, uint256[10] memory _preDetails) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        (,, uint256[10] memory _postDetails) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        (, int8 schedule,) = OCC_Modular_USDC.loanInfo(_loanID_USDC);

        uint256[6] memory balanceData = [
            IERC20(USDC).balanceOf(address(DAO)),               // _preDAO_stable
            IERC20(USDC).balanceOf(address(DAO)),               // _postDAO_stable
            IERC20(USDC).balanceOf(address(Treasury)),          // _prcOCT_stable
            IERC20(USDC).balanceOf(address(Treasury)),          // _postOCT_stable
            IERC20(USDC).balanceOf(address(tim)),               // _preTim_stable
            IERC20(USDC).balanceOf(address(tim))                // _postTim_stable
        ];

        (
            uint256 principalOwed, 
            uint256 interestOwed, 
            uint256 lateFeeOwed,
            uint256 totalOwed
        ) = OCC_Modular_USDC.amountOwed(_loanID_USDC);

        hevm.warp(_preDetails[3] + 1 seconds);

        while(_postDetails[4] > 0) {
            
            // Pre-state.
            (principalOwed, interestOwed, lateFeeOwed, totalOwed) = OCC_Modular_USDC.amountOwed(_loanID_USDC);
            (,, _preDetails) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
            balanceData[0] = IERC20(USDC).balanceOf(address(DAO));
            balanceData[2] = IERC20(USDC).balanceOf(address(Treasury));
            balanceData[4] = IERC20(USDC).balanceOf(address(tim));

            // details[0] = principalOwed
            // details[1] = APR
            // details[2] = APRLateFee
            // details[3] = paymentDueBy
            // details[4] = paymentsRemaining
            // details[6] = paymentInterval
            // details[9] = loanState

            // Check amountOwed() data ...
            assertEq(principalOwed + interestOwed + lateFeeOwed, totalOwed);
            if (schedule == int8(0)) {
                // Balloon payment structure.
                if (_preDetails[4] == 1) {
                    assertEq(principalOwed, _preDetails[0]);
                }
            }
            else {
                // Amortization payment structure.
                assertEq(principalOwed, _preDetails[0] / _preDetails[4]);
            }
            if (block.timestamp > _preDetails[3]) {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS) +
                // loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
                assertEq(
                    interestOwed + lateFeeOwed, 
                    _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS) + 
                    _preDetails[0] * (block.timestamp - _preDetails[3]) * (_preDetails[2]) / (86400 * 365 * BIPS)

                );
            }
            else {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS)
                assertEq(
                    interestOwed + lateFeeOwed, 
                    _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS)
                );
            }

            // Make payment.
            hevm.expectEmit(true, true, false, true, address(OCC_Modular_USDC));
            emit PaymentMade(_loanID_USDC, address(tim), principalOwed + interestOwed + lateFeeOwed, principalOwed, interestOwed, lateFeeOwed, _preDetails[3] + _preDetails[6]);
            OCC_Modular_USDC.processPayment(_loanID_USDC);

            // Post-state.
            (,, _postDetails) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
            balanceData[1] = IERC20(USDC).balanceOf(address(DAO));
            balanceData[3] = IERC20(USDC).balanceOf(address(Treasury));
            balanceData[5] = IERC20(USDC).balanceOf(address(tim));

            // details[0] = principalOwed
            // details[3] = paymentDueBy
            // details[4] = paymentsRemaining
            // details[6] = paymentInterval
            // details[9] = loanState

            assertEq(_postDetails[0], _preDetails[0] - principalOwed);

            if (_postDetails[4] == 0) {
                assertEq(_postDetails[0], 0);
                assertEq(_postDetails[3], 0);
                assertEq(_postDetails[4], 0);
                assertEq(_postDetails[9], 3);
            }
            else {
                assertEq(_postDetails[3], _preDetails[3] + _preDetails[6]);
                assertEq(_postDetails[4], _preDetails[4] - 1);
                assertEq(_postDetails[9], 2);
            }

            assertEq(balanceData[1] - balanceData[0], principalOwed);
            assertEq(balanceData[3] - balanceData[2], interestOwed + lateFeeOwed);
            assertEq(balanceData[4] - balanceData[5], totalOwed);
            
            // Warp to next paymentDueBy.
            hevm.warp(_postDetails[3] + 1 seconds);

            // 20% chance to make late payment (warp ahead of time).
            if (totalOwed % 5 == 0) {
                hevm.warp(_postDetails[3] + random % 7776000); // Potentially up to 90 days late payment.
            }
        }

    }

    function test_OCC_Modular_processPayment_state_USDT(uint96 random, bool choice) public {

        (,,, uint256 _loanID_USDT) = simulateITO_and_createOffers_and_acceptOffers(random, choice);

        (,, uint256[10] memory _preDetails) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
        (,, uint256[10] memory _postDetails) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
        (, int8 schedule,) = OCC_Modular_USDT.loanInfo(_loanID_USDT);

        uint256[6] memory balanceData = [
            IERC20(USDT).balanceOf(address(DAO)),               // _preDAO_stable
            IERC20(USDT).balanceOf(address(DAO)),               // _postDAO_stable
            IERC20(USDT).balanceOf(address(Treasury)),          // _prcOCT_stable
            IERC20(USDT).balanceOf(address(Treasury)),          // _postOCT_stable
            IERC20(USDT).balanceOf(address(tim)),               // _preTim_stable
            IERC20(USDT).balanceOf(address(tim))                // _postTim_stable
        ];

        (
            uint256 principalOwed, 
            uint256 interestOwed, 
            uint256 lateFeeOwed,
            uint256 totalOwed
        ) = OCC_Modular_USDT.amountOwed(_loanID_USDT);

        hevm.warp(_preDetails[3] + 1 seconds);

        while(_postDetails[4] > 0) {
            
            // Pre-state.
            (principalOwed, interestOwed, lateFeeOwed, totalOwed) = OCC_Modular_USDT.amountOwed(_loanID_USDT);
            (,, _preDetails) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
            balanceData[0] = IERC20(USDT).balanceOf(address(DAO));
            balanceData[2] = IERC20(USDT).balanceOf(address(Treasury));
            balanceData[4] = IERC20(USDT).balanceOf(address(tim));

            // details[0] = principalOwed
            // details[1] = APR
            // details[2] = APRLateFee
            // details[3] = paymentDueBy
            // details[4] = paymentsRemaining
            // details[6] = paymentInterval
            // details[9] = loanState

            // Check amountOwed() data ...
            assertEq(principalOwed + interestOwed + lateFeeOwed, totalOwed);
            if (schedule == int8(0)) {
                // Balloon payment structure.
                if (_preDetails[4] == 1) {
                    assertEq(principalOwed, _preDetails[0]);
                }
            }
            else {
                // Amortization payment structure.
                assertEq(principalOwed, _preDetails[0] / _preDetails[4]);
            }
            if (block.timestamp > _preDetails[3]) {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS) +
                // loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
                assertEq(
                    interestOwed + lateFeeOwed, 
                    _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS) + 
                    _preDetails[0] * (block.timestamp - _preDetails[3]) * (_preDetails[2]) / (86400 * 365 * BIPS)

                );
            }
            else {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS)
                assertEq(
                    interestOwed + lateFeeOwed, 
                    _preDetails[0] * _preDetails[6] * _preDetails[1] / (86400 * 365 * BIPS)
                );
            }

            // Make payment.
            hevm.expectEmit(true, true, false, true, address(OCC_Modular_USDT));
            emit PaymentMade(_loanID_USDT, address(tim), principalOwed + interestOwed + lateFeeOwed, principalOwed, interestOwed, lateFeeOwed, _preDetails[3] + _preDetails[6]);
            OCC_Modular_USDT.processPayment(_loanID_USDT);

            // Post-state.
            (,, _postDetails) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
            balanceData[1] = IERC20(USDT).balanceOf(address(DAO));
            balanceData[3] = IERC20(USDT).balanceOf(address(Treasury));
            balanceData[5] = IERC20(USDT).balanceOf(address(tim));
            
            // details[0] = principalOwed
            // details[3] = paymentDueBy
            // details[4] = paymentsRemaining
            // details[6] = paymentInterval
            // details[9] = loanState

            assertEq(_postDetails[0], _preDetails[0] - principalOwed);

            if (_postDetails[4] == 0) {
                assertEq(_postDetails[0], 0);
                assertEq(_postDetails[3], 0);
                assertEq(_postDetails[4], 0);
                assertEq(_postDetails[9], 3);
            }
            else {
                assertEq(_postDetails[3], _preDetails[3] + _preDetails[6]);
                assertEq(_postDetails[4], _preDetails[4] - 1);
                assertEq(_postDetails[9], 2);
            }

            assertEq(balanceData[1] - balanceData[0], principalOwed);
            assertEq(balanceData[3] - balanceData[2], interestOwed + lateFeeOwed);
            assertEq(balanceData[4] - balanceData[5], totalOwed);
            
            // Warp to next paymentDueBy.
            hevm.warp(_postDetails[3] + 1 seconds);

            // 20% chance to make late payment (warp ahead of time).
            if (totalOwed % 5 == 0) {
                hevm.warp(_postDetails[3] + random % 7776000); // Potentially up to 90 days late payment.
            }
        }

    }

    // Validate resolveDefault() state changes.
    // Validate resolveDefault() restrictions.
    // This includes:
    //  - loans[id].state must equal LoanState.Defaulted

    function test_OCC_Modular_resolveDefault_restrictions_loanState(uint96 random, bool choice) public {

        uint256 amount = uint256(random);
        
        (
            uint256 _loanID_DAI, 
            uint256 _loanID_FRAX, 
            uint256 _loanID_USDC, 
            uint256 _loanID_USDT 
        ) = simulateITO_and_createOffers(random, choice);

        mint("DAI", address(bob), amount);
        mint("FRAX", address(bob), amount);
        mint("USDC", address(bob), amount);
        mint("USDT", address(bob), amount);

        hevm.startPrank(address(bob));
        hevm.expectRevert("OCC_Modular::resolveDefaut() loans[id].state != LoanState.Defaulted");
        OCC_Modular_DAI.resolveDefault(_loanID_DAI, amount);
        hevm.stopPrank();

        assert(!bob.try_resolveDefault(address(OCC_Modular_FRAX), _loanID_FRAX, amount));
        assert(!bob.try_resolveDefault(address(OCC_Modular_USDC), _loanID_USDC, amount));
        assert(!bob.try_resolveDefault(address(OCC_Modular_USDT), _loanID_USDT, amount));

    }

    function test_OCC_Modular_resolveDefault_state(uint96 random, bool choice) public {
        
        (
            uint256 _loanID_DAI, 
            uint256 _loanID_FRAX, 
            uint256 _loanID_USDC, 
            uint256 _loanID_USDT
        ) = simulateITO_and_createOffers_and_acceptOffers_and_defaultLoans(random, choice);

        // Pre-state DAI, partial resolve.
        uint256 _preGlobalDefaults = GBL.defaults();
        (,, uint256[10] memory _preDetails) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        uint256 _preStable_DAO = IERC20(DAI).balanceOf(address(DAO));
        uint256 _preStable_tim = IERC20(DAI).balanceOf(address(tim));

        // Pay off 1/3rd of the default amount.
        hevm.expectEmit(true, true, false, true, address(OCC_Modular_DAI));
        emit DefaultResolved(_loanID_DAI, _preDetails[0] / 3, address(tim), _preDetails[0] == 0);
        assert(tim.try_resolveDefault(address(OCC_Modular_DAI), _loanID_DAI, _preDetails[0] / 3));

        // Post-state DAI, partial resolve.
        uint256 _postGlobalDefaults = GBL.defaults();
        (,, uint256[10] memory _postDetails) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        uint256 _postStable_DAO = IERC20(DAI).balanceOf(address(DAO));
        uint256 _postStable_tim = IERC20(DAI).balanceOf(address(tim));

        assertEq(_preGlobalDefaults - _postGlobalDefaults, GBL.standardize(_preDetails[0] / 3, DAI));
        assertEq(_preDetails[0] - _postDetails[0], _preDetails[0] / 3);
        assertEq(_preStable_tim - _postStable_tim, _preDetails[0] / 3);
        assertEq(_postStable_DAO - _preStable_DAO, _preDetails[0] / 3);

        // Note: In some cases, a low-amount loan (of 0 / 1) will transition state => Resolved 
        //       on 0 x-fer resolveDefault(), therefore we perform quick check here.
        if (_postDetails[9] != 6) {
            // Post-state DAI, full resolve.
            _preGlobalDefaults = GBL.defaults();
            (,, _preDetails) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
            _preStable_DAO = IERC20(DAI).balanceOf(address(DAO));
            _preStable_tim = IERC20(DAI).balanceOf(address(tim));

            // Pay off remaining amount.
            hevm.expectEmit(true, true, false, true, address(OCC_Modular_DAI));
            emit DefaultResolved(_loanID_DAI, _preDetails[0], address(tim), true);
            assert(tim.try_resolveDefault(address(OCC_Modular_DAI), _loanID_DAI, _preDetails[0]));

            // Post-state DAI, full resolve.
            _postGlobalDefaults = GBL.defaults();
            (,, _postDetails) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
            _postStable_DAO = IERC20(DAI).balanceOf(address(DAO));
            _postStable_tim = IERC20(DAI).balanceOf(address(tim));

            assertEq(_preGlobalDefaults - _postGlobalDefaults, GBL.standardize(_preDetails[0], DAI));
            assertEq(_preDetails[0] - _postDetails[0], _preDetails[0]);
            assertEq(_preStable_tim - _postStable_tim, _preDetails[0]);
            assertEq(_postStable_DAO - _preStable_DAO, _preDetails[0]);
            assertEq(_postDetails[9], 6);
        }

        // Pre-state FRAX, partial resolve.
        _preGlobalDefaults = GBL.defaults();
        (,, _preDetails) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        _preStable_DAO = IERC20(FRAX).balanceOf(address(DAO));
        _preStable_tim = IERC20(FRAX).balanceOf(address(tim));

        // Pay off 1/3rd of the default amount.
        hevm.expectEmit(true, true, false, true, address(OCC_Modular_FRAX));
        emit DefaultResolved(_loanID_FRAX, _preDetails[0] / 3, address(tim), _preDetails[0] == 0);
        assert(tim.try_resolveDefault(address(OCC_Modular_FRAX), _loanID_FRAX, _preDetails[0] / 3));

        // Post-state FRAX, partial resolve.
        _postGlobalDefaults = GBL.defaults();
        (,, _postDetails) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        _postStable_DAO = IERC20(FRAX).balanceOf(address(DAO));
        _postStable_tim = IERC20(FRAX).balanceOf(address(tim));

        assertEq(_preGlobalDefaults - _postGlobalDefaults, GBL.standardize(_preDetails[0] / 3, FRAX));
        assertEq(_preDetails[0] - _postDetails[0], _preDetails[0] / 3);
        assertEq(_preStable_tim - _postStable_tim, _preDetails[0] / 3);
        assertEq(_postStable_DAO - _preStable_DAO, _preDetails[0] / 3);

        // Note: In some cases, a low-amount loan (of 0 / 1) will transition state => Resolved 
        //       on 0 x-fer resolveDefault(), therefore we perform quick check here.
        if (_postDetails[9] != 6) {
            // Post-state FRAX, full resolve.
            _preGlobalDefaults = GBL.defaults();
            (,, _preDetails) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
            _preStable_DAO = IERC20(FRAX).balanceOf(address(DAO));
            _preStable_tim = IERC20(FRAX).balanceOf(address(tim));

            // Pay off remaining amount.
            hevm.expectEmit(true, true, false, true, address(OCC_Modular_FRAX));
            emit DefaultResolved(_loanID_FRAX, _preDetails[0], address(tim), true);
            assert(tim.try_resolveDefault(address(OCC_Modular_FRAX), _loanID_FRAX, _preDetails[0]));

            // Post-state FRAX, full resolve.
            _postGlobalDefaults = GBL.defaults();
            (,, _postDetails) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
            _postStable_DAO = IERC20(FRAX).balanceOf(address(DAO));
            _postStable_tim = IERC20(FRAX).balanceOf(address(tim));

            assertEq(_preGlobalDefaults - _postGlobalDefaults, GBL.standardize(_preDetails[0], FRAX));
            assertEq(_preDetails[0] - _postDetails[0], _preDetails[0]);
            assertEq(_preStable_tim - _postStable_tim, _preDetails[0]);
            assertEq(_postStable_DAO - _preStable_DAO, _preDetails[0]);
            assertEq(_postDetails[9], 6);
        }

        // Pre-state USDC, partial resolve.
        _preGlobalDefaults = GBL.defaults();
        (,, _preDetails) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        _preStable_DAO = IERC20(USDC).balanceOf(address(DAO));
        _preStable_tim = IERC20(USDC).balanceOf(address(tim));

        // Pay off 1/3rd of the default amount.
        hevm.expectEmit(true, true, false, true, address(OCC_Modular_USDC));
        emit DefaultResolved(_loanID_USDC, _preDetails[0] / 3, address(tim), _preDetails[0] == 0);
        assert(tim.try_resolveDefault(address(OCC_Modular_USDC), _loanID_USDC, _preDetails[0] / 3));

        // Post-state USDC, partial resolve.
        _postGlobalDefaults = GBL.defaults();
        (,, _postDetails) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        _postStable_DAO = IERC20(USDC).balanceOf(address(DAO));
        _postStable_tim = IERC20(USDC).balanceOf(address(tim));

        assertEq(_preGlobalDefaults - _postGlobalDefaults, GBL.standardize(_preDetails[0] / 3, USDC));
        assertEq(_preDetails[0] - _postDetails[0], _preDetails[0] / 3);
        assertEq(_preStable_tim - _postStable_tim, _preDetails[0] / 3);
        assertEq(_postStable_DAO - _preStable_DAO, _preDetails[0] / 3);

        // Note: In some cases, a low-amount loan (of 0 / 1) will transition state => Resolved 
        //       on 0 x-fer resolveDefault(), therefore we perform quick check here.
        if (_postDetails[9] != 6) {
            // Post-state USDC, full resolve.
            _preGlobalDefaults = GBL.defaults();
            (,, _preDetails) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
            _preStable_DAO = IERC20(USDC).balanceOf(address(DAO));
            _preStable_tim = IERC20(USDC).balanceOf(address(tim));

            // Pay off remaining amount.
            hevm.expectEmit(true, true, false, true, address(OCC_Modular_USDC));
            emit DefaultResolved(_loanID_USDC, _preDetails[0], address(tim), true);
            assert(tim.try_resolveDefault(address(OCC_Modular_USDC), _loanID_USDC, _preDetails[0]));

            // Post-state USDC, full resolve.
            _postGlobalDefaults = GBL.defaults();
            (,, _postDetails) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
            _postStable_DAO = IERC20(USDC).balanceOf(address(DAO));
            _postStable_tim = IERC20(USDC).balanceOf(address(tim));

            assertEq(_preGlobalDefaults - _postGlobalDefaults, GBL.standardize(_preDetails[0], USDC));
            assertEq(_preDetails[0] - _postDetails[0], _preDetails[0]);
            assertEq(_preStable_tim - _postStable_tim, _preDetails[0]);
            assertEq(_postStable_DAO - _preStable_DAO, _preDetails[0]);
            assertEq(_postDetails[9], 6);
        }

        // Pre-state USDT, partial resolve.
        _preGlobalDefaults = GBL.defaults();
        (,, _preDetails) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
        _preStable_DAO = IERC20(USDT).balanceOf(address(DAO));
        _preStable_tim = IERC20(USDT).balanceOf(address(tim));

        // Pay off 1/3rd of the default amount.
        hevm.expectEmit(true, true, false, true, address(OCC_Modular_USDT));
        emit DefaultResolved(_loanID_USDT, _preDetails[0] / 3, address(tim), _preDetails[0] == 0);
        assert(tim.try_resolveDefault(address(OCC_Modular_USDT), _loanID_USDT, _preDetails[0] / 3));

        // Post-state USDT, partial resolve.
        _postGlobalDefaults = GBL.defaults();
        (,, _postDetails) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
        _postStable_DAO = IERC20(USDT).balanceOf(address(DAO));
        _postStable_tim = IERC20(USDT).balanceOf(address(tim));

        assertEq(_preGlobalDefaults - _postGlobalDefaults, GBL.standardize(_preDetails[0] / 3, USDT));
        assertEq(_preDetails[0] - _postDetails[0], _preDetails[0] / 3);
        assertEq(_preStable_tim - _postStable_tim, _preDetails[0] / 3);
        assertEq(_postStable_DAO - _preStable_DAO, _preDetails[0] / 3);

        // Note: In some cases, a low-amount loan (of 0 / 1) will transition state => Resolved 
        //       on 0 x-fer resolveDefault(), therefore we perform quick check here.
        if (_postDetails[9] != 6) {
            // Post-state USDT, full resolve.
            _preGlobalDefaults = GBL.defaults();
            (,, _preDetails) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
            _preStable_DAO = IERC20(USDT).balanceOf(address(DAO));
            _preStable_tim = IERC20(USDT).balanceOf(address(tim));

            // Pay off remaining amount.
            hevm.expectEmit(true, true, false, true, address(OCC_Modular_USDT));
            emit DefaultResolved(_loanID_USDT, _preDetails[0], address(tim), true);
            assert(tim.try_resolveDefault(address(OCC_Modular_USDT), _loanID_USDT, _preDetails[0]));

            // Post-state USDT, full resolve.
            _postGlobalDefaults = GBL.defaults();
            (,, _postDetails) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
            _postStable_DAO = IERC20(USDT).balanceOf(address(DAO));
            _postStable_tim = IERC20(USDT).balanceOf(address(tim));

            assertEq(_preGlobalDefaults - _postGlobalDefaults, GBL.standardize(_preDetails[0], USDT));
            assertEq(_preDetails[0] - _postDetails[0], _preDetails[0]);
            assertEq(_preStable_tim - _postStable_tim, _preDetails[0]);
            assertEq(_postStable_DAO - _preStable_DAO, _preDetails[0]);
            assertEq(_postDetails[9], 6);
        }

    }

    // Validate setOCTYDL() state changes.
    // Validate setOCTYDL() restrictions.
    // This includes:
    //   - _msgSender() must be ZVL

    function test_OCC_Modular_setOCTYDL_restrictions_msgSender() public {
        // Can't call if _msgSender() is not ZVL.
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCC_Modular::setOCTYDL() _msgSender() != IZivoeGlobals_OCC(GBL).ZVL()");
        OCC_Modular_DAI.setOCTYDL(address(bob));
        hevm.stopPrank();
    }

    function test_OCC_Modular_setOCTYDL_state(address fuzzed) public {
        
        // Pre-state.
        assertEq(OCC_Modular_DAI.OCT_YDL(), address(Treasury));

        // setOCTYDL().
        hevm.expectEmit(true, true, false, false, address(OCC_Modular_DAI));
        emit OCTYDLSetZVL(address(fuzzed), address(Treasury));
        hevm.startPrank(address(zvl));
        OCC_Modular_DAI.setOCTYDL(address(fuzzed));
        hevm.stopPrank();

        // Post-state.
        assertEq(OCC_Modular_DAI.OCT_YDL(), address(fuzzed));

    }

    // Validate supplyInterest() state changes.
    // Validate supplyInterest() restrictions.
    // This includes:
    //  - loans[id].state must equal LoanState.Resolved

    function test_OCC_Modular_supplyInterest_restrictions_loanState(uint96 random, bool choice) public {
        
        (
            uint256 _loanID_DAI,
            uint256 _loanID_FRAX,
            uint256 _loanID_USDC,
            uint256 _loanID_USDT
        ) = simulateITO_and_createOffers_and_acceptOffers(random, choice);

        mint("DAI", address(bob), uint256(random));
        mint("FRAX", address(bob), uint256(random));
        mint("USDC", address(bob), uint256(random));
        mint("USDT", address(bob), uint256(random));

        // Can't call supplyInterest() unless state == LoanState.Resolved.
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCC_Modular::supplyInterest() loans[id].state != LoanState.Resolved");
        OCC_Modular_DAI.supplyInterest(_loanID_DAI, uint256(random));
        hevm.stopPrank();

        assert(!bob.try_supplyInterest(address(OCC_Modular_FRAX), _loanID_FRAX, uint256(random)));
        assert(!bob.try_supplyInterest(address(OCC_Modular_USDC), _loanID_USDC, uint256(random)));
        assert(!bob.try_supplyInterest(address(OCC_Modular_USDT), _loanID_USDT, uint256(random)));
    }

    function test_OCC_Modular_supplyInterest_state(uint96 random, bool choice) public {

        uint256 amount = uint256(random);

        (
            uint256 _loanID_DAI,
            uint256 _loanID_FRAX,
            uint256 _loanID_USDC,
            uint256 _loanID_USDT
        ) = simulateITO_and_createOffers_and_acceptOffers_and_defaultLoans_and_resolveLoans(random, choice);

        {
            // Pre-state DAI.
            uint256 _preStable_YDL = IERC20(DAI).balanceOf(address(YDL));
            uint256 _preStable_tim = IERC20(DAI).balanceOf(address(tim));

            hevm.expectEmit(true, true, false, true, address(OCC_Modular_DAI));
            emit InterestSupplied(_loanID_DAI, amount, address(tim));
            assert(tim.try_supplyInterest(address(OCC_Modular_DAI), _loanID_DAI, amount));

            // Post-state DAI.
            uint256 _postStable_YDL = IERC20(DAI).balanceOf(address(YDL));
            uint256 _postStable_tim = IERC20(DAI).balanceOf(address(tim));

            assertEq(_postStable_YDL - _preStable_YDL, amount);
            assertEq(_preStable_tim - _postStable_tim, amount);
        }

        {
            // Pre-state FRAX.
            uint256 _preStable_OCT = IERC20(FRAX).balanceOf(address(Treasury));
            uint256 _preStable_tim = IERC20(FRAX).balanceOf(address(tim));

            hevm.expectEmit(true, true, false, true, address(OCC_Modular_FRAX));
            emit InterestSupplied(_loanID_FRAX, amount, address(tim));
            assert(tim.try_supplyInterest(address(OCC_Modular_FRAX), _loanID_FRAX, amount));

            // Post-state FRAX.
            uint256 _postStable_OCT = IERC20(FRAX).balanceOf(address(Treasury));
            uint256 _postStable_tim = IERC20(FRAX).balanceOf(address(tim));

            assertEq(_postStable_OCT - _preStable_OCT, amount);
            assertEq(_preStable_tim - _postStable_tim, amount);
        }

        {
            // Pre-state USDC.
            uint256 _preStable_OCT = IERC20(USDC).balanceOf(address(Treasury));
            uint256 _preStable_tim = IERC20(USDC).balanceOf(address(tim));

            hevm.expectEmit(true, true, false, true, address(OCC_Modular_USDC));
            emit InterestSupplied(_loanID_USDC, amount, address(tim));
            assert(tim.try_supplyInterest(address(OCC_Modular_USDC), _loanID_USDC, amount));

            // Post-state USDC.
            uint256 _postStable_OCT = IERC20(USDC).balanceOf(address(Treasury));
            uint256 _postStable_tim = IERC20(USDC).balanceOf(address(tim));

            assertEq(_postStable_OCT - _preStable_OCT, amount);
            assertEq(_preStable_tim - _postStable_tim, amount);
        }
        
        {
            // Pre-state USDT.
            uint256 _preStable_OCT = IERC20(USDT).balanceOf(address(Treasury));
            uint256 _preStable_tim = IERC20(USDT).balanceOf(address(tim));

            hevm.expectEmit(true, true, false, true, address(OCC_Modular_USDT));
            emit InterestSupplied(_loanID_USDT, amount, address(tim));
            assert(tim.try_supplyInterest(address(OCC_Modular_USDT), _loanID_USDT, amount));

            // Post-state USDT.
            uint256 _postStable_OCT = IERC20(USDT).balanceOf(address(Treasury));
            uint256 _postStable_tim = IERC20(USDT).balanceOf(address(tim));

            assertEq(_postStable_OCT - _preStable_OCT, amount);
            assertEq(_preStable_tim - _postStable_tim, amount);
        }

    }

    // Validate applyCombine() state changes.
    // Validate applyCombine() restrictions.
    // This includes:
    //  - paymentInterval must be approved
    //  - length > 1 (more than 2 loans supplied)
    //  - each loan supplied, _msgSender() is borrower
    //  - each loan supplied, state == LoanState.Active

    function test_OCC_Modular_applyCombine_restrictions_approved(uint96 random, bool choice) public {

        simulateITO_and_createOffers(random, choice);
        createRandomOffer(random, choice, DAI);

        uint[] memory ids = new uint[](2);
        ids[0] = 0;
        ids[1] = 1;

        hevm.startPrank(address(tim));
        hevm.expectRevert("OCC_Modular::applyCombine() !combinations[_msgSender()][paymentInterval] == 0");
        OCC_Modular_DAI.applyCombine(ids, 86400 * 14);
        hevm.stopPrank();
    }

    function test_OCC_Modular_applyCombine_restrictions_length(uint96 random, bool choice) public {
        
        simulateITO_and_createOffers(random, choice);
        createRandomOffer(random, choice, DAI);

        assert(roy.try_approveCombine(address(OCC_Modular_DAI), address(tim), 86400 * 14, 24));

        uint[] memory ids = new uint[](1);
        ids[0] = 0;

        hevm.startPrank(address(tim));
        hevm.expectRevert("OCC_Modular::applyCombine() ids.length <= 1");
        OCC_Modular_DAI.applyCombine(ids, 86400 * 14);
        hevm.stopPrank();
    }

    function test_OCC_Modular_applyCombine_restrictions_borrower(uint96 random, bool choice) public {
        
        simulateITO_and_createOffers(random, choice);
        createRandomOffer(random, choice, DAI);

        assert(roy.try_approveCombine(address(OCC_Modular_DAI), address(tim), 86400 * 14, 24));
        assert(roy.try_approveCombine(address(OCC_Modular_DAI), address(sam), 86400 * 14, 24));

        // NOTE: These two loan IDs, borrower == address(tim)
        uint[] memory ids = new uint[](2);
        ids[0] = 0;
        ids[1] = 1;

        hevm.startPrank(address(sam));
        hevm.expectRevert("OCC_Modular::applyCombine() _msgSender() != loans[ids[i]].borrower");
        OCC_Modular_DAI.applyCombine(ids, 86400 * 14);
        hevm.stopPrank();
    }

    function test_OCC_Modular_applyCombine_restrictions_loanState(uint96 random, bool choice) public {
        
        simulateITO_and_createOffers(random, choice);
        createRandomOffer(random, choice, DAI);

        assert(roy.try_cancelOffer(address(OCC_Modular_DAI), 0));
        assert(roy.try_approveCombine(address(OCC_Modular_DAI), address(tim), 86400 * 14, 24));

        uint[] memory ids = new uint[](2);
        ids[0] = 0;
        ids[1] = 1;

        hevm.startPrank(address(tim));
        hevm.expectRevert("OCC_Modular::applyCombine() loans[ids]i]].state != LoanState.Active");
        OCC_Modular_DAI.applyCombine(ids, 86400 * 14);
        hevm.stopPrank();
    }


    function test_OCC_Modular_applyCombine_twoLoans_state(uint96 random, bool choice) public {

        simulateITO_and_createOffers(random, choice);
        createRandomOffer(random, choice, DAI);

        assert(roy.try_approveCombine(address(OCC_Modular_DAI), address(tim), 86400 * 14, 24));

        uint[] memory ids = new uint[](2);
        ids[0] = 0;
        ids[1] = 1;

        man_acceptOffer(0, DAI);
        man_acceptOffer(1, DAI);

        (,, uint256[10] memory preDetails_0) = OCC_Modular_DAI.loanInfo(0);
        (,, uint256[10] memory preDetails_1) = OCC_Modular_DAI.loanInfo(1);

        assertEq(OCC_Modular_DAI.counterID(), 2);
        assertEq(OCC_Modular_DAI.viewCombinations(address(tim), 14 * 86400), 24);

        hevm.startPrank(address(tim));
        OCC_Modular_DAI.applyCombine(ids, 86400 * 14);
        hevm.stopPrank();

        (,, uint256[10] memory postDetails_0) = OCC_Modular_DAI.loanInfo(0);
        (,, uint256[10] memory postDetails_1) = OCC_Modular_DAI.loanInfo(1);
        (address borrower, int8 paymentSchedule, uint256[10] memory postDetails_2) = OCC_Modular_DAI.loanInfo(2);

        assertEq(OCC_Modular_DAI.counterID(), 3);
        assertEq(OCC_Modular_DAI.viewCombinations(address(tim), 14 * 86400), 0);

        // Loan ID #0 (combined into Loan ID #2)
        {
            assertEq(postDetails_0[0], 0); // principalOwed
            assertEq(postDetails_0[3], 0); // paymentDueBy
            assertEq(postDetails_0[4], 0); // paymentsRemaining
            assertEq(postDetails_0[9], 7); // loanState (7 => combined)
        }

        // Loan ID #1 (Combined into Loan ID #2)
        {
            assertEq(postDetails_1[0], 0); // principalOwed
            assertEq(postDetails_1[3], 0); // paymentDueBy
            assertEq(postDetails_1[4], 0); // paymentsRemaining
            assertEq(postDetails_1[9], 7); // loanState (7 => combined)
        }
        
        // Loan ID #2
        {
            assertEq(postDetails_2[0], preDetails_0[0] + preDetails_1[0]); // principalOwed
            assertEq(
                postDetails_2[1], 
                (preDetails_0[0] * preDetails_0[1] + preDetails_1[0] *  preDetails_1[1]) / (preDetails_0[0] + preDetails_1[0]) % 10000
            ); // APR
            assertEq(postDetails_2[2], postDetails_2[1]); // APRLateFee == APR
            assertEq(postDetails_2[3], block.timestamp - block.timestamp % 7 days + 9 days + postDetails_2[6]); // paymentDueBy
            assertEq(postDetails_2[4], 24); // paymentsRemaining
            assertEq(postDetails_2[5], 24); // term
            assertEq(postDetails_2[6], 86400 * 14); // paymentInterval
            assertEq(postDetails_2[7], block.timestamp - 1 days); // paymentInterval
            assertEq(postDetails_2[8], 86400 * 14); // gracePeriod
            assertEq(postDetails_2[9], 2); // loanState (2 => active)

            assertEq(borrower, address(tim));
            assertEq(paymentSchedule, int8(0));
        }
    }

    function test_OCC_Modular_applyCombine_threeLoans_state(uint96 random, bool choice) public {

        simulateITO_and_createOffers(random, choice);
        createRandomOffer(random, choice, DAI);
        createRandomOffer(random, choice, DAI);

        assert(roy.try_approveCombine(address(OCC_Modular_DAI), address(tim), 86400 * 14, 24));

        uint[] memory ids = new uint[](3);
        ids[0] = 0;
        ids[1] = 1;
        ids[2] = 2;

        man_acceptOffer(0, DAI);
        man_acceptOffer(1, DAI);
        man_acceptOffer(2, DAI);

        (,, uint256[10] memory preDetails_0) = OCC_Modular_DAI.loanInfo(0);
        (,, uint256[10] memory preDetails_1) = OCC_Modular_DAI.loanInfo(1);
        (,, uint256[10] memory preDetails_2) = OCC_Modular_DAI.loanInfo(2);

        assertEq(OCC_Modular_DAI.counterID(), 3);
        assertEq(OCC_Modular_DAI.viewCombinations(address(tim), 14 * 86400), 24);

        hevm.startPrank(address(tim));
        OCC_Modular_DAI.applyCombine(ids, 86400 * 14);
        hevm.stopPrank();

        (,, uint256[10] memory postDetails_0) = OCC_Modular_DAI.loanInfo(0);
        (,, uint256[10] memory postDetails_1) = OCC_Modular_DAI.loanInfo(1);
        (,, uint256[10] memory postDetails_2) = OCC_Modular_DAI.loanInfo(2);
        (address borrower, int8 paymentSchedule, uint256[10] memory postDetails_3) = OCC_Modular_DAI.loanInfo(3);

        assertEq(OCC_Modular_DAI.counterID(), 4);
        assertEq(OCC_Modular_DAI.viewCombinations(address(tim), 14 * 86400), 0);

        // Loan ID #0 (combined into Loan ID #3)
        {
            assertEq(postDetails_0[0], 0); // principalOwed
            assertEq(postDetails_0[3], 0); // paymentDueBy
            assertEq(postDetails_0[4], 0); // paymentsRemaining
            assertEq(postDetails_0[9], 7); // loanState (7 => combined)
        }

        // Loan ID #1 (Combined into Loan ID #3)
        {
            assertEq(postDetails_1[0], 0); // principalOwed
            assertEq(postDetails_1[3], 0); // paymentDueBy
            assertEq(postDetails_1[4], 0); // paymentsRemaining
            assertEq(postDetails_1[9], 7); // loanState (7 => combined)
        }

        // Loan ID #2 (Combined into Loan ID #3)
        {
            assertEq(postDetails_2[0], 0); // principalOwed
            assertEq(postDetails_2[3], 0); // paymentDueBy
            assertEq(postDetails_2[4], 0); // paymentsRemaining
            assertEq(postDetails_2[9], 7); // loanState (7 => combined)
        }

        uint upper = preDetails_0[0] * preDetails_0[1] + preDetails_1[0] *  preDetails_1[1] + preDetails_2[0] * preDetails_2[1];
        uint lower = preDetails_0[0] + preDetails_1[0] + preDetails_2[0];
        
        // Loan ID #3
        {
            assertEq(postDetails_3[0], preDetails_0[0] + preDetails_1[0] + preDetails_2[0]); // principalOwed
            assertEq(
                postDetails_3[1], 
                upper / lower % 10000
            ); // APR
            assertEq(postDetails_3[2], postDetails_3[1]); // APRLateFee == APR
            assertEq(postDetails_3[3], block.timestamp - block.timestamp % 7 days + 9 days + postDetails_3[6]); // paymentDueBy
            assertEq(postDetails_3[4], 24); // paymentsRemaining
            assertEq(postDetails_3[5], 24); // term
            assertEq(postDetails_3[6], 86400 * 14); // paymentInterval
            assertEq(postDetails_3[7], block.timestamp - 1 days); // paymentInterval
            assertEq(postDetails_3[8], 86400 * 14); // gracePeriod
            assertEq(postDetails_3[9], 2); // loanState (2 => active)

            assertEq(borrower, address(tim));
            assertEq(paymentSchedule, int8(0));
        }

    }

    function test_OCC_Modular_applyCombine_fourLoans_state(uint96 random, bool choice) public {
        
        simulateITO_and_createOffers(random, choice);
        createRandomOffer(random, choice, DAI);
        createRandomOffer(random, choice, DAI);
        createRandomOffer(random, choice, DAI);

        assert(roy.try_approveCombine(address(OCC_Modular_DAI), address(tim), 86400 * 14, 24));

        uint[] memory ids = new uint[](4);
        ids[0] = 0;
        ids[1] = 1;
        ids[2] = 2;
        ids[3] = 3;

        man_acceptOffer(0, DAI);
        man_acceptOffer(1, DAI);
        man_acceptOffer(2, DAI);
        man_acceptOffer(3, DAI);

        (,, uint256[10] memory preDetails_0) = OCC_Modular_DAI.loanInfo(0);
        (,, uint256[10] memory preDetails_1) = OCC_Modular_DAI.loanInfo(1);
        (,, uint256[10] memory preDetails_2) = OCC_Modular_DAI.loanInfo(2);
        (,, uint256[10] memory preDetails_3) = OCC_Modular_DAI.loanInfo(3);

        assertEq(OCC_Modular_DAI.counterID(), 4);
        assertEq(OCC_Modular_DAI.viewCombinations(address(tim), 14 * 86400), 24);

        hevm.startPrank(address(tim));
        OCC_Modular_DAI.applyCombine(ids, 86400 * 14);
        hevm.stopPrank();

        (,, uint256[10] memory postDetails_0) = OCC_Modular_DAI.loanInfo(0);
        (,, uint256[10] memory postDetails_1) = OCC_Modular_DAI.loanInfo(1);
        (,, uint256[10] memory postDetails_2) = OCC_Modular_DAI.loanInfo(2);
        (,, uint256[10] memory postDetails_3) = OCC_Modular_DAI.loanInfo(3);
        (address borrower, int8 paymentSchedule, uint256[10] memory postDetails_4) = OCC_Modular_DAI.loanInfo(4);

        assertEq(OCC_Modular_DAI.counterID(), 5);
        assertEq(OCC_Modular_DAI.viewCombinations(address(tim), 14 * 86400), 0);

        // Loan ID #0 (combined into Loan ID #4)
        {
            assertEq(postDetails_0[0], 0); // principalOwed
            assertEq(postDetails_0[3], 0); // paymentDueBy
            assertEq(postDetails_0[4], 0); // paymentsRemaining
            assertEq(postDetails_0[9], 7); // loanState (7 => combined)
        }

        // Loan ID #1 (Combined into Loan ID #4)
        {
            assertEq(postDetails_1[0], 0); // principalOwed
            assertEq(postDetails_1[3], 0); // paymentDueBy
            assertEq(postDetails_1[4], 0); // paymentsRemaining
            assertEq(postDetails_1[9], 7); // loanState (7 => combined)
        }

        // Loan ID #2 (Combined into Loan ID #4)
        {
            assertEq(postDetails_2[0], 0); // principalOwed
            assertEq(postDetails_2[3], 0); // paymentDueBy
            assertEq(postDetails_2[4], 0); // paymentsRemaining
            assertEq(postDetails_2[9], 7); // loanState (7 => combined)
        }

        // Loan ID #3 (Combined into Loan ID #4)
        {
            assertEq(postDetails_3[0], 0); // principalOwed
            assertEq(postDetails_3[3], 0); // paymentDueBy
            assertEq(postDetails_3[4], 0); // paymentsRemaining
            assertEq(postDetails_3[9], 7); // loanState (7 => combined)
        }

        uint upper = preDetails_0[0] * preDetails_0[1] + preDetails_1[0] * preDetails_1[1] + preDetails_2[0] * preDetails_2[1] + preDetails_3[0] *  preDetails_3[1];
        uint lower = preDetails_0[0] + preDetails_1[0] + preDetails_2[0] + preDetails_3[0];
        
        // Loan ID #2
        {
            assertEq(postDetails_4[0], lower); // principalOwed
            assertEq(
                postDetails_4[1], 
                upper / lower % 10000
            ); // APR
            assertEq(postDetails_4[2], postDetails_4[1]); // APRLateFee == APR
            assertEq(postDetails_4[3], block.timestamp - block.timestamp % 7 days + 9 days + postDetails_4[6]); // paymentDueBy
            assertEq(postDetails_4[4], 24); // paymentsRemaining
            assertEq(postDetails_4[5], 24); // term
            assertEq(postDetails_4[6], 86400 * 14); // paymentInterval
            assertEq(postDetails_4[7], block.timestamp - 1 days); // paymentInterval
            assertEq(postDetails_4[8], 86400 * 14); // gracePeriod
            assertEq(postDetails_4[9], 2); // loanState (2 => active)

            assertEq(borrower, address(tim));
            assertEq(paymentSchedule, int8(0));
        }

    }

    // Validate applyConversionAmortization() state changes.
    // Validate applyConversionAmortization() restrictions.
    // This includes:
    //  - _msgSender() is borrower of loan
    //  - loan has been approved for conversion


    function test_OCC_Modular_applyConversionAmortization_restrictions_borrower(uint96 random) public {
        
        simulateITO_and_createOffers(random, true);   // true = Bullet loans

        man_acceptOffer(0, DAI);

        // approveConversionAmortization().
        hevm.startPrank(address(roy));
        OCC_Modular_DAI.approveConversionAmortization(0);
        hevm.stopPrank();

        // applyConversionAmortization()
        hevm.startPrank(address(sam));
        hevm.expectRevert("OCC_Modular::applyConversionAmortization() _msgSender() != loans[id].borrower");
        OCC_Modular_DAI.applyConversionAmortization(0);
        hevm.stopPrank();

    }

    function test_OCC_Modular_applyConversionAmortization_restrictions_approved(uint96 random) public {
        
        simulateITO_and_createOffers(random, true);   // true = Bullet loans

        man_acceptOffer(0, DAI);

        // approveConversionAmortization().
        // hevm.startPrank(address(roy));
        // OCC_Modular_DAI.approveConversionAmortization(0);
        // hevm.stopPrank();

        // applyConversionAmortization()
        hevm.startPrank(address(tim));
        hevm.expectRevert("OCC_Modular::applyConversionAmortization() !conversionAmortization[id]");
        OCC_Modular_DAI.applyConversionAmortization(0);
        hevm.stopPrank();
        
    }

    function test_OCC_Modular_applyConversionAmortization_state(uint96 random) public {
        
        simulateITO_and_createOffers(random, true);   // true = Bullet loans

        man_acceptOffer(0, DAI);

        (, int8 paymentStructure, ) = OCC_Modular_DAI.loanInfo(0);

        // Pre-state.
        assertEq(paymentStructure, int8(0));

        // approveConversionAmortization().
        hevm.startPrank(address(roy));
        OCC_Modular_DAI.approveConversionAmortization(0);
        hevm.stopPrank();

        // applyConversionAmortization().
        hevm.startPrank(address(tim));
        hevm.expectEmit(true, false, false, false, address(OCC_Modular_DAI));
        emit ConversionAmortizationApplied(0);
        OCC_Modular_DAI.applyConversionAmortization(0);
        hevm.stopPrank();
        
        // Post-state.
        (, paymentStructure, ) = OCC_Modular_DAI.loanInfo(0);

        assertEq(paymentStructure, int8(1));
    }

    // Validate applyConversionBullet() state changes.
    // Validate applyConversionBullet() restrictions.
    // This includes:
    //  - _msgSender() is borrower of loan
    //  - loan has been approved for conversion

    function test_OCC_Modular_applyConversionBullet_restrictions_borrower(uint96 random) public {

        simulateITO_and_createOffers(random, false);   // false = Amortization loans

        man_acceptOffer(0, DAI);

        // approveConversionBullet().
        hevm.startPrank(address(roy));
        OCC_Modular_DAI.approveConversionBullet(0);
        hevm.stopPrank();

        // applyConversionBullet()
        hevm.startPrank(address(sam));
        hevm.expectRevert("OCC_Modular::applyConversionBullet() _msgSender() != loans[id].borrower");
        OCC_Modular_DAI.applyConversionBullet(0);
        hevm.stopPrank();

    }

    function test_OCC_Modular_applyConversionBullet_restrictions_approved(uint96 random) public {
        
        simulateITO_and_createOffers(random, false);   // false = Amortization loans

        man_acceptOffer(0, DAI);

        // approveConversionBullet().
        // hevm.startPrank(address(roy));
        // OCC_Modular_DAI.approveConversionBullet(0);
        // hevm.stopPrank();

        // applyConversionBullet()
        hevm.startPrank(address(tim));
        hevm.expectRevert("OCC_Modular::applyConversionBullet() !conversionBullet[id]");
        OCC_Modular_DAI.applyConversionBullet(0);
        hevm.stopPrank();

    }

    function test_OCC_Modular_applyConversionBullet_state(uint96 random) public {
        
        simulateITO_and_createOffers(random, false);   // false = Amortization loans

        man_acceptOffer(0, DAI);

        // approveConversionBullet().
        hevm.startPrank(address(roy));
        OCC_Modular_DAI.approveConversionBullet(0);
        hevm.stopPrank();

        (, int8 paymentStructure, ) = OCC_Modular_DAI.loanInfo(0);

        // Pre-state.
        assertEq(paymentStructure, int8(1));

        // applyConversionBullet().
        hevm.startPrank(address(tim));
        hevm.expectEmit(true, false, false, false, address(OCC_Modular_DAI));
        emit ConversionBulletApplied(0);
        OCC_Modular_DAI.applyConversionBullet(0);
        hevm.stopPrank();
        
        // Post-state.
        (, paymentStructure, ) = OCC_Modular_DAI.loanInfo(0);

        assertEq(paymentStructure, int8(0));
    }

    // Validate applyExtension() state changes.
    // Validate applyExtension() restrictions.
    // This includes:
    //  - _msgSender() is borrower of loan
    //  - supplied extensions ("intervals") amount is >= approved extensions

    function test_OCC_Modular_applyExtension_restrictions_borrower(uint96 random, bool choice, uint intervals) public {
        
        simulateITO_and_createOffers(random, choice);

        man_acceptOffer(0, DAI);

        // approveExtension().
        hevm.startPrank(address(roy));
        OCC_Modular_DAI.approveExtension(0, intervals);
        hevm.stopPrank();

        // applyExtension()
        hevm.startPrank(address(sam));
        hevm.expectRevert("OCC_Modular::applyExtension() _msgSender() != loans[id].borrower");
        OCC_Modular_DAI.applyExtension(0, 1);
        hevm.stopPrank();

    }

    function test_OCC_Modular_applyExtension_restrictions_approved(uint96 random, bool choice) public {

        simulateITO_and_createOffers(random, choice);

        man_acceptOffer(0, DAI);

        // approveExtension().
        // hevm.startPrank(address(roy));
        // OCC_Modular_DAI.approveExtension(id, intervals);
        // hevm.stopPrank();

        // applyExtension()
        hevm.startPrank(address(tim));
        hevm.expectRevert("OCC_Modular::applyExtension() intervals > extensions[id]");
        OCC_Modular_DAI.applyExtension(0, 1);
        hevm.stopPrank();

    }

    function test_OCC_Modular_applyExtension_state(uint96 random, bool choice, uint intervals) public {
        
        hevm.assume(intervals > 0);

        simulateITO_and_createOffers(random, choice);

        man_acceptOffer(0, DAI);

        // approveExtension().
        hevm.startPrank(address(roy));
        OCC_Modular_DAI.approveExtension(0, intervals);
        hevm.stopPrank();

        (,, uint256[10] memory preDetails_0) = OCC_Modular_DAI.loanInfo(0);

        uint extensionToApply = random % intervals + 1;

        // applyExtension()
        hevm.startPrank(address(tim));
        hevm.expectEmit(true, false, false, true, address(OCC_Modular_DAI));
        emit ExtensionApplied(0, extensionToApply);
        OCC_Modular_DAI.applyExtension(0, extensionToApply);
        hevm.stopPrank();

        // Post-state.
        (,, uint256[10] memory postDetails_0) = OCC_Modular_DAI.loanInfo(0);

        assertEq(postDetails_0[4], preDetails_0[4] + extensionToApply);
        assertEq(OCC_Modular_DAI.extensions(0), intervals - extensionToApply);

    }

    // Validate applyRefinance() state changes.
    // Validate applyRefinance() restrictions.
    // This includes:
    //  - _msgSender() is borrower of loan
    //  - loan is approved for refinancing
    //  - state of loan is LoanState.Active

    function test_OCC_Modular_applyRefinance_restrictions_borrower(uint96 random, bool choice, uint apr) public {
        
        simulateITO_and_createOffers(random, choice);

        // Approve refinance.
        hevm.startPrank(address(roy));
        OCC_Modular_DAI.approveRefinance(0, apr);
        hevm.stopPrank();

        // Can't apply refinance if not borrower.
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCC_Modular::applyRefinance() _msgSender() != loans[id].borrower");
        OCC_Modular_DAI.applyRefinance(0);
        hevm.stopPrank();
    }

    function test_OCC_Modular_applyRefinance_restrictions_approved(uint96 random, bool choice) public {
        
        simulateITO_and_createOffers(random, choice);
        
        man_acceptOffer(0, DAI);

        // Approve refinance.
        // hevm.startPrank(address(roy));
        // OCC_Modular_DAI.approveRefinance(0, apr);
        // hevm.stopPrank();

        // Can't apply refinance if not approved.
        hevm.startPrank(address(tim));
        hevm.expectRevert("OCC_Modular::applyRefinance() refinancing[id] == 0");
        OCC_Modular_DAI.applyRefinance(0);
        hevm.stopPrank();

    }

    function test_OCC_Modular_applyRefinance_restrictions_loanState(uint96 random, bool choice, uint apr) public {

        hevm.assume(apr > 0);

        simulateITO_and_createOffers(random, choice);
        
        // man_acceptOffer(0, DAI);

        // Approve refinance.
        hevm.startPrank(address(roy));
        OCC_Modular_DAI.approveRefinance(0, apr);
        hevm.stopPrank();

        // Can't apply refinance if LoanState not Active
        hevm.startPrank(address(tim));
        hevm.expectRevert("OCC_Modular::applyRefinance() loans[id].state != LoanState.Active");
        OCC_Modular_DAI.applyRefinance(0);
        hevm.stopPrank();

    }

    function test_OCC_Modular_applyRefinance_state(uint96 random, bool choice, uint apr) public {

        hevm.assume(apr > 0);

        simulateITO_and_createOffers(random, choice);
        
        man_acceptOffer(0, DAI);

        // Approve refinance.
        hevm.startPrank(address(roy));
        OCC_Modular_DAI.approveRefinance(0, apr);
        hevm.stopPrank();

        assertEq(OCC_Modular_DAI.refinancing(0), apr);
        
        (,, uint256[10] memory details) = OCC_Modular_DAI.loanInfo(0);

        // applyRefinance().
        hevm.expectEmit(true, false, false, true, address(OCC_Modular_DAI));
        emit RefinanceApplied(0, apr, details[1]);
        hevm.startPrank(address(tim));
        OCC_Modular_DAI.applyRefinance(0);

        (,, details) = OCC_Modular_DAI.loanInfo(0);

        // Post-state.
        assertEq(details[1], apr);
        assertEq(OCC_Modular_DAI.refinancing(0), 0);

    }

    // Validate approveCombine() state changes.
    // Validate approveCombine() restrictions.
    // This includes:
    //  - _msgSender() is underwriter
    //  - paymentInterval is one of 7 | 14 | 28 | 91 | 364 options ( * seconds in days)

    function test_OCC_Modular_approveCombine_restrictions_underwriter() public {
        
        // Can't call if not underwriter
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCC_Modular::isUnderwriter() _msgSender() != underwriter");
        OCC_Modular_DAI.approveCombine(address(bob), 86400 * 7, 24);
        hevm.stopPrank();
    }

    function test_OCC_Modular_approveCombine_restrictions_paymentInterval() public {
        
        // Can't call if paymentInterval isn't proper
        hevm.startPrank(address(roy));
        hevm.expectRevert("OCC_Modular::approveCombine() invalid paymentInterval value, try: 86400 * (7 || 14 || 28 || 91 || 364)");
        OCC_Modular_DAI.approveCombine(address(bob), 86400 * 30, 24);
        hevm.stopPrank();
    }

    function test_OCC_Modular_approveCombine_state(address account, uint8 select, uint term) public {
        
        uint256 option = uint256(select) % 5;

        // Pre-state.
        assertEq(OCC_Modular_DAI.viewCombinations(address(tim), 7 * 86400), 0);
        assertEq(OCC_Modular_DAI.viewCombinations(address(tim), 14 * 86400), 0);
        assertEq(OCC_Modular_DAI.viewCombinations(address(tim), 28 * 86400), 0);
        assertEq(OCC_Modular_DAI.viewCombinations(address(tim), 91 * 86400), 0);
        assertEq(OCC_Modular_DAI.viewCombinations(address(tim), 364 * 86400), 0);

        // approveCombine().
        hevm.startPrank(address(roy));
        hevm.expectEmit(true, false, false, true, address(OCC_Modular_DAI));
        emit CombineApproved(account, options[option], term);
        OCC_Modular_DAI.approveCombine(account, options[option], term);
        hevm.stopPrank();

        // Post-state.
        if (option == 0) {
            assertEq(OCC_Modular_DAI.viewCombinations(account, 7 * 86400), term);
        }
        else if (option == 1) {
            assertEq(OCC_Modular_DAI.viewCombinations(account, 14 * 86400), term);
        }
        else if (option == 2) {
            assertEq(OCC_Modular_DAI.viewCombinations(account, 28 * 86400), term);
        }
        else if (option == 3) {
            assertEq(OCC_Modular_DAI.viewCombinations(account, 91 * 86400), term);
        }
        else if (option == 4) {
            assertEq(OCC_Modular_DAI.viewCombinations(account, 364 * 86400), term);
        }
        else {
            revert();
        }
    }

    // Validate approveConversionAmortization() state changes.
    // Validate approveConversionAmortization() restrictions.
    // This includes:
    //  - _msgSender() is underwriter

    function test_OCC_Modular_approveConversionAmortization_restrictions_underwriter() public {
        
        // Can't call if not underwriter
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCC_Modular::isUnderwriter() _msgSender() != underwriter");
        OCC_Modular_DAI.approveConversionAmortization(0);
        hevm.stopPrank();
    }

    function test_OCC_Modular_approveConversionAmortization_state(uint id) public {

        // Pre-state.
        assert(!OCC_Modular_DAI.conversionAmortization(id));

        // Approve conversion.
        hevm.startPrank(address(roy));
        hevm.expectEmit(true, false, false, false, address(OCC_Modular_DAI));
        emit ConversionAmortizationApproved(id);
        OCC_Modular_DAI.approveConversionAmortization(id);
        hevm.stopPrank();

        // Post-state.
        assert(OCC_Modular_DAI.conversionAmortization(id));

    }

    // Validate approveConversionBullet() state changes.
    // Validate approveConversionBullet() restrictions.
    // This includes:
    //  - _msgSender() is underwriter

    function test_OCC_Modular_approveConversionBullet_restrictions_underwriter() public {
        
        // Can't call if not underwriter
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCC_Modular::isUnderwriter() _msgSender() != underwriter");
        OCC_Modular_DAI.approveConversionBullet(0);
        hevm.stopPrank();
    }

    function test_OCC_Modular_approveConversionBullet_state(uint id) public {

        // Pre-state.
        assert(!OCC_Modular_DAI.conversionBullet(id));

        // Approve conversion.
        hevm.startPrank(address(roy));
        hevm.expectEmit(true, false, false, false, address(OCC_Modular_DAI));
        emit ConversionBulletApproved(id);
        OCC_Modular_DAI.approveConversionBullet(id);
        hevm.stopPrank();

        // Post-state.
        assert(OCC_Modular_DAI.conversionBullet(id));
    }

    // Validate approveExtension() state changes.
    // Validate approveExtension() restrictions.
    // This includes:
    //  - _msgSender() is underwriter

    function test_OCC_Modular_approveExtension_restrictions_underwriter() public {
        
        // Can't call if not underwriter
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCC_Modular::isUnderwriter() _msgSender() != underwriter");
        OCC_Modular_DAI.approveExtension(0, 12);
        hevm.stopPrank();
        
    }

    function test_OCC_Modular_approveExtension_state(uint id, uint intervals) public {

        // Pre-state.
        assertEq(OCC_Modular_DAI.extensions(id), 0);

        // approveExtension().
        hevm.startPrank(address(roy));
        hevm.expectEmit(true, false, false, true, address(OCC_Modular_DAI));
        emit ExtensionApproved(id, intervals);
        OCC_Modular_DAI.approveExtension(id, intervals);
        hevm.stopPrank();

        // Post-state.
        assertEq(OCC_Modular_DAI.extensions(id), intervals);
        
    }

    // Validate approveRefinance() state changes.
    // Validate approveRefinance() restrictions.
    // This includes:
    //  - _msgSender() is underwriter

    function test_OCC_Modular_approveRefinance_restrictions_underwriter() public {
    
        // Can't call if not underwriter
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCC_Modular::isUnderwriter() _msgSender() != underwriter");
        OCC_Modular_DAI.approveRefinance(0, 1200);
        hevm.stopPrank();
    }

    function test_OCC_Modular_approveRefinance_state(uint id, uint apr) public {
        
        // Pre-state.
        assertEq(OCC_Modular_DAI.refinancing(id), 0);

        // approveRefinance().
        hevm.startPrank(address(roy));
        hevm.expectEmit(true, false, false, true, address(OCC_Modular_DAI));
        emit RefinanceApproved(id, apr);
        OCC_Modular_DAI.approveRefinance(id, apr);
        hevm.stopPrank();

        // Post-state.
        assertEq(OCC_Modular_DAI.refinancing(id), apr);
    }

    // Validate unapproveCombine() state changes.
    // Validate unapproveCombine() restrictions.
    // This includes:
    //  - _msgSender() is underwriter
    //  - paymentInterval is one of 7 | 14 | 28 | 91 | 364 options ( * seconds in days)

    function test_OCC_Modular_unapproveCombine_restrictions_underwriter() public {
        
        // Can't call if not underwriter
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCC_Modular::isUnderwriter() _msgSender() != underwriter");
        OCC_Modular_DAI.unapproveCombine(address(tim), 86400 * 14);
        hevm.stopPrank();
    }

    function test_OCC_Modular_unapproveCombine_restrictions_paymentInterval() public {
        
        // Can't call if not underwriter
        hevm.startPrank(address(roy));
        hevm.expectRevert("OCC_Modular::unapproveCombine() invalid paymentInterval value, try: 86400 * (7 || 14 || 28 || 91 || 364)");
        OCC_Modular_DAI.unapproveCombine(address(tim), 86400 * 30);
        hevm.stopPrank();
    }

    function test_OCC_Modular_unapproveCombine_state(address account, uint8 select, uint term) public {
        
        uint256 option = uint256(select) % 5;

        // Pre-state.
        assertEq(OCC_Modular_DAI.viewCombinations(address(tim), 7 * 86400), 0);
        assertEq(OCC_Modular_DAI.viewCombinations(address(tim), 14 * 86400), 0);
        assertEq(OCC_Modular_DAI.viewCombinations(address(tim), 28 * 86400), 0);
        assertEq(OCC_Modular_DAI.viewCombinations(address(tim), 91 * 86400), 0);
        assertEq(OCC_Modular_DAI.viewCombinations(address(tim), 364 * 86400), 0);

        // approveCombine().
        hevm.startPrank(address(roy));
        hevm.expectEmit(true, false, false, true, address(OCC_Modular_DAI));
        emit CombineApproved(account, options[option], term);
        OCC_Modular_DAI.approveCombine(account, options[option], term);
        hevm.stopPrank();

        // Post-state.
        if (option == 0) {
            assertEq(OCC_Modular_DAI.viewCombinations(account, 7 * 86400), term);
        }
        else if (option == 1) {
            assertEq(OCC_Modular_DAI.viewCombinations(account, 14 * 86400), term);
        }
        else if (option == 2) {
            assertEq(OCC_Modular_DAI.viewCombinations(account, 28 * 86400), term);
        }
        else if (option == 3) {
            assertEq(OCC_Modular_DAI.viewCombinations(account, 91 * 86400), term);
        }
        else if (option == 4) {
            assertEq(OCC_Modular_DAI.viewCombinations(account, 364 * 86400), term);
        }
        else {
            revert();
        }

        // unapproveCombine().
        hevm.startPrank(address(roy));
        hevm.expectEmit(true, false, false, true, address(OCC_Modular_DAI));
        emit CombineUnapproved(account, options[option]);
        OCC_Modular_DAI.unapproveCombine(account, options[option]);
        hevm.stopPrank();

        // Post-state.
        if (option == 0) {
            assertEq(OCC_Modular_DAI.viewCombinations(account, 7 * 86400), 0);
        }
        else if (option == 1) {
            assertEq(OCC_Modular_DAI.viewCombinations(account, 14 * 86400), 0);
        }
        else if (option == 2) {
            assertEq(OCC_Modular_DAI.viewCombinations(account, 28 * 86400), 0);
        }
        else if (option == 3) {
            assertEq(OCC_Modular_DAI.viewCombinations(account, 91 * 86400), 0);
        }
        else if (option == 4) {
            assertEq(OCC_Modular_DAI.viewCombinations(account, 364 * 86400), 0);
        }
        else {
            revert();
        }
    }

    // Validate unapproveConversionAmortization() state changes.
    // Validate unapproveConversionAmortization() restrictions.
    // This includes:
    //  - _msgSender() is underwriter

    function test_OCC_Modular_unapproveConversionAmortization_restrictions_underwriter() public {
        
        // Can't call if not underwriter
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCC_Modular::isUnderwriter() _msgSender() != underwriter");
        OCC_Modular_DAI.unapproveConversionAmortization(0);
        hevm.stopPrank();
    }

    function test_OCC_Modular_unapproveConversionAmortization_state(uint id) public {
        
        // Pre-state.
        assert(!OCC_Modular_DAI.conversionAmortization(id));

        // Approve conversion.
        hevm.startPrank(address(roy));
        hevm.expectEmit(true, false, false, false, address(OCC_Modular_DAI));
        emit ConversionAmortizationApproved(id);
        OCC_Modular_DAI.approveConversionAmortization(id);
        hevm.stopPrank();

        // Post-state.
        assert(OCC_Modular_DAI.conversionAmortization(id));

        // Unapprove conversion.
        hevm.startPrank(address(roy));
        hevm.expectEmit(true, false, false, false, address(OCC_Modular_DAI));
        emit ConversionAmortizationUnapproved(id);
        OCC_Modular_DAI.unapproveConversionAmortization(id);
        hevm.stopPrank();

        // Post-state.
        assert(!OCC_Modular_DAI.conversionAmortization(id));
    }

    // Validate unapproveConversionBullet() state changes.
    // Validate unapproveConversionBullet() restrictions.
    // This includes:
    //  - _msgSender() is underwriter

    function test_OCC_Modular_unapproveConversionBullet_restrictions_underwriter() public {
        
        // Can't call if not underwriter
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCC_Modular::isUnderwriter() _msgSender() != underwriter");
        OCC_Modular_DAI.unapproveConversionBullet(0);
        hevm.stopPrank();
    }

    function test_OCC_Modular_unapproveConversionBullet_state(uint id) public {
        
        
        // Pre-state.
        assert(!OCC_Modular_DAI.conversionBullet(id));

        // Approve conversion.
        hevm.startPrank(address(roy));
        hevm.expectEmit(true, false, false, false, address(OCC_Modular_DAI));
        emit ConversionBulletApproved(id);
        OCC_Modular_DAI.approveConversionBullet(id);
        hevm.stopPrank();

        // Post-state.
        assert(OCC_Modular_DAI.conversionBullet(id));

        // Unapprove conversion.
        hevm.startPrank(address(roy));
        hevm.expectEmit(true, false, false, false, address(OCC_Modular_DAI));
        emit ConversionBulletUnapproved(id);
        OCC_Modular_DAI.unapproveConversionBullet(id);
        hevm.stopPrank();

        // Post-state.
        assert(!OCC_Modular_DAI.conversionBullet(id));
    }

    // Validate unapproveExtension() state changes.
    // Validate unapproveExtension() restrictions.
    // This includes:
    //  - _msgSender() is underwriter

    function test_OCC_Modular_unapproveExtension_restrictions_underwriter() public {
        
        // Can't call if not underwriter
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCC_Modular::isUnderwriter() _msgSender() != underwriter");
        OCC_Modular_DAI.unapproveExtension(0);
        hevm.stopPrank();
    }

    function test_OCC_Modular_unapproveExtension_state(uint id, uint intervals) public {
        
        // Pre-state.
        assertEq(OCC_Modular_DAI.extensions(id), 0);

        // approveExtension().
        hevm.startPrank(address(roy));
        hevm.expectEmit(true, false, false, true, address(OCC_Modular_DAI));
        emit ExtensionApproved(id, intervals);
        OCC_Modular_DAI.approveExtension(id, intervals);
        hevm.stopPrank();

        // Post-state.
        assertEq(OCC_Modular_DAI.extensions(id), intervals);

        // unapproveExtension().
        hevm.startPrank(address(roy));
        hevm.expectEmit(true, false, false, true, address(OCC_Modular_DAI));
        emit ExtensionUnapproved(id);
        OCC_Modular_DAI.unapproveExtension(id);
        hevm.stopPrank();

        // Post-state.
        assertEq(OCC_Modular_DAI.extensions(id), 0);

    }

    // Validate unapproveRefinance() state changes.
    // Validate unapproveRefinance() restrictions.
    // This includes:
    //  - _msgSender() is underwriter

    function test_OCC_Modular_unapproveRefinance_restrictions_underwriter() public {
        
        // Can't call if not underwriter
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCC_Modular::isUnderwriter() _msgSender() != underwriter");
        OCC_Modular_DAI.unapproveRefinance(0);
        hevm.stopPrank();
    }

    function test_OCC_Modular_unapproveRefinance_state(uint id, uint apr) public {
        
        // Pre-state.
        assertEq(OCC_Modular_DAI.refinancing(id), 0);

        // approveRefinance().
        hevm.startPrank(address(roy));
        hevm.expectEmit(true, false, false, true, address(OCC_Modular_DAI));
        emit RefinanceApproved(id, apr);
        OCC_Modular_DAI.approveRefinance(id, apr);
        hevm.stopPrank();

        // Post-state.
        assertEq(OCC_Modular_DAI.refinancing(id), apr);

        // unapproveRefinance().
        hevm.startPrank(address(roy));
        hevm.expectEmit(true, false, false, false, address(OCC_Modular_DAI));
        emit RefinanceUnapproved(id);
        OCC_Modular_DAI.unapproveRefinance(id);
        hevm.stopPrank();

        // Post-state.
        assertEq(OCC_Modular_DAI.refinancing(id), 0);
    }

}
