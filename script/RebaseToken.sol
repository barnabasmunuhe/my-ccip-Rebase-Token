// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ===== Layout of Contract: =====
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

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// ====== Errors ======
error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);

/**
 * @title RebaseToken
 * @author Barnabas Milton
 * @notice This is a cross-chain rebase token that incentivises users to deposit into a vault and gain interest in rewards
 * @notice The interest rate in the smart contract can only decrease
 * @notice Each user will have their own interest rate that is the global interest rate at time of depositing.
 */
contract RebaseToken is ERC20 {
    // ====== State Variables ======
    uint256 private constant PRECISION_FACTOR = 1e18;
    uint256 private s_interestRate = 5e10; // The interest rate for the token, can only decrease
    mapping(address => uint256) private s_userInterestRates;
    mapping(address => uint256) s_UserLastUpdatedTimestamp;

    // ====== Events ======
    event InterestRateReset(uint256 _newInterestRate);

    constructor() ERC20("Rebase Token", "RBT") {}

    function setInterestRate(uint256 _newInterestRate) external {
        // set the interest rate for the token
        if (_newInterestRate > s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;
        emit InterestRateReset(_newInterestRate);
    }

    /**
     * @notice  .This mint function will be called by the user to mint tokens when deposited to the vault
     * @dev     .
     * @param   _to  .
     * @param   _amount  .
     */
    function mint(address _to, uint256 _amount) external {
        _mintAccruedInterest(_to);
        _mint(_to, _amount); // calling the _mint function from the ERC20 contract

        s_userInterestRates[_to] = s_interestRate; // setting the the user's interest rate to match the contract's interest rate.at the time they call the mint function
    }

    /**
     * @notice  .Burn user tokens when they withdraw from the vault
     * @dev     .
     * @param   _from  .
     * @param   _amount  .
     */
    function burn(address _from, uint256 _amount) external{
        if (_amount == type (uint256).max) {//this solves problem token dust(leftover tokens that can accumulate when user withdraws  and burn their entire balance )
            _amount = balanceOf(_from);
        }
        _mintAccruedInterest(_from);
        _burn(_from,_amount);
    }

    /**
     * @notice  .This function will find the balance of rebase tokens minted to the user,(Principal balance)
     * @notice  .It will also calculate current balance including any interests(BalanceOf).
     * @dev     .This function will only calculate the interest earned and mint it.
     * @notice  . Will also set the last updated timestamp
     * @param   _user  .
     */
    function _mintAccruedInterest(address _user) internal {
        // 1.Find the current balance of rebase tokens that have been minted to the user -> PRINCIPLE BALANCE
        uint256 previousPrincipleBalance = super.balanceOf(_user);
        // 2.Calculate current balance including any interests
        uint256 currentBalance = balanceOf(_user);
        // 3.calculate no of tokens that need to be minted to the user(2-1)
        uint256 balanceIncrease = currentBalance - previousPrincipleBalance;
        // set user's last updated timestamp
        s_UserLastUpdatedTimestamp[_user] = block.timestamp;
        // call _mint function from ERC20 to mint the tokens to the user
        _mint(_user,balanceIncrease);
    }

    /**
     * @notice  .We will get the current principle balance
     * of the user(number of tokens that have actually been minted to the user)
     * @notice  .we will multiply principle balance * interest accumulated since the last update
     * @dev     .This function will calculate the balance of the user including interest
     * accumulated since the last update.(principle balance + some interest accrued)
     * @param   _user  .
     * @return  uint256  .
     */
    function balanceOf(address _user) public view override returns (uint256) {
        return super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdate(_user) / PRECISION_FACTOR; // This balances the limit of precision inthe equation
            // making the units the same
    }

    /**
     * @notice  .Calculate the interest accumulated since last update
     * @dev     .
     * @param   _user  .
     * @return  linearInterest  .
     */
    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user)
        internal
        view
        returns (uint256 linearInterest)
    {
        // we need to calculate interest accumulated since last update
        // This is going to be linear growth in time.
        // 1. calculate the time since the last update
        // 2. calculate amount of linear growth
        //  principle amount + (principle amount * user interest * timeElapsed)
        //  the above is same as principle amount * (1 + user interest * timeElapsed)
        uint256 timeElapsed = block.timestamp - s_UserLastUpdatedTimestamp[_user];
        linearInterest = PRECISION_FACTOR + (s_userInterestRates[_user] * timeElapsed);
    }

    // ===== Getter Functions =====
    /**
     * @notice  .Getter function for the User's interest rate
     * @dev     .It's from the mapping in the storage variables section
     * @param   _user  .
     * @return  uint256  .
     */
    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRates[_user];
    }
}
