// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;
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

    function try_fundLoan(address occ, uint256 id) external returns (bool ok) {
        string memory sig = "fundLoan(uint256)";
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
    
}