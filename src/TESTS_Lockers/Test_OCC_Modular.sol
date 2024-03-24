// SPDX-License-Identifier: UNLICENSED
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

    struct Combine {
        uint256[] loans;                /// @dev The loans approved for combination.
        uint256 paymentInterval;        /// @dev The paymentInterval of the resulting combined loan.
        uint256 term;                   /// @dev The term of the resulting combined loan.
        uint256 expires;                /// @dev The expiration of this combination.
        int8 paymentSchedule;           /// @dev The paymentSchedule of the resulting combined loan.
        bool valid;                     /// @dev The validity of the combination (if it can be executed).
    }

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

    event CombineApplied(
        address indexed borrower, 
        uint256[] loanIDs, 
        uint256 term,
        uint256 paymentInterval,
        uint256 gracePeriod,
        int8 indexed paymentSchedule
    );
    
    event CombineApproved(
        uint256 indexed id, 
        uint256[] loanIDs,
        uint256 APRLateFee,
        uint256 term,
        uint256 paymentInterval, 
        uint256 gracePeriod,
        uint256 expires,
        int8 indexed paymentSchedule
    );
    
    event CombineUnapproved(uint id);

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

    event ConversionToAmortizationApplied(uint indexed id);
    
    event ConversionToAmortizationApproved(uint indexed id);
    
    event ConversionToAmortizationUnapproved(uint indexed id);
    
    event ConversionToBulletApplied(uint indexed id);
    
    event ConversionToBulletApproved(uint indexed id);
    
    event ConversionToBulletUnapproved(uint indexed id);
    
    event DefaultMarked(uint256 indexed id, uint256 principalDefaulted);

    event DefaultResolved(uint256 indexed id, uint256 amount, address indexed payee, bool resolved);
    
    event ExtensionApplied(uint indexed id, uint intervals);
    
    event ExtensionApproved(uint indexed id, uint intervals);
    
    event ExtensionUnapproved(uint indexed id);
    
    event LoanCalled(uint256 indexed id, uint256 amount, uint256 principal, uint256 interest, uint256 lateFee);
    
    event InterestSupplied(uint256 indexed id, uint256 amount, address indexed payee);
    
    event UpdatedOCTYDL(address indexed newOCT, address indexed oldOCT);
    
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

    event RefinanceApproved(uint indexed id, uint APR);
    
    event RefinanceUnapproved(uint indexed id);
    
    event RefinanceApplied(uint indexed id, uint APRNew, uint APRPrior);
    
    event RepaidMarked(uint256 indexed id);

    // ----------------------
    //    Helper Functions
    // ----------------------

    function createRandomOffer(uint96 random, bool choice, address asset) internal returns (uint256 loanID) {
        
        uint256 borrowAmount = uint256(random) + 1;
        uint256 APR = uint256(random) % 5000;
        uint256 APRLateFee = uint256(random) % 5000;
        uint256 term = uint256(random) % 25 + 1;
        uint256 gracePeriod = uint256(random) % 90 days + 7 days;
        uint256 option = uint256(random) % 5;
        int8 paymentSchedule = choice ? int8(0) : int8(1);

        if (asset == DAI) {
            loanID = OCC_Modular_DAI.loanCounter();
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
            loanID = OCC_Modular_FRAX.loanCounter();
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
            loanID = OCC_Modular_USDC.loanCounter();
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
            loanID = OCC_Modular_USDT.loanCounter();
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

    function tim_acceptOffer(uint256 loanID, address asset) public {

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

        // // Mint borrower tokens for paying interest, or other purposes.
        mint("DAI", address(tim), MAX_UINT / 10**18);
        mint("FRAX", address(tim), MAX_UINT / 10**18);
        mint("USDC", address(tim), MAX_UINT / 10**18);
        mint("USDT", address(tim), MAX_UINT / 10**18);

        // // Handle pre-approvals here for future convenience.
        assert(tim.try_approveToken(address(DAI), address(OCC_Modular_DAI), MAX_UINT / 10**18));
        assert(tim.try_approveToken(address(FRAX), address(OCC_Modular_FRAX), MAX_UINT / 10**18));
        assert(tim.try_approveToken(address(USDC), address(OCC_Modular_USDC), MAX_UINT / 10**18));
        assert(tim.try_approveToken(address(USDT), address(OCC_Modular_USDT), MAX_UINT / 10**18));

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
        mint("DAI", address(tim), MAX_UINT / 100);
        mint("FRAX", address(tim), MAX_UINT / 100);
        mint("USDC", address(tim), MAX_UINT / 100);
        mint("USDT", address(tim), MAX_UINT / 100);

        // Handle pre-approvals here for future convenience.
        assert(tim.try_approveToken(address(DAI), address(OCC_Modular_DAI), MAX_UINT / 100));
        assert(tim.try_approveToken(address(FRAX), address(OCC_Modular_FRAX), MAX_UINT / 100));
        assert(tim.try_approveToken(address(USDC), address(OCC_Modular_USDC), MAX_UINT / 100));
        assert(tim.try_approveToken(address(USDT), address(OCC_Modular_USDT), MAX_UINT / 100));

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
        mint("DAI", address(tim), MAX_UINT / 100);
        mint("FRAX", address(tim), MAX_UINT / 100);
        mint("USDC", address(tim), MAX_UINT / 100);
        mint("USDT", address(tim), MAX_UINT / 100);

        // Handle pre-approvals here for future convenience.
        assert(tim.try_approveToken(address(DAI), address(OCC_Modular_DAI), MAX_UINT / 100));
        assert(tim.try_approveToken(address(FRAX), address(OCC_Modular_FRAX), MAX_UINT / 100));
        assert(tim.try_approveToken(address(USDC), address(OCC_Modular_USDC), MAX_UINT / 100));
        assert(tim.try_approveToken(address(USDT), address(OCC_Modular_USDT), MAX_UINT / 100));

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
        mint("DAI", address(tim), MAX_UINT / 100);
        mint("FRAX", address(tim), MAX_UINT / 100);
        mint("USDC", address(tim), MAX_UINT / 100);
        mint("USDT", address(tim), MAX_UINT / 100);

        // Handle pre-approvals here for future convenience.
        assert(tim.try_approveToken(address(DAI), address(OCC_Modular_DAI), MAX_UINT / 100));
        assert(tim.try_approveToken(address(FRAX), address(OCC_Modular_FRAX), MAX_UINT / 100));
        assert(tim.try_approveToken(address(USDC), address(OCC_Modular_USDC), MAX_UINT / 100));
        assert(tim.try_approveToken(address(USDT), address(OCC_Modular_USDT), MAX_UINT / 100));

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
    //  - loans[id].state must be LoanState.Offered
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

        // Can't accept loan offer if state != LoanState.Offered.
        hevm.startPrank(address(roy));
        hevm.expectRevert("OCC_Modular::acceptOffer() loans[id].state != LoanState.Offered");
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

        // Warp past expiry time (3 days past loan creation).
        hevm.warp(block.timestamp + 3 days + 1 seconds);

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
        (,, uint256[10] memory _preInfo) = OCC_Modular_DAI.loanInfo(_loanID_DAI);

        hevm.expectEmit(true, true, false, true, address(OCC_Modular_DAI));
        emit OfferAccepted(_loanID_DAI, _preInfo[0], address(tim), block.timestamp - block.timestamp % 7 days + 9 days + _preInfo[6]);
        assert(tim.try_acceptOffer(address(OCC_Modular_DAI), _loanID_DAI));

        // Post-state DAI.
        (,, uint256[10] memory _postInfo) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        uint256 _postStable_borrower = IERC20(DAI).balanceOf(address(tim));
        uint256 _postStable_occ = IERC20(DAI).balanceOf(address(OCC_Modular_DAI));

        // block.timestamp - block.timestamp % 7 days + 9 days + loans[id].paymentInterval
        assertEq(_postInfo[3], block.timestamp - block.timestamp % 7 days + 9 days + _postInfo[6]);
        assertEq(_postInfo[9], 2);
        assertEq(_postStable_borrower - _preStable_borrower, _postInfo[0]);
        assertEq(_preStable_occ - _postStable_occ, _postInfo[0]);

        // Pre-state FRAX.
        _preStable_borrower = IERC20(FRAX).balanceOf(address(tim));
        _preStable_occ = IERC20(FRAX).balanceOf(address(OCC_Modular_FRAX));
        (,, _preInfo) = OCC_Modular_DAI.loanInfo(_loanID_FRAX);

        hevm.expectEmit(true, true, false, true, address(OCC_Modular_FRAX));
        emit OfferAccepted(_loanID_FRAX, _preInfo[0], address(tim), block.timestamp - block.timestamp % 7 days + 9 days + _preInfo[6]);
        assert(tim.try_acceptOffer(address(OCC_Modular_FRAX), _loanID_FRAX));

        // Post-state FRAX
        (,, _postInfo) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        _postStable_borrower = IERC20(FRAX).balanceOf(address(tim));
        _postStable_occ = IERC20(FRAX).balanceOf(address(OCC_Modular_FRAX));
        
        assertEq(_postInfo[3], block.timestamp - block.timestamp % 7 days + 9 days + _postInfo[6]);
        assertEq(_postInfo[9], 2);
        assertEq(_postStable_borrower - _preStable_borrower, _postInfo[0]);
        assertEq(_preStable_occ - _postStable_occ, _postInfo[0]);

        // Pre-state USDC.
        _preStable_borrower = IERC20(USDC).balanceOf(address(tim));
        _preStable_occ = IERC20(USDC).balanceOf(address(OCC_Modular_USDC));
        (,, _preInfo) = OCC_Modular_DAI.loanInfo(_loanID_USDC);

        hevm.expectEmit(true, true, false, true, address(OCC_Modular_USDC));
        emit OfferAccepted(_loanID_USDC, _preInfo[0], address(tim), block.timestamp - block.timestamp % 7 days + 9 days + _preInfo[6]);
        assert(tim.try_acceptOffer(address(OCC_Modular_USDC), _loanID_USDC));

        // Post-state USDC
        (,, _postInfo) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        _postStable_borrower = IERC20(USDC).balanceOf(address(tim));
        _postStable_occ = IERC20(USDC).balanceOf(address(OCC_Modular_USDC));
        
        assertEq(_postInfo[3], block.timestamp - block.timestamp % 7 days + 9 days + _postInfo[6]);
        assertEq(_postInfo[9], 2);
        assertEq(_postStable_borrower - _preStable_borrower, _postInfo[0]);
        assertEq(_preStable_occ - _postStable_occ, _postInfo[0]);

        // Pre-state USDT.
        _preStable_borrower = IERC20(USDT).balanceOf(address(tim));
        _preStable_occ = IERC20(USDT).balanceOf(address(OCC_Modular_USDT));
        (,, _preInfo) = OCC_Modular_DAI.loanInfo(_loanID_USDT);

        hevm.expectEmit(true, true, false, true, address(OCC_Modular_USDT));
        emit OfferAccepted(_loanID_USDT, _preInfo[0], address(tim), block.timestamp - block.timestamp % 7 days + 9 days + _preInfo[6]);
        assert(tim.try_acceptOffer(address(OCC_Modular_USDT), _loanID_USDT));

        // Post-state USDT
        (,, _postInfo) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
        _postStable_borrower = IERC20(USDT).balanceOf(address(tim));
        _postStable_occ = IERC20(USDT).balanceOf(address(OCC_Modular_USDT));
        
        assertEq(_postInfo[3], block.timestamp - block.timestamp % 7 days + 9 days + _postInfo[6]);
        assertEq(_postInfo[9], 2);
        assertEq(_postStable_borrower - _preStable_borrower, _postInfo[0]);
        assertEq(_preStable_occ - _postStable_occ, _postInfo[0]);

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
        hevm.expectRevert("OCC_Modular::callLoan() _msgSender() != loans[id].borrower && !isLocker(_msgSender())");
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
        (,, uint256[10] memory _preInfo) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        
        uint256 principalOwed = _preInfo[0];

        // 20% chance to make late callLoan() (warp ahead of time).
        if (principalOwed % 5 == 0) {
            hevm.warp(_preInfo[3] + random % 7776000); // Potentially up to 90 days late callLoan().
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

        assertEq(_preInfo[9], 2);

        // Check amountOwed() interest ...
        if (block.timestamp > _preInfo[3]) {
            // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS) +
            // loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
            assertEq(
                interestOwed + lateFee, 
                _preInfo[0] * _preInfo[6] * _preInfo[1] / (86400 * 365 * BIPS) + 
                _preInfo[0] * (block.timestamp - _preInfo[3]) * (_preInfo[2]) / (86400 * 365 * BIPS)

            );
        }
        else {
            // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS)
            assertEq(
                interestOwed + lateFee, 
                _preInfo[0] * _preInfo[6] * _preInfo[1] / (86400 * 365 * BIPS)
            );
        }

        hevm.expectEmit(true, false, false, true, address(OCC_Modular_DAI));
        emit LoanCalled(_loanID_DAI, principalOwed + interestOwed + lateFee, principalOwed, interestOwed, lateFee);
        assert(tim.try_callLoan(address(OCC_Modular_DAI), _loanID_DAI));

        // Post-state.
        (,, uint256[10] memory _postInfo) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        balanceData[1] = IERC20(DAI).balanceOf(address(DAO));
        balanceData[3] = IERC20(DAI).balanceOf(address(YDL));
        balanceData[5] = IERC20(DAI).balanceOf(address(tim));

        assertEq(balanceData[1] - balanceData[0], principalOwed);
        assertEq(balanceData[3] - balanceData[2], interestOwed + lateFee);
        assertEq(balanceData[4] - balanceData[5], principalOwed + interestOwed + lateFee);

        // info[0] = principalOwed
        // info[3] = paymentDueBy
        // info[4] = paymentsRemaining
        // info[6] = paymentInterval
        // info[9] = loanState

        assertEq(_postInfo[0], 0);
        assertEq(_postInfo[3], 0);
        assertEq(_postInfo[4], 0);
        assertEq(_postInfo[9], 3);
        
    }

    function test_OCC_Modular_callLoan_state_FRAX(uint96 random, bool choice) public {

        (, uint256 _loanID_FRAX,,) = simulateITO_and_createOffers_and_acceptOffers(random, choice);

        // Pre-state FRAX.
        (,, uint256[10] memory _preInfo) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        
        uint256 principalOwed = _preInfo[0];

        // 20% chance to make late callLoan() (warp ahead of time).
        if (principalOwed % 5 == 0) {
            hevm.warp(_preInfo[3] + random % 7776000); // Potentially up to 90 days late callLoan().
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

        assertEq(_preInfo[9], 2);

        // Check amountOwed() interest ...
        if (block.timestamp > _preInfo[3]) {
            // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS) +
            // loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
            assertEq(
                interestOwed + lateFee, 
                _preInfo[0] * _preInfo[6] * _preInfo[1] / (86400 * 365 * BIPS) + 
                _preInfo[0] * (block.timestamp - _preInfo[3]) * (_preInfo[2]) / (86400 * 365 * BIPS)

            );
        }
        else {
            // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS)
            assertEq(
                interestOwed + lateFee, 
                _preInfo[0] * _preInfo[6] * _preInfo[1] / (86400 * 365 * BIPS)
            );
        }

        hevm.expectEmit(true, false, false, true, address(OCC_Modular_FRAX));
        emit LoanCalled(_loanID_FRAX, principalOwed + interestOwed + lateFee, principalOwed, interestOwed, lateFee);
        assert(tim.try_callLoan(address(OCC_Modular_FRAX), _loanID_FRAX));

        // Post-state.
        (,, uint256[10] memory _postInfo) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        balanceData[1] = IERC20(FRAX).balanceOf(address(DAO));
        balanceData[3] = IERC20(FRAX).balanceOf(address(Treasury));
        balanceData[5] = IERC20(FRAX).balanceOf(address(tim));

        assertEq(balanceData[1] - balanceData[0], principalOwed);
        assertEq(balanceData[3] - balanceData[2], interestOwed + lateFee);
        assertEq(balanceData[4] - balanceData[5], principalOwed + interestOwed + lateFee);

        // info[0] = principalOwed
        // info[3] = paymentDueBy
        // info[4] = paymentsRemaining
        // info[6] = paymentInterval
        // info[9] = loanState

        assertEq(_postInfo[0], 0);
        assertEq(_postInfo[3], 0);
        assertEq(_postInfo[4], 0);
        assertEq(_postInfo[9], 3);
        
    }

    function test_OCC_Modular_callLoan_state_USDC(uint96 random, bool choice) public {

        (,, uint256 _loanID_USDC,) = simulateITO_and_createOffers_and_acceptOffers(random, choice);

        // Pre-state USDC.
        (,, uint256[10] memory _preInfo) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        
        uint256 principalOwed = _preInfo[0];

        // 20% chance to make late callLoan() (warp ahead of time).
        if (principalOwed % 5 == 0) {
            hevm.warp(_preInfo[3] + random % 7776000); // Potentially up to 90 days late callLoan().
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

        assertEq(_preInfo[9], 2);

        // Check amountOwed() interest ...
        if (block.timestamp > _preInfo[3]) {
            // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS) +
            // loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
            assertEq(
                interestOwed + lateFee, 
                _preInfo[0] * _preInfo[6] * _preInfo[1] / (86400 * 365 * BIPS) + 
                _preInfo[0] * (block.timestamp - _preInfo[3]) * (_preInfo[2]) / (86400 * 365 * BIPS)

            );
        }
        else {
            // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS)
            assertEq(
                interestOwed + lateFee, 
                _preInfo[0] * _preInfo[6] * _preInfo[1] / (86400 * 365 * BIPS)
            );
        }

        hevm.expectEmit(true, false, false, true, address(OCC_Modular_USDC));
        emit LoanCalled(_loanID_USDC, principalOwed + interestOwed + lateFee, principalOwed, interestOwed, lateFee);
        assert(tim.try_callLoan(address(OCC_Modular_USDC), _loanID_USDC));

        // Post-state.
        (,, uint256[10] memory _postInfo) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        balanceData[1] = IERC20(USDC).balanceOf(address(DAO));
        balanceData[3] = IERC20(USDC).balanceOf(address(Treasury));
        balanceData[5] = IERC20(USDC).balanceOf(address(tim));

        assertEq(balanceData[1] - balanceData[0], principalOwed);
        assertEq(balanceData[3] - balanceData[2], interestOwed + lateFee);
        assertEq(balanceData[4] - balanceData[5], principalOwed + interestOwed + lateFee);

        // info[0] = principalOwed
        // info[3] = paymentDueBy
        // info[4] = paymentsRemaining
        // info[6] = paymentInterval
        // info[9] = loanState

        assertEq(_postInfo[0], 0);
        assertEq(_postInfo[3], 0);
        assertEq(_postInfo[4], 0);
        assertEq(_postInfo[9], 3);
        
    }

    function test_OCC_Modular_callLoan_state_USDT(uint96 random, bool choice) public {

        (,,, uint256 _loanID_USDT) = simulateITO_and_createOffers_and_acceptOffers(random, choice);

        // Pre-state USDT.
        (,, uint256[10] memory _preInfo) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
        
        uint256 principalOwed = _preInfo[0];

        // 20% chance to make late callLoan() (warp ahead of time).
        if (principalOwed % 5 == 0) {
            hevm.warp(_preInfo[3] + random % 7776000); // Potentially up to 90 days late callLoan().
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

        assertEq(_preInfo[9], 2);

        // Check amountOwed() interest ...
        if (block.timestamp > _preInfo[3]) {
            // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS) +
            // loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
            assertEq(
                interestOwed + lateFee, 
                _preInfo[0] * _preInfo[6] * _preInfo[1] / (86400 * 365 * BIPS) + 
                _preInfo[0] * (block.timestamp - _preInfo[3]) * (_preInfo[2]) / (86400 * 365 * BIPS)

            );
        }
        else {
            // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS)
            assertEq(
                interestOwed + lateFee, 
                _preInfo[0] * _preInfo[6] * _preInfo[1] / (86400 * 365 * BIPS)
            );
        }

        hevm.expectEmit(true, false, false, true, address(OCC_Modular_USDT));
        emit LoanCalled(_loanID_USDT, principalOwed + interestOwed + lateFee, principalOwed, interestOwed, lateFee);
        assert(tim.try_callLoan(address(OCC_Modular_USDT), _loanID_USDT));

        // Post-state.
        (,, uint256[10] memory _postInfo) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
        balanceData[1] = IERC20(USDT).balanceOf(address(DAO));
        balanceData[3] = IERC20(USDT).balanceOf(address(Treasury));
        balanceData[5] = IERC20(USDT).balanceOf(address(tim));

        assertEq(balanceData[1] - balanceData[0], principalOwed);
        assertEq(balanceData[3] - balanceData[2], interestOwed + lateFee);
        assertEq(balanceData[4] - balanceData[5], principalOwed + interestOwed + lateFee);

        // info[0] = principalOwed
        // info[3] = paymentDueBy
        // info[4] = paymentsRemaining
        // info[6] = paymentInterval
        // info[9] = loanState

        assertEq(_postInfo[0], 0);
        assertEq(_postInfo[3], 0);
        assertEq(_postInfo[4], 0);
        assertEq(_postInfo[9], 3);
        
    }

    // Validate cancelOffer() state changes.
    // Validate cancelOffer() restrictions.
    // This includes:
    //  - _msgSender() must equal underwriter
    //  - loans[id].state must equal LoanState.Offered

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
        tim_acceptOffer(_loanID_DAI, DAI);
        tim_acceptOffer(_loanID_FRAX, FRAX);

        // Cancel two of these loans (in advance) of restrictions check.
        assert(roy.try_cancelOffer(address(OCC_Modular_USDC), _loanID_USDC));
        assert(roy.try_cancelOffer(address(OCC_Modular_USDT), _loanID_USDT));

        // Can't cancelOffer() if state != LoanState.Offered.
        hevm.startPrank(address(roy));
        hevm.expectRevert("OCC_Modular::cancelOffer() loans[id].state != LoanState.Offered");
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
        (,, uint256[10] memory info_DAI) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        (,, uint256[10] memory info_FRAX) = OCC_Modular_DAI.loanInfo(_loanID_FRAX);
        (,, uint256[10] memory info_USDC) = OCC_Modular_DAI.loanInfo(_loanID_USDC);
        (,, uint256[10] memory info_USDT) = OCC_Modular_DAI.loanInfo(_loanID_USDT);

        assertEq(info_DAI[9], 1);
        assertEq(info_FRAX[9], 1);
        assertEq(info_USDC[9], 1);
        assertEq(info_USDT[9], 1);

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
        (,, info_DAI) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        (,, info_FRAX) = OCC_Modular_DAI.loanInfo(_loanID_FRAX);
        (,, info_USDC) = OCC_Modular_DAI.loanInfo(_loanID_USDC);
        (,, info_USDT) = OCC_Modular_DAI.loanInfo(_loanID_USDT);

        // Post-state.
        assertEq(info_DAI[9], 5);
        assertEq(info_FRAX[9], 5);
        assertEq(info_USDC[9], 5);
        assertEq(info_USDT[9], 5);
    }

    // Validate state changes of createOffer() function.
    // Validate restrictions of createOffer() function.
    // Restrictions include:
    //  - term == 0
    //  - Invalid paymentInterval (only 5 valid options)
    //  - gracePeriod >= 7 days
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

    function test_OCC_Modular_createOffer_restrictions_gracePeriod(uint96 random) public {

        uint256 borrowAmount = uint256(random);
        uint256 APR;
        uint256 APRLateFee;
        uint256 term;
        uint256 paymentInterval;
        uint256 gracePeriod = 6 days;
        int8 paymentSchedule;
        
        APR = uint256(random) % 3601;
        APRLateFee = uint256(random) % 3601;
        term = uint256(random) % 100 + 1;
        paymentInterval = options[uint256(random) % 5];
        
        // Can't createOffer with gracePeriod less than 7 days.
        hevm.startPrank(address(roy));
        hevm.expectRevert("OCC_Modular::createOffer() gracePeriod < 7 days");
        OCC_Modular_DAI.createOffer(
            address(tim), borrowAmount, APR, APRLateFee, term, paymentInterval, gracePeriod, paymentSchedule
        );
        hevm.stopPrank();

    }

    function test_OCC_Modular_createOffer_restrictions_paymentSchedule(uint96 random) public {

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
        gracePeriod = uint256(random) % 90 days + 7 days;
        
        // Can't createOffer with invalid paymentSchedule (0 || 1).
        hevm.startPrank(address(roy));
        hevm.expectRevert("OCC_Modular::createOffer() paymentSchedule > 1");
        OCC_Modular_DAI.createOffer(
            address(tim), borrowAmount, APR, APRLateFee, term, paymentInterval, gracePeriod, paymentSchedule
        );
        hevm.stopPrank();

    }

    function test_OCC_Modular_createOffer_state(uint96 random, bool choice, uint8 modularity) public {

        uint256 borrowAmount = uint256(random);
        uint256 APR = uint256(random) % 5000;
        uint256 APRLateFee = uint256(random) % 5000;
        uint256 term = uint256(random) % 25 + 1;
        uint256 gracePeriod = uint256(random) % 90 days + 7 days;
        uint256 option = uint256(random) % 5;
        int8 paymentSchedule = choice ? int8(0) : int8(1);
        
        uint256 loanID;

        hevm.startPrank(address(roy));

        if (modularity % 4 == 0) {

            loanID = OCC_Modular_DAI.loanCounter();
            
            hevm.expectEmit(true, true, true, true, address(OCC_Modular_DAI));
            emit OfferCreated(
                address(this), loanID,
                borrowAmount, APR, APRLateFee, term, uint256(options[option]),
                block.timestamp + 3 days, gracePeriod, paymentSchedule
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
                uint256[10] memory _info
            ) = OCC_Modular_DAI.loanInfo(loanID);

            assertEq(_borrower, address(this));
            assertEq(paymentSchedule, _paymentSchedule);
            assertEq(_info[0], borrowAmount);
            assertEq(_info[1], APR);
            assertEq(_info[2], APRLateFee);
            assertEq(_info[3], 0);
            assertEq(_info[4], term);
            assertEq(_info[5], term);
            assertEq(_info[6], uint256(options[option]));
            assertEq(_info[7], block.timestamp + 3 days);
            assertEq(_info[8], gracePeriod);
            assertEq(_info[9], 1);

            assertEq(OCC_Modular_DAI.loanCounter(), loanID + 1);

        }

        if (modularity % 4 == 1) {

            loanID = OCC_Modular_FRAX.loanCounter();

            
            hevm.expectEmit(true, true, true, true, address(OCC_Modular_FRAX));
            emit OfferCreated(
                address(this), loanID,
                borrowAmount, APR, APRLateFee, term, uint256(options[option]),
                block.timestamp + 3 days, gracePeriod, paymentSchedule
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
                uint256[10] memory _info
            ) = OCC_Modular_FRAX.loanInfo(loanID);

            assertEq(_borrower, address(this));
            assertEq(paymentSchedule, _paymentSchedule);
            assertEq(_info[0], borrowAmount);
            assertEq(_info[1], APR);
            assertEq(_info[2], APRLateFee);
            assertEq(_info[3], 0);
            assertEq(_info[4], term);
            assertEq(_info[5], term);
            assertEq(_info[6], uint256(options[option]));
            assertEq(_info[7], block.timestamp + 3 days);
            assertEq(_info[8], gracePeriod);
            assertEq(_info[9], 1);

            assertEq(OCC_Modular_FRAX.loanCounter(), loanID + 1);

        }

        if (modularity % 4 == 2) {

            loanID = OCC_Modular_USDC.loanCounter();

            hevm.expectEmit(true, true, true, true, address(OCC_Modular_USDC));
            emit OfferCreated(
                address(this), loanID,
                borrowAmount, APR, APRLateFee, term, uint256(options[option]),
                block.timestamp + 3 days, gracePeriod, paymentSchedule
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
                uint256[10] memory _info
            ) = OCC_Modular_USDC.loanInfo(loanID);

            assertEq(_borrower, address(this));
            assertEq(paymentSchedule, _paymentSchedule);
            assertEq(_info[0], borrowAmount);
            assertEq(_info[1], APR);
            assertEq(_info[2], APRLateFee);
            assertEq(_info[3], 0);
            assertEq(_info[4], term);
            assertEq(_info[5], term);
            assertEq(_info[6], uint256(options[option]));
            assertEq(_info[7], block.timestamp + 3 days);
            assertEq(_info[8], gracePeriod);
            assertEq(_info[9], 1);

            assertEq(OCC_Modular_USDC.loanCounter(), loanID + 1);

        }

        if (modularity % 4 == 3) {

            loanID = OCC_Modular_USDT.loanCounter();

            hevm.expectEmit(true, true, true, true, address(OCC_Modular_USDT));
            emit OfferCreated(
                address(this), loanID,
                borrowAmount, APR, APRLateFee, term, uint256(options[option]),
                block.timestamp + 3 days, gracePeriod, paymentSchedule
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
                uint256[10] memory _info
            ) = OCC_Modular_USDT.loanInfo(loanID);

            assertEq(_borrower, address(this));
            assertEq(paymentSchedule, _paymentSchedule);
            assertEq(_info[0], borrowAmount);
            assertEq(_info[1], APR);
            assertEq(_info[2], APRLateFee);
            assertEq(_info[3], 0);
            assertEq(_info[4], term);
            assertEq(_info[5], term);
            assertEq(_info[6], uint256(options[option]));
            assertEq(_info[7], block.timestamp + 3 days);
            assertEq(_info[8], gracePeriod);
            assertEq(_info[9], 1);

            assertEq(OCC_Modular_USDT.loanCounter(), loanID + 1);

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

        (,, uint256[10] memory _preInfo) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        (,, uint256[10] memory _postInfo) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
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

        while(_postInfo[4] > 0) {
            
            // Pre-state.
            (principalOwed, interestOwed, lateFeeOwed, totalOwed) = OCC_Modular_DAI.amountOwed(_loanID_DAI);
            (,, _preInfo) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
            balanceData[0] = IERC20(DAI).balanceOf(address(DAO));
            balanceData[2] = IERC20(DAI).balanceOf(address(YDL));
            balanceData[4] = IERC20(DAI).balanceOf(address(tim));

            // info[0] = principalOwed
            // info[1] = APR
            // info[2] = APRLateFee
            // info[3] = paymentDueBy
            // info[4] = paymentsRemaining
            // info[6] = paymentInterval
            // info[9] = loanState

            // Check amountOwed() data ...
            assertEq(principalOwed + interestOwed + lateFeeOwed, totalOwed);
            if (schedule == int8(0)) {
                // Bullet payment structure.
                if (_preInfo[4] == 1) {
                    assertEq(principalOwed, _preInfo[0]);
                }
            }
            else {
                // Amortization payment structure.
                assertEq(principalOwed, _preInfo[0] / _preInfo[4]);
            }
            if (block.timestamp > _preInfo[3]) {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS) +
                // loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
                assertEq(
                    interestOwed + lateFeeOwed, 
                    _preInfo[0] * _preInfo[6] * _preInfo[1] / (86400 * 365 * BIPS) + 
                    _preInfo[0] * (block.timestamp - _preInfo[3]) * (_preInfo[2]) / (86400 * 365 * BIPS)

                );
            }
            else {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS)
                assertEq(
                    interestOwed + lateFeeOwed, 
                    _preInfo[0] * _preInfo[6] * _preInfo[1] / (86400 * 365 * BIPS)
                );
            }

            // Make payment.
            hevm.expectEmit(true, true, false, true, address(OCC_Modular_DAI));
            emit PaymentMade(_loanID_DAI, address(tim), totalOwed, principalOwed, interestOwed, lateFeeOwed, _preInfo[3] + _preInfo[6]);
            assert(tim.try_makePayment(address(OCC_Modular_DAI), _loanID_DAI));

            // Post-state.
            (,, _postInfo) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
            balanceData[1] = IERC20(DAI).balanceOf(address(DAO));
            balanceData[3] = IERC20(DAI).balanceOf(address(YDL));
            balanceData[5] = IERC20(DAI).balanceOf(address(tim));

            // info[0] = principalOwed
            // info[3] = paymentDueBy
            // info[4] = paymentsRemaining
            // info[6] = paymentInterval
            // info[9] = loanState

            // Check state changes.
            assertEq(_postInfo[0], _preInfo[0] - principalOwed);

            if (_postInfo[4] == 0) {
                assertEq(_postInfo[0], 0);
                assertEq(_postInfo[3], 0);
                assertEq(_postInfo[4], 0);
                assertEq(_postInfo[9], 3);
            }
            else {
                assertEq(_postInfo[3], _preInfo[3] + _preInfo[6]);
                assertEq(_postInfo[4], _preInfo[4] - 1);
                assertEq(_postInfo[9], 2);
            }

            assertEq(balanceData[1] - balanceData[0], principalOwed);
            assertEq(balanceData[3] - balanceData[2], interestOwed + lateFeeOwed);
            assertEq(balanceData[4] - balanceData[5], totalOwed);
            
            // Warp to next paymentDueBy.
            hevm.warp(_postInfo[3]);

            // 20% chance to make late payment (warp ahead of time).
            if (totalOwed % 5 == 0) {
                hevm.warp(_postInfo[3] + random % 7776000); // Potentially up to 90 days late payment.
            }
        }

    }

    function test_OCC_Modular_makePayment_state_FRAX(uint96 random, bool choice) public {

        (, uint256 _loanID_FRAX,,) = simulateITO_and_createOffers_and_acceptOffers(random, choice);

        (,, uint256[10] memory _preInfo) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        (,, uint256[10] memory _postInfo) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
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

        while(_postInfo[4] > 0) {
            
            // Pre-state.
            (principalOwed, interestOwed, lateFeeOwed, totalOwed) = OCC_Modular_FRAX.amountOwed(_loanID_FRAX);
            (,, _preInfo) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
            balanceData[0] = IERC20(FRAX).balanceOf(address(DAO));
            balanceData[2] = IERC20(FRAX).balanceOf(address(Treasury));
            balanceData[4] = IERC20(FRAX).balanceOf(address(tim));

            // info[0] = principalOwed
            // info[1] = APR
            // info[2] = APRLateFee
            // info[3] = paymentDueBy
            // info[4] = paymentsRemaining
            // info[6] = paymentInterval
            // info[9] = loanState

            // Check amountOwed() data ...
            assertEq(principalOwed + interestOwed + lateFeeOwed, totalOwed);
            if (schedule == int8(0)) {
                // Bullet payment structure.
                if (_preInfo[4] == 1) {
                    assertEq(principalOwed, _preInfo[0]);
                }
            }
            else {
                // Amortization payment structure.
                assertEq(principalOwed, _preInfo[0] / _preInfo[4]);
            }
            if (block.timestamp > _preInfo[3]) {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS) +
                // loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
                assertEq(
                    interestOwed + lateFeeOwed, 
                    _preInfo[0] * _preInfo[6] * _preInfo[1] / (86400 * 365 * BIPS) + 
                    _preInfo[0] * (block.timestamp - _preInfo[3]) * (_preInfo[2]) / (86400 * 365 * BIPS)

                );
            }
            else {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS)
                assertEq(
                    interestOwed + lateFeeOwed, 
                    _preInfo[0] * _preInfo[6] * _preInfo[1] / (86400 * 365 * BIPS)
                );
            }

            // Make payment.
            hevm.expectEmit(true, true, false, true, address(OCC_Modular_FRAX));
            emit PaymentMade(_loanID_FRAX, address(tim), totalOwed, principalOwed, interestOwed, lateFeeOwed, _preInfo[3] + _preInfo[6]);
            assert(tim.try_makePayment(address(OCC_Modular_FRAX), _loanID_FRAX));

            // Post-state.
            (,, _postInfo) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
            balanceData[1] = IERC20(FRAX).balanceOf(address(DAO));
            balanceData[3] = IERC20(FRAX).balanceOf(address(Treasury));
            balanceData[5] = IERC20(FRAX).balanceOf(address(tim));

            // info[0] = principalOwed
            // info[3] = paymentDueBy
            // info[4] = paymentsRemaining
            // info[6] = paymentInterval
            // info[9] = loanState

            assertEq(_postInfo[0], _preInfo[0] - principalOwed);

            if (_postInfo[4] == 0) {
                assertEq(_postInfo[0], 0);
                assertEq(_postInfo[3], 0);
                assertEq(_postInfo[4], 0);
                assertEq(_postInfo[9], 3);
            }
            else {
                assertEq(_postInfo[3], _preInfo[3] + _preInfo[6]);
                assertEq(_postInfo[4], _preInfo[4] - 1);
                assertEq(_postInfo[9], 2);
            }

            assertEq(balanceData[1] - balanceData[0], principalOwed);
            assertEq(balanceData[3] - balanceData[2], interestOwed + lateFeeOwed);
            assertEq(balanceData[4] - balanceData[5], totalOwed);
            
            // Warp to next paymentDueBy.
            hevm.warp(_postInfo[3]);

            // 20% chance to make late payment (warp ahead of time).
            if (totalOwed % 5 == 0) {
                hevm.warp(_postInfo[3] + random % 7776000); // Potentially up to 90 days late payment.
            }
        }

    }

    function test_OCC_Modular_makePayment_state_USDC(uint96 random, bool choice) public {

        (,, uint256 _loanID_USDC,) = simulateITO_and_createOffers_and_acceptOffers(random, choice);

        (,, uint256[10] memory _preInfo) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        (,, uint256[10] memory _postInfo) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
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

        while(_postInfo[4] > 0) {
            
            // Pre-state.
            (principalOwed, interestOwed, lateFeeOwed, totalOwed) = OCC_Modular_USDC.amountOwed(_loanID_USDC);
            (,, _preInfo) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
            balanceData[0] = IERC20(USDC).balanceOf(address(DAO));
            balanceData[2] = IERC20(USDC).balanceOf(address(Treasury));
            balanceData[4] = IERC20(USDC).balanceOf(address(tim));

            // info[0] = principalOwed
            // info[1] = APR
            // info[2] = APRLateFee
            // info[3] = paymentDueBy
            // info[4] = paymentsRemaining
            // info[6] = paymentInterval
            // info[9] = loanState

            // Check amountOwed() data ...
            assertEq(principalOwed + interestOwed + lateFeeOwed, totalOwed);
            if (schedule == int8(0)) {
                // Bullet payment structure.
                if (_preInfo[4] == 1) {
                    assertEq(principalOwed, _preInfo[0]);
                }
            }
            else {
                // Amortization payment structure.
                assertEq(principalOwed, _preInfo[0] / _preInfo[4]);
            }
            if (block.timestamp > _preInfo[3]) {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS) +
                // loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
                assertEq(
                    interestOwed + lateFeeOwed, 
                    _preInfo[0] * _preInfo[6] * _preInfo[1] / (86400 * 365 * BIPS) + 
                    _preInfo[0] * (block.timestamp - _preInfo[3]) * (_preInfo[2]) / (86400 * 365 * BIPS)

                );
            }
            else {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS)
                assertEq(
                    interestOwed + lateFeeOwed, 
                    _preInfo[0] * _preInfo[6] * _preInfo[1] / (86400 * 365 * BIPS)
                );
            }

            // Make payment.
            hevm.expectEmit(true, true, false, true, address(OCC_Modular_USDC));
            emit PaymentMade(_loanID_USDC, address(tim), totalOwed, principalOwed, interestOwed, lateFeeOwed, _preInfo[3] + _preInfo[6]);
            assert(tim.try_makePayment(address(OCC_Modular_USDC), _loanID_USDC));

            // Post-state.
            (,, _postInfo) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
            balanceData[1] = IERC20(USDC).balanceOf(address(DAO));
            balanceData[3] = IERC20(USDC).balanceOf(address(Treasury));
            balanceData[5] = IERC20(USDC).balanceOf(address(tim));

            // info[0] = principalOwed
            // info[3] = paymentDueBy
            // info[4] = paymentsRemaining
            // info[6] = paymentInterval
            // info[9] = loanState

            assertEq(_postInfo[0], _preInfo[0] - principalOwed);

            if (_postInfo[4] == 0) {
                assertEq(_postInfo[0], 0);
                assertEq(_postInfo[3], 0);
                assertEq(_postInfo[4], 0);
                assertEq(_postInfo[9], 3);
            }
            else {
                assertEq(_postInfo[3], _preInfo[3] + _preInfo[6]);
                assertEq(_postInfo[4], _preInfo[4] - 1);
                assertEq(_postInfo[9], 2);
            }
            
            assertEq(balanceData[1] - balanceData[0], principalOwed);
            assertEq(balanceData[3] - balanceData[2], interestOwed + lateFeeOwed);
            assertEq(balanceData[4] - balanceData[5], totalOwed);
            
            // Warp to next paymentDueBy.
            hevm.warp(_postInfo[3]);

            // 20% chance to make late payment (warp ahead of time).
            if (totalOwed % 5 == 0) {
                hevm.warp(_postInfo[3] + random % 7776000); // Potentially up to 90 days late payment.
            }
        }

    }

    function test_OCC_Modular_makePayment_state_USDT(uint96 random, bool choice) public {

        (,,, uint256 _loanID_USDT) = simulateITO_and_createOffers_and_acceptOffers(random, choice);

        (,, uint256[10] memory _preInfo) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
        (,, uint256[10] memory _postInfo) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
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

        while(_postInfo[4] > 0) {
            
            // Pre-state.
            (principalOwed, interestOwed, lateFeeOwed, totalOwed) = OCC_Modular_USDT.amountOwed(_loanID_USDT);
            (,, _preInfo) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
            balanceData[0] = IERC20(USDT).balanceOf(address(DAO));
            balanceData[2] = IERC20(USDT).balanceOf(address(Treasury));
            balanceData[4] = IERC20(USDT).balanceOf(address(tim));

            // info[0] = principalOwed
            // info[1] = APR
            // info[2] = APRLateFee
            // info[3] = paymentDueBy
            // info[4] = paymentsRemaining
            // info[6] = paymentInterval
            // info[9] = loanState

            // Check amountOwed() data ...
            assertEq(principalOwed + interestOwed + lateFeeOwed, totalOwed);
            if (schedule == int8(0)) {
                // Bullet payment structure.
                if (_preInfo[4] == 1) {
                    assertEq(principalOwed, _preInfo[0]);
                }
            }
            else {
                // Amortization payment structure.
                assertEq(principalOwed, _preInfo[0] / _preInfo[4]);
            }
            if (block.timestamp > _preInfo[3]) {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS) +
                // loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
                assertEq(
                    interestOwed + lateFeeOwed, 
                    _preInfo[0] * _preInfo[6] * _preInfo[1] / (86400 * 365 * BIPS) + 
                    _preInfo[0] * (block.timestamp - _preInfo[3]) * (_preInfo[2]) / (86400 * 365 * BIPS)

                );
            }
            else {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS)
                assertEq(
                    interestOwed + lateFeeOwed, 
                    _preInfo[0] * _preInfo[6] * _preInfo[1] / (86400 * 365 * BIPS)
                );
            }

            // Make payment.
            hevm.expectEmit(true, true, false, true, address(OCC_Modular_USDT));
            emit PaymentMade(_loanID_USDT, address(tim), totalOwed, principalOwed, interestOwed, lateFeeOwed, _preInfo[3] + _preInfo[6]);
            assert(tim.try_makePayment(address(OCC_Modular_USDT), _loanID_USDT));

            // Post-state.
            (,, _postInfo) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
            balanceData[1] = IERC20(USDT).balanceOf(address(DAO));
            balanceData[3] = IERC20(USDT).balanceOf(address(Treasury));
            balanceData[5] = IERC20(USDT).balanceOf(address(tim));
            
            // info[0] = principalOwed
            // info[3] = paymentDueBy
            // info[4] = paymentsRemaining
            // info[6] = paymentInterval
            // info[9] = loanState

            assertEq(_postInfo[0], _preInfo[0] - principalOwed);

            if (_postInfo[4] == 0) {
                assertEq(_postInfo[0], 0);
                assertEq(_postInfo[3], 0);
                assertEq(_postInfo[4], 0);
                assertEq(_postInfo[9], 3);
            }
            else {
                assertEq(_postInfo[3], _preInfo[3] + _preInfo[6]);
                assertEq(_postInfo[4], _preInfo[4] - 1);
                assertEq(_postInfo[9], 2);
            }

            assertEq(balanceData[1] - balanceData[0], principalOwed);
            assertEq(balanceData[3] - balanceData[2], interestOwed + lateFeeOwed);
            assertEq(balanceData[4] - balanceData[5], totalOwed);
            
            // Warp to next paymentDueBy.
            hevm.warp(_postInfo[3]);

            // 20% chance to make late payment (warp ahead of time).
            if (totalOwed % 5 == 0) {
                hevm.warp(_postInfo[3] + random % 7776000); // Potentially up to 90 days late payment.
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
        emit DefaultMarked(_loanID_DAI, loanInfo[0]);
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
        emit DefaultMarked(_loanID_FRAX, loanInfo[0]);
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
        emit DefaultMarked(_loanID_USDC, loanInfo[0]);
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
        emit DefaultMarked(_loanID_USDT, loanInfo[0]);
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
        (,, uint256[10] memory _info_DAI) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        (,, uint256[10] memory _info_FRAX) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        (,, uint256[10] memory _info_USDC) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        (,, uint256[10] memory _info_USDT) = OCC_Modular_USDT.loanInfo(_loanID_USDT);

        assertEq(_info_DAI[9], 6);
        assertEq(_info_FRAX[9], 6);
        assertEq(_info_USDC[9], 6);
        assertEq(_info_USDT[9], 6);

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
        (,, _info_DAI) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        (,, _info_FRAX) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        (,, _info_USDC) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        (,, _info_USDT) = OCC_Modular_USDT.loanInfo(_loanID_USDT);

        assertEq(_info_DAI[9], 3);
        assertEq(_info_FRAX[9], 3);
        assertEq(_info_USDC[9], 3);
        assertEq(_info_USDT[9], 3);

    }


    // Validate processPayment() state changes.
    // Validate processPayment() restrictions.
    // This includes:
    //  - Can't call unless _msgSender() is underwriter or keeper
    //  - Can't call processPayment() unless state == LoanState.Active
    //  - Can't call processPayment() unless block.timestamp > nextPaymentDue

    function test_OCC_Modular_processPayment_restrictions_msgSender(uint96 random, bool choice) public {
        
        (
            uint256 _loanID_DAI,
            uint256 _loanID_FRAX,
            uint256 _loanID_USDC,
            uint256 _loanID_USDT
        ) = simulateITO_and_createOffers(random, choice);

        // Can't call processPayment() unless state == LoanState.Active.
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCC_Modular::processPayment() _msgSender() != underwriter && !IZivoeGlobals_OCC(GBL).isKeeper(_msgSender())");
        OCC_Modular_DAI.processPayment(_loanID_DAI);
        hevm.stopPrank();

        assert(!bob.try_processPayment(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(!bob.try_processPayment(address(OCC_Modular_USDC), _loanID_USDC));
        assert(!bob.try_processPayment(address(OCC_Modular_USDT), _loanID_USDT));
    }

    function test_OCC_Modular_processPayment_restrictions_loanState(uint96 random, bool choice) public {
        
        (
            uint256 _loanID_DAI,
            uint256 _loanID_FRAX,
            uint256 _loanID_USDC,
            uint256 _loanID_USDT
        ) = simulateITO_and_createOffers(random, choice);

        // Can't call processPayment() unless state == LoanState.Active.
        hevm.startPrank(address(roy));
        hevm.expectRevert("OCC_Modular::processPayment() loans[id].state != LoanState.Active");
        OCC_Modular_DAI.processPayment(_loanID_DAI);
        hevm.stopPrank();

        assert(!roy.try_processPayment(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(!roy.try_processPayment(address(OCC_Modular_USDC), _loanID_USDC));
        assert(!roy.try_processPayment(address(OCC_Modular_USDT), _loanID_USDT));
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
        hevm.startPrank(address(roy));
        hevm.expectRevert("OCC_Modular::processPayment() block.timestamp <= loans[id].paymentDueBy - 12 hours");
        OCC_Modular_DAI.processPayment(_loanID_DAI);
        hevm.stopPrank();

        assert(!roy.try_processPayment(address(OCC_Modular_FRAX), _loanID_FRAX));
        assert(!roy.try_processPayment(address(OCC_Modular_USDC), _loanID_USDC));
        assert(!roy.try_processPayment(address(OCC_Modular_USDT), _loanID_USDT));
    }

    function test_OCC_Modular_processPayment_state_DAI(uint96 random, bool choice) public {

        (uint256 _loanID_DAI,,,) = simulateITO_and_createOffers_and_acceptOffers(random, choice);

        (,, uint256[10] memory _preInfo) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        (,, uint256[10] memory _postInfo) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
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

        hevm.warp(_preInfo[3] + 1 seconds);

        while(_postInfo[4] > 0) {
            
            // Pre-state.
            (principalOwed, interestOwed, lateFeeOwed, totalOwed) = OCC_Modular_DAI.amountOwed(_loanID_DAI);
            (,, _preInfo) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
            balanceData[0] = IERC20(DAI).balanceOf(address(DAO));
            balanceData[2] = IERC20(DAI).balanceOf(address(YDL));
            balanceData[4] = IERC20(DAI).balanceOf(address(tim));

            // info[0] = principalOwed
            // info[1] = APR
            // info[2] = APRLateFee
            // info[3] = paymentDueBy
            // info[4] = paymentsRemaining
            // info[6] = paymentInterval
            // info[9] = loanState

            // Check amountOwed() data ...
            assertEq(principalOwed + interestOwed + lateFeeOwed, totalOwed);
            if (schedule == int8(0)) {
                // Bullet payment structure.
                if (_preInfo[4] == 1) {
                    assertEq(principalOwed, _preInfo[0]);
                }
            }
            else {
                // Amortization payment structure.
                assertEq(principalOwed, _preInfo[0] / _preInfo[4]);
            }
            if (block.timestamp > _preInfo[3]) {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS) +
                // loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
                assertEq(
                    interestOwed + lateFeeOwed, 
                    _preInfo[0] * _preInfo[6] * _preInfo[1] / (86400 * 365 * BIPS) + 
                    _preInfo[0] * (block.timestamp - _preInfo[3]) * (_preInfo[2]) / (86400 * 365 * BIPS)

                );
            }
            else {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS)
                assertEq(
                    interestOwed + lateFeeOwed, 
                    _preInfo[0] * _preInfo[6] * _preInfo[1] / (86400 * 365 * BIPS)
                );
            }

            // Make payment.
            hevm.startPrank(address(roy));
            hevm.expectEmit(true, true, false, true, address(OCC_Modular_DAI));
            emit PaymentMade(_loanID_DAI, address(tim), principalOwed + interestOwed + lateFeeOwed, principalOwed, interestOwed, lateFeeOwed, _preInfo[3] + _preInfo[6]);
            OCC_Modular_DAI.processPayment(_loanID_DAI);
            hevm.stopPrank();

            // Post-state.
            (,, _postInfo) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
            balanceData[1] = IERC20(DAI).balanceOf(address(DAO));
            balanceData[3] = IERC20(DAI).balanceOf(address(YDL));
            balanceData[5] = IERC20(DAI).balanceOf(address(tim));
            
            // info[0] = principalOwed
            // info[3] = paymentDueBy
            // info[4] = paymentsRemaining
            // info[6] = paymentInterval
            // info[9] = loanState

            // Check state changes.
            assertEq(_postInfo[0], _preInfo[0] - principalOwed);

            if (_postInfo[4] == 0) {
                assertEq(_postInfo[0], 0);
                assertEq(_postInfo[3], 0);
                assertEq(_postInfo[4], 0);
                assertEq(_postInfo[9], 3);
            }
            else {
                assertEq(_postInfo[3], _preInfo[3] + _preInfo[6]);
                assertEq(_postInfo[4], _preInfo[4] - 1);
                assertEq(_postInfo[9], 2);
            }

            assertEq(balanceData[1] - balanceData[0], principalOwed);
            assertEq(balanceData[3] - balanceData[2], interestOwed + lateFeeOwed);
            assertEq(balanceData[4] - balanceData[5], totalOwed);
            
            // Warp to next paymentDueBy.
            hevm.warp(_postInfo[3] + 1 seconds);

            // 20% chance to make late payment (warp ahead of time).
            if (totalOwed % 5 == 0) {
                hevm.warp(_postInfo[3] + random % 7776000); // Potentially up to 90 days late payment.
            }
        }

    }

    function test_OCC_Modular_processPayment_state_FRAX(uint96 random, bool choice) public {

        (, uint256 _loanID_FRAX,,) = simulateITO_and_createOffers_and_acceptOffers(random, choice);

        (,, uint256[10] memory _preInfo) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        (,, uint256[10] memory _postInfo) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
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

        hevm.warp(_preInfo[3] + 1 seconds);

        while(_postInfo[4] > 0) {
            
            // Pre-state.
            (principalOwed, interestOwed, lateFeeOwed, totalOwed) = OCC_Modular_FRAX.amountOwed(_loanID_FRAX);
            (,, _preInfo) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
            balanceData[0] = IERC20(FRAX).balanceOf(address(DAO));
            balanceData[2] = IERC20(FRAX).balanceOf(address(Treasury));
            balanceData[4] = IERC20(FRAX).balanceOf(address(tim));

            // info[0] = principalOwed
            // info[1] = APR
            // info[2] = APRLateFee
            // info[3] = paymentDueBy
            // info[4] = paymentsRemaining
            // info[6] = paymentInterval
            // info[9] = loanState

            // Check amountOwed() data ...
            assertEq(principalOwed + interestOwed + lateFeeOwed, totalOwed);
            if (schedule == int8(0)) {
                // Bullet payment structure.
                if (_preInfo[4] == 1) {
                    assertEq(principalOwed, _preInfo[0]);
                }
            }
            else {
                // Amortization payment structure.
                assertEq(principalOwed, _preInfo[0] / _preInfo[4]);
            }
            if (block.timestamp > _preInfo[3]) {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS) +
                // loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
                assertEq(
                    interestOwed + lateFeeOwed, 
                    _preInfo[0] * _preInfo[6] * _preInfo[1] / (86400 * 365 * BIPS) + 
                    _preInfo[0] * (block.timestamp - _preInfo[3]) * (_preInfo[2]) / (86400 * 365 * BIPS)

                );
            }
            else {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS)
                assertEq(
                    interestOwed + lateFeeOwed, 
                    _preInfo[0] * _preInfo[6] * _preInfo[1] / (86400 * 365 * BIPS)
                );
            }

            // Make payment.
            hevm.startPrank(address(roy));
            hevm.expectEmit(true, true, false, true, address(OCC_Modular_FRAX));
            emit PaymentMade(_loanID_FRAX, address(tim), principalOwed + interestOwed + lateFeeOwed, principalOwed, interestOwed, lateFeeOwed, _preInfo[3] + _preInfo[6]);
            OCC_Modular_FRAX.processPayment(_loanID_FRAX);
            hevm.stopPrank();

            // Post-state.
            (,, _postInfo) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
            balanceData[1] = IERC20(FRAX).balanceOf(address(DAO));
            balanceData[3] = IERC20(FRAX).balanceOf(address(Treasury));
            balanceData[5] = IERC20(FRAX).balanceOf(address(tim));

            // info[0] = principalOwed
            // info[3] = paymentDueBy
            // info[4] = paymentsRemaining
            // info[6] = paymentInterval
            // info[9] = loanState

            assertEq(_postInfo[0], _preInfo[0] - principalOwed);

            if (_postInfo[4] == 0) {
                assertEq(_postInfo[0], 0);
                assertEq(_postInfo[3], 0);
                assertEq(_postInfo[4], 0);
                assertEq(_postInfo[9], 3);
            }
            else {
                assertEq(_postInfo[3], _preInfo[3] + _preInfo[6]);
                assertEq(_postInfo[4], _preInfo[4] - 1);
                assertEq(_postInfo[9], 2);
            }

            assertEq(balanceData[1] - balanceData[0], principalOwed);
            assertEq(balanceData[3] - balanceData[2], interestOwed + lateFeeOwed);
            assertEq(balanceData[4] - balanceData[5], totalOwed);
            
            // Warp to next paymentDueBy.
            hevm.warp(_postInfo[3] + 1 seconds);

            // 20% chance to make late payment (warp ahead of time).
            if (totalOwed % 5 == 0) {
                hevm.warp(_postInfo[3] + random % 7776000); // Potentially up to 90 days late payment.
            }
        }

    }

    function test_OCC_Modular_processPayment_state_USDC(uint96 random, bool choice) public {

        (,, uint256 _loanID_USDC,) = simulateITO_and_createOffers_and_acceptOffers(random, choice);

        (,, uint256[10] memory _preInfo) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        (,, uint256[10] memory _postInfo) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
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

        hevm.warp(_preInfo[3] + 1 seconds);

        while(_postInfo[4] > 0) {
            
            // Pre-state.
            (principalOwed, interestOwed, lateFeeOwed, totalOwed) = OCC_Modular_USDC.amountOwed(_loanID_USDC);
            (,, _preInfo) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
            balanceData[0] = IERC20(USDC).balanceOf(address(DAO));
            balanceData[2] = IERC20(USDC).balanceOf(address(Treasury));
            balanceData[4] = IERC20(USDC).balanceOf(address(tim));

            // info[0] = principalOwed
            // info[1] = APR
            // info[2] = APRLateFee
            // info[3] = paymentDueBy
            // info[4] = paymentsRemaining
            // info[6] = paymentInterval
            // info[9] = loanState

            // Check amountOwed() data ...
            assertEq(principalOwed + interestOwed + lateFeeOwed, totalOwed);
            if (schedule == int8(0)) {
                // Bullet payment structure.
                if (_preInfo[4] == 1) {
                    assertEq(principalOwed, _preInfo[0]);
                }
            }
            else {
                // Amortization payment structure.
                assertEq(principalOwed, _preInfo[0] / _preInfo[4]);
            }
            if (block.timestamp > _preInfo[3]) {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS) +
                // loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
                assertEq(
                    interestOwed + lateFeeOwed, 
                    _preInfo[0] * _preInfo[6] * _preInfo[1] / (86400 * 365 * BIPS) + 
                    _preInfo[0] * (block.timestamp - _preInfo[3]) * (_preInfo[2]) / (86400 * 365 * BIPS)

                );
            }
            else {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS)
                assertEq(
                    interestOwed + lateFeeOwed, 
                    _preInfo[0] * _preInfo[6] * _preInfo[1] / (86400 * 365 * BIPS)
                );
            }

            // Make payment.
            hevm.startPrank(address(roy));
            hevm.expectEmit(true, true, false, true, address(OCC_Modular_USDC));
            emit PaymentMade(_loanID_USDC, address(tim), principalOwed + interestOwed + lateFeeOwed, principalOwed, interestOwed, lateFeeOwed, _preInfo[3] + _preInfo[6]);
            OCC_Modular_USDC.processPayment(_loanID_USDC);
            hevm.stopPrank();

            // Post-state.
            (,, _postInfo) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
            balanceData[1] = IERC20(USDC).balanceOf(address(DAO));
            balanceData[3] = IERC20(USDC).balanceOf(address(Treasury));
            balanceData[5] = IERC20(USDC).balanceOf(address(tim));

            // info[0] = principalOwed
            // info[3] = paymentDueBy
            // info[4] = paymentsRemaining
            // info[6] = paymentInterval
            // info[9] = loanState

            assertEq(_postInfo[0], _preInfo[0] - principalOwed);

            if (_postInfo[4] == 0) {
                assertEq(_postInfo[0], 0);
                assertEq(_postInfo[3], 0);
                assertEq(_postInfo[4], 0);
                assertEq(_postInfo[9], 3);
            }
            else {
                assertEq(_postInfo[3], _preInfo[3] + _preInfo[6]);
                assertEq(_postInfo[4], _preInfo[4] - 1);
                assertEq(_postInfo[9], 2);
            }

            assertEq(balanceData[1] - balanceData[0], principalOwed);
            assertEq(balanceData[3] - balanceData[2], interestOwed + lateFeeOwed);
            assertEq(balanceData[4] - balanceData[5], totalOwed);
            
            // Warp to next paymentDueBy.
            hevm.warp(_postInfo[3] + 1 seconds);

            // 20% chance to make late payment (warp ahead of time).
            if (totalOwed % 5 == 0) {
                hevm.warp(_postInfo[3] + random % 7776000); // Potentially up to 90 days late payment.
            }
        }

    }

    function test_OCC_Modular_processPayment_state_USDT(uint96 random, bool choice) public {

        (,,, uint256 _loanID_USDT) = simulateITO_and_createOffers_and_acceptOffers(random, choice);

        (,, uint256[10] memory _preInfo) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
        (,, uint256[10] memory _postInfo) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
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

        hevm.warp(_preInfo[3] + 1 seconds);

        while(_postInfo[4] > 0) {
            
            // Pre-state.
            (principalOwed, interestOwed, lateFeeOwed, totalOwed) = OCC_Modular_USDT.amountOwed(_loanID_USDT);
            (,, _preInfo) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
            balanceData[0] = IERC20(USDT).balanceOf(address(DAO));
            balanceData[2] = IERC20(USDT).balanceOf(address(Treasury));
            balanceData[4] = IERC20(USDT).balanceOf(address(tim));

            // info[0] = principalOwed
            // info[1] = APR
            // info[2] = APRLateFee
            // info[3] = paymentDueBy
            // info[4] = paymentsRemaining
            // info[6] = paymentInterval
            // info[9] = loanState

            // Check amountOwed() data ...
            assertEq(principalOwed + interestOwed + lateFeeOwed, totalOwed);
            if (schedule == int8(0)) {
                // Bullet payment structure.
                if (_preInfo[4] == 1) {
                    assertEq(principalOwed, _preInfo[0]);
                }
            }
            else {
                // Amortization payment structure.
                assertEq(principalOwed, _preInfo[0] / _preInfo[4]);
            }
            if (block.timestamp > _preInfo[3]) {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS) +
                // loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) * (loans[id].APR + loans[id].APRLateFee) / (86400 * 365 * BIPS);
                assertEq(
                    interestOwed + lateFeeOwed, 
                    _preInfo[0] * _preInfo[6] * _preInfo[1] / (86400 * 365 * BIPS) + 
                    _preInfo[0] * (block.timestamp - _preInfo[3]) * (_preInfo[2]) / (86400 * 365 * BIPS)

                );
            }
            else {
                // loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS)
                assertEq(
                    interestOwed + lateFeeOwed, 
                    _preInfo[0] * _preInfo[6] * _preInfo[1] / (86400 * 365 * BIPS)
                );
            }

            // Make payment.
            hevm.startPrank(address(roy));
            hevm.expectEmit(true, true, false, true, address(OCC_Modular_USDT));
            emit PaymentMade(_loanID_USDT, address(tim), principalOwed + interestOwed + lateFeeOwed, principalOwed, interestOwed, lateFeeOwed, _preInfo[3] + _preInfo[6]);
            OCC_Modular_USDT.processPayment(_loanID_USDT);
            hevm.stopPrank();

            // Post-state.
            (,, _postInfo) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
            balanceData[1] = IERC20(USDT).balanceOf(address(DAO));
            balanceData[3] = IERC20(USDT).balanceOf(address(Treasury));
            balanceData[5] = IERC20(USDT).balanceOf(address(tim));
            
            // info[0] = principalOwed
            // info[3] = paymentDueBy
            // info[4] = paymentsRemaining
            // info[6] = paymentInterval
            // info[9] = loanState

            assertEq(_postInfo[0], _preInfo[0] - principalOwed);

            if (_postInfo[4] == 0) {
                assertEq(_postInfo[0], 0);
                assertEq(_postInfo[3], 0);
                assertEq(_postInfo[4], 0);
                assertEq(_postInfo[9], 3);
            }
            else {
                assertEq(_postInfo[3], _preInfo[3] + _preInfo[6]);
                assertEq(_postInfo[4], _preInfo[4] - 1);
                assertEq(_postInfo[9], 2);
            }

            assertEq(balanceData[1] - balanceData[0], principalOwed);
            assertEq(balanceData[3] - balanceData[2], interestOwed + lateFeeOwed);
            assertEq(balanceData[4] - balanceData[5], totalOwed);
            
            // Warp to next paymentDueBy.
            hevm.warp(_postInfo[3] + 1 seconds);

            // 20% chance to make late payment (warp ahead of time).
            if (totalOwed % 5 == 0) {
                hevm.warp(_postInfo[3] + random % 7776000); // Potentially up to 90 days late payment.
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
        (,, uint256[10] memory _preInfo) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        uint256 _preStable_DAO = IERC20(DAI).balanceOf(address(DAO));
        uint256 _preStable_tim = IERC20(DAI).balanceOf(address(tim));

        // Pay off 1/3rd of the default amount.
        hevm.expectEmit(true, true, false, true, address(OCC_Modular_DAI));
        emit DefaultResolved(_loanID_DAI, _preInfo[0] / 3, address(tim), _preInfo[0] == 0);
        assert(tim.try_resolveDefault(address(OCC_Modular_DAI), _loanID_DAI, _preInfo[0] / 3));

        // Post-state DAI, partial resolve.
        uint256 _postGlobalDefaults = GBL.defaults();
        (,, uint256[10] memory _postInfo) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
        uint256 _postStable_DAO = IERC20(DAI).balanceOf(address(DAO));
        uint256 _postStable_tim = IERC20(DAI).balanceOf(address(tim));

        assertEq(_preGlobalDefaults - _postGlobalDefaults, GBL.standardize(_preInfo[0] / 3, DAI));
        assertEq(_preInfo[0] - _postInfo[0], _preInfo[0] / 3);
        assertEq(_preStable_tim - _postStable_tim, _preInfo[0] / 3);
        assertEq(_postStable_DAO - _preStable_DAO, _preInfo[0] / 3);

        // Note: In some cases, a low-amount loan (of 0 / 1) will transition state => Resolved 
        //       on 0 x-fer resolveDefault(), therefore we perform quick check here.
        if (_postInfo[9] != 6) {
            // Post-state DAI, full resolve.
            _preGlobalDefaults = GBL.defaults();
            (,, _preInfo) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
            _preStable_DAO = IERC20(DAI).balanceOf(address(DAO));
            _preStable_tim = IERC20(DAI).balanceOf(address(tim));

            // Pay off remaining amount.
            hevm.expectEmit(true, true, false, true, address(OCC_Modular_DAI));
            emit DefaultResolved(_loanID_DAI, _preInfo[0], address(tim), true);
            assert(tim.try_resolveDefault(address(OCC_Modular_DAI), _loanID_DAI, _preInfo[0]));

            // Post-state DAI, full resolve.
            _postGlobalDefaults = GBL.defaults();
            (,, _postInfo) = OCC_Modular_DAI.loanInfo(_loanID_DAI);
            _postStable_DAO = IERC20(DAI).balanceOf(address(DAO));
            _postStable_tim = IERC20(DAI).balanceOf(address(tim));

            assertEq(_preGlobalDefaults - _postGlobalDefaults, GBL.standardize(_preInfo[0], DAI));
            assertEq(_preInfo[0] - _postInfo[0], _preInfo[0]);
            assertEq(_preStable_tim - _postStable_tim, _preInfo[0]);
            assertEq(_postStable_DAO - _preStable_DAO, _preInfo[0]);
            assertEq(_postInfo[9], 6);
        }

        // Pre-state FRAX, partial resolve.
        _preGlobalDefaults = GBL.defaults();
        (,, _preInfo) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        _preStable_DAO = IERC20(FRAX).balanceOf(address(DAO));
        _preStable_tim = IERC20(FRAX).balanceOf(address(tim));

        // Pay off 1/3rd of the default amount.
        hevm.expectEmit(true, true, false, true, address(OCC_Modular_FRAX));
        emit DefaultResolved(_loanID_FRAX, _preInfo[0] / 3, address(tim), _preInfo[0] == 0);
        assert(tim.try_resolveDefault(address(OCC_Modular_FRAX), _loanID_FRAX, _preInfo[0] / 3));

        // Post-state FRAX, partial resolve.
        _postGlobalDefaults = GBL.defaults();
        (,, _postInfo) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
        _postStable_DAO = IERC20(FRAX).balanceOf(address(DAO));
        _postStable_tim = IERC20(FRAX).balanceOf(address(tim));

        assertEq(_preGlobalDefaults - _postGlobalDefaults, GBL.standardize(_preInfo[0] / 3, FRAX));
        assertEq(_preInfo[0] - _postInfo[0], _preInfo[0] / 3);
        assertEq(_preStable_tim - _postStable_tim, _preInfo[0] / 3);
        assertEq(_postStable_DAO - _preStable_DAO, _preInfo[0] / 3);

        // Note: In some cases, a low-amount loan (of 0 / 1) will transition state => Resolved 
        //       on 0 x-fer resolveDefault(), therefore we perform quick check here.
        if (_postInfo[9] != 6) {
            // Post-state FRAX, full resolve.
            _preGlobalDefaults = GBL.defaults();
            (,, _preInfo) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
            _preStable_DAO = IERC20(FRAX).balanceOf(address(DAO));
            _preStable_tim = IERC20(FRAX).balanceOf(address(tim));

            // Pay off remaining amount.
            hevm.expectEmit(true, true, false, true, address(OCC_Modular_FRAX));
            emit DefaultResolved(_loanID_FRAX, _preInfo[0], address(tim), true);
            assert(tim.try_resolveDefault(address(OCC_Modular_FRAX), _loanID_FRAX, _preInfo[0]));

            // Post-state FRAX, full resolve.
            _postGlobalDefaults = GBL.defaults();
            (,, _postInfo) = OCC_Modular_FRAX.loanInfo(_loanID_FRAX);
            _postStable_DAO = IERC20(FRAX).balanceOf(address(DAO));
            _postStable_tim = IERC20(FRAX).balanceOf(address(tim));

            assertEq(_preGlobalDefaults - _postGlobalDefaults, GBL.standardize(_preInfo[0], FRAX));
            assertEq(_preInfo[0] - _postInfo[0], _preInfo[0]);
            assertEq(_preStable_tim - _postStable_tim, _preInfo[0]);
            assertEq(_postStable_DAO - _preStable_DAO, _preInfo[0]);
            assertEq(_postInfo[9], 6);
        }

        // Pre-state USDC, partial resolve.
        _preGlobalDefaults = GBL.defaults();
        (,, _preInfo) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        _preStable_DAO = IERC20(USDC).balanceOf(address(DAO));
        _preStable_tim = IERC20(USDC).balanceOf(address(tim));

        // Pay off 1/3rd of the default amount.
        hevm.expectEmit(true, true, false, true, address(OCC_Modular_USDC));
        emit DefaultResolved(_loanID_USDC, _preInfo[0] / 3, address(tim), _preInfo[0] == 0);
        assert(tim.try_resolveDefault(address(OCC_Modular_USDC), _loanID_USDC, _preInfo[0] / 3));

        // Post-state USDC, partial resolve.
        _postGlobalDefaults = GBL.defaults();
        (,, _postInfo) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
        _postStable_DAO = IERC20(USDC).balanceOf(address(DAO));
        _postStable_tim = IERC20(USDC).balanceOf(address(tim));

        assertEq(_preGlobalDefaults - _postGlobalDefaults, GBL.standardize(_preInfo[0] / 3, USDC));
        assertEq(_preInfo[0] - _postInfo[0], _preInfo[0] / 3);
        assertEq(_preStable_tim - _postStable_tim, _preInfo[0] / 3);
        assertEq(_postStable_DAO - _preStable_DAO, _preInfo[0] / 3);

        // Note: In some cases, a low-amount loan (of 0 / 1) will transition state => Resolved 
        //       on 0 x-fer resolveDefault(), therefore we perform quick check here.
        if (_postInfo[9] != 6) {
            // Post-state USDC, full resolve.
            _preGlobalDefaults = GBL.defaults();
            (,, _preInfo) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
            _preStable_DAO = IERC20(USDC).balanceOf(address(DAO));
            _preStable_tim = IERC20(USDC).balanceOf(address(tim));

            // Pay off remaining amount.
            hevm.expectEmit(true, true, false, true, address(OCC_Modular_USDC));
            emit DefaultResolved(_loanID_USDC, _preInfo[0], address(tim), true);
            assert(tim.try_resolveDefault(address(OCC_Modular_USDC), _loanID_USDC, _preInfo[0]));

            // Post-state USDC, full resolve.
            _postGlobalDefaults = GBL.defaults();
            (,, _postInfo) = OCC_Modular_USDC.loanInfo(_loanID_USDC);
            _postStable_DAO = IERC20(USDC).balanceOf(address(DAO));
            _postStable_tim = IERC20(USDC).balanceOf(address(tim));

            assertEq(_preGlobalDefaults - _postGlobalDefaults, GBL.standardize(_preInfo[0], USDC));
            assertEq(_preInfo[0] - _postInfo[0], _preInfo[0]);
            assertEq(_preStable_tim - _postStable_tim, _preInfo[0]);
            assertEq(_postStable_DAO - _preStable_DAO, _preInfo[0]);
            assertEq(_postInfo[9], 6);
        }

        // Pre-state USDT, partial resolve.
        _preGlobalDefaults = GBL.defaults();
        (,, _preInfo) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
        _preStable_DAO = IERC20(USDT).balanceOf(address(DAO));
        _preStable_tim = IERC20(USDT).balanceOf(address(tim));

        // Pay off 1/3rd of the default amount.
        hevm.expectEmit(true, true, false, true, address(OCC_Modular_USDT));
        emit DefaultResolved(_loanID_USDT, _preInfo[0] / 3, address(tim), _preInfo[0] == 0);
        assert(tim.try_resolveDefault(address(OCC_Modular_USDT), _loanID_USDT, _preInfo[0] / 3));

        // Post-state USDT, partial resolve.
        _postGlobalDefaults = GBL.defaults();
        (,, _postInfo) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
        _postStable_DAO = IERC20(USDT).balanceOf(address(DAO));
        _postStable_tim = IERC20(USDT).balanceOf(address(tim));

        assertEq(_preGlobalDefaults - _postGlobalDefaults, GBL.standardize(_preInfo[0] / 3, USDT));
        assertEq(_preInfo[0] - _postInfo[0], _preInfo[0] / 3);
        assertEq(_preStable_tim - _postStable_tim, _preInfo[0] / 3);
        assertEq(_postStable_DAO - _preStable_DAO, _preInfo[0] / 3);

        // Note: In some cases, a low-amount loan (of 0 / 1) will transition state => Resolved 
        //       on 0 x-fer resolveDefault(), therefore we perform quick check here.
        if (_postInfo[9] != 6) {
            // Post-state USDT, full resolve.
            _preGlobalDefaults = GBL.defaults();
            (,, _preInfo) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
            _preStable_DAO = IERC20(USDT).balanceOf(address(DAO));
            _preStable_tim = IERC20(USDT).balanceOf(address(tim));

            // Pay off remaining amount.
            hevm.expectEmit(true, true, false, true, address(OCC_Modular_USDT));
            emit DefaultResolved(_loanID_USDT, _preInfo[0], address(tim), true);
            assert(tim.try_resolveDefault(address(OCC_Modular_USDT), _loanID_USDT, _preInfo[0]));

            // Post-state USDT, full resolve.
            _postGlobalDefaults = GBL.defaults();
            (,, _postInfo) = OCC_Modular_USDT.loanInfo(_loanID_USDT);
            _postStable_DAO = IERC20(USDT).balanceOf(address(DAO));
            _postStable_tim = IERC20(USDT).balanceOf(address(tim));

            assertEq(_preGlobalDefaults - _postGlobalDefaults, GBL.standardize(_preInfo[0], USDT));
            assertEq(_preInfo[0] - _postInfo[0], _preInfo[0]);
            assertEq(_preStable_tim - _postStable_tim, _preInfo[0]);
            assertEq(_postStable_DAO - _preStable_DAO, _preInfo[0]);
            assertEq(_postInfo[9], 6);
        }

    }

    // Validate updateOCTYDL() state changes.
    // Validate updateOCTYDL() restrictions.
    // This includes:
    //   - _msgSender() must be ZVL

    function test_OCC_Modular_updateOCTYDL_restrictions_msgSender() public {
        // Can't call if _msgSender() is not ZVL.
        hevm.startPrank(address(bob));
        hevm.expectRevert("");
        OCC_Modular_DAI.updateOCTYDL(address(bob));
        hevm.stopPrank();
    }

    function test_OCC_Modular_updateOCTYDL_state(address fuzzed) public {
        
        hevm.assume(fuzzed != address(0));
        
        // Pre-state.
        assertEq(OCC_Modular_DAI.OCT_YDL(), address(Treasury));

        // updateOCTYDL().
        hevm.expectEmit(true, true, false, false, address(OCC_Modular_DAI));
        emit UpdatedOCTYDL(address(fuzzed), address(Treasury));
        hevm.startPrank(address(zvl));
        OCC_Modular_DAI.updateOCTYDL(address(fuzzed));
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
    //  - combination[id].valid == True
    //  - combination[id].expires has not passed yet
    //  - each loan supplied, _msgSender() is borrower
    //  - each loan supplied, state == LoanState.Active

    function test_OCC_Modular_applyCombine_restrictions_valid() public {

        // applyCombine(0) NOTE: ID 0 does not exist (not valid)
        hevm.startPrank(address(tim));
        hevm.expectRevert("OCC_Modular::applyCombine() !combinations[id].valid");
        OCC_Modular_DAI.applyCombine(0);
        hevm.stopPrank();

    }

    function test_OCC_Modular_applyCombine_restrictions_expires(
        uint96 random, bool choice, uint8 select, uint termOffer, uint gracePeriodOffer, uint24 aprLateFee
    ) public {
        
        hevm.assume(gracePeriodOffer >= 7 days);
        hevm.assume(termOffer > 0 && termOffer < 100);

        simulateITO_and_createOffers(random, choice);
        createRandomOffer(random, choice, DAI);

        uint256[] memory loanIDs = new uint256[](2);
        loanIDs[0] = 0;
        loanIDs[1] = 1;

        uint256 option = uint256(select) % 5;
        int8 paymentScheduleOffer = choice ? int8(0) : int8(1);

        // approveCombine().
        hevm.startPrank(address(roy));
        OCC_Modular_DAI.approveCombine(loanIDs, aprLateFee, termOffer, options[option], gracePeriodOffer, paymentScheduleOffer);
        hevm.stopPrank();

        hevm.warp(block.timestamp + 72 hours);

        // applyCombine().
        hevm.startPrank(address(tim));
        hevm.expectRevert("OCC_Modular::applyCombine() block.timestamp >= combinations[id].expires");
        OCC_Modular_DAI.applyCombine(0);
        hevm.stopPrank();
    }

    function test_OCC_Modular_applyCombine_restrictions_borrower(
        uint96 random, bool choice, uint8 select, uint termOffer, uint gracePeriodOffer, uint24 aprLateFee
    ) public {
        
        hevm.assume(gracePeriodOffer >= 7 days);
        hevm.assume(termOffer > 0 && termOffer < 100);

        simulateITO_and_createOffers(random, choice);
        createRandomOffer(random, choice, DAI);

        tim_acceptOffer(0, DAI);
        tim_acceptOffer(1, DAI);

        uint256[] memory loanIDs = new uint256[](2);
        loanIDs[0] = 0;
        loanIDs[1] = 1;

        uint256 option = uint256(select) % 5;
        int8 paymentScheduleOffer = choice ? int8(0) : int8(1);

        // approveCombine().
        hevm.startPrank(address(roy));
        OCC_Modular_DAI.approveCombine(loanIDs, aprLateFee, termOffer, options[option], gracePeriodOffer, paymentScheduleOffer);
        hevm.stopPrank();

        // applyCombine().
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCC_Modular::applyCombine() _msgSender() != loans[loanID].borrower");
        OCC_Modular_DAI.applyCombine(0);
        hevm.stopPrank();
    }

    function test_OCC_Modular_applyCombine_restrictions_loanState(
        uint96 random, bool choice, uint8 select, uint termOffer, uint gracePeriodOffer, uint24 aprLateFee
    ) public {
        
        hevm.assume(gracePeriodOffer >= 7 days);
        hevm.assume(termOffer > 0 && termOffer < 100);

        simulateITO_and_createOffers(random, choice);
        createRandomOffer(random, choice, DAI);

        // tim_acceptOffer(0, DAI);
        // tim_acceptOffer(1, DAI);

        uint256[] memory loanIDs = new uint256[](2);
        loanIDs[0] = 0;
        loanIDs[1] = 1;

        uint256 option = uint256(select) % 5;
        int8 paymentScheduleOffer = choice ? int8(0) : int8(1);

        // approveCombine().
        hevm.startPrank(address(roy));
        OCC_Modular_DAI.approveCombine(loanIDs, aprLateFee, termOffer, options[option], gracePeriodOffer, paymentScheduleOffer);
        hevm.stopPrank();

        // applyCombine().
        hevm.startPrank(address(tim));
        hevm.expectRevert("OCC_Modular::applyCombine() loans[loanID].state != LoanState.Active");
        OCC_Modular_DAI.applyCombine(0);
        hevm.stopPrank();
    }


    function test_OCC_Modular_applyCombine_twoLoans_state(
        uint96 random, bool choice, uint8 select, uint termOffer, uint gracePeriodOffer, uint24 aprLateFee
    ) public {

        hevm.assume(gracePeriodOffer >= 7 days);
        hevm.assume(termOffer > 0 && termOffer < 100);

        simulateITO_and_createOffers(random, choice);
        createRandomOffer(random, choice, DAI);
        
        uint[] memory loanIDs = new uint[](2);
        loanIDs[0] = 0;
        loanIDs[1] = 1;

        tim_acceptOffer(0, DAI);
        tim_acceptOffer(1, DAI);

        uint256 option = uint256(select) % 5;
        int8 paymentScheduleOffer = choice ? int8(0) : int8(1);

        // approveCombine().
        hevm.startPrank(address(roy));
        OCC_Modular_DAI.approveCombine(loanIDs, aprLateFee, termOffer, options[option], gracePeriodOffer, paymentScheduleOffer);
        hevm.stopPrank();

        (,, uint256[10] memory preInfo_0) = OCC_Modular_DAI.loanInfo(0);
        (,, uint256[10] memory preInfo_1) = OCC_Modular_DAI.loanInfo(1);

        assertEq(OCC_Modular_DAI.loanCounter(), 2);

        hevm.startPrank(address(tim));
        OCC_Modular_DAI.applyCombine(0);
        hevm.stopPrank();

        (,, uint256[10] memory postInfo_0) = OCC_Modular_DAI.loanInfo(0);
        (,, uint256[10] memory postInfo_1) = OCC_Modular_DAI.loanInfo(1);
        (address borrower, int8 paymentSchedule, uint256[10] memory postInfo_2) = OCC_Modular_DAI.loanInfo(2);

        assertEq(OCC_Modular_DAI.loanCounter(), 3);

        // Loan ID #0 (combined into Loan ID #2)
        {
            assertEq(postInfo_0[0], 0); // principalOwed
            assertEq(postInfo_0[3], 0); // paymentDueBy
            assertEq(postInfo_0[4], 0); // paymentsRemaining
            assertEq(postInfo_0[9], 7); // loanState (7 => combined)
        }

        // Loan ID #1 (Combined into Loan ID #2)
        {
            assertEq(postInfo_1[0], 0); // principalOwed
            assertEq(postInfo_1[3], 0); // paymentDueBy
            assertEq(postInfo_1[4], 0); // paymentsRemaining
            assertEq(postInfo_1[9], 7); // loanState (7 => combined)
        }
        
        // Loan ID #2
        {
            assertEq(postInfo_2[0], preInfo_0[0] + preInfo_1[0]); // principalOwed
            assertEq(
                postInfo_2[1], 
                (preInfo_0[0] * preInfo_0[1] + preInfo_1[0] *  preInfo_1[1]) / (preInfo_0[0] + preInfo_1[0])
            ); // APR
            assertEq(postInfo_2[2], aprLateFee); // APRLateFee == APR
            assertEq(postInfo_2[3], block.timestamp - block.timestamp % 7 days + 9 days + postInfo_2[6]); // paymentDueBy
            assertEq(postInfo_2[4], termOffer); // paymentsRemaining
            assertEq(postInfo_2[5], termOffer); // term
            assertEq(postInfo_2[6], options[option]); // paymentInterval
            assertEq(postInfo_2[7], block.timestamp - 1 days); // offerExpiry
            assertEq(postInfo_2[8], gracePeriodOffer); // gracePeriod
            assertEq(postInfo_2[9], 2); // loanState (2 => active)

            assertEq(borrower, address(tim));
            assertEq(paymentSchedule, paymentScheduleOffer);
        }
    }

    function test_OCC_Modular_applyCombine_threeLoans_state(
        uint96 random, bool choice, uint8 select, uint termOffer, uint gracePeriodOffer, uint24 aprLateFee
    ) public {

        hevm.assume(gracePeriodOffer >= 7 days);
        hevm.assume(termOffer > 0 && termOffer < 100);

        simulateITO_and_createOffers(random, choice);
        createRandomOffer(random, choice, DAI);
        createRandomOffer(random, choice, DAI);

        uint[] memory loanIDs = new uint[](3);
        loanIDs[0] = 0;
        loanIDs[1] = 1;
        loanIDs[2] = 2;

        tim_acceptOffer(0, DAI);
        tim_acceptOffer(1, DAI);
        tim_acceptOffer(2, DAI);

        uint256 option = uint256(select) % 5;
        int8 paymentScheduleOffer = choice ? int8(0) : int8(1);

        // approveCombine().
        hevm.startPrank(address(roy));
        OCC_Modular_DAI.approveCombine(loanIDs, aprLateFee, termOffer, options[option], gracePeriodOffer, paymentScheduleOffer);
        hevm.stopPrank();

        (,, uint256[10] memory preInfo_0) = OCC_Modular_DAI.loanInfo(0);
        (,, uint256[10] memory preInfo_1) = OCC_Modular_DAI.loanInfo(1);
        (,, uint256[10] memory preInfo_2) = OCC_Modular_DAI.loanInfo(2);

        assertEq(OCC_Modular_DAI.loanCounter(), 3);

        hevm.startPrank(address(tim));
        OCC_Modular_DAI.applyCombine(0);
        hevm.stopPrank();

        (,, uint256[10] memory postInfo_0) = OCC_Modular_DAI.loanInfo(0);
        (,, uint256[10] memory postInfo_1) = OCC_Modular_DAI.loanInfo(1);
        (,, uint256[10] memory postInfo_2) = OCC_Modular_DAI.loanInfo(2);
        (address borrower, int8 paymentSchedule, uint256[10] memory postInfo_3) = OCC_Modular_DAI.loanInfo(3);

        assertEq(OCC_Modular_DAI.loanCounter(), 4);

        // Loan ID #0 (combined into Loan ID #3)
        {
            assertEq(postInfo_0[0], 0); // principalOwed
            assertEq(postInfo_0[3], 0); // paymentDueBy
            assertEq(postInfo_0[4], 0); // paymentsRemaining
            assertEq(postInfo_0[9], 7); // loanState (7 => combined)
        }

        // Loan ID #1 (Combined into Loan ID #3)
        {
            assertEq(postInfo_1[0], 0); // principalOwed
            assertEq(postInfo_1[3], 0); // paymentDueBy
            assertEq(postInfo_1[4], 0); // paymentsRemaining
            assertEq(postInfo_1[9], 7); // loanState (7 => combined)
        }

        // Loan ID #2 (Combined into Loan ID #3)
        {
            assertEq(postInfo_2[0], 0); // principalOwed
            assertEq(postInfo_2[3], 0); // paymentDueBy
            assertEq(postInfo_2[4], 0); // paymentsRemaining
            assertEq(postInfo_2[9], 7); // loanState (7 => combined)
        }
        
        // Loan ID #3
        {


            uint upper = preInfo_0[0] * preInfo_0[1] + preInfo_1[0] *  preInfo_1[1] + preInfo_2[0] * preInfo_2[1];
            uint lower = preInfo_0[0] + preInfo_1[0] + preInfo_2[0];

            assertEq(postInfo_3[0], preInfo_0[0] + preInfo_1[0] + preInfo_2[0]); // principalOwed
            assertEq(
                postInfo_3[1], 
                upper / lower
            ); // APR
            // assertEq(postInfo_3[2], aprLateFee); // APRLateFee == APR
            assertEq(postInfo_3[3], block.timestamp - block.timestamp % 7 days + 9 days + postInfo_3[6]); // paymentDueBy

        }

        {
            // assertEq(postInfo_3[4], termOffer); // paymentsRemaining
            // assertEq(postInfo_3[5], termOffer); // term
            // assertEq(postInfo_3[6], options[option]); // paymentInterval
            // assertEq(postInfo_3[7], block.timestamp - 1 days); // offerExpiry
            // assertEq(postInfo_3[8], gracePeriodOffer); // gracePeriod
            // assertEq(postInfo_3[9], 2); // loanState (2 => active)

            // assertEq(borrower, address(tim));
            // assertEq(paymentSchedule, paymentScheduleOffer);
        }

    }

    function test_OCC_Modular_applyCombine_fourLoans_state(
        uint96 random, bool choice, uint8 select, uint termOffer, uint gracePeriodOffer, uint24 aprLateFee
    ) public {

        hevm.assume(gracePeriodOffer >= 7 days);
        hevm.assume(termOffer > 0 && termOffer < 100);

        simulateITO_and_createOffers(random, choice);
        createRandomOffer(random, choice, DAI);
        createRandomOffer(random, choice, DAI);
        createRandomOffer(random, choice, DAI);

        uint[] memory loanIDs = new uint[](4);
        loanIDs[0] = 0;
        loanIDs[1] = 1;
        loanIDs[2] = 2;
        loanIDs[3] = 3;

        tim_acceptOffer(0, DAI);
        tim_acceptOffer(1, DAI);
        tim_acceptOffer(2, DAI);
        tim_acceptOffer(3, DAI);

        uint256 option = uint256(select) % 5;
        int8 paymentScheduleOffer = choice ? int8(0) : int8(1);

        // approveCombine().
        hevm.startPrank(address(roy));
        OCC_Modular_DAI.approveCombine(loanIDs, aprLateFee, termOffer, options[option], gracePeriodOffer, paymentScheduleOffer);
        hevm.stopPrank();

        (,, uint256[10] memory preInfo_0) = OCC_Modular_DAI.loanInfo(0);
        (,, uint256[10] memory preInfo_1) = OCC_Modular_DAI.loanInfo(1);
        (,, uint256[10] memory preInfo_2) = OCC_Modular_DAI.loanInfo(2);
        (,, uint256[10] memory preInfo_3) = OCC_Modular_DAI.loanInfo(3);

        assertEq(OCC_Modular_DAI.loanCounter(), 4);

        hevm.startPrank(address(tim));
        OCC_Modular_DAI.applyCombine(0);
        hevm.stopPrank();

        (,, uint256[10] memory postInfo_0) = OCC_Modular_DAI.loanInfo(0);
        (,, uint256[10] memory postInfo_1) = OCC_Modular_DAI.loanInfo(1);
        (,, uint256[10] memory postInfo_2) = OCC_Modular_DAI.loanInfo(2);
        (,, uint256[10] memory postInfo_3) = OCC_Modular_DAI.loanInfo(3);

        // NOTE: borrower and paymentSchedule marked as "unused" in compiler, but code is commented out below
        (address borrower, int8 paymentSchedule, uint256[10] memory postInfo_4) = OCC_Modular_DAI.loanInfo(4);

        assertEq(OCC_Modular_DAI.loanCounter(), 5);

        // Loan ID #0 (combined into Loan ID #4)
        {
            assertEq(postInfo_0[0], 0); // principalOwed
            assertEq(postInfo_0[3], 0); // paymentDueBy
            assertEq(postInfo_0[4], 0); // paymentsRemaining
            assertEq(postInfo_0[9], 7); // loanState (7 => combined)
        }

        // Loan ID #1 (Combined into Loan ID #4)
        {
            assertEq(postInfo_1[0], 0); // principalOwed
            assertEq(postInfo_1[3], 0); // paymentDueBy
            assertEq(postInfo_1[4], 0); // paymentsRemaining
            assertEq(postInfo_1[9], 7); // loanState (7 => combined)
        }

        // Loan ID #2 (Combined into Loan ID #4)
        {
            assertEq(postInfo_2[0], 0); // principalOwed
            assertEq(postInfo_2[3], 0); // paymentDueBy
            assertEq(postInfo_2[4], 0); // paymentsRemaining
            assertEq(postInfo_2[9], 7); // loanState (7 => combined)
        }

        // Loan ID #3 (Combined into Loan ID #4)
        {
            assertEq(postInfo_3[0], 0); // principalOwed
            assertEq(postInfo_3[3], 0); // paymentDueBy
            assertEq(postInfo_3[4], 0); // paymentsRemaining
            assertEq(postInfo_3[9], 7); // loanState (7 => combined)
        }
        
        // Loan ID #4
        {
            uint upper = preInfo_0[0] * preInfo_0[1] + preInfo_1[0] * preInfo_1[1] + preInfo_2[0] * preInfo_2[1] + preInfo_3[0] *  preInfo_3[1];
            uint lower = preInfo_0[0] + preInfo_1[0] + preInfo_2[0] + preInfo_3[0];
            
            assertEq(postInfo_4[0], lower); // principalOwed
            assertEq(
                postInfo_4[1], 
                upper / lower
            ); // APR
            // assertEq(postInfo_4[2], aprLateFee); // APRLateFee == APR
            assertEq(postInfo_4[3], block.timestamp - block.timestamp % 7 days + 9 days + postInfo_4[6]); // paymentDueBy
        }
        
        {   
            // NOTE: Stack too deep to run below, but works
            // assertEq(postInfo_4[4], termOffer); // paymentsRemaining
            // assertEq(postInfo_4[5], termOffer); // term
            // assertEq(postInfo_4[6], options[option]); // paymentInterval
            // assertEq(postInfo_4[7], block.timestamp - 1 days); // offerExpiry
            // assertEq(postInfo_4[8], gracePeriodOffer); // gracePeriod
            // assertEq(postInfo_4[9], 2); // loanState (2 => active)

            // assertEq(borrower, address(tim));
            // assertEq(paymentSchedule, paymentScheduleOffer);
        }

    }

    // Validate applyConversionToAmortization() state changes.
    // Validate applyConversionToAmortization() restrictions.
    // This includes:
    //  - _msgSender() is borrower of loan
    //  - loan has been approved for conversion


    function test_OCC_Modular_applyConversionToAmortization_restrictions_borrower(uint96 random) public {
        
        simulateITO_and_createOffers(random, true);   // true = Bullet loans

        tim_acceptOffer(0, DAI);

        // approveConversionToAmortization().
        hevm.startPrank(address(roy));
        OCC_Modular_DAI.approveConversionToAmortization(0);
        hevm.stopPrank();

        // applyConversionToAmortization()
        hevm.startPrank(address(sam));
        hevm.expectRevert("OCC_Modular::applyConversionToAmortization() _msgSender() != loans[id].borrower");
        OCC_Modular_DAI.applyConversionToAmortization(0);
        hevm.stopPrank();

    }

    function test_OCC_Modular_applyConversionToAmortization_restrictions_approved(uint96 random) public {
        
        simulateITO_and_createOffers(random, true);   // true = Bullet loans

        tim_acceptOffer(0, DAI);

        // approveConversionToAmortization().
        // hevm.startPrank(address(roy));
        // OCC_Modular_DAI.approveConversionToAmortization(0);
        // hevm.stopPrank();

        // applyConversionToAmortization()
        hevm.startPrank(address(tim));
        hevm.expectRevert("OCC_Modular::applyConversionToAmortization() !conversionToAmortization[id]");
        OCC_Modular_DAI.applyConversionToAmortization(0);
        hevm.stopPrank();
        
    }

    function test_OCC_Modular_applyConversionToAmortization_state(uint96 random) public {
        
        simulateITO_and_createOffers(random, true);   // true = Bullet loans

        tim_acceptOffer(0, DAI);

        (, int8 paymentStructure, ) = OCC_Modular_DAI.loanInfo(0);

        // Pre-state.
        assertEq(paymentStructure, int8(0));

        // approveConversionToAmortization().
        hevm.startPrank(address(roy));
        OCC_Modular_DAI.approveConversionToAmortization(0);
        hevm.stopPrank();

        // applyConversionToAmortization().
        hevm.startPrank(address(tim));
        hevm.expectEmit(true, false, false, false, address(OCC_Modular_DAI));
        emit ConversionToAmortizationApplied(0);
        OCC_Modular_DAI.applyConversionToAmortization(0);
        hevm.stopPrank();
        
        // Post-state.
        (, paymentStructure, ) = OCC_Modular_DAI.loanInfo(0);

        assertEq(paymentStructure, int8(1));
    }

    // Validate applyConversioToBullet() state changes.
    // Validate applyConversionToBullet() restrictions.
    // This includes:
    //  - _msgSender() is borrower of loan
    //  - loan has been approved for conversion

    function test_OCC_Modular_applyConversionToBullet_restrictions_borrower(uint96 random) public {

        simulateITO_and_createOffers(random, false);   // false = Amortization loans

        tim_acceptOffer(0, DAI);

        // approveConversionToBullet().
        hevm.startPrank(address(roy));
        OCC_Modular_DAI.approveConversionToBullet(0);
        hevm.stopPrank();

        // applyConversionToBullet()
        hevm.startPrank(address(sam));
        hevm.expectRevert("OCC_Modular::applyConversionToBullet() _msgSender() != loans[id].borrower");
        OCC_Modular_DAI.applyConversionToBullet(0);
        hevm.stopPrank();

    }

    function test_OCC_Modular_applyConversionToBullet_restrictions_approved(uint96 random) public {
        
        simulateITO_and_createOffers(random, false);   // false = Amortization loans

        tim_acceptOffer(0, DAI);

        // approveConversionToBullet().
        // hevm.startPrank(address(roy));
        // OCC_Modular_DAI.approveConversionToBullet(0);
        // hevm.stopPrank();

        // applyConversionToBullet()
        hevm.startPrank(address(tim));
        hevm.expectRevert("OCC_Modular::applyConversionToBullet() !conversionToBullet[id]");
        OCC_Modular_DAI.applyConversionToBullet(0);
        hevm.stopPrank();

    }

    function test_OCC_Modular_applyConversionToBullet_state(uint96 random) public {
        
        simulateITO_and_createOffers(random, false);   // false = Amortization loans

        tim_acceptOffer(0, DAI);

        // approveConversionToBullet().
        hevm.startPrank(address(roy));
        OCC_Modular_DAI.approveConversionToBullet(0);
        hevm.stopPrank();

        (, int8 paymentStructure, ) = OCC_Modular_DAI.loanInfo(0);

        // Pre-state.
        assertEq(paymentStructure, int8(1));

        // applyConversionToBullet().
        hevm.startPrank(address(tim));
        hevm.expectEmit(true, false, false, false, address(OCC_Modular_DAI));
        emit ConversionToBulletApplied(0);
        OCC_Modular_DAI.applyConversionToBullet(0);
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

        tim_acceptOffer(0, DAI);

        // approveExtension().
        hevm.startPrank(address(roy));
        OCC_Modular_DAI.approveExtension(0, intervals);
        hevm.stopPrank();

        // applyExtension()
        hevm.startPrank(address(sam));
        hevm.expectRevert("OCC_Modular::applyExtension() _msgSender() != loans[id].borrower");
        OCC_Modular_DAI.applyExtension(0);
        hevm.stopPrank();

    }

    function test_OCC_Modular_applyExtension_restrictions_approved(uint96 random, bool choice) public {

        simulateITO_and_createOffers(random, choice);

        tim_acceptOffer(0, DAI);

        // approveExtension().
        // hevm.startPrank(address(roy));
        // OCC_Modular_DAI.approveExtension(id, intervals);
        // hevm.stopPrank();

        // applyExtension()
        hevm.startPrank(address(tim));
        hevm.expectRevert("OCC_Modular::applyExtension() extensions[id] == 0");
        OCC_Modular_DAI.applyExtension(0);
        hevm.stopPrank();

    }

    function test_OCC_Modular_applyExtension_state(uint96 random, bool choice, uint24 intervalRandom) public {
        
        hevm.assume(intervalRandom > 0);

        uint256 intervals = uint256(intervalRandom);

        simulateITO_and_createOffers(random, choice);

        tim_acceptOffer(0, DAI);

        // approveExtension().
        hevm.startPrank(address(roy));
        OCC_Modular_DAI.approveExtension(0, intervals);
        hevm.stopPrank();

        (,, uint256[10] memory preInfo_0) = OCC_Modular_DAI.loanInfo(0);

        // applyExtension()
        hevm.startPrank(address(tim));
        hevm.expectEmit(true, false, false, true, address(OCC_Modular_DAI));
        emit ExtensionApplied(0, intervals);
        OCC_Modular_DAI.applyExtension(0);
        hevm.stopPrank();

        // Post-state.
        (,, uint256[10] memory postInfo_0) = OCC_Modular_DAI.loanInfo(0);

        assertEq(postInfo_0[4], preInfo_0[4] + intervals);    // paymentsRemaining
        assertEq(postInfo_0[5], preInfo_0[5] + intervals);    // term
        assertEq(OCC_Modular_DAI.extensions(0), 0);

    }

    // Validate applyRefinance() state changes.
    // Validate applyRefinance() restrictions.
    // This includes:
    //  - _msgSender() is borrower of loan
    //  - loan is approved for refinancing
    //  - state of loan is LoanState.Active

    function test_OCC_Modular_applyRefinance_restrictions_borrower(uint96 random, bool choice, uint APR) public {
        
        simulateITO_and_createOffers(random, choice);

        // Approve refinance.
        hevm.startPrank(address(roy));
        OCC_Modular_DAI.approveRefinance(0, APR);
        hevm.stopPrank();

        // Can't apply refinance if not borrower.
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCC_Modular::applyRefinance() _msgSender() != loans[id].borrower");
        OCC_Modular_DAI.applyRefinance(0);
        hevm.stopPrank();
    }

    function test_OCC_Modular_applyRefinance_restrictions_approved(uint96 random, bool choice) public {
        
        simulateITO_and_createOffers(random, choice);
        
        tim_acceptOffer(0, DAI);

        // Approve refinance.
        // hevm.startPrank(address(roy));
        // OCC_Modular_DAI.approveRefinance(0, APR);
        // hevm.stopPrank();

        // Can't apply refinance if not approved.
        hevm.startPrank(address(tim));
        hevm.expectRevert("OCC_Modular::applyRefinance() refinancing[id] == 0");
        OCC_Modular_DAI.applyRefinance(0);
        hevm.stopPrank();

    }

    function test_OCC_Modular_applyRefinance_restrictions_loanState(uint96 random, bool choice, uint APR) public {

        hevm.assume(APR > 0);

        simulateITO_and_createOffers(random, choice);
        
        // tim_acceptOffer(0, DAI);

        // Approve refinance.
        hevm.startPrank(address(roy));
        OCC_Modular_DAI.approveRefinance(0, APR);
        hevm.stopPrank();

        // Can't apply refinance if LoanState not Active
        hevm.startPrank(address(tim));
        hevm.expectRevert("OCC_Modular::applyRefinance() loans[id].state != LoanState.Active");
        OCC_Modular_DAI.applyRefinance(0);
        hevm.stopPrank();

    }

    function test_OCC_Modular_applyRefinance_state(uint96 random, bool choice, uint APR) public {

        hevm.assume(APR > 0);

        simulateITO_and_createOffers(random, choice);
        
        tim_acceptOffer(0, DAI);

        // Approve refinance.
        hevm.startPrank(address(roy));
        OCC_Modular_DAI.approveRefinance(0, APR);
        hevm.stopPrank();

        assertEq(OCC_Modular_DAI.refinancing(0), APR);
        
        (,, uint256[10] memory info) = OCC_Modular_DAI.loanInfo(0);

        // applyRefinance().
        hevm.expectEmit(true, false, false, true, address(OCC_Modular_DAI));
        emit RefinanceApplied(0, APR, info[1]);
        hevm.startPrank(address(tim));
        OCC_Modular_DAI.applyRefinance(0);

        (,, info) = OCC_Modular_DAI.loanInfo(0);

        // Post-state.
        assertEq(info[1], APR);
        assertEq(OCC_Modular_DAI.refinancing(0), 0);

    }

    // Validate approveCombine() state changes.
    // Validate approveCombine() restrictions.
    // This includes:
    //  - _msgSender() is underwriter
    //  - paymentInterval is one of 7 | 14 | 28 | 91 | 364 options ( * seconds in days)
    //  - length must be greater than 1
    //  - term must be greater than 0
    //  - gracePeriod must be 7 days or more
    //  - paymentSchedule must be less than or equal to 1

    function test_OCC_Modular_approveCombine_restrictions_underwriter() public {
        
        uint256[] memory loanIDs;

        // Can't call if not underwriter
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCC_Modular::isUnderwriter() _msgSender() != underwriter");
        OCC_Modular_DAI.approveCombine(loanIDs, 0, 24, 86400 * 7, 86400 * 7, int8(0));
        hevm.stopPrank();
    }

    function test_OCC_Modular_approveCombine_restrictions_paymentInterval() public {
        
        uint256[] memory loanIDs;

        // Can't call if paymentInterval isn't proper
        hevm.startPrank(address(roy));
        hevm.expectRevert("OCC_Modular::approveCombine() invalid paymentInterval value, try: 86400 * (7 || 14 || 28 || 91 || 364)");
        OCC_Modular_DAI.approveCombine(loanIDs, 0, 24, 86400 * 8, 86400 * 7, int8(0));
        hevm.stopPrank();
    }

    function test_OCC_Modular_approveCombine_restrictions_idsLength() public {
        
        uint256[] memory loanIDs = new uint256[](1);

        // Can't call if idsLength == 1 or == 0
        hevm.startPrank(address(roy));
        hevm.expectRevert("OCC_Modular::approveCombine() loanIDs.length <= 1 || paymentSchedule > 1 || gracePeriod < 7 days");
        OCC_Modular_DAI.approveCombine(loanIDs, 0, 24, 86400 * 7, 86400 * 7, int8(0));
        hevm.stopPrank();
    }

    function test_OCC_Modular_approveCombine_restrictions_term() public {
        
        uint256[] memory loanIDs = new uint256[](2);

        // Can't call if term == 0
        hevm.startPrank(address(roy));
        hevm.expectRevert("OCC_Modular::approveCombine() term == 0");
        OCC_Modular_DAI.approveCombine(loanIDs, 0, 0, 86400 * 7, 86400 * 7, int8(0));
        hevm.stopPrank();
    }

    function test_OCC_Modular_approveCombine_restrictions_gracePeriod() public {
        
        uint256[] memory loanIDs = new uint256[](2);

        // Can't call if gracePeriod < 7 days
        hevm.startPrank(address(roy));
        hevm.expectRevert("OCC_Modular::approveCombine() loanIDs.length <= 1 || paymentSchedule > 1 || gracePeriod < 7 days");
        OCC_Modular_DAI.approveCombine(loanIDs, 0, 6, 86400 * 7, 86400 * 6, int8(2));
        hevm.stopPrank();
    }

    function test_OCC_Modular_approveCombine_restrictions_paymentSchedule() public {
        
        uint256[] memory loanIDs = new uint256[](2);

        // Can't call if paymentSchedule > 1
        hevm.startPrank(address(roy));
        hevm.expectRevert("OCC_Modular::approveCombine() loanIDs.length <= 1 || paymentSchedule > 1 || gracePeriod < 7 days");
        OCC_Modular_DAI.approveCombine(loanIDs, 0, 6, 86400 * 7, 86400 * 7, int8(2));
        hevm.stopPrank();
    }

    function test_OCC_Modular_approveCombine_state(
        uint8 select, uint termOffer, uint gracePeriodOffer, bool choice, uint24 aprLateFee
    ) public {
        
        hevm.assume(gracePeriodOffer >= 7 days);
        hevm.assume(termOffer > 0 && termOffer < 100);

        uint256[] memory loanIDs = new uint256[](2);

        loanIDs[0] = 0;
        loanIDs[1] = 1;

        uint256 option = uint256(select) % 5;
        
        int8 paymentScheduleOffer = choice ? int8(0) : int8(1);

        {
            // approveCombine().
            hevm.startPrank(address(roy));
            hevm.expectEmit(false, false, false, true, address(OCC_Modular_DAI));
            emit CombineApproved(
                OCC_Modular_DAI.combineCounter(), 
                loanIDs, 
                aprLateFee,
                termOffer,
                options[option],
                gracePeriodOffer,
                block.timestamp + 72 hours, 
                paymentScheduleOffer
            );
            OCC_Modular_DAI.approveCombine(loanIDs, aprLateFee, termOffer, options[option], gracePeriodOffer, paymentScheduleOffer);
            hevm.stopPrank();
        }

        {
            // Post-state.
            assertEq(OCC_Modular_DAI.combineCounter(), 1);

            (
                uint APRLateFee,
                uint term,
                uint paymentInterval,
                uint gracePeriod,
                uint expires,
                int8 paymentSchedule,
                bool valid
            ) = OCC_Modular_DAI.combinations(0);

            assertEq(APRLateFee, uint256(aprLateFee));
            assertEq(paymentInterval, options[option]);
            assertEq(term, termOffer);
            assertEq(gracePeriod, gracePeriodOffer);
            assertEq(expires, block.timestamp + 72 hours);
            assertEq(paymentSchedule, paymentScheduleOffer);
            assert(valid);
        }
        
    }

    // Validate approveConversionToAmortization() state changes.
    // Validate approveConversionToAmortization() restrictions.
    // This includes:
    //  - _msgSender() is underwriter

    function test_OCC_Modular_approveConversionToAmortization_restrictions_underwriter() public {
        
        // Can't call if not underwriter
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCC_Modular::isUnderwriter() _msgSender() != underwriter");
        OCC_Modular_DAI.approveConversionToAmortization(0);
        hevm.stopPrank();
    }

    function test_OCC_Modular_approveConversionToAmortization_state(uint id) public {

        // Pre-state.
        assert(!OCC_Modular_DAI.conversionToAmortization(id));

        // Approve conversion.
        hevm.startPrank(address(roy));
        hevm.expectEmit(true, false, false, false, address(OCC_Modular_DAI));
        emit ConversionToAmortizationApproved(id);
        OCC_Modular_DAI.approveConversionToAmortization(id);
        hevm.stopPrank();

        // Post-state.
        assert(OCC_Modular_DAI.conversionToAmortization(id));

    }

    // Validate approveConversionToBullet() state changes.
    // Validate approveConversionToBullet() restrictions.
    // This includes:
    //  - _msgSender() is underwriter

    function test_OCC_Modular_approveConversionToBullet_restrictions_underwriter() public {
        
        // Can't call if not underwriter
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCC_Modular::isUnderwriter() _msgSender() != underwriter");
        OCC_Modular_DAI.approveConversionToBullet(0);
        hevm.stopPrank();
    }

    function test_OCC_Modular_approveConversionToBullet_state(uint id) public {

        // Pre-state.
        assert(!OCC_Modular_DAI.conversionToBullet(id));

        // Approve conversion.
        hevm.startPrank(address(roy));
        hevm.expectEmit(true, false, false, false, address(OCC_Modular_DAI));
        emit ConversionToBulletApproved(id);
        OCC_Modular_DAI.approveConversionToBullet(id);
        hevm.stopPrank();

        // Post-state.
        assert(OCC_Modular_DAI.conversionToBullet(id));
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

    function test_OCC_Modular_approveRefinance_state(uint id, uint APR) public {
        
        // Pre-state.
        assertEq(OCC_Modular_DAI.refinancing(id), 0);

        // approveRefinance().
        hevm.startPrank(address(roy));
        hevm.expectEmit(true, false, false, true, address(OCC_Modular_DAI));
        emit RefinanceApproved(id, APR);
        OCC_Modular_DAI.approveRefinance(id, APR);
        hevm.stopPrank();

        // Post-state.
        assertEq(OCC_Modular_DAI.refinancing(id), APR);
    }

    // Validate unapproveCombine() state changes.
    // Validate unapproveCombine() restrictions.
    // This includes:
    //  - _msgSender() is underwriter

    function test_OCC_Modular_unapproveCombine_restrictions_underwriter() public {
        
        // Can't call if not underwriter
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCC_Modular::isUnderwriter() _msgSender() != underwriter");
        OCC_Modular_DAI.unapproveCombine(0);
        hevm.stopPrank();
    }

    function test_OCC_Modular_unapproveCombine_state(
        uint8 select, uint termOffer, uint gracePeriodOffer, bool choice, uint24 aprLateFee
    ) public {
        
        hevm.assume(gracePeriodOffer >= 7 days);
        hevm.assume(termOffer > 0 && termOffer < 100);

        uint256[] memory loanIDs = new uint256[](2);

        loanIDs[0] = 0;
        loanIDs[1] = 1;

        uint256 option = uint256(select) % 5;
        
        int8 paymentScheduleOffer = choice ? int8(0) : int8(1);

        // approveCombine().
        hevm.startPrank(address(roy));
        OCC_Modular_DAI.approveCombine(loanIDs, aprLateFee, termOffer, options[option], gracePeriodOffer, paymentScheduleOffer);
        hevm.stopPrank();

        // Pre-state.
        (
            ,
            uint256 term,
            uint256 paymentInterval,
            uint256 gracePeriod,
            uint256 expires,
            int8 paymentSchedule,
            bool valid
        ) = OCC_Modular_DAI.combinations(0);

        assertEq(paymentInterval, options[option]);
        assertEq(term, termOffer);
        assertEq(expires, block.timestamp + 72 hours);
        assertEq(paymentSchedule, paymentScheduleOffer);
        assert(valid);

        // unapproveCombine().
        hevm.startPrank(address(roy));
        hevm.expectEmit(true, false, false, true, address(OCC_Modular_DAI));
        emit CombineUnapproved(0);
        OCC_Modular_DAI.unapproveCombine(0);
        hevm.stopPrank();

        // Post-state.
        (
            ,
            term,
            paymentInterval,
            gracePeriod,
            expires,
            paymentSchedule,
            valid
        ) = OCC_Modular_DAI.combinations(0);

        assert(!valid);

    }

    // Validate unapproveConversionToAmortization() state changes.
    // Validate unapproveConversionToAmortization() restrictions.
    // This includes:
    //  - _msgSender() is underwriter

    function test_OCC_Modular_unapproveConversionToAmortization_restrictions_underwriter() public {
        
        // Can't call if not underwriter
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCC_Modular::isUnderwriter() _msgSender() != underwriter");
        OCC_Modular_DAI.unapproveConversionToAmortization(0);
        hevm.stopPrank();
    }

    function test_OCC_Modular_unapproveConversionToAmortization_state(uint id) public {
        
        // Pre-state.
        assert(!OCC_Modular_DAI.conversionToAmortization(id));

        // Approve conversion.
        hevm.startPrank(address(roy));
        hevm.expectEmit(true, false, false, false, address(OCC_Modular_DAI));
        emit ConversionToAmortizationApproved(id);
        OCC_Modular_DAI.approveConversionToAmortization(id);
        hevm.stopPrank();

        // Post-state.
        assert(OCC_Modular_DAI.conversionToAmortization(id));

        // Unapprove conversion.
        hevm.startPrank(address(roy));
        hevm.expectEmit(true, false, false, false, address(OCC_Modular_DAI));
        emit ConversionToAmortizationUnapproved(id);
        OCC_Modular_DAI.unapproveConversionToAmortization(id);
        hevm.stopPrank();

        // Post-state.
        assert(!OCC_Modular_DAI.conversionToAmortization(id));
    }

    // Validate unapproveConversionToBullet() state changes.
    // Validate unapproveConversionToBullet() restrictions.
    // This includes:
    //  - _msgSender() is underwriter

    function test_OCC_Modular_unapproveConversionToBullet_restrictions_underwriter() public {
        
        // Can't call if not underwriter
        hevm.startPrank(address(bob));
        hevm.expectRevert("OCC_Modular::isUnderwriter() _msgSender() != underwriter");
        OCC_Modular_DAI.unapproveConversionToBullet(0);
        hevm.stopPrank();
    }

    function test_OCC_Modular_unapproveConversionToBullet_state(uint id) public {
        
        
        // Pre-state.
        assert(!OCC_Modular_DAI.conversionToBullet(id));

        // Approve conversion.
        hevm.startPrank(address(roy));
        hevm.expectEmit(true, false, false, false, address(OCC_Modular_DAI));
        emit ConversionToBulletApproved(id);
        OCC_Modular_DAI.approveConversionToBullet(id);
        hevm.stopPrank();

        // Post-state.
        assert(OCC_Modular_DAI.conversionToBullet(id));

        // Unapprove conversion.
        hevm.startPrank(address(roy));
        hevm.expectEmit(true, false, false, false, address(OCC_Modular_DAI));
        emit ConversionToBulletUnapproved(id);
        OCC_Modular_DAI.unapproveConversionToBullet(id);
        hevm.stopPrank();

        // Post-state.
        assert(!OCC_Modular_DAI.conversionToBullet(id));
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

    function test_OCC_Modular_unapproveRefinance_state(uint id, uint APR) public {
        
        // Pre-state.
        assertEq(OCC_Modular_DAI.refinancing(id), 0);

        // approveRefinance().
        hevm.startPrank(address(roy));
        hevm.expectEmit(true, false, false, true, address(OCC_Modular_DAI));
        emit RefinanceApproved(id, APR);
        OCC_Modular_DAI.approveRefinance(id, APR);
        hevm.stopPrank();

        // Post-state.
        assertEq(OCC_Modular_DAI.refinancing(id), APR);

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
