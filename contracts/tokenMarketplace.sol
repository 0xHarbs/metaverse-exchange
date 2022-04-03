// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./interfaces/IFactory.sol";

contract PropertyMarketplace {
    IFactory factory;

    // ============ STRUCTS & ENUMS ============ //
    struct PropertySale {
        string saleType;
        uint128 propertyId;
        uint128 startingPrice;
        mapping(uint128 => address) bids;
    }

    struct PropertyRental {
        uint128 propertyId;
        uint128 nightlyPrice;
        mapping(uint256 => uint256) availability;
        bool exists;
    }

    // =================== MAPPINGS ==================== //
    mapping(uint128 => PropertySale) public auctions;
    mapping(uint128 => PropertyRental) public rentals;
    mapping(address => uint256) private balance;
    mapping(uint128 => uint256) public availableIssuedSupply;

    constructor(address factoryContract) {
        factory = IFactory(factoryContract);
    }

    // ================= PUBLIC ICO FUNCTIONS ==================== //
    // @dev Price of a token is the fundraise divided by supply
    // Manager opts to sell all tokens as they need to provide funds to hold
    function sellIssuerTokens(uint256 _amount, uint128 _propertyId) external {
        address owner;
        (owner, , , , , , , , , ) = factory.getProperty(_propertyId);
        require(owner == msg.sender);
        factory.setApprovalForAll(address(this), true);
        availableIssuedSupply[_propertyId] = _amount;
    }

    // @dev Check if payment and value are sufficient
    // Send funds to manager and transfer assets to buyers
    function buyIssuerTokens(uint128 _propertyId, uint256 _amount)
        external
        payable
    {
        address owner;
        uint256 price;
        (owner, , , , , , , , price, ) = factory.getProperty(_propertyId);
        uint256 supply = availableIssuedSupply[_propertyId];
        require(msg.value > _amount * price, "Not enough funds sent");
        require(supply > _amount, "There isn't enough supply");
        bool sent = payable(owner).send(msg.value);
        require(sent, "Failed to send Ether");

        availableIssuedSupply[_propertyId] = supply - _amount;
        factory.safeTransferFrom(owner, msg.sender, _propertyId, _amount, "");
    }

    // ================= PUBLIC MARKETPLACE FUNCTIONS ================ //
    function buyProperty(uint128 _propertyId, string memory _saleType)
        external
        payable
    {
        PropertySale storage property = auctions[_propertyId];
        require(
            keccak256(abi.encodePacked(property.saleType)) ==
                keccak256(abi.encodePacked(_saleType))
        );
        require(msg.value >= property.startingPrice);
        (bool sent, ) = address(this).call{value: msg.value}("");
        require(sent, "Failed to send Ether");
        // Transfer event for all ERC1155 tokens - need to finish coding this
        // factory.updateBalances(_propertyId);
    }

    function createRental(uint128 _propertyId, uint128 _nightlyPrice) external {
        address manager;
        (manager, , , , , , , , , ) = factory.getProperty(_propertyId);
        require(manager == msg.sender);
        require(!rentals[_propertyId].exists);
        PropertyRental storage rental = rentals[_propertyId];
        rental.propertyId = _propertyId;
        rental.nightlyPrice = _nightlyPrice;
        rental.exists = true;
    }

    function createAuction(
        uint128 _propertyId,
        uint128 _startingPrice,
        string memory _saleType
    ) external {
        address manager;
        (manager, , , , , , , , , ) = factory.getProperty(_propertyId);
        require(manager == msg.sender);
        require(auctions[_propertyId].startingPrice == 0);
        PropertySale storage property = auctions[_propertyId];
        property.saleType = _saleType;
        property.propertyId = _propertyId;
        property.startingPrice = _startingPrice;
        // Approval for the contract to transfer ownership
    }

    function addBalance(uint256 _amount) external payable {
        require(_amount > 0, "Amount must be more than 0");
        require(msg.value > 0, "Amount sent must be more than 0");
        (bool sent, ) = address(this).call{value: msg.value}("");
        require(sent, "Transaction failed");
        balance[msg.sender] += _amount;
    }

    function withdrawBalance(uint256 _amount) external {
        require(balance[msg.sender] >= _amount);
        balance[msg.sender] -= _amount;
        (bool sent, ) = (msg.sender).call{value: _amount}("");
        require(sent, "Failed to sent to customers");
    }
}
