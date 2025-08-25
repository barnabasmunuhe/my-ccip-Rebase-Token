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

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// ===== Errors =====

error RebaseToken_InterestCanOnlyDecrease(uint256 oldRate, uint256 newRate);

/**
 * @author  .Barnabas Mwangi 
 * @title   .Rebase Token
 * @notice This is a cross-chain rebase token that incentivises users to deposit into a vault and gain interest in rewards
 * @notice The interest rate in the smart contract can only decrease 
 * @notice Each user will have their own interest rate that is the global interest rate at time of depositing.
 */

contract RebaseToken is ERC20{
    constructor() ERC20("Rebase Token", "RBT")  {
        
    }

    // ===== Storage Variables =====
    uint256 private constant PRECISION_FACTOR = 1e18;
    uint256 private s_interestRate = 5e10; // The global interest rate for the token
    mapping(address => uint256) private s_userInterestRate;// for tracking user's interest rate
    mapping(address => uint256) private s_UserLastUpdatedTimestamp; // tracks the user's timestamps

    // ===== Events =====
    event InterestRateSet(uint256 _newInterestRate);

    function setInterestRate(uint256 _newInterestRate) external {
        if (_newInterestRate > s_interestRate) {
            revert RebaseToken_InterestCanOnlyDecrease(s_interestRate, _newInterestRate);
        }

        emit InterestRateSet(_newInterestRate);
    }

    /**
     * @notice  .function is called by the user
     * @dev     .we call the _mintAccruedInterst function to track the interest of the user
     * @param   to  .
     * @param   amount  .
     */
    function mint(address to, uint256 amount) external {
        _mintAccruedInterest(to);// this function checks if the user had minted before and the interest minted
        s_userInterestRate[to] = s_interestRate;// before the user calls the mint function the interest rate shld match the contract's interest rate.
        _mint(to, amount);// calling _mint function from ERC20

    }

    function _mintAccruedInterest(address to) internal {
        s_UserLastUpdatedTimestamp[to] = block.timestamp;
    }


    /**
     * @notice  .will calculate the principal balance of the  user accumulated since the last timestamp(the actual tokens minted to the user)
     * @dev     .principle amount ( principle amount * interest rate * timeElapsed) same as
     * principle amount (1(PRECISION_FACTOR) + (userInterest * timeElapsed))
     * @param   _user  .
     * @return  uint256  .
     */
    function balanceOf (address _user) public view override returns (uint256){
        return super.balanceOf(_user) * calculateAccumulatedUserInterestSinceLastUpdate(_user);
    }

    /**
     * @notice  .We need to calculate the user's accumulated interest since the last update
     * @dev     .
     * @param   _user  .
     * @return  linearInterest The user's accumulated linear interest since the last update.
     */
    function calculateAccumulatedUserInterestSinceLastUpdate(address _user) internal view returns (uint256 linearInterest) {
        // we need the time difference since the last update to current time of update
        // the interest grows linearly with time.(LinearInterest)
        uint256 timeElapsed = block.timestamp - s_UserLastUpdatedTimestamp[_user];
        linearInterest = PRECISION_FACTOR + (s_userInterestRate[_user] * timeElapsed);
    }

    // ===== Getter Functions =====
    /**
     * @notice  .Gets the user's interest rate
     * @dev     .
     * @param   _user  .
     * @return  uint256  .
     */
    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }


}