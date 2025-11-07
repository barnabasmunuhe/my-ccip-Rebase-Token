// SPDX-License-Identifier:MIT

pragma solidity ^0.8.24;

// ===== Imports =====
import {Test} from "forge-std/Test.sol";
import {RebaseToken} from "../src/my-rebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/Interfaces/IRebaseToken.sol";
import {Ownable} from "@openzeppelin-contracts/contracts/access/Ownable.sol";
import {IAccessControl} from "@openzeppelin-contracts/contracts/access/IAccessControl.sol";
import {RebaseToken__InterestCanOnlyDecrease} from "../src/my-rebaseToken.sol";

contract RebaseTokenTest is Test {
    // ===== State Variables =====
    RebaseToken private rebaseToken;
    Vault private vault;

    // ===== Direct Access Addresses =====
    address private owner = makeAddr("owner");
    address private user = makeAddr("user");

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        // giving the test contract mint and burn role
        rebaseToken.grantMintAndBurnRole(address(vault));
        vm.stopPrank();
    }

    function addRewardsToVault(uint256 rewardAmount) public {
        (bool success,) = payable(address(vault)).call{value: rewardAmount}(""); // sending some ETH to the vault
    }

    function testDeposit(uint256 amount) public {
        amount = uint96(bound(amount, 1e5, type(uint96).max));
        vm.startPrank(user);
        vm.deal(user, amount); // giving some ETH to the user
        // 1. Deposit
        vault.deposit{value: amount}();
        // 2. Check rebaseToken balance
        uint256 startBalance = rebaseToken.balanceOf(user);
        // checking if startBalance = amount
        assertEq(startBalance, amount);
        // 3. Warp the time and check the balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebaseToken.balanceOf(user);
        // checking if middleBalance > startBalance
        assertGt(middleBalance, startBalance);
        // 4. Warp the time again and check the balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebaseToken.balanceOf(user);
        // checking if endBalance > middleBalance
        assertGt(endBalance, middleBalance);
        // checking the growth amount between the balance intervals is roughly the same
        assertApproxEqAbs(middleBalance - startBalance, endBalance - middleBalance, 1);
        vm.stopPrank();
    }

    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(user);
        vm.deal(user, amount);
        // 1. deposit
        vault.deposit{value: amount}();
        // check if amount =  balance of user
        assertEq(rebaseToken.balanceOf(user), amount);
        // redeem//// we are redeeming everything
        vault.redeem(type(uint256).max);
        // check if the balance of user = 0
        assertEq(rebaseToken.balanceOf(user), 0);
        // check if balance of converted ETH matches amount
        assertEq(address(user).balance, amount);
        vm.stopPrank();
    }

    function testRedeemAfterTimeHasPassed(uint256 depositAmount, uint256 time) public {
        time = bound(time, 1000, type(uint96).max); // a massive crazy number of seconds
        depositAmount = bound(depositAmount, 1e5, type(uint96).max);

        // 1. deposit
        vm.deal(user, depositAmount);
        vm.prank(user);
        vault.deposit{value: depositAmount}();

        // 2. warp time and check balance 
        vm.warp(block.timestamp + time);

        // check balance of token balance after time has passed
        uint256 tokenBalance = rebaseToken.balanceOf(user);

        // adding rewards to the balance in the vault
        // uint256 rewards = tokenBalance-depositAmount;
        vm.deal(owner, tokenBalance - depositAmount);//fakes the existence of yield by crediting the vault’s owner with the ETH needed to cover users’ accrued profits.
        vm.prank(owner); //the owner is the one to call addRewardsToVault function
        addRewardsToVault(tokenBalance - depositAmount);

        // 3. redeem funds
        vm.prank(user);
        vault.redeem(tokenBalance);

        // making sure the user has received ETH back
        uint256 ethBalance = address(user).balance;
        // check if the eth balance is equal to the token balance
        assertEq(ethBalance, tokenBalance);
        // check if the token balance is greater than the initial deposit amount
        assertGt(tokenBalance, depositAmount);
    }

    function testTransferIfUserHadNoTokensInAccount(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5 + 1e5, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5); // here we are making sure the user has enough tokens to send

        // 1.deposit
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();

        // create user2(recipient) address
        address user2 = makeAddr("user2");
        uint256 userBalance = rebaseToken.balanceOf(user);
        uint256 user2Balance = rebaseToken.balanceOf(user2);

        assertEq(userBalance, amount);
        assertEq(user2Balance, 0);

        // 2.transfer
        vm.prank(user);
        rebaseToken.transfer(user2, amountToSend);

        // 3.post-transfer check balances
        assertEq(rebaseToken.balanceOf(user2), user2Balance + amountToSend);
        assertEq(rebaseToken.balanceOf(user), userBalance - amountToSend);
    }

    function testTransferIfReceiverHadNoTokensInAccountAndInterestRateIsChangedByOwner(
        uint256 amount,
        uint256 amountToSend
    ) public {
        amount = bound(amount, 1e5 + 1e5, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5); // here we are making sure the user has enough tokens to send

        // 1.deposit
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();

        // create user2(recipient) address
        address user2 = makeAddr("user2");
        uint256 userBalance = rebaseToken.balanceOf(user);
        uint256 user2Balance = rebaseToken.balanceOf(user2);

        assertEq(userBalance, amount);
        assertEq(user2Balance, 0);
        // the owner changes the interest rate
        vm.prank(owner);
        rebaseToken.setInterestRate(4e10);

        // 2.transfer
        vm.prank(user);
        rebaseToken.transfer(user2, amountToSend);

        // 3.post-transfer check balances
        assertEq(rebaseToken.balanceOf(user2), user2Balance + amountToSend);
        assertEq(rebaseToken.balanceOf(user), userBalance - amountToSend);
    }

    function testCannotSetInterestRate(uint256 newInterestRate) public {
        vm.prank(user);
        vm.expectRevert();
        rebaseToken.setInterestRate(newInterestRate);
    }

    function testCannotSetInterestRateVersion2(uint256 newInterestRate) public {
        vm.prank(user);
        vm.expectPartialRevert(bytes4(Ownable.OwnableUnauthorizedAccount.selector));
        rebaseToken.setInterestRate(newInterestRate);
    }

    function testCannotCallMintAndBurn() public {
        vm.prank(user);
        vm.expectPartialRevert(bytes4(IAccessControl.AccessControlUnauthorizedAccount.selector));
        rebaseToken.mint(user, 100, 4e10);

        vm.prank(user);
        vm.expectPartialRevert(bytes4(IAccessControl.AccessControlUnauthorizedAccount.selector));
        rebaseToken.burn(user, 100);
    }

    function testGetPrincipleAmount(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(user, amount);
        vm.prank(user);

        vault.deposit{value: amount}();
        assertEq(rebaseToken.principleBalanceOf(user), amount);
        // warp the time
        vm.warp(block.timestamp + 1 hours);
        assertEq(rebaseToken.principleBalanceOf(user), amount);
    }

    function testRebaseTokenAddress() public view{
        assertEq(address(rebaseToken), vault.getRebaseTokenAddress());
    }

    function testInterestRateCanOnlyDecrease(uint256 newInterestRate) public {
        uint256 initialInterestRate = rebaseToken.getGlobalInterestRate();
        newInterestRate = bound(newInterestRate, initialInterestRate, type(uint96).max);
        vm.prank(owner);
        vm.expectPartialRevert(bytes4(RebaseToken__InterestCanOnlyDecrease.selector));
        rebaseToken.setInterestRate(newInterestRate);
        assertEq(rebaseToken.getGlobalInterestRate(),initialInterestRate);
    }
}
