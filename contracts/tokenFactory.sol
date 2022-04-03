// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenFactory is ERC1155, Ownable {
    uint128 propertyIds;

    // =============== STRUCTS ================== //
    enum Status {
        FUNDRAISING,
        PURCHASING,
        OWNED
    }

    struct Property {
        address manager;
        string name;
        string description;
        string location;
        string metaverse;
        uint128 fundingTarget;
        uint128 totalInvestors;
        uint256 supply;
        uint256 price;
        mapping(uint128 => address) investors;
        Status status;
    }

    // =================== MAPPINGS ============= //
    mapping(uint128 => Property) public properties;
    mapping(uint128 => bool) saleAgreed;
    mapping(uint128 => address) newManager;
    mapping(uint128 => mapping(address => uint128))
        public propertyHolderPercent;

    // ==================== MODIFIERS =================== //
    modifier onlyManager(uint128 propertyId) {
        require(properties[propertyId].manager == msg.sender);
        _;
    }

    constructor() ERC1155("") {}

    // ================== PUBLIC FUNCTIONS ============== //
    function mintProperty(
        uint128 _fundingTarget,
        uint256 _tokens,
        string memory _name,
        string memory _description,
        string memory _location,
        string memory _metaverse,
        Status _status
    ) external {
        require(_fundingTarget > 0);
        _mint(msg.sender, propertyIds, _tokens, "");
        Property storage property = properties[propertyIds];
        property.manager = msg.sender;
        property.name = _name;
        property.description = _description;
        property.location = _location;
        property.metaverse = _metaverse;
        property.fundingTarget = _fundingTarget;
        property.supply = _tokens;
        property.status = _status;
        property.price = _fundingTarget / _tokens;
        propertyIds += 1;
    }

    function removeProperty(uint128 _propertyId)
        external
        onlyManager(_propertyId)
    {
        require(
            saleAgreed[_propertyId] == true,
            "This property has not been voted to sell by investors"
        );
        delete properties[_propertyId];
    }

    function changeManager(uint128 _propertyId)
        external
        onlyManager(_propertyId)
    {
        Property storage property = properties[_propertyId];
        address updatedManager = newManager[_propertyId];
        property.manager = updatedManager;
    }

    function changeStatus(uint128 _propertyId, Status _status)
        external
        onlyManager(_propertyId)
    {
        Property storage property = properties[_propertyId];
        property.status = _status;
    }

    function changeName(uint128 _propertyId, string memory _name)
        external
        onlyManager(_propertyId)
    {
        Property storage property = properties[_propertyId];
        property.name = _name;
    }

    // ================ GETTER FUNCTIONS =================== //
    function getProperty(uint128 _propertyId)
        external
        view
        returns (
            address manager,
            string memory name,
            string memory description,
            string memory location,
            string memory metaverse,
            uint128 fundingTarget,
            uint128 totalInvestors,
            uint256 supply,
            uint256 price,
            Status status
        )
    {
        Property storage property = properties[_propertyId];
        manager = property.manager;
        name = property.name;
        description = property.description;
        location = property.location;
        metaverse = property.metaverse;
        fundingTarget = property.fundingTarget;
        totalInvestors = property.totalInvestors;
        supply = property.supply;
        price = property.price;
        status = property.status;
    }
}
