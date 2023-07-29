/* 
  Copyright Statement

  gNFT is an NFT project created by AtDex. The following is our copyright statement for NFT:

  i. You own the NFT. Each gNFT on the ZkSync Era. When you purchase an NFT, you own the underlying Art completely. Ownership of the NFT is mediated entirely by the Smart Contract and the Ethereum Network: at no point may we seize, freeze, or otherwise modify the ownership of any gNFT.

  ii. Personal Use. Subject to your continued compliance with these Terms, AtDex LTD grants you a worldwide, royalty-free license to use, copy, and display the purchased Art, along with any extensions that you choose to create or use, solely for the following purposes: (i) for your own personal, non-commercial use; (ii) as part of a marketplace that permits the purchase and sale of your gNFT, provided that the marketplace cryptographically verifies each gNFT owner’s rights to display the Art for their gNFT to ensure that only the actual owner can display the Art; or (iii) as part of a third party website or application that permits the inclusion, involvement, or participation of your gNFT, provided that the website/application cryptographically verifies each gNFT owner’s rights to display the Art for their gNFT to ensure that only the actual owner can display the Art, and provided that the Art is no longer visible once the owner of the gNFT leaves the website/application.

  iii. Commercial Use. Subject to your continued compliance with these Terms, AtDex LTD grants you an unlimited, worldwide license to use, copy, and display the purchased Art for the purpose of creating derivative works based upon the Art (“Commercial Use”). Examples of such Commercial Use would e.g. be the use of the Art to produce and sell merchandise products (T-Shirts etc.) displaying copies of the Art. For the sake of clarity, nothing in this Section will be deemed to restrict you from (i) owning or operating a marketplace that permits the use and sale of gNFT generally, provided that the marketplace cryptographically verifies each gNFT owner’s rights to display the Art for their gNFT to ensure that only the actual owner can display the Art; (ii) owning or operating a third party website or application that permits the inclusion, involvement, or participation of gNFT generally, provided that the third party website or application cryptographically verifies each gNFT owner’s rights to display the Art for their gNFT to ensure that only the actual owner can display the Art, and provided that the Art is no longer visible once the owner of the Purchased gNFT leaves the website/application; or (iii) earning revenue from any of the foregoing.

  iiii. The holder of a gNFT can claim the CC0 copyright. Once the holder once does so, they will share the copyright of the NFT free to the world. The CC0 copyright is irreversible and will override the copyright notice in the i. ii. iii. content. 
*/

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./ERC721A.sol";

contract gNFT is Ownable, ERC721A {
    using ECDSA for bytes32;
    using SafeERC20 for IERC20;


    //Whitelist Merkle Root
    bytes32 public merkleRoot;

    //The quantity for WL.
    uint256 public WL_QUANTITY = 800;

    //MAX Supply.
    uint256 public constant NFT_MAX_INDEX = 1000;

    //How many WL have been minted.
    uint256 public WL_MINTED;


    //Takes place time of whitelist sale.
    uint256 public WL_STARTING_TIMESTAMP; 


    //Whitelist sale period.
    uint256 public WL_PERIOD = 24 * 3600;


    //Minted by user in WLsale.
    mapping(address => uint256) public userToHasMintedWL;

    mapping(address => bool) public hasMinted;

    //Metadata reveal state
    bool public REVEALED = false;

    bool public open_mint = true;

    //Token Base URI
    string public BASE_URI;

    modifier notZeroAddress(address addr) {
        if (addr == address(0)) {
            revert NotZeroAddress(addr);
        }
        _;
    }

    constructor(string memory uri, uint256 ts, bytes32 root) ERC721A("AtDex Gnesis NFT", "gNFT", 1000) {
        BASE_URI = uri;
        WL_STARTING_TIMESTAMP = ts;
        merkleRoot = root;

    } 

    /*------------------------------- views -------------------------------*/

    function _baseURI() internal view override(ERC721A) returns (string memory) {
        return BASE_URI;
    }

    /*------------------------------- writes -------------------------------*/


    function mintWL(uint256 quantity, bytes32[] calldata merkleProof) public {
        if (block.timestamp <= WL_STARTING_TIMESTAMP) {
            revert WLSaleNotStart(block.timestamp, WL_STARTING_TIMESTAMP);
        }

        if (block.timestamp > WL_STARTING_TIMESTAMP + WL_PERIOD) {
            revert WlMintingFinished(block.timestamp, WL_STARTING_TIMESTAMP + WL_PERIOD);
        }

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        bool valid = MerkleProof.verify(merkleProof, merkleRoot, leaf);
        if (!valid && !open_mint) {
            revert MerkleProofFail();
        }
        
        if (WL_MINTED + quantity > WL_QUANTITY) {
            revert MaxSupplyWl(WL_MINTED + quantity, WL_QUANTITY);
        }

        if (hasMinted[msg.sender]) {
            revert MerkleProofFail();
        }
         

        userToHasMintedWL[msg.sender] = userToHasMintedWL[msg.sender] + quantity;
        hasMinted[msg.sender] = true;
        WL_MINTED = WL_MINTED + quantity;

        //Mint them
        _safeMint(msg.sender, quantity);

        emit MintWL(msg.sender, quantity);
    }

    //send remaining NFTs to pool
    function devMint(address dev_Add) external onlyOwner {
        if (block.timestamp < WL_STARTING_TIMESTAMP + WL_PERIOD) {
            revert WLNotFinished(block.timestamp, WL_STARTING_TIMESTAMP + WL_PERIOD);
        }
        uint256 leftOver = NFT_MAX_INDEX - totalSupply();
        _safeMint(dev_Add, leftOver);

        emit DevMint(leftOver);
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory baseURI = _baseURI();
        return baseURI;
    }

    //send remaining NFTs to pool
    function devMintSafe(address dev_Add, uint leftNum) external onlyOwner {
        if (block.timestamp < WL_STARTING_TIMESTAMP + WL_PERIOD) {//mainnet WL_STARTING_TIMESTAMP + 86400
            revert WLNotFinished(block.timestamp, WL_STARTING_TIMESTAMP + WL_PERIOD);
        }
        uint256 leftOver = NFT_MAX_INDEX - totalSupply();
        if (leftNum > leftOver) {
            revert DevMintOver(leftNum, leftOver);
        }
        _safeMint(dev_Add, leftNum);
        
        emit DevMint(leftNum);
    }



    function setStartTime(uint256 startTime) external onlyOwner {
        WL_STARTING_TIMESTAMP = startTime;

        emit SetStartTime(startTime); 
    }

    function setOpenMint(bool open) external onlyOwner {
        open_mint = open;
    }

    function setWLPeriod(uint256 wlPeriod) external onlyOwner {
        WL_PERIOD = wlPeriod;

        emit SetWLPeriod(wlPeriod); 
    }


    function setWLSupply(uint256 quantity) external onlyOwner {
        WL_QUANTITY = quantity;

        emit SetWLSupply(quantity);
    }

    
    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;

        emit SetMerkleRoot(_merkleRoot);
    }

    function setBaseURI(string memory baseURI_, bool _revealed) external onlyOwner {
        BASE_URI = baseURI_;
        REVEALED = _revealed;

        emit SetBaseURI(baseURI_, _revealed);
    }

    /*------------------------------- errors -------------------------------*/
    
    error CallIsAnContract(address originCaller, address caller);
    error WLSaleNotStart(uint256 timestamp, uint256 startTime);
    error WLNotFinished(uint256 timestamp, uint256 psFinishTime);
    error MaxSupplyWl(uint256 mintNum, uint256 wlNum);
    error WlMintOverMax(uint256 mintNum);
    error WlMintingFinished(uint256 timestamp, uint256 wlFinishTime);       
    error NotZeroAddress(address addr); 
    error MerkleProofFail();
    error DevMintOver(uint256 leftNum, uint256 leftOver);

    /*------------------------------- events -------------------------------*/
    
    event MintWL(address minter, uint256 quantity);
    event DevMint(uint256 quantity);
    event SetWLPeriod(uint256 wlPeriod);
    event SetStartTime(uint256 startTime); 
    event SetWLSupply(uint256 quantity);
    event SetMerkleRoot(bytes32 _merkleRoot);
    event SetBaseURI(string baseURI, bool revealed);
}