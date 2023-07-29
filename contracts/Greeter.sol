//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract Greeter is IERC721Receiver{
    string private greeting;
    IERC721 public gNftAds; // gNFT address

    mapping(address => mapping(uint256 => uint256)) public _gNFTOwner;

    constructor(string memory _greeting, IERC721 gNft) {
        greeting = _greeting;
        gNftAds = gNft;
    }

    function greet() public view returns (string memory) {
        return greeting;
    }

    function setGreeting(string memory _greeting) public {
        greeting = _greeting;
    }

  function gNftBoost(uint256 tokenId, uint256 gNftId, uint256 lockDuration) external {
    uint256 nftMultiper = 0;
    // require(_gNFTOwner[msg.sender][tokenId] == 0, "position already gNft Boost");
    // require(ERC721._exists(tokenId), "invalid tokenId");
    // require(IERC721(gNftAds).ownerOf(gNftId) == msg.sender, "invalid gNFT tokenId");

    _gNFTOwner[msg.sender][tokenId] = gNftId;
    IERC721(gNftAds).safeTransferFrom(msg.sender, address(this), gNftId);
    
    // _updatePool();
    // _harvestPosition(tokenId, address(0));

    // StakingPosition storage position = _stakingPositions[tokenId];

    // // update position
    // position.gNftlockMultiplier = nftMultiper;
    // position.gNftLockDuration = lockDuration;
    // position.startgNftLockTime =  _currentBlockTimestamp();
    // _updateBoostMultiplierInfoAndRewardDebt(position);
    // emit GNftBoost(msg.sender, tokenId, gNftId, lockDuration);
  }

  function gNftUnboost(uint256 tokenId, uint256 gNftId) external {
    _gNFTOwner[msg.sender][tokenId] = 0;
    IERC721(gNftAds).safeTransferFrom(address(this), msg.sender, gNftId);
  }

  /**
    * @dev Automatically stakes transferred positions from a BasePool
  */
  function onERC721Received(address /*operator*/, address from, uint256 tokenId, bytes calldata /*data*/) external override returns (bytes4) {
    return this.onERC721Received.selector;
  }
}
