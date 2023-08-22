// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;
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

    function try_propose(
        address GOV, 
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external returns (bool ok, bytes memory data) {
        string memory sig = "propose(address[],uint256[],bytes[],string)";
        (ok, data) = address(GOV).call(abi.encodeWithSignature(sig, targets, values, calldatas, description));
    }

    function try_execute(
        address TLC, 
        address target,
        uint256 value,
        bytes calldata payload,
        bytes32 predecessor,
        bytes32 salt
    ) external returns (bool ok) {
        string memory sig = "execute(address,uint256,bytes,bytes32,bytes32)";
        (ok, ) = address(TLC).call(abi.encodeWithSignature(sig, target, value, payload, predecessor, salt));
    }

    function try_executeBatch(
        address TLC, 
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory payloads,
        bytes32 predecessor,
        bytes32 salt
    ) external returns (bool ok) {
        string memory sig = "executeBatch(address[],uint256[],bytes[],bytes32,bytes32)";
        (ok, ) = address(TLC).call(abi.encodeWithSignature(sig, targets, values, payloads, predecessor, salt));
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