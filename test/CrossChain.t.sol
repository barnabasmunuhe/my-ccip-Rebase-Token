// SPDX-License-Identifier:MIT

pragma solidity ^0.8.24;

// ===== Imports =====
import {Test} from "forge-std/Test.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";
import {myRebaseTokenPool} from "../src/myRebaseTokenPool.sol";
import {Vault} from "../src/Vault.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {RateLimiter} from "@ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";


contract CrossChainTest is Test {
    address owner = makeAddr("owner");

    CCIPLocalSimulatorFork ccipLocalSimulatorFork;

    uint256 sepoliaFork;
    uint256 arbSepoliaFork;

    RebaseToken sepoliaToken;
    RebaseToken arbSepoliaToken;

    Register.NetworkDetails sepoliaNetworkDetails;
    Register.NetworkDetails arbSepoliaNetworkDetails;

    myRebaseTokenPool sepoliaTokenPool;
    myRebaseTokenPool arbSepoliaTokenPool;



    Vault vault

function setUp(){
    sepoliaFork = vm.createSelectFork(sepolia-eth);
    arbSepoliaFork = vm.createFork(arb-sepolia);

    ccipLocalSimulatorFork = new CCIPLocalSimulatorFork(); 
    vm.makePersistent(address(ccipLocalSimulatorFork));

    // deploy and configure sepolia
    sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
    vm.startBroadcast(owner);
    sepoliaToken = new RebaseToken();
    sepoliaTokenPool = new myRebaseTokenPool(IERC20(IRebaseToken(sepoliaToken)),new address[](0), sepoliaNetworkDetails.rmnProxyAddress, sepoliaNetworkDetails.routerAddress);
    vault = new Vault(IRebaseToken(sepoliaToken));
    sepoliaToken.grantMintAndBurnRole(address(vault));
    sepoliaToken.grantMintAndBurnRole(address(sepoliaTokenPool));

    configureTokenPools(sepoliaFork, address(sepoliaTokenPool), sepoliaNetworkDetails.chainSelector,address(arbSepoliaToken), address(arbSepoliaTokenPool));
    vm.stopBroadcast();


    // deploy and configure arbSepolia
    arbSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
    vm.startPrank(owner);
    arbSepolia = new RebaseToken();
    arSepoliaTokenPool = new myRebaseTokenPool(IERC20(IRebaseToken(arbSepoliaToken)),new address[](0), arbSepoliaNetworkDetails.rmnProxyAddress, arbSepoliaNetworkDetails.routerAddress);
    arbSepoliaToken.grantMintAndBurnRole(address(arbSepoliaTokenPool));

    configureTokenPools(arbSepoliaFork, address(arbSepoliaTokenPool), arbSepoliaNetworkDetails.chainSelector,address(sepoliaToken), address(sepoliaTokenPool));

    vm.stopPrank();
}

function configureTokenPools(uint256 fork,address localPool, uint64 remoteChainSelector, address remoteTokenAddress, address remotePool) public{
    vm.select(fork);
    bytes remotePoolAddress = new bytes[](1);
    remotePoolAddress[0] = abi.encode(remotePool);//abi.encoding the remote tokenAddress
    TokenPool.ChainUpdate[] calldata chains = new TokenPool.ChainUpdate[](1);//creating a new instance of the TokenPool struct array with one element
//       struct ChainUpdate {
//     uint64 remoteChainSelector; // ──╮ Remote chain selector
//     bool allowed; // ────────────────╯ Whether the chain should be enabled
//     bytes remotePoolAddress; //        Address of the remote pool, ABI encoded in the case of a remote EVM chain.
//     bytes remoteTokenAddress; //       Address of the remote token, ABI encoded in the case of a remote EVM chain.
//     RateLimiter.Config outboundRateLimiterConfig; // Outbound rate limited config, meaning the rate limits for all of the onRamps for the given chain
//     RateLimiter.Config inboundRateLimiterConfig; // Inbound rate limited config, meaning the rate limits for all of the offRamps for the given chain
//   }
chains(0) = TokenPool.ChainUpdate({
    remoteChainSelector : remoteChainSelector,
    allowed : true,
    remotePoolAddress : remotePoolAddress[0],
    remoteTokenAddress : abi.encode(remoteTokenAddress);
    outboundRateLimiterConfig : RateLimiter.Config({
        isEnabled: false,
        capcity: 0,
        rate : 0

    }),
    inboundRateLimiterConfig: RateLimiter.Config({
        isEnabled: false,
        capcity : 0,
        rate : 0
    }),
});
    TokenPool(localPool).applyChainUpdates(chains);
}
}


