// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IFactory {
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

    function getProperty(uint256 _propertyId)
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
        );

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external;

    function balanceOf(address account, uint256 id)
        external
        view
        returns (uint256);

    function setApprovalForAll(address operator, bool approved) external;
}
