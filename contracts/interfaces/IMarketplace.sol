// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IMarketplace {
    function sellIssuerTokens(uint256 _amount, uint128 _propertyId) external;

    function buyIssuerTokens(uint128 _propertyId, uint256 _amount)
        external
        payable;

    function buyProperty(uint128 _propertyId, string memory _saleType)
        external
        payable;

    function createRental(uint128 _propertyId, uint128 _nightlyPrice) external;

    function createAuction(
        uint128 _propertyId,
        uint128 _startingPrice,
        string memory _saleType
    ) external;

    function addBalance(uint256 _amount) external payable;

    function withdrawBalance(uint256 _amount) external;
}
