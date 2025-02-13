// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

interface IRebaseToken {
    function mint(address _to, uint256 _amount, uint256 _userInterestRate) external;
    function burn(address _from, uint256 _amount) external;
    function setInterestRate(uint256 _newInterestRate) external;
    function principalBalanceOf(address _user) external view returns (uint256);
    function getInterestRate() external view returns (uint256);
    function getUserInterestRate(address _user) external view returns (uint256);
    function hasRole(bytes32 role, address account) external view returns (bool);
    function grantMintAndBurnRole(address _address) external;

    event InterestRateSet(uint256 newInterestRate);
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
}