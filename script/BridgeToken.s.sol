// SPDX-License-Identifier:MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {IRouterClient} from "@ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";

contract BridgeTokens is Script {
    function run(uint256 amountToSend,address tokenToSendAddress, address routerAddress, uint64 destinationChainSelector, address receiverAddress, address linkTokenAddress) public {
//         struct EVM2AnyMessage {
//     bytes receiver; // abi.encode(receiver address) for dest EVM chains
//     bytes data; // Data payload
//     EVMTokenAmount[] tokenAmounts; // Token transfers
//     address feeToken; // Address of feeToken. address(0) means you will send msg.value.
//     bytes extraArgs; // Populate this with _argsToBytes(EVMExtraArgsV2)
//   }
        vm.startBroadcast();
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: tokenToSendAddress,
            amount: amountToSend
        }); 
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiverAddress),
            data: "",
            tokenAmounts:tokenAmounts,
            feeToken: linkTokenAddress,
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 0}))
        });
        uint256 ccipFee = IRouterClient(routerAddress).getFee(destinationChainSelector, message);
        IERC20(linkTokenAddress).approve(routerAddress, ccipFee);//approving router to spend our fees
        IERC20(tokenToSendAddress).approve(routerAddress, amountToSend);//approving the router to spend our tokens
        IRouterClient(routerAddress).ccipSend(destinationChainSelector, message);
        vm.stopBroadcast();
    }
}