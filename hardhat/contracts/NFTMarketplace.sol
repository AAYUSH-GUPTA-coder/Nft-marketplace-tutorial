// SPDX-License-Identifier: MIT
/*
@author Aayush Gupta. Twiiter: @Aayush_gupta_ji Github: AAYUSH-GUPTA-coder
 */
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFTMarketplace is ERC721URIStorage {
    using Counters for Counters.Counter;
    // helps us to Use Counter library to increase TokenID of NFT
    Counters.Counter private _tokenIds;
    Counters.Counter private _itemsSold;

    // the price marketplace get for listing NFT for Sale
    uint256 listingPrice = 0.025 ether;
    // Address of the owner of NFT-Marketplace
    address payable owner;

    // storing market status of each NFT through tokenId => MarketItem
    mapping(uint256 => MarketItem) private idToMarketItem;

    // struct for storing status of NFT
    struct MarketItem {
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
        bool sold;
    }

    // event to capture all the details when NFT is created
    event MarketItemCreated(
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        bool sold
    );

    /**
     * @dev contructor is function that runs only once, when the contract is deployed to set initial values. 
     */
    constructor() ERC721("Metaverse Tokens", "METT") {
        // setting owner of the contract
        owner = payable(msg.sender);
    }


    /**
     * @dev function to Update the listing price of the contract (Price user have to list their NFT)
     * @param _listingPrice is updated price of NFT listing
     */
    function updateListingPrice(uint256 _listingPrice) public payable {
        require(
            owner == msg.sender,
            "Only marketplace owner can update listing price."
        );
        listingPrice = _listingPrice;
    }

    
    /**
     * @dev function to return the listing price of the NFT
     * It is read only / view function
     */
    function getListingPrice() public view returns (uint256) {
        return listingPrice;
    }

    /**
     * @dev function to create / mint token from our dapp and list it on our marketplace 
     * @param tokenURI : metadata of the NFT
     * @param price : price of the NFT 
     */
    function createToken(string memory tokenURI, uint256 price)
        public
        payable
        returns (uint256)
    {
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        _mint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, tokenURI);
        createMarketItem(newTokenId, price);
        return newTokenId;
    }

    /**
     * @dev tranfer the NFT from seller to marketplace smart contract. Basically to list NFT in our marketplace it is private function excuted inside the contract without the calling/interference of user. 
     * @param tokenId of NFT
     * @param price of NFT
     */
    function createMarketItem(uint256 tokenId, uint256 price) private {
        require(price > 0, "Price must be at least 1 wei");
        require(
            msg.value == listingPrice,
            "Price must be equal to listing price"
        );

        idToMarketItem[tokenId] = MarketItem(
            tokenId,
            payable(msg.sender),
            payable(address(this)), // address(this) means ADDRESS OF THIS CONTRACT
            price,
            false
        );

        // transfer the NFT from seller to marketplace smart contract 
        _transfer(msg.sender, address(this), tokenId);

        emit MarketItemCreated(
            tokenId,
            msg.sender,
            address(this),
            price,
            false
        );
    }

    /**
     * @dev function to allow Buyer of our marketplace to become seller also.
     * @param tokenId of NFT
     * @param price of NFT
     */
    function resellToken(uint256 tokenId, uint256 price) public payable {
        require(
            idToMarketItem[tokenId].owner == msg.sender,
            "Only item owner can perform this operation"
        );
        require(
            msg.value == listingPrice,
            "Price must be equal to listing price"
        );
        idToMarketItem[tokenId].sold = false;
        idToMarketItem[tokenId].price = price;
        idToMarketItem[tokenId].seller = payable(msg.sender);
        idToMarketItem[tokenId].owner = payable(address(this));
        _itemsSold.decrement();

        _transfer(msg.sender, address(this), tokenId);
    }

    /**
     * @dev Creates the sale of a marketplace item
     * Transfers ownership of the item, as well as funds between parties
     * @param tokenId of the NFT
     */
    function createMarketSale(uint256 tokenId) public payable {
        uint256 price = idToMarketItem[tokenId].price;
        address seller = idToMarketItem[tokenId].seller;
        require(
            msg.value == price,
            "Please submit the asking price in order to complete the purchase"
        );
        idToMarketItem[tokenId].owner = payable(msg.sender);
        idToMarketItem[tokenId].sold = true;
        idToMarketItem[tokenId].seller = payable(address(0));
        _itemsSold.increment();
        // Transfer NFT from martketplace contract to buyer
        _transfer(address(this), msg.sender, tokenId);
        // transfer the listing amount which is store/present in marketplace contract to MarketplaceContractOwner.
        payable(owner).transfer(listingPrice); 
        // transfer the selling amount to SELLER from Buyer
        payable(seller).transfer(msg.value);
    }

    /**
     * @dev function to fetch all the unsold NFTs
     */
    function fetchMarketItems() public view returns (MarketItem[] memory) {
        uint256 itemCount = _tokenIds.current();
        uint256 unsoldItemCount = _tokenIds.current() - _itemsSold.current();
        uint256 currentIndex = 0;

        // created a new array of size(unsoldItemCount) name items
        MarketItem[] memory items = new MarketItem[](unsoldItemCount);
        for (uint256 i = 0; i < itemCount; i++) {
            if (idToMarketItem[i + 1].owner == address(this)) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    /**
     * @dev function to fetch all NFTs that a user/buyer has purchased
     */
    function fetchMyNFTs() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _tokenIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            // check if owner address of NFT and address of caller is SAME
            if (idToMarketItem[i + 1].owner == msg.sender) {
                itemCount += 1;
            }
        }
        // created a new array of size(itemCount) name items
        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }


    /**
     * @dev function to Returns only items a user has listed
     */
    function fetchItemsListed() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _tokenIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }
    
    
    /**
     * @dev function to get the balance of the martketplace contract
     */
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }


    /**
     * @dev function to transfer the balance of the martketplace contract to MarketplaceContract OWNER
     */
    function withdraw() external {
        uint256 amount = address(this).balance;
        (bool sent, ) = owner.call{value: amount}("");
        require(sent, "Failed to send Ether");
    }

    /**
     * @dev Function to receive Ether, when msg.data must be empty
     */
    receive() external payable {}

    /**
     * @dev Function to receive Ether, when msg.data is NOT empty 
     */
    fallback() external payable {}
}