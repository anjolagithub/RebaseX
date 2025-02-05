// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";

import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";


contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;

    address public owner = makeAddr ("owner");
    address public user = makeAddr ("user");


    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnableRole(address(vault));
        //(bool success, ) = payable(address(vault)).call{value: 1e18}("");
        vm.stopPrank();



    }

    function addRewardsToVault(uint256 rewardAmount) public {
        (bool success, ) = payable(address(vault)).call{value: rewardAmount}("");
        amount = bound(amount, 1e5, type(uint256).max);
        vm.startPrank(owner);
        rebaseToken.mint(address(vault), amount);
        vm.stopPrank();
    }   

    function testDepositLinear(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint256).max);
        
        //deposit amount into the vault
        vm.startPrank(user);

     //   vm.assume(amount > 1e5);
     //   amount = bound(amount, 1e5, type(uint256).max);
        
        vm.deal(user, amount);
        vault.deposit{value: amount}();

        // check the rebase token balance of the user
        uint256 startBalance = rebaseToken.balanceOf(user);
        console.log("startBalance", startBalance);
        assertEq(startBalance, amount);

        //warp the time by 1 hour and check the balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebaseToken.balanceOf(user);
        assertGt(middleBalance, startBalance);

        //warp the time again by the same amount and check the balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebaseToken.balanceOf(user);
        assertGt(endBalance, middleBalance);


        assertApproxEqAbs(endBalance - middleBalance, middleBalance - startBalance, 1);


        vm.stopPrank();
    }

    function testReedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint256).max);

        //deposit amount into the vault
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.balanceOf(user), amount);

        //redeem the amount from the vault
        vault.redeem(type(uint256).max);
        assertEq(rebaseToken.balanceOf(user), 0);
        assertEq(address(user).balance, amount);
        vm.stopPrank();

    }

    function testReedeemAfterSomeTimePassed(uint256 depositAmount, uint256 time) public {
        time = bound(time, 1000, type(uint256).max);
        depositAmount = bound(depositAmount, 1e5, type(uint256).max);
        

        //deposit amount into the vault
        vm.deal(user, amount);
        vault.deposit{value: depositAmount}();
        assertEq(rebaseToken.balanceOf(user), amount);

        //warp the time by 1 hour
        vm.warp(block.timestamp + time);
        uint256 balanceAfterSomeTime = rebaseToken.balanceOf(user);

        //Add some rewards to the vault
        vm.prank(owner);
        addRewardsToVault(depositAmount - balanceAfterSomeTime);

        //redeem the amount from the vault
        vm.prank(user);
        vault.redeem(type(uint256).max);
        vm.stopPrank();

        uint256 ethBalance = address(user).balance;
        assertEq(ethBalance, balance);
        assertGt(ethBalance, depositAmount);

        //warp the time by 1 hour
        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebaseToken.balanceOf(user);
        assertGt(middleBalance, startBalance);

        //redeem the amount from the vault
        vault.redeem(type(uint256).max);
        assertEq(rebaseToken.balanceOf(user), 0);
        assertEq(address(user).balance, amount * 2);

        vm.stopPrank();

    }


}
