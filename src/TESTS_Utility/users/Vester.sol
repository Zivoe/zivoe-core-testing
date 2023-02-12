// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.16;
pragma experimental ABIEncoderV2;

contract Vester {

    /*********************/
    /*** TRY FUNCTIONS ***/
    /*********************/
    
    function try_delegate(address zve, address delegatee) external returns (bool ok) {
        string memory sig = "delegate(address)";
        (ok,) = address(zve).call(abi.encodeWithSignature(sig, delegatee));
    }

    function try_fullWithdraw(address mrv) external returns (bool ok) {
        string memory sig = "fullWithdraw()";
        (ok,) = address(mrv).call(abi.encodeWithSignature(sig));
    }

    function try_withdraw(address mrv) external returns (bool ok) {
        string memory sig = "withdraw()";
        (ok,) = address(mrv).call(abi.encodeWithSignature(sig));
    }

    function try_getRewards(address mrv) external returns (bool ok) {
        string memory sig = "getRewards()";
        (ok,) = address(mrv).call(abi.encodeWithSignature(sig));
    }

    function try_getRewardAt(address stk, uint256 ind) external returns (bool ok) {
        string memory sig = "getRewardAt(uint256)";
        (ok,) = address(stk).call(abi.encodeWithSignature(sig, ind));
    }

    function try_approveToken(address token, address to, uint256 amount) external returns (bool ok) {
        string memory sig = "approve(address,uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, to, amount));
    }    

    function try_stake(address stk, uint256 amount) external returns (bool ok) {
        string memory sig = "stake(uint256)";
        (ok,) = address(stk).call(abi.encodeWithSignature(sig, amount));
    }
}