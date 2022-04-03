// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IExchange {
    function buyMarket(uint256 _amount, uint128 _propertyId) external;

    function sellMarket(uint256 _amount, uint128 _propertyId) external;

    function createBid(
        uint256 _amount,
        uint256 _price,
        uint128 _propertyId
    ) external;

    function createOffer(
        uint256 _amount,
        uint256 _price,
        uint128 _propertyId
    ) external;
}
