// SPDX-License-Identifier:MIT

pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {RateLimiter} from "@ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";

contract ConfugurePools is Script {
    function run(address remoteToken, address localPool, address remotePool, uint64 remoteChainSelector, bool isAllowed, bool inboundRateLimiterIsEnabled, uint128 inboundRateLimiterCapacity,uint128 inboundRateLimiterRate, bool outboundRateLimiterIsEnabled, uint128 outboundRateLimiterCapacity, uint128 outboundRateLimiterRate) public {
        vm.startBroadcast();
        //       struct ChainUpdate {
        //     uint64 remoteChainSelector; // ──╮ Remote chain selector
        //     bool allowed; // ────────────────╯ Whether the chain should be enabled
        //     bytes remotePoolAddress; //        Address of the remote pool, ABI encoded in the case of a remote EVM chain.
        //     bytes remoteTokenAddress; //       Address of the remote token, ABI encoded in the case of a remote EVM chain.
        //     RateLimiter.Config outboundRateLimiterConfig; // Outbound rate limited config, meaning the rate limits for all of the onRamps for the given chain
        //     RateLimiter.Config inboundRateLimiterConfig; // Inbound rate limited config, meaning the rate limits for all of the offRamps for the given chain
        //   }
        bytes memory encodeRemotePool = abi.encode(remotePool);

        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            allowed: true,
            remotePoolAddress: encodeRemotePool,
            remoteTokenAddress: abi.encode(remoteToken),
            outboundRateLimiterConfig: RateLimiter.Config({isEnabled: outboundRateLimiterIsEnabled, capacity: outboundRateLimiterCapacity, rate: outboundRateLimiterRate}),
            inboundRateLimiterConfig: RateLimiter.Config({isEnabled: inboundRateLimiterIsEnabled, capacity: inboundRateLimiterCapacity, rate: inboundRateLimiterRate})
        });
        TokenPool(address(localPool)).applyChainUpdates(chainsToAdd);
        vm.stopBroadcast();
    }
}