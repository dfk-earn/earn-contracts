// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// The Bank is full of rewards and jewels.
// The longer you stay, the more JEWELs you end up with when you leave.
// This contract handles swapping to and from xJewelToken <> JewelToken
contract MockBank is ERC20 {
    IERC20 public govToken;

    // Define the Bank token contract
    constructor(address _govToken) ERC20("xMockJewel", "xMJ") {
        govToken = IERC20(_govToken);
    }

    // Enter the bank. Deposit some JEWELs. Earn some shares.
    // Locks GovernanceToken and mints xGovernanceToken
    function enter(uint256 _amount) public {
        // Gets the amount of GovernanceToken locked in the contract
        uint256 totalGovernanceToken = govToken.balanceOf(address(this));
        // Gets the amount of xGovernanceToken in existence
        uint256 totalShares = totalSupply();
        // If no xGovernanceToken exists, mint it 1:1 to the amount put in
        if (totalShares == 0 || totalGovernanceToken == 0) {
            _mint(msg.sender, _amount);
        }
        // Calculate and mint the amount of xGovernanceToken the GovernanceToken is worth. The ratio will change overtime, as xGovernanceToken is burned/minted and GovernanceToken deposited + gained from fees / withdrawn.
        else {
            uint256 what = _amount * totalShares / totalGovernanceToken;
            _mint(msg.sender, what);
        }
        // Lock the GovernanceToken in the contract
        govToken.transferFrom(msg.sender, address(this), _amount);
    }

    // Leave the bar. Claim back your JEWELs.
    // Unclocks the staked + gained GovernanceToken and burns xGovernanceToken
    function leave(uint256 _share) public {
        // Gets the amount of xGovernanceToken in existence
        uint256 totalShares = totalSupply();
        // Calculates the amount of GovernanceToken the xGovernanceToken is worth
        uint256 what = _share * govToken.balanceOf(address(this)) / totalShares;
        _burn(msg.sender, _share);
        govToken.transfer(msg.sender, what);
    }
}
