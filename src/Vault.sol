// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract Vault {
    /**
     * @notice The address of the rebase token
     * @dev This is the address of the rebase token
     * @dev This is set in the constructor
     * @dev This is immutable
     */
    IRebaseToken private immutable i_rebaseToken;

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    error Vault__RedeemFailed();
    error Vault__InvalidAmount();
    error Vault__NotEnoughBalance();

    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    receive() external payable {}

    /**
     * @notice Deposit ether into the vault
     * @dev This function mints the rebase token to the user
     * @dev This function emits a Deposit event
     */
    function deposit() external payable {
        uint256 _amount = msg.value;
        if (_amount == 0) {
            revert Vault__InvalidAmount();
        }
        if (_amount == type(uint256).max) {
            _amount = i_rebaseToken.principalBalanceOf(msg.sender);
        }

        // Mint rebase tokens to the user with the current interest rate
        i_rebaseToken.mint(msg.sender, _amount, i_rebaseToken.getInterestRate());
        emit Deposit(msg.sender, _amount);
    }

    /**
     * @notice Redeem rebase tokens for ether
     * @param _amount The amount of tokens to redeem
     * @dev This function burns the rebase tokens from the user and sends them ether
     * @dev This function emits a Redeem event
     */
    function redeem(uint256 _amount) external {
        if (_amount == 0) {
            revert Vault__InvalidAmount();
        }

        uint256 userPrincipalBalance = i_rebaseToken.principalBalanceOf(msg.sender);
        
        if (_amount == type(uint256).max) {
            _amount = userPrincipalBalance;
        }

        if (_amount > userPrincipalBalance) {
            revert Vault__NotEnoughBalance();
        }

        // Burn the tokens first
        i_rebaseToken.burn(msg.sender, _amount);

        // Then transfer ETH to the user
        (bool success,) = msg.sender.call{value: _amount}("");
        if (!success) {
            revert Vault__RedeemFailed();
        }

        emit Redeem(msg.sender, _amount);
    }

    /**
     * @notice Get the address of the rebase token
     * @return The address of the rebase token
     */
    function getRebaseTokenAddress() external view returns (address) {
        return address(i_rebaseToken);
    }
}