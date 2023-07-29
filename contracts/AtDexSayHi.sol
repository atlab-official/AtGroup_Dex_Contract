// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/// @title AtDexSayHi
/// twitter https://twitter.com/AtDex_Official
/// discord discord.atdex.org
/// website https://atdex.org/
contract AtDexSayHi {

    uint256 public constant MAX_LUCKY_GUY = 50;
    uint256 public luckyGuy;
    mapping(address => bool) public hasLuck;
    mapping(address => uint256) public luckyValue;
    function lucky() public payable {
        require(luckyGuy < MAX_LUCKY_GUY, "over");
        require(!hasLuck[msg.sender], "lucky lucky");
        luckyGuy++;
        hasLuck[msg.sender] = true;
        luckyValue[msg.sender] = msg.value;
    }

    receive() external payable {

    }

}