// // SPDX-License-Identifier: GPL-3.0-only
// pragma solidity ^0.8.17;

// import "../Utility/Utility.sol";

// import "../../lib/zivoe-core-foundry/src/lockers/OCR/OCR_Modular.sol";
// import "../../lib/zivoe-core-foundry/src/lockers/OCG/OCG_Defaults.sol";

// contract Test_OCR_Modular is Utility {

//     using SafeERC20 for IERC20;

//     OCR_Modular OCR_Modular_DAI;
//     OCG_Defaults OCG_Defaults_Test;

//     function setUp() public {

//         deployCore(false);
//         simulateITO_byTranche_stakeTokens(25_000_000 ether, 4_000_000 ether);

//         // Initialize and whitelist OCR_Modular lockers.
//         OCR_Modular_DAI = new OCR_Modular(address(DAO), address(DAI), address(GBL), 1000);
//         zvl.try_updateIsLocker(address(GBL), address(OCR_Modular_DAI), true);

//         // Initialize an OCG_Defaults locker to account for defaults in the system
//         OCG_Defaults_Test = new OCG_Defaults(address(DAO), address(GBL));
//         zvl.try_updateIsLocker(address(GBL), address(OCG_Defaults_Test), true);
//     }



//     // ----------------------
//     //    Helper Functions
//     // ----------------------

//     // helper function to initiate a redemption request
//     function requestJuniorRedemption(uint256 amount) public returns (uint256 accountInitBalance) {

//         // Withdraw staked tranche tokens
//         hevm.startPrank(address(jim));
//         stJTT.fullWithdraw();
//         IERC20(zJTT).safeApprove(address(OCR_Modular_DAI), amount);
//         // initial values
//         accountInitBalance = IERC20(zJTT).balanceOf(address(jim));
//         // call function
//         OCR_Modular_DAI.requestJuniorRedemption(amount);
//         hevm.stopPrank();

//         return accountInitBalance;
//     }

//     // helper function to initiate a redemption request
//     function requestSeniorRedemption(uint256 amount) public returns (uint256 accountInitBalance) {

//         // Withdraw staked tranche tokens
//         hevm.startPrank(address(sam));
//         stSTT.fullWithdraw();
//         IERC20(zSTT).safeApprove(address(OCR_Modular_DAI), amount);
//         // initial values
//         accountInitBalance = IERC20(zSTT).balanceOf(address(sam));
//         // call function
//         OCR_Modular_DAI.requestSeniorRedemption(amount);
//         hevm.stopPrank();

//         return accountInitBalance;
//     }



//     // ------------
//     //    Events
//     // ------------

//     event UpdatedRedemptionFee(uint256 oldValue, uint256 newValue);

//     event RequestedJuniorRedemption(address indexed account, uint256 amount);

//     event requestSeniorRedemption(address indexed account, uint256 amount);

//     event RedeemedJunior(address indexed account, uint256 redeemablePreFee, uint256 fee, uint256 defaults);

//     event RedeemedSenior(address indexed account, uint256 redeemablePreFee, uint256 fee, uint256 defaults);

//     event CancelledJunior(address indexed account, uint256 amount);

//     event CancelledSenior(address indexed account, uint256 amount);



//     // ----------------
//     //    Unit Tests
//     // ----------------

//     // Validate initial state of OCR_Modular.

//     function test_OCR_init() public {
        
//         // Ownership.
//         assertEq(OCR_Modular_DAI.owner(), address(DAO));

//         // State variables.
//         assertEq(OCR_Modular_DAI.stablecoin(), address(DAI));
//         assertEq(OCR_Modular_DAI.GBL(), address(GBL));
//         assertEq(OCR_Modular_DAI.currentEpoch(), block.timestamp);
//         assertEq(OCR_Modular_DAI.nextEpoch(), block.timestamp + 30 days);
//         assertEq(OCR_Modular_DAI.redemptionFee(), 1000);
//         assertEq(OCR_Modular_DAI.redemptionsRequested(), 0);
//         assertEq(OCR_Modular_DAI.redemptionsAllowed(), 0);
//         assertEq(OCR_Modular_DAI.amountRedeemable(), 0);
//         assertEq(OCR_Modular_DAI.redemptionsUnclaimed(), 0);
//         assertEq(OCR_Modular_DAI.amountRedeemableQueued(), 0);

//         // Permissions
//         assert(OCR_Modular_DAI.canPush());
//         assert(OCR_Modular_DAI.canPull());
//         assert(OCR_Modular_DAI.canPullPartial());
//     }

//     // Validate pushToLocker() state changes.
//     // Validate pushToLocker() restrictions.
//     // This includes:
//     //   - _msgSender() must be owner
//     //   - asset must be stablecoin (specified in state variable)
    
//     function test_OCR_pushToLocker_restrictions_owner() public {

//         // Can't push to locker if _msgSender != owner
//         hevm.startPrank(address(bob));
//         hevm.expectRevert("Ownable: caller is not the owner");
//         OCR_Modular_DAI.pushToLocker(FRAX, 1_000 ether, "");
//         hevm.stopPrank();
//     }
    
//     function test_OCR_pushToLocker_restrictions_stablecoin() public {

//         // Can't push to locker if asset != stablecoin
//         hevm.startPrank(address(DAO));
//         hevm.expectRevert("OCR_Modular::pushToLocker() asset != stablecoin");
//         OCR_Modular_DAI.pushToLocker(FRAX, 1_000 ether, "");
//         hevm.stopPrank();
//     }

//     function test_OCR_pushToLocker_state(uint96 random) public {

//         uint256 amount = uint256(random);

//         deal(DAI, address(DAO), amount);

//         // Pre-state.
//         assertEq(OCR_Modular_DAI.amountRedeemableQueued(), 0);

//         // pushToLocker().
//         assert(god.try_push(address(DAO), address(OCR_Modular_DAI), DAI, amount, ""));

//         // Post-state.
//         assertEq(OCR_Modular_DAI.amountRedeemableQueued(), amount);

//     }

//     // Validate pullFromLocker() state changes.
//     // Validate pullFromLocker() restrictions.
//     // This includes:
//     //   - _msgSender() must be owner
//     //   - asset can't be zJTT or zSTT
    
//     function test_OCR_pullFromLocker_restrictions_owner() public {

//         // Can't pull from locker if _msgSender != owner
//         hevm.startPrank(address(bob));
//         hevm.expectRevert("Ownable: caller is not the owner");
//         OCR_Modular_DAI.pullFromLocker(DAI, "");
//         hevm.stopPrank();
//     }
    
//     function test_OCR_pullFromLocker_restrictions_zJTT() public {

//         // Can't pull from locker if asset == zJTT
//         hevm.startPrank(address(DAO));
//         hevm.expectRevert("OCR_Modular::pullFromLocker() asset == zJTT || asset == zSTT");
//         OCR_Modular_DAI.pullFromLocker(address(zJTT), "");
//         hevm.stopPrank();
//     }
    
//     function test_OCR_pullFromLocker_restrictions_zSTT() public {

//         // Can't pull from locker if asset == zSTT
//         hevm.startPrank(address(DAO));
//         hevm.expectRevert("OCR_Modular::pullFromLocker() asset == zJTT || asset == zSTT");
//         OCR_Modular_DAI.pullFromLocker(address(zSTT), "");
//         hevm.stopPrank();
//     }

//     function test_OCR_pullFromLocker_state(uint96 randomPush) public {

//         uint256 amountToPush = uint256(randomPush) + 1_000 ether;

//         // Push some stablecoins to increase amountRedeemableQueued
//         deal(DAI, address(DAO), amountToPush);
//         assert(god.try_push(address(DAO), address(OCR_Modular_DAI), DAI, amountToPush, ""));

//         // Warp to next epoch distribution, call updateEpoch() to increase amountRedeemable (sets amountRedeemableQueued to 0)
//         hevm.warp(block.timestamp + 31 days);
//         OCR_Modular_DAI.updateEpoch();

//         // Push more stablecoins to increase amountRedeemableQueued again
//         deal(DAI, address(DAO), amountToPush);
//         assert(god.try_push(address(DAO), address(OCR_Modular_DAI), DAI, amountToPush, ""));

//         // Pre-state.
//         assertEq(OCR_Modular_DAI.amountRedeemable(), amountToPush);
//         assertEq(OCR_Modular_DAI.amountRedeemableQueued(), amountToPush);

//         // pullFromLocker()
//         assert(god.try_pull(address(DAO), address(OCR_Modular_DAI), DAI, ""));

//         // Post-state.
//         assert(OCR_Modular_DAI.amountRedeemable() == 0);
//         assert(OCR_Modular_DAI.amountRedeemableQueued() == 0);
//         assert(IERC20(DAI).balanceOf(address(OCR_Modular_DAI)) == 0);
//     }

//     // Validate pullFromLockerPartial() state changes.
//     // Validate pullFromLockerPartial() restrictions.
//     // This includes:
//     //   - _msgSender() must be owner
//     //   - asset can't be zJTT or zSTT
    
//     function test_OCR_pullFromLockerPartial_restrictions_owner() public {

//         // Can't pull from locker if _msgSender != owner
//         hevm.startPrank(address(bob));
//         hevm.expectRevert("Ownable: caller is not the owner");
//         OCR_Modular_DAI.pullFromLockerPartial(DAI, 10, "");
//         hevm.stopPrank();
//     }
    
//     function test_OCR_pullFromLockerPartial_restrictions_zJTT() public {

//         // Can't pull from locker if asset == zJTT
//         hevm.startPrank(address(DAO));
//         hevm.expectRevert("OCR_Modular::pullFromLockerPartial() asset == zJTT || asset == zSTT");
//         OCR_Modular_DAI.pullFromLockerPartial(address(zJTT), 10, "");
//         hevm.stopPrank();
//     }
    
//     function test_OCR_pullFromLockerPartial_restrictions_zSTT() public {

//         // Can't pull from locker if asset == zSTT
//         hevm.startPrank(address(DAO));
//         hevm.expectRevert("OCR_Modular::pullFromLockerPartial() asset == zJTT || asset == zSTT");
//         OCR_Modular_DAI.pullFromLockerPartial(address(zSTT), 10, "");
//         hevm.stopPrank();
//     }

//     function test_OCR_pullFromLockerPartial_state(uint96 randomPush, uint96 randomPull) public {

//         uint256 amountToPushOnce = uint256(randomPush) + 1_000 ether;

//         // Push some stablecoins to increase amountRedeemableQueued
//         deal(DAI, address(DAO), amountToPushOnce);
//         assert(god.try_push(address(DAO), address(OCR_Modular_DAI), DAI, amountToPushOnce, ""));

//         // Warp to next epoch distribution, call updateEpoch() to increase amountRedeemable (sets amountRedeemableQueued to 0)
//         hevm.warp(block.timestamp + 31 days);
//         OCR_Modular_DAI.updateEpoch();

//         // Push more stablecoins to increase amountRedeemableQueued again
//         deal(DAI, address(DAO), amountToPushOnce);
//         assert(god.try_push(address(DAO), address(OCR_Modular_DAI), DAI, amountToPushOnce, ""));

//         // Pre-state.
//         assertEq(OCR_Modular_DAI.amountRedeemable(), amountToPushOnce);
//         assertEq(OCR_Modular_DAI.amountRedeemableQueued(), amountToPushOnce);

//         // pullFromLockerPartial()
//         uint256 amountToPull = randomPull % IERC20(DAI).balanceOf(address(OCR_Modular_DAI));
//         assert(god.try_pullPartial(address(DAO), address(OCR_Modular_DAI), DAI, amountToPull, ""));

//         // Post-state.
//         // NOTE: DAI balance is effectively amountToPushOnce * 2 in OCR_Modular_DAI, and amountRedeemable + amountRedeemableQueued == DAI balance
//         assertEq(OCR_Modular_DAI.amountRedeemable() + OCR_Modular_DAI.amountRedeemableQueued(), IERC20(DAI).balanceOf(address(OCR_Modular_DAI)));
        
//         if (amountToPull > amountToPushOnce) {
//             emit Logger("a OCR_Modular_DAI.amountRedeemable()", OCR_Modular_DAI.amountRedeemable());
//             emit Logger("a OCR_Modular_DAI.amountRedeemableQueued()", OCR_Modular_DAI.amountRedeemableQueued());
//             emit Logger("a amountToPull", amountToPull);
//             emit Logger("a amountToPushOnce", amountToPushOnce);
//             assertEq(OCR_Modular_DAI.amountRedeemable(), amountToPushOnce - (amountToPull - amountToPushOnce));
//             assertEq(OCR_Modular_DAI.amountRedeemableQueued(), 0);
//         }
//         else {
//             emit Logger("b OCR_Modular_DAI.amountRedeemable()", OCR_Modular_DAI.amountRedeemable());
//             emit Logger("b OCR_Modular_DAI.amountRedeemableQueued()", OCR_Modular_DAI.amountRedeemableQueued());
//             emit Logger("b amountToPull", amountToPull);
//             emit Logger("b amountToPushOnce", amountToPushOnce);
//             assertEq(OCR_Modular_DAI.amountRedeemable(), amountToPushOnce);
//             assertEq(OCR_Modular_DAI.amountRedeemableQueued(), amountToPushOnce - amountToPull);
//         }
//     }

//     event Logger(string, uint);

//     // Validate requestJuniorRedemption() state changes.

//     function test_OCR_requestJuniorRedemption_state() public {
        
//         uint256 amountToRedeem = 2_000_000 ether;
//         assert(OCR_Modular_DAI.redemptionsRequested() == 0);

//         uint256 accountInitBalance = requestJuniorRedemption(amountToRedeem);

//         // checks
//         assert(IERC20(zJTT).balanceOf(address(jim)) == accountInitBalance - amountToRedeem);
//         assert(OCR_Modular_DAI.redemptionsRequested() == amountToRedeem);
//         assert(OCR_Modular_DAI.juniorBalances(address(jim)) == amountToRedeem);
//         assert(OCR_Modular_DAI.juniorRedemptionsQueued(address(jim)) == amountToRedeem);
//         assert(OCR_Modular_DAI.juniorRedemptionRequestedOn(address(jim)) == block.timestamp);

//         // initiate a new redemption request
//         hevm.startPrank(address(jim));
//         IERC20(zJTT).safeApprove(address(OCR_Modular_DAI), amountToRedeem);
//         hevm.expectEmit(true, false, false, true, address(OCR_Modular_DAI));
//         emit RequestedJuniorRedemption(address(jim), amountToRedeem);
//         OCR_Modular_DAI.requestJuniorRedemption(amountToRedeem);
//         hevm.stopPrank();

//         // additional check when second redemption request in same epoch
//         assert(OCR_Modular_DAI.juniorRedemptionsQueued(address(jim)) == 2 * amountToRedeem);
//     }    

//     // Validate "juniorRedemptionsQueued" for the case:
//     // juniorBalances[_msgSender()] > 0 && juniorRedemptionRequestedOn[_msgSender()] < currentEpoch
//     function test_OCR_juniorRedemptionsQueued_state() public {
        
//         uint256 amountToRedeem = 2_000_000 ether;
//         assert(OCR_Modular_DAI.redemptionsRequested() == 0);

//         // initiate a first redemption request
//         requestJuniorRedemption(amountToRedeem);

//         // +31 days to be able to call updateEpoch()
//         hevm.warp(block.timestamp + 31 days);

//         // intermediate check
//         assert(OCR_Modular_DAI.juniorRedemptionsQueued(address(jim)) == amountToRedeem);

//         // start next epoch
//         OCR_Modular_DAI.updateEpoch();

//         // initiate a new redemption request
//         hevm.startPrank(address(jim));
//         IERC20(zJTT).safeApprove(address(OCR_Modular_DAI), 1000 ether);
//         OCR_Modular_DAI.requestJuniorRedemption(1000 ether);
//         hevm.stopPrank();

//         // additional check when second redemption request in same epoch
//         assert(OCR_Modular_DAI.juniorRedemptionsQueued(address(jim)) == 1000 ether);
//     } 

//     // Validate requestJuniorRedemption() restrictions
//     function test_OCR_requestJuniorRedemption_restrictions() public {

//         uint256 amountToRedeem = 20_000_000 ether;
//         assert(OCR_Modular_DAI.redemptionsRequested() == 0);

//         // Withdraw staked tranche tokens
//         hevm.startPrank(address(jim));
//         stJTT.fullWithdraw();
//         IERC20(zJTT).safeApprove(address(OCR_Modular_DAI), amountToRedeem);
//         // initial values
//         uint256 accountInitBalance = IERC20(zJTT).balanceOf(address(jim));
//         assert(accountInitBalance < amountToRedeem);
//         // checks
//         hevm.expectRevert("ERC20: transfer amount exceeds balance");
//         // call function
//         OCR_Modular_DAI.requestJuniorRedemption(amountToRedeem);

//         hevm.stopPrank();
//     }   

//     // Validate requestSeniorRedemption() state changes
//     function test_OCR_requestSeniorRedemption_state() public {

//         uint256 amountToRedeem = 10_000_000 ether;
//         assert(OCR_Modular_DAI.redemptionsRequested() == 0);

//         uint256 accountInitBalance = requestSeniorRedemption(amountToRedeem);

//         // checks
//         assert(IERC20(zSTT).balanceOf(address(sam)) == accountInitBalance - amountToRedeem);
//         assert(OCR_Modular_DAI.redemptionsRequested() == amountToRedeem);
//         assert(OCR_Modular_DAI.seniorBalances(address(sam)) == amountToRedeem);
//         assert(OCR_Modular_DAI.seniorRedemptionRequestedOn(address(sam)) == block.timestamp);
//         assert(OCR_Modular_DAI.seniorRedemptionsQueued(address(sam)) == amountToRedeem);

//         // initiate a new redemption request
//         hevm.startPrank(address(sam));
//         IERC20(zSTT).safeApprove(address(OCR_Modular_DAI), amountToRedeem);
//         hevm.expectEmit(true, false, false, true, address(OCR_Modular_DAI));
//         emit requestSeniorRedemption(address(sam), amountToRedeem);
//         OCR_Modular_DAI.requestSeniorRedemption(amountToRedeem);
//         hevm.stopPrank();

//         // additional check when second redemption request in same epoch
//         assert(OCR_Modular_DAI.seniorRedemptionsQueued(address(sam)) == 2 * amountToRedeem);
//     }  

//     // Validate "seniorRedemptionsQueued" for the case:
//     // seniorBalances[_msgSender()] > 0 && seniorRedemptionRequestedOn[_msgSender()] < currentEpoch
//     function test_OCR_seniorRedemptionsQueued_state() public {
        
//         uint256 amountToRedeem = 2_000_000 ether;
//         assert(OCR_Modular_DAI.redemptionsRequested() == 0);

//         // initiate a first redemption request
//         requestSeniorRedemption(amountToRedeem);

//         // +31 days to be able to call updateEpoch()
//         hevm.warp(block.timestamp + 31 days);

//         // intermediate check
//         assert(OCR_Modular_DAI.seniorRedemptionsQueued(address(sam)) == amountToRedeem);

//         // start next epoch
//         OCR_Modular_DAI.updateEpoch();

//         // initiate a new redemption request
//         hevm.startPrank(address(sam));
//         IERC20(zSTT).safeApprove(address(OCR_Modular_DAI), 1000 ether);
//         OCR_Modular_DAI.requestSeniorRedemption(1000 ether);
//         hevm.stopPrank();

//         // additional check when second redemption request in same epoch
//         assert(OCR_Modular_DAI.seniorRedemptionsQueued(address(sam)) == 1000 ether);
//     } 

//     // Validate requestSeniorRedemption() restrictions
//     function test_OCR_requestSeniorRedemption_restrictions() public {

//         uint256 amountToRedeem = 26_000_000 ether;
//         assert(OCR_Modular_DAI.redemptionsRequested() == 0);

//         // Withdraw staked tranche tokens
//         hevm.startPrank(address(sam));
//         stSTT.fullWithdraw();
//         IERC20(zSTT).safeApprove(address(OCR_Modular_DAI), amountToRedeem);
//         // initial values
//         uint256 accountInitBalance = IERC20(zSTT).balanceOf(address(sam));
//         assert(accountInitBalance < amountToRedeem);
//         // check
//         hevm.expectRevert("ERC20: transfer amount exceeds balance");
//         // call function
//         OCR_Modular_DAI.requestSeniorRedemption(amountToRedeem);
//         hevm.stopPrank();
//     }

//     // Validate updateEpoch state changes
//     function test_OCR_updateEpoch_state() public {
//         uint256 amountToDistribute= 2_000_000 ether;
//         uint256 amountToRedeem = 4_000_000 ether;
//         // push stablecoins to the locker
//         hevm.startPrank(address(DAO));
//         IERC20(DAI).safeApprove(address(OCR_Modular_DAI), amountToDistribute);
//         OCR_Modular_DAI.pushToLocker(DAI, amountToDistribute, "");
//         hevm.stopPrank();

//         // initiate a redemption request
//         requestSeniorRedemption(amountToRedeem);

//         // warp time to next epoch distribution
//         hevm.warp(block.timestamp + 30 days + 1);

//         // pre check
//         assert(IERC20(DAI).balanceOf(address(OCR_Modular_DAI)) == amountToDistribute);
//         assert(OCR_Modular_DAI.redemptionsRequested() == amountToRedeem);
//         assert(OCR_Modular_DAI.amountRedeemableQueued() == amountToDistribute);
//         uint256 currentEpoch = OCR_Modular_DAI.currentEpoch();
//         // distribute new epoch
//         OCR_Modular_DAI.updateEpoch();

//         // checks
//         assertEq(OCR_Modular_DAI.amountRedeemable(), amountToDistribute);
//         assertEq(OCR_Modular_DAI.nextEpoch(), block.timestamp + 30 days);
//         assertEq(OCR_Modular_DAI.currentEpoch(), block.timestamp);
//         assertEq(OCR_Modular_DAI.redemptionsAllowed(), amountToRedeem);
//         assertEq(OCR_Modular_DAI.redemptionsRequested(), 0);
//         assertEq(OCR_Modular_DAI.redemptionsUnclaimed(), amountToRedeem);
//         assertEq(OCR_Modular_DAI.amountRedeemableQueued(), 0);
//     }

//     // Validate updateEpoch() restrictions
//     function test_OCR_updateEpoch_restrictions() public {
//         uint256 amountToDistribute= 2_000_000 ether;
//         uint256 amountToRedeem = 4_000_000 ether;
//         // push stablecoins to the locker
//         hevm.startPrank(address(DAO));
//         IERC20(DAI).safeApprove(address(OCR_Modular_DAI), amountToDistribute);
//         OCR_Modular_DAI.pushToLocker(DAI, amountToDistribute, "");
//         hevm.stopPrank();

//         // initiate a redemption request
//         requestSeniorRedemption(amountToRedeem);

//         // warp time 1 day before next distribution
//         hevm.warp(block.timestamp + 29 days);

//         // check
//         hevm.expectRevert("OCR_Modular::updateEpoch() block.timestamp <= nextEpoch");
//         // distribute new epoch
//         OCR_Modular_DAI.updateEpoch();
//     }

//     // validate a scenario where amount of stablecoins >= total redemption amount
//     function test_OCR_redeemJunior_full_state() public {
//         uint256 amountToRedeem = 2_000_000 ether;

//         // push stablecoins to the locker
//         hevm.startPrank(address(DAO));
//         IERC20(DAI).safeApprove(address(OCR_Modular_DAI), amountToRedeem);
//         OCR_Modular_DAI.pushToLocker(DAI, amountToRedeem, "");
//         hevm.stopPrank(); 

//         // pre check
//         assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(OCR_Modular_DAI)) == amountToRedeem);
//         assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(jim)) == 0);
//         uint256 initSupplyJTT = zJTT.totalSupply();

//         // initiate a redemption request
//         requestJuniorRedemption(amountToRedeem);

//         // warp time to next redemption epoch
//         hevm.warp(block.timestamp + 31 days);

//         // distribute new epoch
//         OCR_Modular_DAI.updateEpoch();

//         // warp time + 1 day
//         hevm.warp(block.timestamp + 1 days);

//         // keep track of following values
//         uint256 initBalanceDAO = IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(DAO));
//         uint256 fee = (amountToRedeem * OCR_Modular_DAI.redemptionFee()) / BIPS;

//         // redeem
//         hevm.startPrank(address(jim));
//         hevm.expectEmit(true, false, false, true, address(OCR_Modular_DAI));
//         emit RedeemedJunior(address(jim), amountToRedeem, fee, 0);
//         OCR_Modular_DAI.redeemJunior();
//         hevm.stopPrank();

//         // checks
//         assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(OCR_Modular_DAI)) == 0);
//         assert(OCR_Modular_DAI.juniorBalances(address(jim)) == 0);
//         assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(jim)) == amountToRedeem - fee);
//         assert(zJTT.totalSupply() == initSupplyJTT - amountToRedeem);
//         assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(DAO)) == initBalanceDAO + fee);
//     }

//     // test for restriction on redeemJunior() when balance = 0
//     function test_OCR_redeemJunior_restrictions_balance() public {
//         // redeem
//         hevm.startPrank(address(jim));
//         hevm.expectRevert("OCR_Modular::redeemJunior() juniorBalances[_msgSender] == 0");
//         OCR_Modular_DAI.redeemJunior();
//         hevm.stopPrank();
//     }

//     // test for restriction on redeemJunior() when claim time is >= "currentEpoch"
//     function test_OCR_redeemJunior_restrictions_timestamp() public {
//         uint256 amountToRedeem = 2_000_000 ether;
//         // push stablecoins to the locker
//         hevm.startPrank(address(DAO));
//         IERC20(DAI).safeApprove(address(OCR_Modular_DAI), amountToRedeem);
//         OCR_Modular_DAI.pushToLocker(DAI, amountToRedeem, "");
//         hevm.stopPrank(); 

//         // initiate a redemption request
//         requestJuniorRedemption(amountToRedeem);

//         // redeem
//         hevm.startPrank(address(jim));
//         hevm.expectRevert("OCR_Modular::redeemJunior() juniorRedemptionRequestedOn[_msgSender()] >= currentEpoch");
//         OCR_Modular_DAI.redeemJunior();
//         hevm.stopPrank();
//     }

//     // test for restriction on redeemJunior() when no amount to withdraw in epoch
//     function test_OCR_redeemJunior_restrictions_noStables() public {
//         uint256 amountToRedeem = 2_000_000 ether;

//         // initiate a redemption request
//         requestJuniorRedemption(amountToRedeem);

//         // warp time to next redemption epoch
//         hevm.warp(block.timestamp + 31 days);

//         // distribute new epoch
//         OCR_Modular_DAI.updateEpoch();

//         // warp time + 1 day
//         hevm.warp(block.timestamp + 1 days);

//         // redeem
//         hevm.startPrank(address(jim));
//         hevm.expectRevert("OCR_Modular::redeemJunior() amountRedeemable == 0");
//         OCR_Modular_DAI.redeemJunior();
//         hevm.stopPrank();
//     }

//     // validate a scenario where amount of stablecoins <= total redemption amount
//     function test_OCR_redeemJunior_partial_state() public {
//         uint256 amountToRedeem = 2_000_000 ether;
//         uint256 amountInLocker = amountToRedeem / 2;
//         // push stablecoins to the locker
//         hevm.startPrank(address(DAO));
//         IERC20(DAI).safeApprove(address(OCR_Modular_DAI), amountInLocker);
//         OCR_Modular_DAI.pushToLocker(DAI, amountInLocker, "");
//         hevm.stopPrank(); 

//         // pre check
//         assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(OCR_Modular_DAI)) == amountInLocker);
//         assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(jim)) == 0);
//         uint256 initSupplyJTT = zJTT.totalSupply();

//         // initiate a redemption request
//         requestJuniorRedemption(amountToRedeem);
//         emit log_named_uint("jim claimed timestamp", OCR_Modular_DAI.juniorRedemptionRequestedOn(address(jim)));

//         // warp time to next redemption epoch
//         hevm.warp(block.timestamp + 31 days);

//         // distribute new epoch
//         OCR_Modular_DAI.updateEpoch();

//         // warp time + 1 day
//         hevm.warp(block.timestamp + 1 days);

//         // redeem
//         hevm.startPrank(address(jim));
//         OCR_Modular_DAI.redeemJunior();
//         hevm.stopPrank();

//         // checks
//         uint256 fee = (amountInLocker * OCR_Modular_DAI.redemptionFee()) / BIPS;
//         assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(OCR_Modular_DAI)) == 0);
//         assert(OCR_Modular_DAI.juniorBalances(address(jim)) == amountToRedeem - amountInLocker);
//         assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(jim)) == amountToRedeem - amountInLocker - fee);
//         assert(zJTT.totalSupply() == initSupplyJTT - amountInLocker);
//     }

//     // validate a scenario where amount of stablecoins <= total redemption amount
//     function test_OCR_redeemSenior_full_state() public {
//         emit log_named_uint("seniorBalance 1", OCR_Modular_DAI.seniorBalances(address(sam)));
//         uint256 amountToRedeem = 6_000_000 ether;
//         // push stablecoins to the locker
//         hevm.startPrank(address(DAO));
//         IERC20(DAI).safeApprove(address(OCR_Modular_DAI), amountToRedeem);
//         OCR_Modular_DAI.pushToLocker(DAI, amountToRedeem, "");
//         hevm.stopPrank(); 

//         // pre check
//         assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(OCR_Modular_DAI)) == amountToRedeem);
//         assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(sam)) == 0);
//         uint256 initSupplySTT = zSTT.totalSupply();

//         // initiate a redemption request
//         requestSeniorRedemption(amountToRedeem);

//         // warp time to next redemption epoch
//         hevm.warp(block.timestamp + 31 days);

//         // distribute new epoch
//         OCR_Modular_DAI.updateEpoch();

//         // warp time + 1 day
//         hevm.warp(block.timestamp + 1 days);

//         // variables to track
//         uint256 initBalanceDAO = IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(DAO));
//         uint256 fee = (amountToRedeem * OCR_Modular_DAI.redemptionFee()) / BIPS;

//         // redeem
//         hevm.startPrank(address(sam));
//         hevm.expectEmit(true, false, false, true, address(OCR_Modular_DAI));
//         emit RedeemedSenior(address(sam), amountToRedeem, fee, 0);
//         OCR_Modular_DAI.redeemSenior();
//         hevm.stopPrank();

//         // checks
//         assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(OCR_Modular_DAI)) == 0);
//         assert(OCR_Modular_DAI.seniorBalances(address(sam)) == 0);
//         assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(sam)) == amountToRedeem - fee);
//         assert(zSTT.totalSupply() == initSupplySTT - amountToRedeem);
//         assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(DAO)) == initBalanceDAO + fee);
//     } 

//     // test for restriction on redeemSenior() when balance = 0
//     function test_OCR_redeemSenior_restrictions_balance() public {
//         // redeem
//         hevm.startPrank(address(sam));
//         hevm.expectRevert("OCR_Modular::redeemSenior() seniorBalances[_msgSender] == 0");
//         OCR_Modular_DAI.redeemSenior();
//         hevm.stopPrank();
//     }

//     // test for restriction on redeemSenior() when claim time is >= "currentEpoch"
//     function test_OCR_redeemSenior_restrictions_timestamp() public {
//         uint256 amountToRedeem = 2_000_000 ether;
//         // push stablecoins to the locker
//         hevm.startPrank(address(DAO));
//         IERC20(DAI).safeApprove(address(OCR_Modular_DAI), amountToRedeem);
//         OCR_Modular_DAI.pushToLocker(DAI, amountToRedeem, "");
//         hevm.stopPrank(); 

//         // initiate a redemption request
//         requestSeniorRedemption(amountToRedeem);

//         // redeem
//         hevm.startPrank(address(sam));
//         hevm.expectRevert("OCR_Modular::redeemSenior() seniorRedemptionRequestedOn[_msgSender()] >= currentEpoch");
//         OCR_Modular_DAI.redeemSenior();
//         hevm.stopPrank();
//     }

//     // test for restriction on redeemSenior() when no amount to withdraw in epoch
//     function test_OCR_redeemSenior_restrictions_noStables() public {
//         uint256 amountToRedeem = 2_000_000 ether;

//         // initiate a redemption request
//         requestSeniorRedemption(amountToRedeem);

//         // warp time to next redemption epoch
//         hevm.warp(block.timestamp + 31 days);

//         // distribute new epoch
//         OCR_Modular_DAI.updateEpoch();

//         // warp time + 1 day
//         hevm.warp(block.timestamp + 1 days);

//         // redeem
//         hevm.startPrank(address(sam));
//         hevm.expectRevert("OCR_Modular::redeemJunior() amountRedeemable == 0");
//         OCR_Modular_DAI.redeemSenior();
//         hevm.stopPrank();
//     }

//     // validate a scenario where amount of stablecoins <= total redemption amount
//     function test_OCR_redeemSenior_partial_state() public {
//         uint256 amountToRedeem = 2_000_000 ether;
//         uint256 amountInLocker = amountToRedeem / 2;
//         // push stablecoins to the locker
//         hevm.startPrank(address(DAO));
//         IERC20(DAI).safeApprove(address(OCR_Modular_DAI), amountInLocker);
//         OCR_Modular_DAI.pushToLocker(DAI, amountInLocker, "");
//         hevm.stopPrank(); 

//         // pre check
//         assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(OCR_Modular_DAI)) == amountInLocker);
//         assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(sam)) == 0);
//         uint256 initSupplySTT = zSTT.totalSupply();

//         // initiate a redemption request
//         requestSeniorRedemption(amountToRedeem);

//         // warp time to next redemption epoch
//         hevm.warp(block.timestamp + 31 days);

//         // distribute new epoch
//         OCR_Modular_DAI.updateEpoch();

//         // warp time + 1 day
//         hevm.warp(block.timestamp + 1 days);

//         // redeem
//         hevm.startPrank(address(sam));
//         OCR_Modular_DAI.redeemSenior();
//         hevm.stopPrank();

//         // checks
//         uint256 fee = (amountInLocker * OCR_Modular_DAI.redemptionFee()) / BIPS;
//         assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(OCR_Modular_DAI)) == 0);
//         assert(OCR_Modular_DAI.seniorBalances(address(sam)) == amountToRedeem - amountInLocker);
//         assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(sam)) == amountToRedeem - amountInLocker - fee);
//         assert(zSTT.totalSupply() == initSupplySTT - amountInLocker);
//     }

//     // validate a scenario where amount of stablecoins < total redemption amount
//     // and there are some defaults in the system
//     function test_OCR_redeemJunior_partialWithDefault_state() public {
//         uint256 amountToRedeem = 2_000_000 ether;
//         uint256 amountInLocker = amountToRedeem / 2;
//         // push stablecoins to the locker
//         hevm.startPrank(address(DAO));
//         IERC20(DAI).safeApprove(address(OCR_Modular_DAI), amountInLocker);
//         OCR_Modular_DAI.pushToLocker(DAI, amountInLocker, "");
//         hevm.stopPrank(); 

//         // increase defaults in the system (25% of zJTT supply)
//         hevm.startPrank(address(god));
//         OCG_Defaults_Test.increaseDefaults(1_000_000 ether);
//         hevm.stopPrank();

//         // pre check
//         assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(OCR_Modular_DAI)) == amountInLocker);
//         assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(jim)) == 0);
//         assert(GBL.defaults() == 1_000_000 ether);
//         uint256 initSupplyJTT = zJTT.totalSupply();

//         // initiate a redemption request
//         requestJuniorRedemption(amountToRedeem);

//         // warp time to next redemption epoch
//         hevm.warp(block.timestamp + 31 days);

//         // distribute new epoch
//         OCR_Modular_DAI.updateEpoch();

//         // warp time + 1 day
//         hevm.warp(block.timestamp + 1 days);

//         // redeem
//         hevm.startPrank(address(jim));
//         OCR_Modular_DAI.redeemJunior();
//         hevm.stopPrank();

//         // checks
//         uint256 fee = (75 * amountInLocker * OCR_Modular_DAI.redemptionFee()) / (BIPS * 100);
//         assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(OCR_Modular_DAI)) == 
//         (25 * (amountInLocker)) / 100);
//         assert(OCR_Modular_DAI.juniorBalances(address(jim)) == amountToRedeem - amountInLocker);
//         assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(jim)) == ((75 * (amountInLocker)) / 100) - fee); 
//         assert(zJTT.totalSupply() == initSupplyJTT - amountInLocker);
//     }

//     // validate a scenario where amount of stablecoins < total redemption amount
//     // and there are some defaults in the system
//     function test_OCR_redeemSenior_partialWithDefault_state() public {
//         uint256 amountToRedeem = 2_000_000 ether;
//         uint256 amountInLocker = amountToRedeem / 2;
//         // push stablecoins to the locker
//         hevm.startPrank(address(DAO));
//         IERC20(DAI).safeApprove(address(OCR_Modular_DAI), amountInLocker);
//         OCR_Modular_DAI.pushToLocker(DAI, amountInLocker, "");
//         hevm.stopPrank(); 

//         // increase defaults in the system (all zJTT + 25% of zSTT supply)
//         hevm.startPrank(address(god));
//         OCG_Defaults_Test.increaseDefaults(8_000_000 ether);
//         hevm.stopPrank();

//         // pre check
//         assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(OCR_Modular_DAI)) == amountInLocker);
//         assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(sam)) == 0);
//         assert(GBL.defaults() == 8_000_000 ether);
//         uint256 initSupplySTT = zSTT.totalSupply();

//         // initiate a redemption request
//         requestSeniorRedemption(amountToRedeem);

//         // warp time to next redemption epoch
//         hevm.warp(block.timestamp + 31 days);

//         // distribute new epoch
//         OCR_Modular_DAI.updateEpoch();

//         // warp time + 1 day
//         hevm.warp(block.timestamp + 1 days);

//         // redeem
//         hevm.startPrank(address(sam));
//         OCR_Modular_DAI.redeemSenior();
//         hevm.stopPrank();

//         // checks
//         uint256 fee = (84 * amountInLocker * OCR_Modular_DAI.redemptionFee()) / (BIPS * 100);
//         assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(OCR_Modular_DAI)) == (16 * amountInLocker) / 100);
//         assert(OCR_Modular_DAI.seniorBalances(address(sam)) == amountToRedeem - amountInLocker);
//         assert(IERC20(OCR_Modular_DAI.stablecoin()).balanceOf(address(sam)) == ((84 * (amountInLocker)) / 100) - fee); 
//         assert(zSTT.totalSupply() == initSupplySTT - amountInLocker);
//     }

//     // perform a fuzz testing on a dynamic basis over 2 epochs
//     function test_OCR_fuzzTest(
//         uint88 depositTranches
//     ) public {
//         // In order to have a minimum of "depositJTT" = 1
//         // we have to assume the following:
//         hevm.assume(depositTranches >= 5);
//         // accounting
//         uint256 depositJTT = uint256((20 * uint256(depositTranches)) / 100);
//         uint256 depositSTT = uint256(depositTranches);

//         // start epoch 1
//         // fund accounts with DAI
//         deal(DAI, address(jim), depositJTT);
//         deal(DAI, address(sam), depositSTT);

//         // deposit in tranches
//         // senior
//         hevm.startPrank(address(sam));
//         IERC20(DAI).safeApprove(address(ZVT), depositSTT);
//         ZVT.depositSenior(depositSTT, DAI);
//         hevm.stopPrank();
//         // junior
//         hevm.startPrank(address(jim));
//         IERC20(DAI).safeApprove(address(ZVT), depositJTT);
//         ZVT.depositJunior(depositJTT, DAI);
//         hevm.stopPrank();

//         // push half of deposits to the locker in epoch 1
//         hevm.startPrank(address(DAO));
//         IERC20(DAI).safeApprove(address(OCR_Modular_DAI), (depositJTT / 2) + (depositSTT / 2));
//         OCR_Modular_DAI.pushToLocker(DAI, (depositJTT / 2) + (depositSTT / 2), "");
//         hevm.stopPrank();

//         // warp 2 days through time
//         hevm.warp(block.timestamp + 2 days);

//         // make redemption request for full amount
//         requestJuniorRedemption(depositJTT);
//         requestSeniorRedemption(depositSTT);

//         assert(OCR_Modular_DAI.juniorBalances(address(jim)) == depositJTT);
//         assert(OCR_Modular_DAI.seniorBalances(address(sam)) == depositSTT);

//         // go to end of epoch
//         hevm.warp(block.timestamp + 29 days);

//         // distribute epoch
//         OCR_Modular_DAI.updateEpoch();

//         // start epoch 2
//         // +2 days 
//         hevm.warp(block.timestamp + 2 days);

//         // redeem junior
//         hevm.startPrank(address(jim));
//         OCR_Modular_DAI.redeemJunior();
//         hevm.stopPrank();

//         // +2 days 
//         hevm.warp(block.timestamp + 2 days);

//         // redeem senior
//         hevm.startPrank(address(sam));
//         OCR_Modular_DAI.redeemSenior();
//         hevm.stopPrank();

//         // push other half of deposits to the locker in epoch 2
//         hevm.startPrank(address(DAO));
//         IERC20(DAI).safeApprove(address(OCR_Modular_DAI), (depositJTT / 2) + (depositSTT / 2));
//         OCR_Modular_DAI.pushToLocker(DAI, (depositJTT / 2) + (depositSTT / 2), "");
//         hevm.stopPrank();

//         // warp to end of epoch
//         hevm.warp(block.timestamp + 27 days);

//         // distribute epoch
//         OCR_Modular_DAI.updateEpoch();

//         // redeem junior
//         hevm.startPrank(address(jim));
//         OCR_Modular_DAI.redeemJunior();
//         hevm.stopPrank();

//         // redeem senior
//         hevm.startPrank(address(sam));
//         OCR_Modular_DAI.redeemSenior();
//         hevm.stopPrank();
        
//         assert(OCR_Modular_DAI.juniorBalances(address(jim)) + OCR_Modular_DAI.seniorBalances(address(sam))
//         == OCR_Modular_DAI.redemptionsUnclaimed());

//         // If we have some unclaimed amounts due to roundings
//         // we continue redeeming in the next epoch (this just to show that difference is due to roundings,
//         // and that the balance when accounting for those roundings = 0 at the end)
//         hevm.startPrank(address(DAO));
//         IERC20(DAI).safeApprove(address(OCR_Modular_DAI), OCR_Modular_DAI.redemptionsUnclaimed());
//         OCR_Modular_DAI.pushToLocker(DAI, OCR_Modular_DAI.redemptionsUnclaimed(), "");
//         hevm.stopPrank();

//         // warp to end of epoch
//         hevm.warp(block.timestamp + 31 days);

//         // distribute epoch
//         OCR_Modular_DAI.updateEpoch();

//         // if we have remaining amounts for junior, redeem
//         if (OCR_Modular_DAI.juniorBalances(address(jim)) > 0) {
//             hevm.startPrank(address(jim));
//             OCR_Modular_DAI.redeemJunior();
//             hevm.stopPrank();
//         }

//         // if we have remaining amounts for senior, redeem
//         if (OCR_Modular_DAI.seniorBalances(address(sam)) > 0) {
//             hevm.startPrank(address(sam));
//             OCR_Modular_DAI.redeemSenior();
//             hevm.stopPrank();
//         }

//         // checks
//         assert(OCR_Modular_DAI.juniorBalances(address(jim)) == 0);
//         assert(OCR_Modular_DAI.seniorBalances(address(sam)) == 0);
//     }

//     // validate updateRedemptionFee() state changes
//     function test_OCR_updateRedemptionFee_state() public {
//         // pre check
//         assertEq(OCR_Modular_DAI.redemptionFee(), 1000);

//         // set new redemption fee
//         hevm.startPrank(address(god));
//         hevm.expectEmit(false, false, false, true, address(OCR_Modular_DAI));
//         emit UpdatedRedemptionFee(1000, 1500);
//         OCR_Modular_DAI.updateRedemptionFee(1500);
//         hevm.stopPrank();

//         // check
//         assert(OCR_Modular_DAI.redemptionFee() == 1500);
//     }

//     // validate updateRedemptionFee() restrictions on caller when != TLC
//     function test_OCR_setRedemptionFee_caller_restrictions() public {
//         // pre check
//         assertEq(OCR_Modular_DAI.redemptionFee(), 1000);

//         // set new redemption fee with account != TLC
//         hevm.expectRevert("OCR_Modular::updateRedemptionFee() _msgSender() != TLC()");
//         OCR_Modular_DAI.updateRedemptionFee(1500);
//     }

//     // validate updateRedemptionFee() restrictions when amount is out of range
//     function test_OCR_updateRedemptionFee_amount_restrictions() public {
//         // pre check
//         assertEq(OCR_Modular_DAI.redemptionFee(), 1000);

//         // set new redemption fee
//         hevm.startPrank(address(god));
//         hevm.expectRevert("OCR_Modular::updateRedemptionFee() _redemptionFee > 2000 && _redemptionFee < 250");
//         OCR_Modular_DAI.updateRedemptionFee(5000);
//         hevm.stopPrank();
//     }

//     // validate cancelRedemptionJunior() state changes - fuzz testing
//     // we won't test for high amounts here - will be done through the same test for senior tranches
//     function test_OCR_cancelRedemptionJunior_state_fuzzTest(
//         uint88 amountToCancel, 
//         uint88 amountToPush,
//         uint88 amountToRedeem
//     ) 
//         public
//     {
//         hevm.assume(amountToPush > 0 && amountToRedeem > 0 && amountToCancel > 0);
//         hevm.assume(amountToPush < 10_000_000 ether);
//         hevm.assume(amountToRedeem <= 2_000_000 ether);
//         hevm.assume(amountToCancel <= 2 * uint256(amountToRedeem));

//         // push stablecoins to the locker
//         hevm.startPrank(address(DAO));
//         IERC20(DAI).safeApprove(address(OCR_Modular_DAI), amountToPush);
//         OCR_Modular_DAI.pushToLocker(DAI, amountToPush, "");
//         hevm.stopPrank();

//         // do a first redemption request
//         requestJuniorRedemption(amountToRedeem);

//         // warp time to next epoch (1) distribution
//         hevm.warp(block.timestamp + 31 days);

//         // distribute new epoch
//         OCR_Modular_DAI.updateEpoch();

//         // push stablecoins to the locker
//         hevm.startPrank(address(DAO));
//         IERC20(DAI).safeApprove(address(OCR_Modular_DAI), amountToPush);
//         OCR_Modular_DAI.pushToLocker(DAI, amountToPush, "");
//         hevm.stopPrank();

//         // do a second redemption request
//         // we are not using the helper fct as we want to avoid a fullWithdraw() again
//         hevm.startPrank(address(jim));
//         IERC20(zJTT).safeApprove(address(OCR_Modular_DAI), amountToRedeem);
//         OCR_Modular_DAI.requestJuniorRedemption(amountToRedeem);
//         hevm.stopPrank();

//         // warp time + 5 days
//         hevm.warp(block.timestamp + 5 days);

//         // pre-check
//         assert(OCR_Modular_DAI.redemptionsAllowed() == amountToRedeem);
//         assert(OCR_Modular_DAI.redemptionsRequested() == amountToRedeem);
//         assert(OCR_Modular_DAI.amountRedeemable() == amountToPush);
//         assert(OCR_Modular_DAI.amountRedeemableQueued() == amountToPush);
//         assert(OCR_Modular_DAI.redemptionsUnclaimed() == amountToRedeem);
//         uint256 initBalance = OCR_Modular_DAI.juniorBalances(address(jim));

//         // cancel redemption request for a specific amount
//         hevm.startPrank(address(jim));
//         hevm.expectEmit(true, false, false, true, address(OCR_Modular_DAI));
//         emit CancelledJunior(address(jim), amountToCancel);
//         OCR_Modular_DAI.cancelRedemptionJunior(amountToCancel);
//         hevm.stopPrank();

//         // final check
//         if (amountToCancel >= amountToRedeem) {
//             uint256 diff = amountToCancel - amountToRedeem;
//             assert(OCR_Modular_DAI.redemptionsRequested() == 0);
//             assert(OCR_Modular_DAI.redemptionsAllowed() == amountToRedeem - diff);
//         }

//         if (amountToCancel < amountToRedeem) {
//             assert(OCR_Modular_DAI.redemptionsRequested() == amountToRedeem - amountToCancel);
//         }
//     }

//     // validate restriction to call cancelRedemptionJunior() when balance < amount
//     function test_OCR_cancelRedemptionJunior_restrictions() public {
//         hevm.startPrank(address(jim));
//         hevm.expectRevert("OCR_Modular::cancelRedemptionJunior() juniorBalances[_msgSender()] < amount");
//         OCR_Modular_DAI.cancelRedemptionJunior(1);
//         hevm.stopPrank();
//     }

//     // validate restriction to call cancelRedemptionSenior() when balance < amount
//     function test_OCR_cancelRedemptionSenior_restrictions() public {
//         hevm.startPrank(address(sam));
//         hevm.expectRevert("OCR_Modular::cancelRedemptionSenior() seniorBalances[_msgSender()] < amount");
//         OCR_Modular_DAI.cancelRedemptionSenior(1);
//         hevm.stopPrank();
//     }

//     // validate cancelRedemptionSenior() state changes - fuzz testing
//     function test_OCR_cancelRedemptionSenior_state_fuzzTest(
//         uint88 amountToCancel, 
//         uint88 amountToPush,
//         uint88 amountToRedeem
//     ) 
//         public
//     {
//         hevm.assume(amountToPush > 0 && amountToRedeem > 0 && amountToCancel > 0);
//         hevm.assume(amountToRedeem <= (3 * uint256(amountToPush)) / 2);
//         hevm.assume(amountToCancel <= 2 * uint256(amountToRedeem));

//         // deposit in senior tranche to have zSTT tokens
//         deal(DAI, address(sam), 3 * uint256(amountToPush));
//         hevm.startPrank(address(sam));
//         IERC20(DAI).safeApprove(address(ZVT), 3 * uint256(amountToPush));
//         ZVT.depositSenior(3 * uint256(amountToPush), DAI);
//         hevm.stopPrank();

//         // push stablecoins to the locker
//         hevm.startPrank(address(DAO));
//         IERC20(DAI).safeApprove(address(OCR_Modular_DAI), amountToPush);
//         OCR_Modular_DAI.pushToLocker(DAI, amountToPush, "");
//         hevm.stopPrank();

//         // do a first redemption request
//         requestSeniorRedemption(amountToRedeem);

//         // warp time to next epoch (1) distribution
//         hevm.warp(block.timestamp + 31 days);

//         // distribute new epoch
//         OCR_Modular_DAI.updateEpoch();

//         // push stablecoins to the locker
//         hevm.startPrank(address(DAO));
//         IERC20(DAI).safeApprove(address(OCR_Modular_DAI), amountToPush);
//         OCR_Modular_DAI.pushToLocker(DAI, amountToPush, "");
//         hevm.stopPrank();

//         emit log_named_uint("zSTT Balance sam", zSTT.balanceOf(address(sam)));
//         // do a second redemption request
//         // we are not using the helper fct as we want to avoid a fullWithdraw() again
//         hevm.startPrank(address(sam));
//         IERC20(zSTT).safeApprove(address(OCR_Modular_DAI), amountToRedeem);
//         emit log_named_uint("zSTT Balance sam", zSTT.balanceOf(address(sam)));
//         OCR_Modular_DAI.requestSeniorRedemption(amountToRedeem);
//         hevm.stopPrank();

//         // warp time + 5 days
//         hevm.warp(block.timestamp + 5 days);

//         // pre-check
//         assert(OCR_Modular_DAI.redemptionsAllowed() == amountToRedeem);
//         assert(OCR_Modular_DAI.redemptionsRequested() == amountToRedeem);
//         assert(OCR_Modular_DAI.amountRedeemable() == amountToPush);
//         assert(OCR_Modular_DAI.amountRedeemableQueued() == amountToPush);
//         assert(OCR_Modular_DAI.redemptionsUnclaimed() == amountToRedeem);
//         uint256 initBalance = OCR_Modular_DAI.seniorBalances(address(sam));

//         // cancel redemption request for a specific amount
//         hevm.startPrank(address(sam));
//         hevm.expectEmit(true, false, false, true, address(OCR_Modular_DAI));
//         emit CancelledSenior(address(sam), amountToCancel);
//         OCR_Modular_DAI.cancelRedemptionSenior(amountToCancel);
//         hevm.stopPrank();

//         // final check
//         if (amountToCancel > amountToRedeem) {
//             uint256 diff = amountToCancel - amountToRedeem;
//             assert(OCR_Modular_DAI.redemptionsRequested() == 0);
//             assert(OCR_Modular_DAI.redemptionsAllowed() == amountToRedeem - diff);
//         }

//         if (amountToCancel < amountToRedeem) {
//             assert(OCR_Modular_DAI.redemptionsRequested() == amountToRedeem - amountToCancel);
//         }
//     }
// }