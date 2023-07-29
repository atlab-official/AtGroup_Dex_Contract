// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


/*
 * ARR is AtDex's native ERC20 token.
 * It has an hard cap and manages its own emissions and allocations.
 */
contract AUsdc is Ownable, ERC20("AtDex USDC", "AUSDC") {
  using SafeMath for uint256;

  uint256 public constant MAX_SUPPLY_LIMIT = 400_000_000 ether;

  address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;


  constructor(uint256 maxSupply_, uint256 initialSupply) {
    _mint(msg.sender, initialSupply);
  }

  /**
   * @dev Burns "amount" of AUsdt by sending it to BURN_ADDRESS
   */
  function burn(uint256 amount) external {
    _transfer(msg.sender, BURN_ADDRESS, amount);
  }

  function mint(uint256 amount) external {
    require(totalSupply() < MAX_SUPPLY_LIMIT, "over flow");
    _mint(msg.sender, amount);
  }

}