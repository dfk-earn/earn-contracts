// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "./interfaces/IDFKQuest.sol";
import "./Upgradable.sol";
import "./Market.sol";
import "./AuctionHouse.sol";

contract HeroPool is Upgradable, PausableUpgradeable, IERC721Receiver, ERC1155Holder {
    using SafeERC20 for IERC20;

    address public constant DFKQuest = 0xAa9a289ce0565E4D6548e63a441e7C084E6B52F6;
    address public constant DFKProfileV2 = 0x6391F796D56201D279a42fD3141aDa7e26A3B4A5;
    address public constant DFKHero = 0x5F753dcDf9b1AD9AabC1346614D1f4746fd6Ce5C;

    AuctionHouse public auctionHouse;
    uint public auctionExpiration;

    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private operators;

    // Mapping from heroId to hero owner address
    mapping(uint256 => address) public heroOwners;

    // Mapping from user address to attempts count
    mapping(address => uint256) public attempts;
    uint256 public totalAttempts;

    // Mapping from quest address to quest weight
    mapping(address => uint8) public questWeights;

    event HeroReceived(address indexed from, uint256 tokenId);
    event HeroSent(address indexed to, uint256 tokenId);
    event QuestWeightUpdated(address quest, uint256 weight);
    event Claim(address indexed user, uint256 userAttempts, uint256 poolAttempts);

    function initialize(address _auctionHouse) public initializer {
        __Ownable_init();
        __Pausable_init();
        auctionHouse = AuctionHouse(_auctionHouse);
        auctionExpiration = 2 days;
    }

    modifier onlyOperator() {
        require(operators.contains(msg.sender), "HeroPool: not operator");
        _;
    }

    function onERC721Received(
        address,
        address from,
        uint256 tokenId,
        bytes calldata
    )
        external
        override
        whenNotPaused
        returns (bytes4)
    {
        if (msg.sender == DFKHero) {
            assert(heroOwners[tokenId] == address(0));
            heroOwners[tokenId] = from;
            emit HeroReceived(from, tokenId);
        }
        return this.onERC721Received.selector;
    }

    function withdrawalHeros(uint256[] calldata tokenIds) external {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            address heroOwner = heroOwners[tokenId];
            require(msg.sender == heroOwner, "HeroPool: not hero owner");
            delete heroOwners[tokenId];
            IERC721(DFKHero).safeTransferFrom(address(this), heroOwner, tokenId);
            emit HeroSent(heroOwner, tokenId);
        }
    }

    function createAuctionAndBid(Item calldata _item, uint256 _initialPrice) external {
        transferMoney(msg.sender, address(this), _initialPrice);
        uint auctionId = auctionHouse.create(_item, _initialPrice, auctionExpiration);
        auctionHouse.money().approve(address(auctionHouse), _initialPrice);
        auctionHouse.bid(auctionId, _initialPrice, msg.sender);
    }

    function getClaimable(address user) public view returns (uint256) {
        return getBalance() * attempts[user] / totalAttempts;
    }

    function claim() external {
        uint256 claimable = getClaimable(msg.sender);
        require(claimable > 0, "HeroPool: no claimable");
        uint256 userAttempts = attempts[msg.sender];
        attempts[msg.sender] = 0;
        totalAttempts -= userAttempts;
        transferMoney(address(this), msg.sender, claimable);
        emit Claim(msg.sender, userAttempts, totalAttempts);
    }

    function startQuest(
        uint256[] calldata _heroIds,
        address _quest,
        uint8 _attempts,
        uint8 _level
    ) 
        external
        onlyOperator
    {
        require(questWeights[_quest] > 0, "HeroPool: unsupported quest");
        IDFKQuest(DFKQuest).startQuest(_heroIds, _quest, _attempts, _level);
        updateAttempts(_heroIds, _quest, _attempts);
    }

    function cancelQuest(uint256 _heroId) external onlyOperator {
        IDFKQuest(DFKQuest).cancelQuest(_heroId);
    }

    function completeQuest(uint256 _heroId) external onlyOperator {
        IDFKQuest(DFKQuest).completeQuest(_heroId);
    }

    function setHeroOwner(uint _heroId, address _owner) external onlyOwner {
        require(IERC721(DFKHero).ownerOf(_heroId) == address(this), "HeroPool: not found");
        require(heroOwners[_heroId] == address(0), "HeroPool: already owned");
        heroOwners[_heroId] = _owner;
        emit HeroReceived(_owner, _heroId);
    }

    function updateQuestWeight(address _quest, uint8 _weight) external onlyOwner {
        if (_weight > 0) {
            questWeights[_quest] = _weight;
        } else {
            delete questWeights[_quest];
        }
        emit QuestWeightUpdated(_quest, _weight);
    }

    function setAuctionExpiration(uint _expiration) external onlyOwner {
        auctionExpiration = _expiration;
    }

    function createProfile(
        string calldata _name,
        uint _nftId,
        uint _collectionId
    )
        external
        onlyOwner
    {
        Address.functionCall(DFKProfileV2, abi.encodeWithSignature(
            "createProfile(string,uint256,uint256)",
            _name,
            _nftId,
            _collectionId
        ));
    }

    function updateOperator(address _operator, bool _add) external onlyOwner {
        if (_add) {
            operators.add(_operator);
        } else {
            operators.remove(_operator);
        }
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function approveItem(
        address _itemAddr,
        ItemType _itemType,
        bool _approved
    )
        external
        onlyOwner
    {
        if (_itemType == ItemType.ERC20) {
            uint amount = _approved ? type(uint).max : 0;
            IERC20(_itemAddr).approve(address(auctionHouse), amount);
        } else if (_itemType == ItemType.ERC721) {
            IERC721(_itemAddr).setApprovalForAll(address(auctionHouse), _approved);
        } else if (_itemType == ItemType.ERC1155) {
            IERC1155(_itemAddr).setApprovalForAll(address(auctionHouse), _approved);
        }
    }

    function getOperators() public view returns (address[] memory) {
        uint length = operators.length();
        address[] memory result = new address[](length);
        for (uint i = 0; i < length; i++) {
            result[i] = operators.at(i);
        }
        return result;
    }

    function updateAttempts(
        uint256[] calldata _heroIds,
        address _quest,
        uint8 _attempts
    )
        private
    {
        uint8 weight = questWeights[_quest];
        uint256 effectiveAttempts = _attempts * weight;
        for (uint256 i = 0; i < _heroIds.length; i++) {
            address heroOwner = heroOwners[_heroIds[i]];
            if (heroOwner != address(0)) {
                attempts[heroOwner] += effectiveAttempts;
                totalAttempts += effectiveAttempts;
            }
        }
    }

    function getBalance() public view returns (uint) {
        return auctionHouse.money().balanceOf(address(this));
    }


    function transferMoney(address _from, address _to, uint _amount) private {
        auctionHouse.money().safeTransferFrom(_from, _to, _amount);
    }
}
