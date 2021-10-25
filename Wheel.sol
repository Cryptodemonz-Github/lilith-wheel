/**
 *   _____________   _______ _____ ___________ ________  ________ _   _ ______
 *  /  __ | ___ \ \ / | ___ |_   _|  _  |  _  |  ___|  \/  |  _  | \ | |___  /
 *  | /  \| |_/ /\ V /| |_/ / | | | | | | | | | |__ |      | | | |  \| |  / /
 *  | |   |    /  \ / |  __/  | | | | | | | | |  __|| |\/| | | | |     | / /
 *  \ \__/| |\ \  | | | |     | | \ \_/ | |/ /| |___| |  | \ \_/ | |\  |/ /___
 *   \____\_| \_| \_/ \_|     \_/  \___/|___/ \____/\_|  |_/\___/\_| \_\_____/
 *
 *
 *  #CryptoDemonz, Wheel of Fortune
 *
 * It’s a wheel with 13 segments, each segment defines a multiplier like 2x, 3x, …, 12x, 13x, and it has a wild segment which gives a free round. 
 * The player can place a bet and has to figure out which multiplier will be the result when the wheel is stopped. 
 * After betting, the wheel starts spinning and spinning, then it stops. 
 * Anyone who successfully figured out the winning multiplier where the wheel’s stopped, gets the prize: bet amount x winning multiplier. 
 * Otherwise, the player loses their bet. With this ruleset players have 7.69% chance to win or at least get a new round where they can try again.
 *
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

contract Wheel is Ownable, VRFConsumerBase {
    using SafeMath for uint256;
    using Address for address;

    // instance of $LLTH token
    IERC20 internal _LLTH;

    // minimum value of the wheel segment multiplier
    uint256 public minMultiplier = 1;

    // maximum value of the wheel segment multiplier
    uint256 public maxMultiplier = 13;

    // fee required to fulfill a VRF request
    uint256 public fee;

    // public key against which randomness is generated
    bytes32 public keyHash;

    // the address of the smart contract which verifies if the numbers returned from Chainlink are actually random
    address public VRFCoordinator = 0x8C7382F9D8f56b33781fE506E897a4F1e2d17255;

    // LINK token's address
    address public LINKToken = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;

    // bets of players
    mapping(address => uint256) public bets;

    // multipliers of players
    mapping(address => uint256) public multipliers;

    // mapping of player's address to requestId
    mapping(address => bytes32) public addressToRequestId;

    // mapping of requestId to the returned random number
    mapping(bytes32 => uint256) public requestIdToRandomNumber;

    // sending random number for front-end
    event RandomIsArrived(bytes32 requestId, uint256 randomNumber);

    // sending request ID for front-end
    event RequestIdIsCreated(address player, bytes32 requestId);

    //-------------------------------------------------------------------------
    // CONSTRUCTOR
    //-------------------------------------------------------------------------

    constructor(address LLTH_) VRFConsumerBase(VRFCoordinator, LINKToken) {
        _LLTH = IERC20(LLTH_);
        keyHash = 0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4;
        fee = 0.0001 * 10**18; // 0.0001 LINK
    }

    //-------------------------------------------------------------------------
    // VIEW FUNCTIONS
    //-------------------------------------------------------------------------

    function requestIdOf(address player) external view returns (bytes32) {
        return addressToRequestId[player];
    }

    function getBalance() external view returns (uint256) {
        return _LLTH.balanceOf(address(this));
    }

    function betOf(address player) external view returns (uint256) {
        require(player != address(0));
        return bets[player];
    }

    //-------------------------------------------------------------------------
    // SET FUNCTIONS
    //-------------------------------------------------------------------------

    function setLLTH(address LLTH_) external onlyOwner {
        _LLTH = IERC20(LLTH_);
    }

    function setMinMultiplier(uint256 minMultiplier_) external onlyOwner {
        minMultiplier = minMultiplier_;
    }

    function setMaxMultiplier(uint256 maxMultiplier_) external onlyOwner {
        maxMultiplier = maxMultiplier_;
    }

    //-------------------------------------------------------------------------
    // RANDOM NUMBER FUNCTIONS
    //-------------------------------------------------------------------------

    function getRandomNumber(address player) internal {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK.");
        bytes32 requestId = requestRandomness(keyHash, fee);
        addressToRequestId[player] = requestId;

        emit RequestIdIsCreated(player, requestId);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness)
        internal
        override
    {
        uint256 randomNumber = (randomness % (maxMultiplier.add(1) - minMultiplier)) +
            minMultiplier; // random number between 1 and 13
        requestIdToRandomNumber[requestId] = randomNumber;

        emit RandomIsArrived(requestId, randomNumber);
    }

    function getWinningMultiplier(address player)
        public
        view
        returns (uint256)
    {
        require(
            requestIdToRandomNumber[addressToRequestId[player]] > 1,
            "Random number must be between 2 and 13."
        );
        require(
            requestIdToRandomNumber[addressToRequestId[player]] < 14,
            "Random number must be between 2 and 13."
        );

        return requestIdToRandomNumber[addressToRequestId[player]];
    }

    //-------------------------------------------------------------------------
    // EXTERNAL FUNCTIONS
    //-------------------------------------------------------------------------

    // Called by front-end when placing bet. It saves player's data and tranfers their bet to this contract's address.
    function placeBet(uint256 bet, uint256 multiplier) external {
        require(multiplier >= 1, "Multiplier must be between 1 and 13.");
        require(multiplier < 14, "Multiplier must be between 1 and 13.");
        require(
            _LLTH.balanceOf(address(msg.sender)) >= bet,
            "Not enough $LLTH token in your wallet."
        );
        require(
            _LLTH.balanceOf(address(this)) >= bet.mul(multiplier),
            "Not enough $LLTH token in game's wallet."
        );

        _LLTH.transferFrom(msg.sender, address(this), bet);
        getRandomNumber(msg.sender);
        bets[msg.sender] = bet;
        multipliers[msg.sender] = multiplier;
    }

    function withdraw(uint256 amount) external onlyOwner {
        require(
            _LLTH.balanceOf(address(this)) >= amount,
            "Not enough $LLTH in game's wallet."
        );

        _LLTH.transfer(owner(), amount);
    }

    // Transfers prize, resets mappings and array.
    function closeRound(address player) external onlyOwner {
        require(player != address(0), "Address cannot be null.");

        if (multipliers[player] == getWinningMultiplier(player)) {
            uint256 amount = getWinningMultiplier(msg.sender)
                .mul(bets[player]);

            require(
                _LLTH.balanceOf(address(this)) >= amount,
                "Not enough $LLTH in game's wallet."
            );
            _LLTH.transfer(player, amount);
        }

        delete multipliers[player];
        delete bets[player];
        delete addressToRequestId[player];
    }
}
