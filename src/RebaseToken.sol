// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title RebaseToken
 * @author Anjitech
 * @notice This is a cross-chain token that can be used to rebase token that incentivises users to deposit into a vault
 * @notice The interest rate in the smart contract can only decrease
 * @notice Each user will only their own interest rate that is global interest rate that is global interest rate
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
    error RebaseToken_InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);

    uint256 private constant PRECISION_FACTOR = 1e27;
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    uint256 private s_interestRate = (5 * PRECISION_FACTOR) / 1e8;
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimeStamp;

    event InterestRateChanged(uint256 newInterestRate);
    event InterestRateSet(uint256 newInterestRate);

    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender) {}

    /**
     * @notice Grant the mint and burn role to an account
     * @param _account The account to grant the mint and burn role to
     * @notice Only the owner of the contract can grant the mint and burn role
     */
    function grantMintAndBurnableRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    /**
     *
     * @param _newInterestRate The new interest rate
     * @notice Set the interest rate for the token
     * @notice The interest rate can only decrease
     * @notice Only the owner of the contract can set the interest rate
     */

    
    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        // check if the new interest rate is less than the current interest rate
        if (_newInterestRate < s_interestRate) {
            revert RebaseToken_InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }

    /**
     * @notice Get the principle balance of a user
     * @param _user The address of the user
     */
    function principleBalanceOf(address _user) public view returns (uint256) {
        return super.balanceOf(_user);
    }

    function mint(address _to, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
      
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    function balanceOf(address _user) public view override returns (uint256) {
        uint256 principalBalance = super.balanceOf(_user);
        uint256 accumulatedInterest = _calculateUserAccumulatedInterestSinceLastUpdate(_user);
        return principalBalance * accumulatedInterest / PRECISION_FACTOR;
    }
    /**
     * @notice Transfer tokens from one address to another
     * @param _receipt The address to transfer the tokens to
     * @param _amount The amount of tokens to transfer
     * @return bool
     */

    function transfer(address _receipt, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_receipt);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }

        if (balanceOf(_receipt) == 0) {
            s_userInterestRate[_receipt] = s_interestRate;
        }
        return super.transfer(_receipt, _amount);
    }
    /**
     * @notice Transfer tokens from one address to another
     * @param _sender The address sending the tokens
     * @param _receipt The address to transfer the tokens to
     * @param _amount The amount of tokens to transfer
     */

    function transferFrom(address _sender, address _receipt, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(_sender);
        _mintAccruedInterest(_receipt);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }

        if (balanceOf(_receipt) == 0) {
            s_userInterestRate[_receipt] = s_interestRate;
        }
        return super.transferFrom(_sender, _receipt, _amount);
    }
    /**
     * @notice Calculate the user's accumulated interest since the last update
     * @param _user The address of the user
     */

    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user)
        internal
        view
        returns (uint256 linearInterest)
    {
        uint256 timeDifference = block.timestamp - s_userLastUpdatedTimeStamp[_user];
        // represents the linear growth over time = 1 + (interest rate * time)
        linearInterest = (s_userInterestRate[_user] * timeDifference) + PRECISION_FACTOR;
    }

    function _mintAccruedInterest(address _user) internal {
        // Get the user's previous principal balance. The amount of tokens they had last time their interest was minted to them.
        uint256 previousPrincipalBalance = super.balanceOf(_user);

        // Calculate the accrued interest since the last accumulation
        // `balanceOf` uses the user's interest rate and the time since their last update to get the updated balance
        uint256 currentBalance = balanceOf(_user);
        uint256 balanceIncrease = currentBalance - previousPrincipalBalance;

        // Mint an amount of tokens equivalent to the interest accrued
        _mint(_user, balanceIncrease);
        // Update the user's last updated timestamp to reflect this most recent time their interest was minted to them.
        s_userLastUpdatedTimeStamp[_user] = block.timestamp;
    }

    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }

    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }
}
