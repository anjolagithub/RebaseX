// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;



interface IRebaseToken {
    function mint(address _to, uint256 _amount) external;
    function burn(address _from, uint256 _amount) external;
    function setInterestRate(uint256 _newInterestRate) external;
    function principleBalanceOf(address _user) external view returns (uint256);
    function getInterestRate() external view returns (uint256);
    function getInterestRateOfUser(address _user) external view returns (uint256);
    function getInterestRateLastUpdatedTimeStamp(address _user) external view returns (uint256);

    event InterestRateChanged(uint256 newInterestRate);
    event InterestRateSet(uint256 newInterestRate);
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
}