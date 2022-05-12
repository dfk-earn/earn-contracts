// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockJewel is ERC20 {
    constructor() ERC20("MockJewel", "MJ") {}

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function mint(address _account, uint256 _amount) public {
        _mint(_account, _amount);
    }
}
