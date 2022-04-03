// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./interfaces/IFactory.sol";

contract TokenOrders {
    IFactory factory;
    uint256 public bidCounter;
    uint256 public offerCounter;

    // ===================== STRUCTS ========================= //
    struct Bids {
        uint256 id;
        uint256 price;
        uint256 totalQuantity;
        uint256 next;
        uint256 previous;
        uint256 head;
        uint256 tail;
        bool exists;
    }

    struct BidByAddress {
        uint256 id;
        uint256 next;
        uint256 previous;
        uint256 amount;
        uint256 price;
        address owner;
    }

    struct BidBook {
        uint256 head;
        uint256 tail;
        uint256 highestBid;
    }

    struct Offers {
        uint256 id;
        uint256 price;
        uint256 totalQuantity;
        uint256 next;
        uint256 previous;
        uint256 head;
        uint256 tail;
        bool exists;
    }

    struct OfferByAddress {
        uint256 id;
        uint256 next;
        uint256 previous;
        uint256 amount;
        uint256 price;
        address owner;
    }

    struct OrderBook {
        uint256 head;
        uint256 tail;
        uint256 lowestOffer;
    }

    // ======================= MAPPINGS ================= //
    mapping(uint256 => Bids) public idToBid;
    mapping(uint128 => BidBook) public propertyToBidBook;
    mapping(uint128 => mapping(address => uint256)) public openBids;
    mapping(uint256 => mapping(uint256 => BidByAddress)) public bidQueue;
    mapping(uint128 => mapping(uint256 => Bids)) public priceToBidbook;

    mapping(uint256 => Offers) public idToOffers;
    mapping(uint128 => OrderBook) public propertyToOrderBook;
    mapping(uint128 => mapping(address => uint256)) public openOffers;
    mapping(uint256 => mapping(uint256 => OfferByAddress)) public offerQueue;
    mapping(uint128 => mapping(uint256 => Offers)) public priceToOfferbook;

    constructor(address factoryContract) {
        factory = IFactory(factoryContract);
    }

    // ================= PUBLIC ORDER FUNCTIONS ========================= //
    // @ dev Get funds required to complete market order
    // Gets the number of books order would fill and fundsRequired to do this
    // Checks the balance of sender is > funds required + book has enough to fill
    // Loops through each Offer book and the queue of offers inside --> adjusting balances and transferring ownership
    function buyMarket(uint256 _amount, uint128 _propertyId) external {
        uint256 headId = propertyToOrderBook[_propertyId].head;
        Offers storage offer = idToOffers[headId];
        Offers storage checkOffer = idToOffers[headId];
        uint256 fundsRequired;
        bool enoughSupply = true;

        if (offer.totalQuantity < _amount) {
            enoughSupply = false;
            uint256 amount = _amount - checkOffer.totalQuantity;
            fundsRequired = checkOffer.totalQuantity * checkOffer.price;
            for (uint256 i; i < 20; i++) {
                // Add offerbook counter here for book length
                checkOffer = idToOffers[checkOffer.next];
                if (checkOffer.totalQuantity < amount) {
                    amount -= checkOffer.totalQuantity;
                    fundsRequired +=
                        checkOffer.totalQuantity *
                        checkOffer.price;
                } else {
                    fundsRequired +=
                        checkOffer.totalQuantity *
                        checkOffer.price;
                    enoughSupply = true;
                    break;
                }
                if (checkOffer.next == checkOffer.id) {
                    break;
                }
            }
        }

        // require(balance[msg.sender] >= fundsRequired, "You do not have enough funds to send this order");
        require(enoughSupply, "Not enough supply to fill order");

        OfferByAddress storage nextOffer = offerQueue[offer.id][offer.head];
        Offers storage holderOffer = offer;

        while (_amount > 0) {
            uint256 amount;
            address fundReceiver;
            // If the next offers amount is more than order amount then set _amount to 0 and finish
            if (nextOffer.amount > _amount) {
                amount = _amount;
                nextOffer.amount -= _amount;
                offer.totalQuantity -= amount;
                _amount = 0;
                fundReceiver = nextOffer.owner;
                // If the order is more than or equal to the amount in the queue
            } else {
                amount = nextOffer.amount;
                _amount -= nextOffer.amount;
                nextOffer.amount = 0;
                offer.totalQuantity -= amount;
                fundReceiver = nextOffer.owner;

                // If there are no more offers - reset offer and reset property to Orderbook to 0
                if (
                    nextOffer.next == nextOffer.id &&
                    propertyToOrderBook[_propertyId].head == offer.id
                ) {
                    // nextOffer.amount < 0 &&
                    propertyToOrderBook[_propertyId].lowestOffer = 0;
                    propertyToOrderBook[_propertyId].head = 0;
                    propertyToOrderBook[_propertyId].tail = 0;

                    delete offerQueue[offer.id][nextOffer.previous];

                    offer.head = 0;
                    offer.tail = 0;
                    offer.next = 0;
                    offer.previous = 0;
                    priceToOfferbook[_propertyId][offer.price] = offer;
                }
                // If the id of the next offer is the next offer & this is head of order book --> set this offerbook values to 0 and reset head in orderbook
                // If the next item in the queue is empty then reset values for the bid book
                else if (nextOffer.next == nextOffer.id) {
                    Offers memory newHead = idToOffers[offer.next];
                    propertyToOrderBook[_propertyId].lowestOffer = newHead
                        .price;
                    propertyToOrderBook[_propertyId].head = newHead.id;

                    delete offerQueue[offer.id][nextOffer.previous];
                    holderOffer = idToOffers[offer.next];

                    offer.head = 0;
                    offer.tail = 0;
                    offer.next = 0;
                    offer.previous = 0;
                    priceToOfferbook[_propertyId][offer.price] = offer;

                    offer = holderOffer; // Set next offer book to holder offer to continue filling this order
                    offer.previous = offer.id; // Set the id to this offer as previous is filled
                    nextOffer = offerQueue[offer.id][offer.head]; // Set first item in offer queue to first order in new book
                } else {
                    offer.head = nextOffer.next;
                    nextOffer = offerQueue[offer.id][nextOffer.next];
                    delete offerQueue[offer.id][nextOffer.previous];
                    nextOffer.previous = nextOffer.id;
                }
            }
            // priceToOfferbook[_propertyId][offer.price] = offer;
            // balance[msg.sender] -= amount * nextOffer.price;
            // balance[nextOffer.owner] += amount * nextOffer.price;
            factory.safeTransferFrom(
                fundReceiver,
                msg.sender,
                _propertyId,
                amount,
                ""
            );
        }
    }

    function sellMarket(uint256 _amount, uint128 _propertyId) external {
        uint256 headId = propertyToBidBook[_propertyId].head;
        Bids storage bid = idToBid[headId];
        Bids storage checkBid = idToBid[headId];
        bool enoughDemand = true;

        if (bid.totalQuantity < _amount) {
            enoughDemand = false;
            uint256 amount = _amount - checkBid.totalQuantity;
            for (uint256 i; i < 20; i++) {
                // Add offerbook counter here for book length
                checkBid = idToBid[checkBid.next];
                if (checkBid.totalQuantity < amount) {
                    amount -= checkBid.totalQuantity;
                } else {
                    enoughDemand = true;
                    break;
                }
                if (checkBid.next == checkBid.id) {
                    break;
                }
            }
        }
        require(enoughDemand, "Not enough supply to fill order");
        BidByAddress storage nextBid = bidQueue[bid.id][bid.head];
        Bids storage holderBid = bid;

        while (_amount > 0) {
            uint256 amount;
            address tokenReceiver;
            // If the next offers amount is more than order amount then set ordr _amount to 0 and finish
            if (nextBid.amount > _amount) {
                amount = _amount;
                nextBid.amount -= _amount;
                bid.totalQuantity -= amount;
                _amount = 0;
                tokenReceiver = nextBid.owner;
                // If the next offer is less than order amount then minus this amount from order_amount and from offer book
            } else {
                amount = nextBid.amount;
                _amount -= nextBid.amount;
                bid.totalQuantity -= amount;
                tokenReceiver = nextBid.owner;
                // If the id of the next offer is the next offer --> set this offerbook values to 0 and get the next book
                // If the next item in the queue is empty then reset values for this bid book
                // Change the highestBid in the bidbook for this property as well
                if (
                    nextBid.next == nextBid.id &&
                    propertyToBidBook[_propertyId].head == bid.id
                ) {
                    propertyToBidBook[_propertyId].highestBid = 0;
                    propertyToBidBook[_propertyId].head = 0;
                    propertyToBidBook[_propertyId].tail = 0;

                    delete bidQueue[bid.id][nextBid.previous];
                    holderBid = idToBid[bid.next];

                    bid.head = 0;
                    bid.tail = 0;
                    bid.next = 0;
                    bid.previous = 0;
                    priceToBidbook[_propertyId][bid.price] = bid;
                } else if (nextBid.next == nextBid.id) {
                    Bids memory newHead = idToBid[bid.next];
                    propertyToBidBook[_propertyId].highestBid = newHead.price;
                    propertyToBidBook[_propertyId].head = newHead.id;

                    delete bidQueue[bid.id][nextBid.previous];
                    holderBid = idToBid[bid.next];

                    bid.head = 0;
                    bid.tail = 0;
                    bid.next = 0;
                    bid.previous = 0;
                    priceToBidbook[_propertyId][bid.price] = bid;

                    bid = holderBid; // Set next offer book to holder offer to continue filling this order
                    bid.previous = bid.id; // Set the id to this offer as previous is filled
                    nextBid = bidQueue[bid.id][bid.head]; // Set first item in offer queue to first order in new book
                } else {
                    bid.head = nextBid.next;
                    nextBid = bidQueue[bid.id][nextBid.next];
                    delete bidQueue[bid.id][nextBid.previous];
                    nextBid.previous = nextBid.id;
                }
            }
            priceToBidbook[_propertyId][bid.price] = bid;
            // balance[msg.sender] -= amount * nextOffer.price;
            // balance[nextOffer.owner] += amount * nextOffer.price;
            factory.safeTransferFrom(
                msg.sender,
                tokenReceiver,
                _propertyId,
                amount,
                ""
            );
        }
    }

    // ========================= PUBLIC BID MANAGEMENT FUNCTIONS =================== //
    function createBid(
        uint256 _amount,
        uint256 _price,
        uint128 _propertyId
    ) external {
        // require(
        //     balance[msg.sender] >= _amount * _price,
        //     "Must have enough ether for this order"
        // );
        require(_amount > 0, "Amount can not be 0");
        if (!priceToBidbook[_propertyId][_price].exists) {
            Bids storage bid = priceToBidbook[_propertyId][_price]; // Creates bid if it doesn't exist
            bid.exists = true;
            addToBidbook(_price, _propertyId);
            addToBidQueue(_propertyId, _amount, _price);
        } else if (priceToBidbook[_propertyId][_price].totalQuantity == 0) {
            addToBidbook(_price, _propertyId);
            addToBidQueue(_propertyId, _amount, _price);
        } else {
            addToBidQueue(_propertyId, _amount, _price);
        }
    }

    // @dev This function adds a new bid to the bid side of the order book
    // Next and previous are used to order items in the bid book
    function addToBidbook(uint256 _price, uint128 _propertyId) internal {
        Bids storage bid = priceToBidbook[_propertyId][_price];
        BidBook storage bidbook = propertyToBidBook[_propertyId];

        bidCounter += 1; // Iterates counter so we can give offer Id
        bid.id = bidCounter;
        bid.price = _price; // Set the offer price

        uint256 nextNode = bidbook.head; // Finds the id for the first offer in the orderbook
        uint256 previousNode = bidbook.head;
        bool ordered = false;
        while (!ordered) {
            // If the Bid book is empty for the property then set this bidBook to be the head & tail
            if (nextNode == 0) {
                // If the id of the first bid is 0 there are no offers
                bidbook.head = bid.id; // Set the id for the first bid to the new bid id
                bidbook.tail = bid.id; // Set the id for the tail bid to the new bid id
                bidbook.highestBid = bid.price;
                bid.next = bid.id; // Set the id for bid that is next to the current id
                bid.previous = bid.id; // Set the id for bid that is previous to current id
                ordered = true;
                break;
            }

            // If price is smaller than current bid & next bid is not empty
            if (
                bid.price < idToBid[nextNode].price &&
                idToBid[nextNode].next != idToBid[nextNode].id
            ) {
                previousNode = nextNode;
                nextNode = idToBid[nextNode].next;
                // If the price is smaller than the next bid and the next bids next is the tail
            } else if (
                bid.price < idToBid[nextNode].price &&
                idToBid[nextNode].next == idToBid[nextNode].id
            ) {
                bid.previous = nextNode;
                bid.next = bid.id;
                idToBid[nextNode].next = bid.id;
                bidbook.tail = bid.id;
                priceToBidbook[_propertyId][idToBid[nextNode].price] = idToBid[
                    nextNode
                ];
                ordered = true;
                // If the price is bigger than the next bid and the nextNode is the head
            } else if (
                bid.price > idToBid[nextNode].price &&
                idToBid[nextNode].previous == idToBid[nextNode].id
            ) {
                bid.next = nextNode;
                bid.previous = bid.id;
                idToBid[nextNode].previous = bid.id;
                priceToBidbook[_propertyId][idToBid[nextNode].price] = idToBid[
                    nextNode
                ];
                bidbook.head = bid.id;
                bidbook.highestBid = bid.price;
                ordered = true;
                // If the price is bigger than the next node and the next node is not the head - insert between
            } else if (bid.price > idToBid[nextNode].price) {
                bid.next = nextNode;
                bid.previous = previousNode;
                idToBid[nextNode].previous = bid.id;
                idToBid[previousNode].next = bid.id;
                priceToBidbook[_propertyId][idToBid[nextNode].price] = idToBid[
                    nextNode
                ];
                priceToBidbook[_propertyId][
                    idToBid[previousNode].price
                ] = idToBid[nextNode];
                ordered = true;
            }
        }
    }

    // @dev Head & Tail are used on Bids to point to items in their queue
    function addToBidQueue(
        uint128 _propertyId,
        uint256 _amount,
        uint256 _price
    ) internal {
        Bids storage bid = priceToBidbook[_propertyId][_price];
        bid.tail += 1;
        BidByAddress storage newBid = bidQueue[bid.id][bid.tail];

        if (bid.tail == 1) {
            // If the id is 1 then this is the first order in the queue
            newBid.next = bid.tail; // We set the next + previous to equal this offer
            newBid.previous = bid.tail;
            bid.head = 1;
        } else {
            // When there are orders in the queue we will set the new order as tail
            BidByAddress storage currentTail = bidQueue[bid.id][bid.tail - 1];
            currentTail.next = bid.tail; // We set the previous tails next order to equal new offer
            newBid.previous = currentTail.id; // We set the new orders previous as the last tail
            newBid.next = bid.tail;
        }

        // We now edit the information for the offer that has been added
        openBids[_propertyId][msg.sender] += _amount; // We can now add the shares this user has offered
        newBid.id = bid.tail; // The id for the order will always be the tail id
        newBid.owner = msg.sender;
        newBid.amount = _amount;
        newBid.price = _price;

        bid.totalQuantity += _amount;
        idToBid[bid.id] = bid; // This mapping helps us find this order in the linked list mapping
    }

    // ======================= PUBLIC ASK MANAGEMENT FUNCTIONS ==================== //
    // @dev This lets users sell tokens if balance is sufficient
    // If the Offer does not exist it's created
    // If the Offer exists but the amount is zero, it's added to Orderbook
    // If the Offer exists and has volume then we just add the order to the queue
    function createOffer(
        uint256 _amount,
        uint256 _price,
        uint128 _propertyId
    ) external {
        require(
            factory.balanceOf(msg.sender, _propertyId) -
                openOffers[_propertyId][msg.sender] >=
                _amount,
            "Must have enough tokens to sell"
        );
        require(_amount > 0, "Amount can not be 0");
        if (!priceToOfferbook[_propertyId][_price].exists) {
            Offers storage offer = priceToOfferbook[_propertyId][_price]; // Creates offer if it doesn't exist
            offer.exists = true;
            addToOrderbook(_price, _propertyId);
            addToOfferQueue(_propertyId, _amount, _price);
        } else if (priceToOfferbook[_propertyId][_price].totalQuantity == 0) {
            addToOrderbook(_price, _propertyId);
            addToOfferQueue(_propertyId, _amount, _price);
        } else {
            addToOfferQueue(_propertyId, _amount, _price);
        }
        factory.setApprovalForAll(address(this), true);
    }

    // @dev This function finds the right place in the order book (a linked list) to add the Offer
    // We traverse the orderbook and insert the Offer when it's less than the next Offer
    // Effectively ordering the offers in the order book
    function addToOrderbook(uint256 _price, uint128 _propertyId) internal {
        Offers storage offer = priceToOfferbook[_propertyId][_price];
        OrderBook storage orderbook = propertyToOrderBook[_propertyId];

        offerCounter += 1; // Iterates counter so we can give offer Id
        offer.id = offerCounter;
        offer.price = _price; // Set the offer price

        uint256 nextNode = orderbook.head; // Finds the id for the first offer in the orderbook
        uint256 previousNode = orderbook.head;
        bool ordered = false;
        while (!ordered) {
            if (nextNode == 0) {
                // If the id of the first offer is 0 there are no offers
                orderbook.head = offer.id; // Set the id for the first offer to the new offer id
                orderbook.tail = offer.id; // Set the id for the tail offer to the new offer id
                offer.next = offer.id; // Set the id for offer that is next to the current id
                offer.previous = offer.id; // Set the id for offer that is previous to current id
                ordered = true;
                break;
            }

            if (
                offer.price > idToOffers[nextNode].price &&
                idToOffers[nextNode].next != idToOffers[nextNode].id
            ) {
                previousNode = nextNode;
                nextNode = idToOffers[nextNode].next;
            } else if (
                offer.price > idToOffers[nextNode].price &&
                idToOffers[nextNode].next == idToOffers[nextNode].id
            ) {
                offer.previous = nextNode;
                offer.next = offer.id;
                idToOffers[nextNode].next = offer.id;
                orderbook.tail = offer.id;
                ordered = true;
            } else if (idToOffers[nextNode].next == idToOffers[nextNode].id) {
                offer.previous = offer.id;
                offer.next = nextNode;
                idToOffers[nextNode].previous = offer.id;
                orderbook.head = offer.id;
                ordered = true;
            } else {
                offer.previous = previousNode;
                offer.next = nextNode;
                ordered = true;
            }
            // Need to change the lowest price if order is lowest
        }
    }

    // @dev This adds the users offer to the queue of existing offers at that price
    // We find the tail of the queue to add the new offer to the end
    // We then iterate the counter in Offer and the quantity available
    function addToOfferQueue(
        uint128 _propertyId,
        uint256 _amount,
        uint256 _price
    ) internal {
        Offers storage offer = priceToOfferbook[_propertyId][_price];
        offer.tail += 1;
        OfferByAddress storage newOffer = offerQueue[offer.id][offer.tail];

        if (offer.tail == 1) {
            // If the id is 1 then this is the first order in the queue
            newOffer.next = offer.tail; // We set the next + previous to equal this offer
            newOffer.previous = offer.tail;
            offer.head = 1;
        } else {
            // When there are orders in the queue we will set the new order as tail
            OfferByAddress storage currentTail = offerQueue[offer.id][
                offer.tail - 1
            ];
            currentTail.next = offer.tail; // We set the previous tails next order to equal new offer
            newOffer.previous = currentTail.id; // We set the new orders previous as the last tail
            newOffer.next = offer.tail;
        }

        // We now edit the information for the offer that has been added
        openOffers[_propertyId][msg.sender] += _amount; // We can now add the shares this user has offered
        newOffer.id = offer.tail; // The id for the order will always be the tail id
        newOffer.owner = msg.sender;
        newOffer.amount = _amount;
        newOffer.price = _price;

        offer.totalQuantity += _amount;
        idToOffers[offer.id] = offer; // This mapping helps us find this order in the linked list mapping
    }
}
