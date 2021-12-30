// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockReward is ERC20 {
    constructor() ERC20("MockReward", "MR") {}

    function decimals() public pure override returns (uint8) {
        return 0;
    }

    function mint(uint256 amount) public {
        _mint(msg.sender, amount);
    }
}
