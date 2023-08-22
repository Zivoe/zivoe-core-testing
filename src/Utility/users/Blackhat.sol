// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;
pragma experimental ABIEncoderV2;

import "lib/zivoe-core-foundry/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract Blackhat {

    /************************/
    /*** DIRECT FUNCTIONS ***/
    /************************/

    function transferByTrader(address token, address to, uint256 amount) external {
        IERC20(token).transfer(to, amount);
    }

    /*********************/
    /*** TRY FUNCTIONS ***/
    /*********************/

    function try_transferByTrader(address token, address to, uint256 amount) external returns (bool ok) {
        string memory sig = "transfer(address,uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, to, amount));
    }

    function try_transferToken(address token, address to, uint256 amount) external returns (bool ok) {
        string memory sig = "transfer(address,uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, to, amount));
    }

    function try_transferFromToken(address token, address from, address to, uint256 amount) external returns (bool ok) {
        string memory sig = "transferFrom(address,address,uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, from, to, amount));
    }

    function try_approveToken(address token, address to, uint256 amount) external returns (bool ok) {
        string memory sig = "approve(address,uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, to, amount));
    }

   function try_changeMinterRole(address token, address account, bool allowed) external returns (bool ok) {
        string memory sig = "changeMinterRole(address,bool)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, account, allowed));
    }

    function try_burn(address token, uint256 amount) external returns (bool ok) {
        string memory sig = "burn(uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, amount));
    }

    function try_burnSenior(address token, uint256 amount, address asset) external returns (bool ok) {
        string memory sig = "burnSenior(uint256,address)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, amount, asset));
    }

    function try_mint(address token, address account, uint256 amount) external returns (bool ok) {
        string memory sig = "mint(address,uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, account, amount));
    }

    function try_createVestingSchedule(address vesting, address account, uint256 daysUntilVestingBegins, uint256 daysToVest, uint256 amountToVest) external returns (bool ok) {
        string memory sig = "createVestingSchedule(address,uint256,uint256,uint256)";
        (ok,) = address(vesting).call(abi.encodeWithSignature(sig, account, daysUntilVestingBegins, daysToVest, amountToVest));
    }

    function try_increaseAmplification(address amp, address account, uint256 amount) external returns (bool ok) {
        string memory sig = "increaseAmplification(address,uint256)";
        (ok,) = address(amp).call(abi.encodeWithSignature(sig, account, amount));
    }

    function try_increaseAllowance(address token, address account, uint256 amount) external returns (bool ok) {
        string memory sig = "increaseAllowance(address,uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, account, amount));
    }

    function try_decreaseAllowance(address token, address account, uint256 amount) external returns (bool ok) {
        string memory sig = "decreaseAllowance(address,uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, account, amount));
    }

    function try_modifyStablecoinWhitelist(address tranches, address asset, bool allowed) external returns (bool ok) {
        string memory sig = "modifyStablecoinWhitelist(address,bool)";
        (ok,) = address(tranches).call(abi.encodeWithSignature(sig, asset, allowed));
    }

    function try_depositJunior(address ito, uint256 amount, address asset) external returns (bool ok) {
        string memory sig = "depositJunior(uint256,address)";
        (ok,) = address(ito).call(abi.encodeWithSignature(sig, amount, asset));
    }

    function try_depositSenior(address ito, uint256 amount, address asset) external returns (bool ok) {
        string memory sig = "depositSenior(uint256,address)";
        (ok,) = address(ito).call(abi.encodeWithSignature(sig, amount, asset));
    }

    function try_claimAirdrop(address ito, address depositor) external returns (bool ok) {
        string memory sig = "claimAirdrop(address)";
        (ok,) = address(ito).call(abi.encodeWithSignature(sig, depositor));
    }

    function try_migrateDeposits(address ito) external returns (bool ok) {
        string memory sig = "migrateDeposits()";
        (ok,) = address(ito).call(abi.encodeWithSignature(sig));
    }

    function try_depositJuniorTranches(address tranches, uint256 amount, address asset) external returns (bool ok) {
        string memory sig = "depositJunior(uint256,address)";
        (ok,) = address(tranches).call(abi.encodeWithSignature(sig, amount, asset));
    }

    function try_depositSeniorTranches(address tranches, uint256 amount, address asset) external returns (bool ok) {
        string memory sig = "depositSenior(uint256,address)";
        (ok,) = address(tranches).call(abi.encodeWithSignature(sig, amount, asset));
    }

    function try_updateIsKeeper(address gbl, address keeper, bool allowed) external returns (bool ok) {
        string memory sig = "updateIsKeeper(address,bool)";
        (ok,) = address(gbl).call(abi.encodeWithSignature(sig, keeper, allowed));
    }

    function try_updateIsLocker(address gbl, address locker, bool allowed) external returns (bool ok) {
        string memory sig = "updateIsLocker(address,bool)";
        (ok,) = address(gbl).call(abi.encodeWithSignature(sig, locker, allowed));
    }

    function try_updateStablecoinWhitelist(address gbl, address stablecoin, bool allowed) external returns (bool ok) {
        string memory sig = "updateStablecoinWhitelist(address,bool)";
        (ok,) = address(gbl).call(abi.encodeWithSignature(sig, stablecoin, allowed));
    }

    function try_push(address dao, address locker, address asset, uint256 amount, bytes calldata data) external returns (bool ok) {
        string memory sig = "push(address,address,uint256,bytes)";
        (ok,) = address(dao).call(abi.encodeWithSignature(sig, locker, asset, amount, data));
    }

    function try_pull(address dao, address locker, address asset, bytes calldata data) external returns (bool ok) {
        string memory sig = "pull(address,address,bytes)";
        (ok,) = address(dao).call(abi.encodeWithSignature(sig, locker, asset, data));
    }

    function try_pullPartial(address dao, address locker, address asset, uint256 amount, bytes calldata data) external returns (bool ok) {
        string memory sig = "pullPartial(address,address,uint256,bytes)";
        (ok,) = address(dao).call(abi.encodeWithSignature(sig, locker, asset, amount, data));
    }

    function try_pushMulti(address dao, address locker, address[] calldata assets, uint256[] calldata amounts, bytes[] calldata data) external returns (bool ok) {
        string memory sig = "pushMulti(address,address[],uint256[],bytes[])";
        (ok,) = address(dao).call(abi.encodeWithSignature(sig, locker, assets, amounts, data));
    }

    function try_pullMulti(address dao, address locker, address[] calldata assets, bytes[] calldata data) external returns (bool ok) {
        string memory sig = "pullMulti(address,address[],bytes[])";
        (ok,) = address(dao).call(abi.encodeWithSignature(sig, locker, assets, data));
    }

    function try_pullMultiPartial(address dao, address locker, address[] calldata assets, uint256[] calldata amounts, bytes[] calldata data) external returns (bool ok) {
        string memory sig = "pullMultiPartial(address,address[],uint256[],bytes[])";
        (ok,) = address(dao).call(abi.encodeWithSignature(sig, locker, assets, amounts, data));
    }

    function try_pushERC721(address dao, address locker, address asset, uint256 tokenId, bytes calldata data) external returns (bool ok) {
        string memory sig = "pushERC721(address,address,uint256,bytes)";
        (ok,) = address(dao).call(abi.encodeWithSignature(sig, locker, asset, tokenId, data));
    }

    function try_pullERC721(address dao, address locker, address asset, uint256 tokenId, bytes calldata data) external returns (bool ok) {
        string memory sig = "pullERC721(address,address,uint256,bytes)";
        (ok,) = address(dao).call(abi.encodeWithSignature(sig, locker, asset, tokenId, data));
    }

    function try_pushMultiERC721(address dao, address locker, address[] calldata assets, uint256[] calldata tokenIds, bytes[] calldata data) external returns (bool ok) {
        string memory sig = "pushMultiERC721(address,address[],uint256[],bytes[])";
        (ok,) = address(dao).call(abi.encodeWithSignature(sig, locker, assets, tokenIds, data));
    }

    function try_pullMultiERC721(address dao, address locker, address[] calldata assets, uint256[] calldata tokenIds, bytes[] calldata data) external returns (bool ok) {
        string memory sig = "pullMultiERC721(address,address[],uint256[],bytes[])";
        (ok,) = address(dao).call(abi.encodeWithSignature(sig, locker, assets, tokenIds, data));
    }

    function try_pushERC1155(address dao, address locker, address asset, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) external returns (bool ok) {
        string memory sig = "pushERC1155(address,address,uint256[],uint256[],bytes)";
        (ok,) = address(dao).call(abi.encodeWithSignature(sig, locker, asset, ids, amounts, data));
    }

    function try_pullERC1155(address dao, address locker, address asset, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) external returns (bool ok) {
        string memory sig = "pullERC1155(address,address,uint256[],uint256[],bytes)";
        (ok,) = address(dao).call(abi.encodeWithSignature(sig, locker, asset, ids, amounts, data));
    }

    function try_createOffer(
        address occ, 
        address borrower,
        uint256 borrowAmount,
        uint256 APR,
        uint256 APRLateFee,
        uint256 term,
        uint256 paymentInterval,
        uint256 gracePeriod,
        int8 schedule
    ) external returns (bool ok) {
        string memory sig = "createOffer(address,uint256,uint256,uint256,uint256,uint256,uint256,int8)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, borrower, borrowAmount, APR, APRLateFee, term, paymentInterval, gracePeriod, schedule));
    }

    function try_cancelOffer(address occ, uint256 id) external returns (bool ok) {
        string memory sig = "cancelOffer(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
    }

    function try_acceptOffer(address occ, uint256 id) external returns (bool ok) {
        string memory sig = "acceptOffer(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
    }

    function try_makePayment(address occ, uint256 id) external returns (bool ok) {
        string memory sig = "makePayment(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
    }

    function try_processPayment(address occ, uint256 id) external returns (bool ok) {
        string memory sig = "processPayment(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
    }

    function try_callLoan(address occ, uint256 id) external returns (bool ok) {
        string memory sig = "callLoan(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
    }

    function try_resolveDefault(address occ, uint256 id, uint256 amount) external returns (bool ok) {
        string memory sig = "resolveDefault(uint256,uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id, amount));
    }

    function try_markDefault(address occ, uint256 id) external returns (bool ok) {
        string memory sig = "markDefault(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
    }

    function try_resolveInsolvency(address occ, uint256 id, uint256 amount) external returns (bool ok) {
        string memory sig = "resolveInsolvency(uint256,uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id, amount));
    }

    function try_markRepaid(address occ, uint256 id) external returns (bool ok) {
        string memory sig = "markRepaid(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
    }

    function try_supplyInterest(address occ, uint256 id, uint256 excessAmount) external returns (bool ok) {
        string memory sig = "supplyInterest(uint256,uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id, excessAmount));
    }

    function try_pushAsset(address ret, address asset, address to, uint256 amount) external returns (bool ok) {
        string memory sig = "pushAsset(address,address,uint256)";
        (ok,) = address(ret).call(abi.encodeWithSignature(sig, asset, to, amount));
    }

    function try_passThroughYDL(address ret, address asset, uint256 amount, address multi) external returns (bool ok) {
        string memory sig = "passThroughYDL(address,uint256,address)";
        (ok,) = address(ret).call(abi.encodeWithSignature(sig, asset, amount, multi));
    }

    function try_exchange_underlying(address pool, int128 i, int128 j, uint256 dx, uint256 min_dy) external returns (bool ok) {
        string memory sig = "exchange_underlying(int128,int128,uint256,uint256)";
        (ok,) = address(pool).call(abi.encodeWithSignature(sig, i, j, dx, min_dy));
    }

    function try_increaseDefaults(address gen, uint256 amount) external returns (bool ok){
        string memory sig = "increaseDefaults(uint256)";
        (ok,) = address(gen).call(abi.encodeWithSignature(sig, amount));
    }

    function try_decreaseDefaults(address gen, uint256 amount) external returns (bool ok){
        string memory sig = "decreaseDefaults(uint256)";
        (ok,) = address(gen).call(abi.encodeWithSignature(sig, amount));
    }

    function try_updateMaxTrancheRatio(address gbl, uint256 amount) external returns (bool ok){
        string memory sig = "updateMaxTrancheRatio(uint256)";
        (ok,) = address(gbl).call(abi.encodeWithSignature(sig, amount));
    }

    function try_updateMinZVEPerJTTMint(address gbl, uint256 amount) external returns (bool ok){
        string memory sig = "updateMinZVEPerJTTMint(uint256)";
        (ok,) = address(gbl).call(abi.encodeWithSignature(sig, amount));
    }

    function try_updateMaxZVEPerJTTMint(address gbl, uint256 amount) external returns (bool ok){
        string memory sig = "updateMaxZVEPerJTTMint(uint256)";
        (ok,) = address(gbl).call(abi.encodeWithSignature(sig, amount));
    }

    function try_updateLowerRatioIncentiveBIPS(address gbl, uint256 amount) external returns (bool ok){
        string memory sig = "updateLowerRatioIncentiveBIPS(uint256)";
        (ok,) = address(gbl).call(abi.encodeWithSignature(sig, amount));
    }

    function try_updateUpperRatioIncentive(address gbl, uint256 amount) external returns (bool ok){
        string memory sig = "updateUpperRatioIncentive(uint256)";
        (ok,) = address(gbl).call(abi.encodeWithSignature(sig, amount));
    }

    function try_pullFromLocker_DIRECT(address lkr, address asset, bytes calldata data) external returns (bool ok) {
        string memory sig = "pullFromLocker(address,bytes)";
        (ok,) = address(lkr).call(abi.encodeWithSignature(sig, asset, data));
    }

    function try_pullFromLockerPartial_DIRECT(address lkr, address asset, uint256 amount, bytes calldata data) external returns (bool ok) {
        string memory sig = "pullFromLockerPartial(address,uint256,bytes)";
        (ok,) = address(lkr).call(abi.encodeWithSignature(sig, asset, amount, data));
    }

    function try_pullFromLockerMulti_DIRECT(address lkr, address[] calldata assets, bytes[] calldata data) external returns (bool ok) {
        string memory sig = "pullFromLockerMulti(address[],bytes[])";
        (ok,) = address(lkr).call(abi.encodeWithSignature(sig, assets, data));
    }

    function try_pullFromLockerMultiPartial_DIRECT(address lkr, address[] calldata assets, uint256[] calldata amts, bytes[] calldata data) external returns (bool ok) {
        string memory sig = "pullFromLockerMultiPartial(address[],uint256[],bytes[])";
        (ok,) = address(lkr).call(abi.encodeWithSignature(sig, assets, amts, data));
    }

    function try_pushToLockerMulti_DIRECT(address lkr, address[] calldata assets, uint256[] calldata amts, bytes[] calldata data) external returns (bool ok) {
        string memory sig = "pushToLockerMulti(address[],uint256[], bytes[])";
        (ok,) = address(lkr).call(abi.encodeWithSignature(sig, assets, amts, data));
    }

    function try_updateDistributionRatioBIPS(address oce, uint256[3] calldata dist) external returns (bool ok) {
        string memory sig = "updateDistributionRatioBIPS(uint256[3])";
        (ok,) = address(oce).call(abi.encodeWithSignature(sig, dist));
    }

    function try_updateExponentialDecayPerSecond(address oce, uint256 val) external returns (bool ok) {
        string memory sig = "updateExponentialDecayPerSecond(uint256)";
        (ok,) = address(oce).call(abi.encodeWithSignature(sig, val));
    }

    function try_updateCompoundingRateBIPS(address ocl, uint256 val) external returns (bool ok) {
        string memory sig = "updateCompoundingRateBIPS(uint256)";
        (ok,) = address(ocl).call(abi.encodeWithSignature(sig, val));
    }

    function try_forwardYield(address ocl) external returns (bool ok) {
        string memory sig = "forwardYield()";
        (ok,) = address(ocl).call(abi.encodeWithSignature(sig));
    }

    function try_addReward(address stk, address token, uint256 duration) external returns (bool ok) {
        string memory sig = "addReward(address,uint256)";
        (ok,) = address(stk).call(abi.encodeWithSignature(sig, token, duration));
    }

    function try_depositReward(address stk, address token, uint256 amount) external returns (bool ok) {
        string memory sig = "depositReward(address,uint256)";
        (ok,) = address(stk).call(abi.encodeWithSignature(sig, token, amount));
    }

    function try_fullWithdraw(address stk) external returns (bool ok) {
        string memory sig = "fullWithdraw()";
        (ok,) = address(stk).call(abi.encodeWithSignature(sig));
    }

    function try_stake(address stk, uint256 amount) external returns (bool ok) {
        string memory sig = "stake(uint256)";
        (ok,) = address(stk).call(abi.encodeWithSignature(sig, amount));
    }

    function try_getRewards(address stk) external returns (bool ok) {
        string memory sig = "getRewards(uint256)";
        (ok,) = address(stk).call(abi.encodeWithSignature(sig));
    }

    function try_getRewardAt(address stk, uint256 ind) external returns (bool ok) {
        string memory sig = "getRewardAt(uint256)";
        (ok,) = address(stk).call(abi.encodeWithSignature(sig, ind));
    }

    function try_withdraw(address stk, uint256 amount) external returns (bool ok) {
        string memory sig = "withdraw(uint256)";
        (ok,) = address(stk).call(abi.encodeWithSignature(sig, amount));
    }

    function try_createVestingSchedule(address stk, address act, uint256 dtc, uint256 dtv, uint256 atv, bool rev) external returns (bool ok) {
        string memory sig = "createVestingSchedule(address,uint256,uint256,uint256,bool)";
        (ok,) = address(stk).call(abi.encodeWithSignature(sig, act, dtc, dtv, atv, rev));
    }

    function try_revokeVestingSchedule(address stk, address act) external returns (bool ok) {
        string memory sig = "revokeVestingSchedule(address)";
        (ok,) = address(stk).call(abi.encodeWithSignature(sig, act));
    }

    function try_unlock(address loc) external returns (bool ok) {
        string memory sig = "unlock()";
        (ok,) = address(loc).call(abi.encodeWithSignature(sig));
    }

    function try_updateRecipients(address ydl, address[] memory recipients, uint256[] memory proportions, bool protocol) external returns (bool ok) {
        string memory sig = "updateRecipients(address[],uint256[],bool)";
        (ok,) = address(ydl).call(abi.encodeWithSignature(sig, recipients, proportions, protocol));
    }

    function try_updateTargetAPYBIPS(address ydl, uint256 val) external returns (bool ok) {
        string memory sig = "updateTargetAPYBIPS(uint256)";
        (ok,) = address(ydl).call(abi.encodeWithSignature(sig, val));
    }

    function try_updateTargetRatioBIPS(address ydl, uint256 val) external returns (bool ok) {
        string memory sig = "updateTargetRatioBIPS(uint256)";
        (ok,) = address(ydl).call(abi.encodeWithSignature(sig, val));
    }

    function try_updateProtocolEarningsRateBIPS(address ydl, uint256 val) external returns (bool ok) {
        string memory sig = "updateProtocolEarningsRateBIPS(uint256)";
        (ok,) = address(ydl).call(abi.encodeWithSignature(sig, val));
    }

    function try_updateDistributedAsset(address ydl, address asset) external returns (bool ok) {
        string memory sig = "updateDistributedAsset(address)";
        (ok,) = address(ydl).call(abi.encodeWithSignature(sig, asset));
    }

    function try_distributeYield(address ydl) external returns (bool ok) {
        string memory sig = "distributeYield()";
        (ok,) = address(ydl).call(abi.encodeWithSignature(sig));
    }

    function try_applyCombine(address occ, uint[] memory ids, uint paymentInterval) external returns (bool ok) {
        string memory sig = "applyCombine(uint256[],uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, ids, paymentInterval));
    }

    function try_applyConversionToAmortization(address occ, uint id) external returns (bool ok) {
        string memory sig = "applyConversionToAmortization(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
    }

    function try_applyConversionToBullet(address occ, uint id) external returns (bool ok) {
        string memory sig = "applyConversionToBullet(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
    }

    function try_applyExtension(address occ, uint id) external returns (bool ok) {
        string memory sig = "applyExtension(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
    }

    function try_applyRefinance(address occ, uint id) external returns (bool ok) {
        string memory sig = "applyRefinance(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
    }

    function try_approveConversionToAmortization(address occ, uint id) external returns (bool ok) {
        string memory sig = "approveConversionToAmortization(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
    }

    function try_approveConversionToBullet(address occ, uint id) external returns (bool ok) {
        string memory sig = "approveConversionToBullet(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
    }

    function try_approveExtension(address occ, uint id, uint intervals) external returns (bool ok) {
        string memory sig = "approveExtension(uint256,uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id, intervals));
    }

    function try_approveRefinance(address occ, uint id, uint apr) external returns (bool ok) {
        string memory sig = "approveRefinance(uint256,uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id, apr));
    }

    function try_unapproveCombine(address occ, address borrower) external returns (bool ok) {
        string memory sig = "unapproveCombine(address,uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, borrower));
    }

    function try_unapproveConversionToAmortization(address occ, uint id) external returns (bool ok) {
        string memory sig = "unapproveConversionToAmortization(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
    }

    function try_unapproveConversionToBullet(address occ, uint id) external returns (bool ok) {
        string memory sig = "unapproveConversionToBullet(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
    }

    function try_unapproveExtension(address occ, uint id) external returns (bool ok) {
        string memory sig = "unapproveExtension(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
    }

    function try_unapproveRefinance(address occ, uint id) external returns (bool ok) {
        string memory sig = "approveRefinance(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
    }
    
}