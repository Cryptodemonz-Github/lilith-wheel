# CryptoDemonz, Wheel Of Destiny

## getRandomNumber
It asks for a random number from Chainlink with calling Chainlink's requestRandomness function. RequestId and user's address stored in a a mapping. RequestId is emitted for the front-end by an event.
``` javascript
    function getRandomNumber(address player) internal {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK.");
        bytes32 requestId = requestRandomness(keyHash, fee);
        addressToRequestId[player] = requestId;

        emit RequestIdIsCreated(player, requestId);
    }
```

## fulfillRandomness
It's an overriden Chainlink callback function, called when random number is received when verified. It creates 2 more random numbers out of that 1 verified random number that is generated by Chainlink. It stores the 3 random number as a Combination struct in a mapping where requestId is the key. When these 3 random numbers a generated, this function calls the prize calculator funtion and emits the random numbers for the front-end by an event.   
``` javascript
    function fulfillRandomness(bytes32 requestId, uint256 randomness)
        internal
        override
    {
        uint256 randomNumber = (randomness % (maxMultiplier.add(1) - minMultiplier)) +
            minMultiplier; // random number between 2 and 13
        requestIdToRandomNumber[requestId] = randomNumber;

        emit RandomIsArrived(requestId, randomNumber);
    }
```

## placeBet
This function is called by the front-end when the user decides to place a bet. It saves player's data and tranfers their bet to this contract address.
``` javascript
    function placeBet(uint256 bet, uint256 multiplier) external {
        require(multiplier > 1, "Multiplier must be between 2 and 13.");
        require(multiplier < 14, "Multiplier must be between 2 and 13.");
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

```

## placeWild
It's called by rhe front-end after user's latest received number was 1. There's no placing bet, the bet remains the same from the last round but new random number is generated.
``` javascript
    function placeWild(uint256 multiplier) external {
        require(
            requestIdToRandomNumber[addressToRequestId[msg.sender]] == 1,
            "Players last winning number must be 1."
        );
        require(multiplier >= 1, "Multiplier must be between 1 and 13.");
        require(multiplier < 14, "Multiplier must be between 1 and 13.");
        require(
            _LLTH.balanceOf(address(this)) >= bets[msg.sender].mul(multiplier),
            "Not enough $LLTH token in game's wallet."
        );

        getRandomNumber(msg.sender);
        multipliers[msg.sender] = multiplier;
    }
 ```

## withdraw
By calling this function, the owner account can withdraw the amount given as input from the contract's LLTH balance.
``` javascript
    function withdraw(uint256 amount) external onlyOwner {
        require(
            _LLTH.balanceOf(address(this)) >= amount,
            "Not enough $LLTH in game's wallet."
        );

        _LLTH.transfer(owner(), amount);
    }
```

## closeRound
When round is over and the random number is arrived, it transfers prize if there's any and resets mappings and array.
``` javascript
    function closeRound(address player) external onlyOwner {
        require(player != address(0), "Address cannot be null.");

        if (multipliers[player] == getWinningMultiplier(player)) {
            uint256 amount = getWinningMultiplier(msg.sender).mul(bets[player]);

            require(
                _LLTH.balanceOf(address(this)) >= amount,
                "Not enough $LLTH in game's wallet."
            );
            _LLTH.transfer(player, amount);
            delete multipliers[player];
            delete bets[player];
            delete addressToRequestId[player];
        } else if (multipliers[player] == getWinningMultiplier(player)) {
            delete multipliers[player];
            delete addressToRequestId[player];
        }
    }
```
