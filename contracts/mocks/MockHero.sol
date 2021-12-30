// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract MockHero is ERC721Enumerable {
    using Counters for Counters.Counter;
    Counters.Counter private heroIds;

    constructor() ERC721("MockHero", "MHR") {}

    function mint()
        public
        returns (uint256)
    {
        uint256 newHeroId = heroIds.current();
        _mint(msg.sender, newHeroId);
        heroIds.increment();
        return newHeroId;
    }
}
