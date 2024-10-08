// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.7.3/contracts/utils/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.7.3/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

contract Lotto is ERC20 Ownable, VRFConsumerBase {
    using SafeMath for uint256;

    // -- MApping of plyaers to their chosen numbers
    mapping(address => uint256[15]) public playerNumbers;

    // -- Mapping of numbers to the players who choose them
    mapping(uint256 => address) public numbersOwners;

    // -- Array of all numbers choosen by players
    uint256[] public choosenNumbers

    // -- The current prize pot
    uint256 public prizePot;

    // -- The current fee balance;
    uint256 public feeBalance;

    The manager's fee wallet
    address public feeWallet

    // -- The timestamp of the nextdray
    uint256 public nextDraw

    // -- The numbers drawn in the previous round
    uint256[15] public previousDraw;

    // -- Event emitted when a player buys a ticket
    event TicketBought(address player, uint256[15] numbers);

    // -- Event emitted when the lottery is drawn
    event LotteryDrawn(uint256[15] numbers, address winner);

    // -- Event emitted when the prize pot is withdrawn
    event PrizePotWithdrawn(address winner, uint256 amount);

    // -- Event emitted when the fee balance is withdrawn
    event FeeBalanceWithdrawn(address recipient, uint256 amount);

    // Chainlink VRF variables
    bytes32 internal keyHash;
    uint256 internal fee;
    uint256[15] internal randomNumbers;


        // -- Constructor
    constructor(address _feeWallet) {
        feeWallet = _feeWallet;
        nextDraw = getNextDrawTimestamp();
    }

    // -- Function to buy a ticket
    function buyTicket(uint256[15] memory numbers) public payable {
        require(msg.value == 0.0005 ether, "Invalid ticket price");
        require(getCurrentTimestamp() < nextDraw, "Ticket sales are closed for this round");
        require(chosenNumbers.length < 100, "Maximum number of tickets reached");

        // Check if the numbers are valid
        for (uint256 i = 0; i < numbers.length; i++) {
            require(numbers[i] >= 0 && numbers[i] <= 25, "Invalid number");
            require(numberOwners[numbers[i]] == address(0), "Number already chosen");
        }

        // Update the player's numbers and the number owners
        playerNumbers[msg.sender] = numbers;
        for (uint256 i = 0; i < numbers.length; i++) {
            numberOwners[numbers[i]] = msg.sender;
            chosenNumbers.push(numbers[i]);
        }

        // Update the prize pot and fee balance
        prizePot += 0.00045 ether;
        feeBalance += 0.00005 ether;

        emit TicketBought(msg.sender, numbers);
    }
    // -- Function to draw the lottery
    function drawLottery() public {
        require(getCurrentTimestamp() >= nextDraw, "Lottery draw is not yet due");
        require(chosenNumbers.length >= 100, "Not enough tickets sold");

        // Generate the random numbers
        uint256[15] memory numbers;
        for (uint256 i = 0; i < numbers.length; i++) {
            numbers[i] = uint256(keccak256(abi.encodePacked(block.timestamp))) % 26;
            while (numberOwners[numbers[i]] != address(0)) {
                numbers[i] = uint256(keccak256(abi.encodePacked(block.timestamp))) % 26;
            }
        }

        // Find the winner
        address winner;
        for (uint256 i = 0; i < chosenNumbers.length; i++) {
            if (playerNumbers[numberOwners[chosenNumbers[i]]] == numbers) {
                winner = numberOwners[chosenNumbers[i]];
                break;
            }
        }

        // Update the previous draw and next draw timestamp
        previousDraw = numbers;
        nextDraw = getNextDrawTimestamp();

        // Reset the chosen numbers and number owners
        delete chosenNumbers;
        for (uint256 i = 0; i < numbers.length; i++) {
            delete numberOwners[numbers[i]];
        }

        emit LotteryDrawn(numbers, winner);

        // If there is a winner, transfer the prize pot
        if (winner != address(0)) {
            payable(winner).transfer(prizePot);
            emit PrizePotWithdrawn(winner, prizePot);
            prizePot = 0;
        }
    }
    // -- Function to withdraw the fee balance
    function withdrawFeeBalance() public onlyOwner {
        require(feeBalance > 0, "No fee balance to withdraw");
        payable(feeWallet).transfer(feeBalance);
        emit FeeBalanceWithdrawn(feeWallet, feeBalance);
        feeBalance = 0;
    }

    // Function to get the current timestamp
    function getCurrentTimestamp() internal view returns (uint256) {
        return block.timestamp;
    }

    // Function to get the next draw timestamp
    function getNextDrawTimestamp() internal view returns (uint256) {
        // Calculate the next Sunday at 20:00 UTC
        uint256 nextSunday = (getCurrentTimestamp() / 604800) * 604800 + 72000;
        if (nextSunday < getCurrentTimestamp()) {
            nextSunday += 604800;
        }
        return nextSunday;
    }
}
