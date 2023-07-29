// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface IPoolOperator is IERC721Receiver {
  function onNFTHarvest(address operator, address to, uint256 tokenId, uint256 arrAmount, uint256 esArrAmount) external returns (bool);
  function onNFTAddToPosition(address operator, uint256 tokenId, uint256 lpAmount) external returns (bool);
  function onNFTWithdraw(address operator, uint256 tokenId, uint256 lpAmount) external returns (bool);
}