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

    error Vault__RedeemFailed();







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
    if (_amount == type(uint256).max) {
        _amount = i_rebaseToken.principleBalanceOf(msg.sender);
    }
    //we need to mint the rebase token to the user

    i_rebaseToken.mint(msg.sender, msg.value);
    emit Deposit(msg.sender, msg.value);
}
 
function redeem(uint256 _amount) external {
      if (_amount == type(uint256).max) {
            _amount = i_rebaseToken.principleBalanceOf(msg.sender);
        }
    /**
     * burn the tokens from the user
     
     * transfer the amount to the user
     */
    i_rebaseToken.burn(msg.sender, _amount);
   (bool success, ) = msg.sender.call{value: _amount}("");
   if (!success) {
       revert Vault__RedeemFailed();
    }

}

/**
 * @notice Get the address of the rebase token
 * @return The address of the rebase token
 */
function getRebaseTokenAddress() external view returns (address) {
    return address (i_rebaseToken);

}



}