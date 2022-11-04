// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

contract Giveaway is VRFConsumerBase, Ownable {
    address[] public entrants;
    address public theGiveawayWinner;

    uint256 public fee;
    bytes32 public keyHash;

    enum GiveawayState {
        OPEN,
        CLOSED,
        CHOOSING_WINNER
    }
    GiveawayState public giveawayState;

    constructor(
        address vrfCoordinator,
        address linkToken,
        bytes32 vrfKeyHash,
        uint256 vrfFee
    ) VRFConsumerBase(vrfCoordinator, linkToken) {
        keyHash = vrfKeyHash;
        fee = vrfFee;
    }

    function startGiveaway() public payable onlyOwner {
        require(
            giveawayState != GiveawayState.OPEN ||
                giveawayState != GiveawayState.CHOOSING_WINNER,
            "The giveaway is currently ongoing."
        );
        giveawayState = GiveawayState.OPEN;
    }

    function enterGiveaway() public {
        require(
            giveawayState == GiveawayState.OPEN,
            "The giveaway is currently closed."
        );
        entrants.push(msg.sender);
    }

    function closeGiveaway() public onlyOwner returns (bytes32 requestId) {
        require(
            giveawayState != GiveawayState.CLOSED ||
                giveawayState != GiveawayState.CHOOSING_WINNER,
            "The giveaway is already closed."
        );
        giveawayState = GiveawayState.CHOOSING_WINNER;
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK");
        return requestRandomness(keyHash, fee);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness)
        internal
        virtual
        override
    {
        uint256 index = randomness % entrants.length;
        address giveawayWinner = entrants[index];
        theGiveawayWinner = giveawayWinner;
        delete entrants;

        (bool success, ) = giveawayWinner.call{value: address(this).balance}(
            ""
        );
        require(success, "Error in sending ETH.");
        giveawayState = GiveawayState.CLOSED;
    }

    receive() external payable {}

    fallback() external payable {}
}
