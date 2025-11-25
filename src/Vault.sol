// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier:MIT

pragma solidity 0.8.24;

// ===== Imports =====
import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

// ===== Errors =====
error Vault__RedeemFailed();

/**
 * @author  . Barnabas Milton
 * @title   . vault contract
 * @dev     . Only the owner can access the redeem function
 * @notice  . This is a vault contract
 */
contract Vault {
    // ===== State Variables =====
    IRebaseToken private i_rebaseToken;

    // ===== Events =====
    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    // 1. Have to pass the token address to our vault's constructor
    // 2. we will have a deposit function that mints token to the user
    // 3. A redeem function to burn tokens from the user
    // 4. A way to receive rewards into the vault
    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    // ===== External Functions =====
    /**
     * @notice  . Mints user's deposit into tokens
     * @dev     . This function allows users to deposit ETH and receive tokens in return.
     */
    function deposit() external payable {
        // we will mint user's deposit into tokens
        uint256 interestRate = i_rebaseToken.getGlobalInterestRate();
        i_rebaseToken.mint(msg.sender, msg.value, interestRate);
        // emitting a deposit event
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice  . Burns user's tokens and redeems them for ETH
     * @dev     . This function allows users to redeem their tokens for ETH.
     * @param   _amount  The amount of tokens to redeem.
     */
    function redeem(uint256 _amount) external {
        if (_amount == type(uint96).max) {
            //this solves problem token dust(leftover tokens that can accumulate when user withdraws  and burn their entire balance )
            _amount = i_rebaseToken.balanceOf(msg.sender);
        }
        // Burn tokens from the user
        i_rebaseToken.burn(msg.sender, _amount);
        // sending the user ETH
        (bool success,) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault__RedeemFailed();
        }
        // emitting a redeem event
        emit Redeem(msg.sender, _amount);
    }

    // ===== Receive Function =====
    receive() external payable {} // now we can receive rewards into the vault

    // ===== Getter Functions =====
    /**
     * @notice  . Gets the rebase token address
     * @dev     . This function returns the address of the rebase token contract.
     * @return  address  The address of the rebase token contract.
     */
    function getRebaseTokenAddress() external view returns (address) {
        return address(i_rebaseToken);
    }
}
