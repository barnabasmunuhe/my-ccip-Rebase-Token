// SPDX-License-Identifier:MIT

pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {myRebaseTokenPool} from "../src/myRebaseTokenPool.sol";
import {Vault} from "../src/Vault.sol";
import {RebaseToken} from "../src/my-rebaseToken.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";

contract deployTokenAndPool is Script {
    function run() public returns (RebaseToken token, address pool) {
        vm.startBroadcast();
        // Deploy Rebase Token
        token = new RebaseToken();
        // Deploy Token Pool
        // pool = new myRebaseTokenPool();
        // Grant mint and burn role to pool
        token.grantMintAndBurnRole(address(pool));
        vm.stopBroadcast();
    }
}

contract deployVault is Script {
    function run() public returns (Vault vault) {
        vm.startBroadcast();
        // Deploy Vault
        vault = new Vault(IRebaseToken(address(vault)));
        // grant mint and burn role to vault
        IRebaseToken(address(vault)).grantMintAndBurnRole(address(vault));
        vm.stopBroadcast();
    }
}
