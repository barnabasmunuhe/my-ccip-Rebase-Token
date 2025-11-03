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

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

// ===== Errors =====

error RebaseToken__InterestCanOnlyDecrease(uint256 oldRate, uint256 newRate);

/**
 * @author  .Barnabas Mwangi
 * @title   .Rebase Token
 * @notice This is a cross-chain rebase token that incentivises users to deposit into a vault and gain interest in rewards
 * @notice The interest rate in the smart contract can only decrease
 * @notice Each user will have their own interest rate that is the global interest rate at time of depositing.
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender) {}

    // ===== Storage Variables =====
    bytes32 public constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    uint256 private constant PRECISION_FACTOR = 1e18; // to maintain precision for interest calculations
    uint256 private s_interestRate = (5 * PRECISION_FACTOR) / 1e8; // The global interest rate for the token
    mapping(address => uint256) private s_userInterestRate; // for tracking user's interest rate
    mapping(address => uint256) private s_UserLastUpdatedTimestamp; // tracks the user's timestamps

    // ===== Events =====
    event InterestRateSet(uint256 _newInterestRate);

    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        if (_newInterestRate > s_interestRate) {
            revert RebaseToken__InterestCanOnlyDecrease(s_interestRate, _newInterestRate);
        }

        emit InterestRateSet(_newInterestRate);
    }

    function grantMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    /**
     * @notice  .function is called by the user
     * @dev     .we call the _mintAccruedInterst function to track the interest of the user
     * @param   to  .
     * @param   amount  .
     */
    function mint(address to, uint256 amount, uint256 _userInterestRate) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(to); // this function checks if the user had minted before and the interest minted
        s_userInterestRate[to] = _userInterestRate; // record the user's interest rate at time of minting
        _mint(to, amount); // calling _mint function from ERC20
    }

    /**
     * @notice Burns a user's tokens, updating their balance by minting accrued interest first.
     *         If `_amount` is set to `type(uint256).max`, the user's entire balance is burned,
     *         which prevents leaving behind small "dust" amounts.
     * @dev This function ensures accrued interest is minted before burning.
     *      It also provides a deflationary mechanism since burning decreases total supply.
     * @param _from   The address whose tokens will be burned.
     * @param _amount The number of tokens to burn. Use `type(uint256).max` to burn the full balance.
     */
    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_from); // bring balance up to date before burning
        _burn(_from, _amount); // ERC20 _burn reduces supply
    }

    /**
     * @notice Transfers tokens from the caller to a recipient, while keeping balances up-to-date
     *         by minting any accrued interest for both parties.
     *         If `_amount` is set to `type(uint256).max`, the caller's entire balance is transferred,
     *         which prevents leaving behind small "dust" amounts.
     * @dev In addition to standard ERC20 transfer behavior:
     *      - Accrued interest is minted for both sender and recipient before transfer.
     *      - If the recipient had a zero balance prior to this transfer, their interest rate
     *        is initialized to match the sender's rate.
     * @param _recipient The address that will receive the tokens.
     * @param _amount    The number of tokens to transfer. Use `type(uint256).max` to transfer the full balance.
     * @return true   True if the transfer succeeded.
     */
    function transfer(address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(msg.sender); // update sender's balance before transfer
        _mintAccruedInterest(_recipient); // update recipient's balance before transfer
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender); // send full balance if "max" flag is passed
        }
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender]; // inherit interest rate
        }
        return super.transfer(_recipient, _amount);
    }

    /**
     * @notice Transfers tokens from `sender` to `recipient` using the allowance mechanism,
     *         while minting any accrued interest for both accounts.
     *         If `amount` is set to `type(uint256).max`, the sender's entire balance is transferred,
     *         preventing leftover "dust" tokens.
     * @dev In addition to the standard ERC20 `transferFrom`:
     *      - Accrued interest is minted for both sender and recipient before transfer.
     *      - If the recipient had a zero balance prior to this transfer, their interest rate
     *        is initialized to match the sender's rate.
     * @param _sender    The address from which tokens will be debited.
     * @param _recipient The address that will receive the tokens.
     * @param _amount    The number of tokens to transfer. Use `type(uint256).max` to transfer the full balance.
     * @return true  True if the transfer succeeded.
     */
    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(msg.sender); // update sender's balance before transfer
        _mintAccruedInterest(_recipient); // update recipient's balance before transfer
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender); // send full balance if "max" flag is passed
        }
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender]; // inherit interest rate
        }
        return super.transferFrom(_sender, _recipient, _amount);
    }

    /**
     * @notice  .here we mint the accrued interest to the user before they mint again
     * @notice  .if the user has never minted before we set the timestamp to current block timestamp
     * @notice  .we find the previous principle balance.(by super.balanceOf)
     * @notice  .we find the current balance with interest(by balanceOf)
     * @notice  .the interest to be minted is the difference between the two(BALANCE INCREASE)
     * @notice  .we mint the interest to the user by calling the _mint function from ERC20
     * @notice  .set the user last updated timestamp
     * @dev     .
     * @param   _user  .
     */
    function _mintAccruedInterest(address _user) internal {
        // if the user has never minted before we set the timestamp to current block timestamp
        // first we'll find the previous principle balance
        uint256 PreviousPrincipleBalance = super.balanceOf(_user);
        // then the current balance with interest
        uint256 CurrentBalanceWithInterest = balanceOf(_user);
        // the interest to be minted is the difference between the two(BALANCE INCREASE)
        uint256 balanceIncerase = CurrentBalanceWithInterest - PreviousPrincipleBalance;
        // mint the interest to the user by calling the _mint function from ERC20
        _mint(_user, balanceIncerase);
        // set the user last updated timestamp
        s_UserLastUpdatedTimestamp[_user] = block.timestamp;
    }

    /**
     * @notice  .will calculate the principal balance of the  user accumulated since the last timestamp(the actual tokens minted to the user)
     * @dev     .principle amount ( principle amount * interest rate * timeElapsed) same as
     * principle amount (1(PRECISION_FACTOR) + (userInterest * timeElapsed))
     * @param   _user  .
     * @return  uint256  .
     */
    function balanceOf(address _user) public view override returns (uint256) {
        return super.balanceOf(_user) * calculateAccumulatedUserInterestSinceLastUpdate(_user) / PRECISION_FACTOR;
    }

    /**
     * @notice  .We need to calculate the user's accumulated interest since the last update
     * @dev     .
     * @param   _user  .
     * @return  linearInterest The user's accumulated linear interest since the last update.
     */
    function calculateAccumulatedUserInterestSinceLastUpdate(address _user)
        internal
        view
        returns (uint256 linearInterest)
    {
        // we need the time difference since the last update to current time of update
        // the interest grows linearly with time.(LinearInterest)
        uint256 timeElapsed = block.timestamp - s_UserLastUpdatedTimestamp[_user];
        // here we will use simple interest Growth Factor formula
        // 1+ (userInterestRate * timeElapsed)
        // we add PRECISION_FACTOR to maintain precision
        linearInterest = PRECISION_FACTOR + (s_userInterestRate[_user] * timeElapsed); //without the 1 you'd get only the interest without the principle baseline
    }

    /**
     * @notice  .Gets the user's principal balance (excluding accrued interest).
     * @dev     .This function returns the raw balance without interest calculations.
     * @param   _user  .
     * @return  uint256  .
     */
    function principleBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
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

    /**
     * @notice  .gets global interest rate
     * @dev     .which is 5e18
     * @return  uint256  .
     */
    function getGlobalInterestRate() external view returns (uint256) {
        return s_interestRate;
    }
}
