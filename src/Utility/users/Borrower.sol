// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;
pragma experimental ABIEncoderV2;

import "lib/zivoe-core-foundry/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract Borrower {

    /************************/
    /*** DIRECT FUNCTIONS ***/
    /************************/

    function transferByTrader(address token, address to, uint256 amount) external {
        IERC20(token).transfer(to, amount);
    }

    /*********************/
    /*** TRY FUNCTIONS ***/
    /*********************/


    function try_approveToken(address token, address to, uint256 amount) external returns (bool ok) {
        string memory sig = "approve(address,uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, to, amount));
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

    function try_resolveDefault(address occ, uint256 id, uint256 amount) external returns (bool ok) {
        string memory sig = "resolveDefault(uint256,uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id, amount));
    }

    function try_callLoan(address occ, uint256 id) external returns (bool ok) {
        string memory sig = "callLoan(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
    }

    function try_markDefault(address occ, uint256 id) external returns (bool ok) {
        string memory sig = "markDefault(uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id));
    }

    function try_resolveInsolvency(address occ, uint256 id, uint256 amount) external returns (bool ok) {
        string memory sig = "resolveInsolvency(uint256,uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id, amount));
    }

    function try_supplyInterest(address occ, uint256 id, uint256 excessAmount) external returns (bool ok) {
        string memory sig = "supplyInterest(uint256,uint256)";
        (ok,) = address(occ).call(abi.encodeWithSignature(sig, id, excessAmount));
    }
    
}