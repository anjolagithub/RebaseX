// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {console, Test} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";

contract RebaseTokenTest is Test {
    RebaseToken public rebaseToken;
    Vault public vault;

    address public user = makeAddr("user");
    address public owner = makeAddr("owner");
    uint256 public SEND_VALUE = 1e5;

    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");

    function addRewardsToVault(uint256 amount) public {
        (bool success,) = payable(address(vault)).call{value: amount}("");
        require(success, "Failed to send rewards");
    }

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        
        console.log("Owner address:", owner);
        console.log("RebaseToken address:", address(rebaseToken));
        console.log("Vault address:", address(vault));
        
        rebaseToken.grantMintAndBurnRole(address(vault));
        bool hasRole = rebaseToken.hasRole(MINT_AND_BURN_ROLE, address(vault));
        console.log("Vault has mint and burn role:", hasRole);
        
        vm.stopPrank();
    }

    function testRoleSetup() public {
        bool hasMintAndBurnRole = rebaseToken.hasRole(MINT_AND_BURN_ROLE, address(vault));
        assertTrue(hasMintAndBurnRole, "Vault should have mint and burn role");
    }

    function testDebugMint() public {
        console.log("=== Debug Mint Test ===");
        uint256 testAmount = 1000;
        uint256 currentInterestRate = rebaseToken.getInterestRate();
        
        vm.startPrank(owner);
        vm.expectRevert();
        rebaseToken.mint(user, testAmount, currentInterestRate);
        vm.stopPrank();
        
        vm.startPrank(address(vault));
        rebaseToken.mint(user, testAmount, currentInterestRate);
        uint256 balance = rebaseToken.balanceOf(user);
        assertEq(balance, testAmount);
        vm.stopPrank();
    }

    function testDepositLinear(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        console.log("Bounded amount:", amount);
        
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        
        uint256 startBalance = rebaseToken.balanceOf(user);
        assertEq(startBalance, amount);
        
        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebaseToken.balanceOf(user);
        assertGt(middleBalance, startBalance);
        
        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebaseToken.balanceOf(user);
        assertGt(endBalance, middleBalance);
        
        assertApproxEqAbs(endBalance - middleBalance, middleBalance - startBalance, 1);
        vm.stopPrank();
    }

    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        vault.redeem(amount);
        uint256 balance = rebaseToken.balanceOf(user);
        assertEq(balance, 0);
        vm.stopPrank();
    }

    function testRedeemAfterTimeHasPassed(uint256 depositAmount, uint256 time) public {
    time = bound(time, 1000, type(uint96).max);
    depositAmount = bound(depositAmount, 1e5, type(uint96).max);
    console.log("Deposit amount:", depositAmount);
    console.log("Time to warp:", time);

    // Deposit funds
    vm.deal(user, depositAmount);
    vm.prank(user);
    vault.deposit{value: depositAmount}();

    // Get initial principal balance
    uint256 initialPrincipalBalance = rebaseToken.principalBalanceOf(user);
    console.log("Initial principal balance:", initialPrincipalBalance);

    // Warp time and check new balance
    vm.warp(block.timestamp + time);
    uint256 balanceAfterTimePass = rebaseToken.balanceOf(user);
    console.log("Balance after time pass:", balanceAfterTimePass);

    // Only try to redeem the principal amount
    vm.prank(user);
    vault.redeem(initialPrincipalBalance);

    assertEq(address(user).balance, initialPrincipalBalance);
    assertGt(rebaseToken.balanceOf(user), 0, "Should still have interest tokens");
}

    function testCannotCallMint() public {
        vm.startPrank(user);
        uint256 interestRate = rebaseToken.getInterestRate();
        vm.expectRevert();
        rebaseToken.mint(user, SEND_VALUE, interestRate);
        vm.stopPrank();
    }

    function testCannotCallBurn() public {
        vm.startPrank(user);
        vm.expectRevert();
        rebaseToken.burn(user, SEND_VALUE);
        vm.stopPrank();
    }

    function testCannotWithdrawMoreThanBalance() public {
        vm.startPrank(user);
        vm.deal(user, SEND_VALUE);
        vault.deposit{value: SEND_VALUE}();
        vm.expectRevert();
        vault.redeem(SEND_VALUE + 1);
        vm.stopPrank();
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5 + 1e3, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e3);

        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();

        address userTwo = makeAddr("userTwo");
        uint256 userBalance = rebaseToken.balanceOf(user);
        uint256 userTwoBalance = rebaseToken.balanceOf(userTwo);
        assertEq(userBalance, amount);
        assertEq(userTwoBalance, 0);

        vm.prank(owner);
        rebaseToken.setInterestRate(4e10);

        vm.prank(user);
        rebaseToken.transfer(userTwo, amountToSend);
        uint256 userBalanceAfterTransfer = rebaseToken.balanceOf(user);
        uint256 userTwoBalancAfterTransfer = rebaseToken.balanceOf(userTwo);
        assertEq(userBalanceAfterTransfer, userBalance - amountToSend);
        assertEq(userTwoBalancAfterTransfer, userTwoBalance + amountToSend);

        vm.warp(block.timestamp + 1 days);
        uint256 userBalanceAfterWarp = rebaseToken.balanceOf(user);
        uint256 userTwoBalanceAfterWarp = rebaseToken.balanceOf(userTwo);

        uint256 userTwoInterestRate = rebaseToken.getUserInterestRate(userTwo);
        assertEq(userTwoInterestRate, 5e10);

        uint256 userInterestRate = rebaseToken.getUserInterestRate(user);
        assertEq(userInterestRate, 5e10);

        assertGt(userBalanceAfterWarp, userBalanceAfterTransfer);
        assertGt(userTwoBalanceAfterWarp, userTwoBalancAfterTransfer);
    }

    function testSetInterestRate(uint256 newInterestRate) public {
        newInterestRate = bound(newInterestRate, 0, rebaseToken.getInterestRate() - 1);
        
        vm.startPrank(owner);
        rebaseToken.setInterestRate(newInterestRate);
        uint256 interestRate = rebaseToken.getInterestRate();
        assertEq(interestRate, newInterestRate);
        vm.stopPrank();

        vm.startPrank(user);
        vm.deal(user, SEND_VALUE);
        vault.deposit{value: SEND_VALUE}();
        uint256 userInterestRate = rebaseToken.getUserInterestRate(user);
        vm.stopPrank();
        assertEq(userInterestRate, newInterestRate);
    }

    function testCannotSetInterestRate(uint256 newInterestRate) public {
        vm.startPrank(user);
        vm.expectRevert();
        rebaseToken.setInterestRate(newInterestRate);
        vm.stopPrank();
    }

    function testInterestRateCanOnlyDecrease(uint256 newInterestRate) public {
    uint256 initialInterestRate = rebaseToken.getInterestRate();
    // Bound newInterestRate to be larger than initial rate
    newInterestRate = bound(newInterestRate, initialInterestRate, type(uint96).max);
    console.log("Current interest rate:", initialInterestRate);
    console.log("New interest rate:", newInterestRate);
    
    vm.prank(owner);
    vm.expectRevert(
        abi.encodeWithSelector(
            RebaseToken.RebaseToken__InterestRateCanOnlyDecrease.selector,
            initialInterestRate,
            newInterestRate
        )
    );
    rebaseToken.setInterestRate(newInterestRate);
    assertEq(rebaseToken.getInterestRate(), initialInterestRate);
}
    function testGetPrincipleAmount() public {
        uint256 amount = 1e5;
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();
        uint256 principleAmount = rebaseToken.principalBalanceOf(user);
        assertEq(principleAmount, amount);

        vm.warp(block.timestamp + 1 days);
        uint256 principleAmountAfterWarp = rebaseToken.principalBalanceOf(user);
        assertEq(principleAmountAfterWarp, amount);
    }
}