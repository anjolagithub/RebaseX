// SPDX-License-Identifier: SEE LICENSE IN LICENSE

pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title RebaseToken
 * @author Anjitech
 * @notice This is a cross-chain token that can be used to rebase token that incentivises users to deposit into a vault
 * @notice The interest rate in the smart contract can only decrease
 * @notice Each user will only their own interest rate that is global interest rate that is global interest rate
 */

contract RebaseToken is ERC20 {

    error RebaseToken_InterestRatCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);

    uint256 private s_interestRate = 5e10;
    mapping(address => uint256) private s_userInterestRate;
    mapping (address => uint256) private s_userLastUpdatedTimeStamp;

    event InterestRateChanged(uint256 newInterestRate);

    constructor() ERC20("Rebase Token", "RBT") {}

    function setInterestRate(uint256 _newInterestRate) public {

        if (_newInterestRate < s_interestRate) {
           rveert RebaseToken_InterestRatCanOnlyDecrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }



    function mint(address _to, uint256 _amount) external{
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external {
        if(_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        _mintAccruedInterest(_from);
        _burn(_from, _amount)
    }

    function balanceOf(address _user) public view override returns (uint256) {
        uint256 _interest = balanceOf(_user) * s_userInterestRate[_user] / 1e18;
        // multiply the principle balance by the that has accumulated since the last update

        return super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdate(_user);
    }

    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user) internal view returns (uint256) {
        uint256 _timeElapsed = block.timestamp - s_userLastUpdatedTimeStamp[_user];
        return balanceOf(_user) * s_userInterestRate[_user] * _timeElapsed / 1e18;
    } 


    function _mintAccruedInterest(address _user) internal view returns {
        uint256 _interest = balanceOf(_user) * s_userInterestRate[_user] / 1e18;
        _mint(_user, _interest);

        s_userLastUpdatedTimeStamp[_user] = block.timestamp;

       // (principal amount) + principal amount * user interest rate * time elapsed

        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimeStamp[_user];  
        linearInterest = 1 + (s_userInterestRate[_user] * timeElapsed);
    }


    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }
}