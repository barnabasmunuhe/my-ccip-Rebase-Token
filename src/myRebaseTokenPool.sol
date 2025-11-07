// SPDX-License-Identifier:MIT

pragma solidity ^0.8.24;

// ===== Imports =====
import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {Pool} from "@ccip/contracts/src/v0.8/ccip/libraries/Pool.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {IRebaseToken} from "./Interfaces/IRebaseToken.sol";

import {}

/**
 * @author  .
 * @title   .
 * @dev     .
 * @notice  .
 */

contract myRebaseTokenPool is TokenPool{
    constructor(IERC20 _token, address[] memory _allowlist, address _rmnProxy, address _router) TokenPool(_token, _allowlist, _rmnProxy, _router) {
    }

    // ===== Functions =====
// function lockOrBurn(
//     Pool.LockOrBurnInV1 calldata lockOrBurnIn
//   ) external returns (Pool.LockOrBurnOutV1 memory lockOrBurnOut)
//   {
//     _validateLockOrBurn(lockOrBurnIn);
//     // sending userInterestRate data
//     uint256 userInterestRate = IRebaseToken(address(i_token)).getUserInterestRate(lockOrBurnIn.originalSender);
//     // burning the tokens
//     IRebaseToken(address(i_token)).burn(address(this),lockOrBurnIn.amount);
//     // preparing the data to send to remoteChain
//     lockOrBurnOut = Pool.LockOrBurnOutV1 ({
//         destTokenAddress : getRemoteToken(lockOrBurnIn.remoteChainSelector),
//         destPoolData : abi.encode(userInterestRate)
//     });
//   }

  function lockOrBurn(
    Pool.LockOrBurnInV1 calldata lockOrBurnIn
  ) external returns (Pool.LockOrBurnOutV1 memory lockOrBurnOut)
  {
    _validateLockOrBurn(lockOrBurnIn);
    // sending the userInterestRate data
    uint256 userInterestRate = IRebaseToken(address(i_token)).getUserInterestRate(lockOrBurnIn.originalSender);
    // burning the tokens
    IRebaseToken(address(i_token)).burn(lockOrBurnIn.amount);
    // preparing data 
    lockOrBurnOut = Pool.LockOrBurnOutV1 ({
      destTokenAddress : getRemoteToken(lockOrBurnIn.remoteChainSelector),
      destPoolData : abi.encode(userInterest)
    });
   
  }

  function releaseOrMint(
    Pool.ReleaseOrMintInV1 calldata releaseOrMintIn
  ) external returns (Pool.ReleaseOrMintOutV1 memory releaseOrMintOut)
  {
    _validateReleaseOrMint(releaseOrMintIn);


  }
}
}

