// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.17;
pragma experimental ABIEncoderV2;

import "lib/zivoe-core-foundry/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract Manager {

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

    function try_acceptOffer(address occ, uint256 id) external returns (bool ok) {
        string memory sig = "acceptOffer(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
    }

    function try_markRepaid(address occ, uint256 id) external returns (bool ok) {
        string memory sig = "markRepaid(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
    }

    function try_cancelOffer(address occ, uint256 id) external returns (bool ok) {
        string memory sig = "cancelOffer(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
    }

    function try_processPayment(address occ, uint256 id) external returns (bool ok) {
        string memory sig = "processPayment(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
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

    function try_markDefault(address occ, uint256 id) external returns (bool ok) {
        string memory sig = "markDefault(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
    }

    function try_applyCombine(address occ, uint[] memory ids, uint paymentInterval) external returns (bool ok) {
        string memory sig = "applyCombine(uint256[],uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, ids, paymentInterval));
    }

    function try_applyConversionAmortization(address occ, uint id) external returns (bool ok) {
        string memory sig = "applyConversionAmortization(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
    }

    function try_applyConversionBullet(address occ, uint id) external returns (bool ok) {
        string memory sig = "applyConversionBullet(uint256)";
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

    function try_approveConversionAmortization(address occ, uint id) external returns (bool ok) {
        string memory sig = "approveConversionAmortization(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
    }

    function try_approveConversionBullet(address occ, uint id) external returns (bool ok) {
        string memory sig = "approveConversionBullet(uint256)";
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

    function try_unapproveConversionAmortization(address occ, uint id) external returns (bool ok) {
        string memory sig = "unapproveConversionAmortization(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
    }

    function try_unapproveConversionBullet(address occ, uint id) external returns (bool ok) {
        string memory sig = "unapproveConversionBullet(uint256)";
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