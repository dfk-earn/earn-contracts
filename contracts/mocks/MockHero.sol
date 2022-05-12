// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract MockHero is ERC721Enumerable {
    using Counters for Counters.Counter;
    Counters.Counter private counter;

    constructor() ERC721("MockHero", "MHR") {}

    function mint(address _account, uint256 _amount) public {
        for (uint256 i = 0; i < _amount; i++) {
            counter.increment();
            _mint(_account, counter.current());
        }
    }
}
