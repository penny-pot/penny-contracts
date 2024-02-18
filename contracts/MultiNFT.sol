// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./Pennypot.sol";

// Contract for Minting Multi-Collection NFTs
contract MultiCollectionNFT is
    Initializable,
    ERC721EnumerableUpgradeable,
    OwnableUpgradeable
{
    Pennypot public PennyContract;

    // Mapping to store the collection ID for each token ID
    mapping(uint256 => uint256) private _collectionIds;

    // Mapping to store all current holders for each collection
    mapping(uint256 => address[]) private _collectionHolders;

    // Mapping to store claimed status for each token ID
    mapping(uint256 => bool) private _claimedStatus;

    // Mapping to store conditions for each collection
    mapping(uint256 => string) private _collectionConditions;

    // Event emitted when a new collection is added
    event CollectionAdded(uint256 indexed collectionId);

    // Event emitted when conditions are set for a collection
    event ConditionsSet(uint256 indexed collectionId, string conditions);

    // event CheckedUser(address user, string conditions);

    // Initialize the contract
    function initialize() public initializer {
        __ERC721_init("Pennypot Badge", "PENNY");
        __Ownable_init(msg.sender);
        PennyContract = Pennypot(
            address(0x5c7E626340B4f821FD22Adf433ff2e3fa6f9CF30)
        );
    }

    // Mint a new NFT and assign it to a specific collection
    function mint(
        address to,
        uint256 tokenId,
        uint256 collectionId
    ) internal onlyOwner {
        require(collectionId > 0, "Collection ID must be greater than zero");
        require(_collectionIds[tokenId] == 0, "Token ID already minted");

        _mint(to, tokenId);
        _collectionIds[tokenId] = collectionId;
        _collectionHolders[collectionId].push(to);
    }

    // Function to get the collection ID for a specific token ID

    // Claim NFT if user qualifies
    function claim(uint256 tokenId) external {
        address user = msg.sender;

        // Check if NFT has been claimed
        require(!_claimedStatus[tokenId], "NFT already claimed");

        // Get the collection ID for the NFT
        uint256 collectionId = getCollectionId(tokenId);

        // Check if the user has an active pot in the Pennypot contract
        address userPot = PennyContract.getPotsByToken(user);
        require(userPot != address(0), "User has no active pot on pennypot");

        // Additional conditions for each collection can be checked here
        // string memory conditions = _collectionConditions[collectionId];
        // require(_checkConditions(user, conditions), "Conditions not met");

        // Mark the NFT as claimed
        _claimedStatus[tokenId] = true;

        // Mint the NFT to the user
        mint(user, tokenId, collectionId);
    }

    // Function to get the collection ID for a specific token ID
    function getCollectionId(uint256 tokenId) public view returns (uint256) {
        return _collectionIds[tokenId];
    }

    // Function to get all current holders for a specific collection
    function getCollectionHolders(
        uint256 collectionId
    ) external view returns (address[] memory) {
        return _collectionHolders[collectionId];
    }

    // Function to add a new collection
    function addCollection(uint256 collectionId) external onlyOwner {
        require(collectionId > 0, "Collection ID must be greater than zero");
        emit CollectionAdded(collectionId);
    }

    // Function to set conditions for an existing collection
    function setConditions(
        uint256 collectionId,
        string calldata conditions
    ) external onlyOwner {
        require(collectionId > 0, "Collection ID must be greater than zero");
        _collectionConditions[collectionId] = conditions;
        emit ConditionsSet(collectionId, conditions);
    }

    // Internal function to check conditions for a specific user
    // function _checkConditions(
    //     address user,
    //     string memory conditions
    // ) internal pure returns (bool) {
    //     emit CheckedUser(user, conditions);
    //     // For simplicity, always return true in this demo
    //     return true;
    // }
}
