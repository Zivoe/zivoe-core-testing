// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;
pragma experimental ABIEncoderV2;

import "lib/zivoe-core-foundry/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import { IZivoeITO } from "lib/zivoe-core-foundry/src/misc/InterfacesAggregated.sol";

contract Investor {

    /************************/
    /*** DIRECT FUNCTIONS ***/
    /************************/

    function transferToken(address token, address to, uint256 amount) external {
        IERC20(token).transfer(to, amount);
    }

    function transferByTrader(address token, address to, uint256 amount) external {
        IERC20(token).transfer(to, amount);
    }

    function claimAirdrop(address ito, address depositor) external returns (uint256, uint256, uint256) {
        return IZivoeITO(ito).claimAirdrop(depositor);
    }

    /*********************/
    /*** TRY FUNCTIONS ***/
    /*********************/

    function try_transferByTrader(address token, address to, uint256 amount) external returns (bool ok) {
        string memory sig = "transfer(address,uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, to, amount));
    }

    function try_approveToken(address token, address to, uint256 amount) external returns (bool ok) {
        string memory sig = "approve(address,uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, to, amount));
    }    

    function try_depositJunior(address ito, uint256 amount, address asset) external returns (bool ok) {
        string memory sig = "depositJunior(uint256,address)";
        (ok,) = address(ito).call(abi.encodeWithSignature(sig, amount, asset));
    }

    function try_depositSenior(address ito, uint256 amount, address asset) external returns (bool ok) {
        string memory sig = "depositSenior(uint256,address)";
        (ok,) = address(ito).call(abi.encodeWithSignature(sig, amount, asset));
    }

    function try_depositBoth(address ito, uint256 amountSe, address assetSe, uint256 amountJu, address assetJu) external returns (bool ok) {
        string memory sig = "depositBoth(uint256,address,uint256,address)";
        (ok,) = address(ito).call(abi.encodeWithSignature(sig, amountSe, assetSe, amountJu, assetJu));
    }
    
    function try_burnSenior(address token, uint256 amount, address asset) external returns (bool ok) {
        string memory sig = "burnSenior(uint256,address)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, amount, asset));
    }
    
    function try_claimAirdrop(address vesting, address account) external returns (bool ok) {
        string memory sig = "claimAirdrop(address)";
        (ok,) = address(vesting).call(abi.encodeWithSignature(sig, account));
    }

    function try_mint(address token, address account, uint256 amount) external returns (bool ok) {
        string memory sig = "mint(address,uint256)";
        (ok,) = address(token).call(abi.encodeWithSignature(sig, account, amount));
    }
    
    function try_modifyStablecoinWhitelist(address tranches, address asset, bool allowed) external returns (bool ok) {
        string memory sig = "modifyStablecoinWhitelist(address,bool)";
        (ok,) = address(tranches).call(abi.encodeWithSignature(sig, asset, allowed));
    }

    function try_depositJuniorTranches(address tranches, uint256 amount, address asset) external returns (bool ok) {
        string memory sig = "depositJunior(uint256,address)";
        (ok,) = address(tranches).call(abi.encodeWithSignature(sig, amount, asset));
    }

    function try_depositSeniorTranches(address tranches, uint256 amount, address asset) external returns (bool ok) {
        string memory sig = "depositSenior(uint256,address)";
        (ok,) = address(tranches).call(abi.encodeWithSignature(sig, amount, asset));
    }

    function try_stake(address stk, uint256 amount) external returns (bool ok) {
        string memory sig = "stake(uint256)";
        (ok,) = address(stk).call(abi.encodeWithSignature(sig, amount));
    }

    function try_stakeFor(address stk, uint256 amount, address account) external returns (bool ok) {
        string memory sig = "stakeFor(uint256,address)";
        (ok,) = address(stk).call(abi.encodeWithSignature(sig, amount, account));
    }

    function try_withdraw(address stk, uint256 amount) external returns (bool ok) {
        string memory sig = "withdraw(uint256)";
        (ok,) = address(stk).call(abi.encodeWithSignature(sig, amount));
    }

    function try_fullWithdraw(address stk) external returns (bool ok) {
        string memory sig = "fullWithdraw()";
        (ok,) = address(stk).call(abi.encodeWithSignature(sig));
    }

    function try_getRewards(address stk) external returns (bool ok) {
        string memory sig = "getRewards()";
        (ok,) = address(stk).call(abi.encodeWithSignature(sig));
    }
    
    function try_delegate(address zve, address delegatee) external returns (bool ok) {
        string memory sig = "delegate(address)";
        (ok,) = address(zve).call(abi.encodeWithSignature(sig, delegatee));
    }

    function try_getRewardAt(address stk, uint256 ind) external returns (bool ok) {
        string memory sig = "getRewardAt(uint256)";
        (ok,) = address(stk).call(abi.encodeWithSignature(sig, ind));
    }
}
