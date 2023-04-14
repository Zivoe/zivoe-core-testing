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
    
}