// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./ExtendPool.sol";
import "./interfaces/IExtendPoolFactory.sol";
import "./interfaces/projects/IARRToken.sol";
import "./interfaces/projects/IesARRToken.sol";


contract ExtendPoolFactory is Ownable, IExtendPoolFactory {
  using EnumerableSet for EnumerableSet.AddressSet;

  IARRToken public arrToken; // ARRToken contract's address
  IesARRToken public esArrToken; // esArrToken contract's address

  EnumerableSet.AddressSet internal _nitroPools; // all nitro pools
  EnumerableSet.AddressSet private _publishedExtendPools; // all published nitro pools
  mapping(address => EnumerableSet.AddressSet) private _nftPoolPublishedExtendPools; // published nitro pools per BasePool
  mapping(address => EnumerableSet.AddressSet) internal _ownerExtendPools; // nitro pools per owner

  uint256 public constant MAX_DEFAULT_FEE = 100; // (1%) max authorized default fee
  uint256 public defaultFee; // default fee for nitro pools (*1e2)
  address public override feeAddress; // to receive fees when defaultFee is set
  EnumerableSet.AddressSet internal _exemptedAddresses; // owners or nitro addresses exempted from default fee

  address public override emergencyRecoveryAddress; // to recover rewards from emergency closed nitro pools


  constructor(IARRToken arrToken_, IesARRToken esArrToken_, address emergencyRecoveryAddress_, address feeAddress_){
    require(emergencyRecoveryAddress_ != address(0) && feeAddress_ != address(0), "invalid");

    arrToken = arrToken_;
    esArrToken = esArrToken_;
    emergencyRecoveryAddress = emergencyRecoveryAddress_;
    feeAddress = feeAddress_;
  }


  /********************************************/
  /****************** EVENTS ******************/
  /********************************************/

  event CreateExtendPool(address nitroAddress);
  event PublishExtendPool(address nitroAddress);
  event SetDefaultFee(uint256 fee);
  event SetFeeAddress(address feeAddress);
  event SetEmergencyRecoveryAddress(address emergencyRecoveryAddress);
  event SetExemptedAddress(address exemptedAddress, bool isExempted);
  event SetExtendPoolOwner(address previousOwner, address newOwner);


  /***********************************************/
  /****************** MODIFIERS ******************/
  /***********************************************/

  modifier nitroPoolExists(address nitroPoolAddress) {
    require(_nitroPools.contains(nitroPoolAddress), "unknown nitroPool");
    _;
  }


  /**************************************************/
  /****************** PUBLIC VIEWS ******************/
  /**************************************************/

  /**
   * @dev Returns the number of nitroPools
   */
  function nitroPoolsLength() external view returns (uint256) {
    return _nitroPools.length();
  }

  /**
   * @dev Returns a nitroPool from its "index"
   */
  function getExtendPool(uint256 index) external view returns (address) {
    return _nitroPools.at(index);
  }

  /**
   * @dev Returns the number of published nitroPools
   */
  function publishedExtendPoolsLength() external view returns (uint256) {
    return _publishedExtendPools.length();
  }

  /**
   * @dev Returns a published nitroPool from its "index"
   */
  function getPublishedExtendPool(uint256 index) external view returns (address) {
    return _publishedExtendPools.at(index);
  }

  /**
   * @dev Returns the number of published nitroPools linked to "nftPoolAddress" BasePool
   */
  function nftPoolPublishedExtendPoolsLength(address nftPoolAddress) external view returns (uint256) {
    return _nftPoolPublishedExtendPools[nftPoolAddress].length();
  }

  /**
   * @dev Returns a published nitroPool linked to "nftPoolAddress" from its "index"
   */
  function getNftPoolPublishedExtendPool(address nftPoolAddress, uint256 index) external view returns (address) {
    return _nftPoolPublishedExtendPools[nftPoolAddress].at(index);
  }

  /**
   * @dev Returns the number of nitroPools owned by "userAddress"
   */
  function ownerExtendPoolsLength(address userAddress) external view returns (uint256) {
    return _ownerExtendPools[userAddress].length();
  }

  /**
   * @dev Returns a nitroPool owned by "userAddress" from its "index"
   */
  function getOwnerExtendPool(address userAddress, uint256 index) external view returns (address) {
    return _ownerExtendPools[userAddress].at(index);
  }

  /**
   * @dev Returns the number of exemptedAddresses
   */
  function exemptedAddressesLength() external view returns (uint256) {
    return _exemptedAddresses.length();
  }

  /**
   * @dev Returns an exemptedAddress from its "index"
   */
  function getExemptedAddress(uint256 index) external view returns (address) {
    return _exemptedAddresses.at(index);
  }

  /**
   * @dev Returns if a given address is in exemptedAddresses
   */
  function isExemptedAddress(address checkedAddress) external view returns (bool) {
    return _exemptedAddresses.contains(checkedAddress);
  }

  /**
   * @dev Returns the fee for "nitroPoolAddress" address
   */
  function getExtendPoolFee(address nitroPoolAddress, address ownerAddress) external view override returns (uint256) {
    if(_exemptedAddresses.contains(nitroPoolAddress) || _exemptedAddresses.contains(ownerAddress)) {
      return 0;
    }
    return defaultFee;
  }


  /*****************************************************************/
  /******************  EXTERNAL PUBLIC FUNCTIONS  ******************/
  /*****************************************************************/

  /**
   * @dev Deploys a new Extend Pool
   */
  function createExtendPool(
    address nftPoolAddress, IERC20 rewardsToken1, IERC20 rewardsToken2, ExtendPool.Settings calldata settings
  ) external virtual returns (address nitroPool) {

    // Initialize new nitro pool
    nitroPool = address(
      new ExtendPool(
        arrToken, esArrToken, msg.sender, IBasePool(nftPoolAddress),
          rewardsToken1, rewardsToken2, settings
      )
    );

    // Add new nitro
    _nitroPools.add(nitroPool);
    _ownerExtendPools[msg.sender].add(nitroPool);

    emit CreateExtendPool(nitroPool);
  }

  /**
   * @dev Publish a Extend Pool
   *
   * Must only be called by the Extend Pool contract
   */
  function publishExtendPool(address nftAddress) external override nitroPoolExists(msg.sender) {
    _publishedExtendPools.add(msg.sender);

    _nftPoolPublishedExtendPools[nftAddress].add(msg.sender);

    emit PublishExtendPool(msg.sender);
  }

  /**
   * @dev Transfers a Extend Pool's ownership
   *
   * Must only be called by the ExtendPool contract
   */
  function setExtendPoolOwner(address previousOwner, address newOwner) external override nitroPoolExists(msg.sender) {
    require(_ownerExtendPools[previousOwner].remove(msg.sender), "invalid owner");
    _ownerExtendPools[newOwner].add(msg.sender);

    emit SetExtendPoolOwner(previousOwner, newOwner);
  }

  /**
   * @dev Set nitroPools default fee (when adding rewards)
   *
   * Must only be called by the owner
   */
  function setDefaultFee(uint256 newFee) external onlyOwner {
    require(newFee <= MAX_DEFAULT_FEE, "invalid amount");

    defaultFee = newFee;
    emit SetDefaultFee(newFee);
  }

  /**
   * @dev Set fee address
   *
   * Must only be called by the owner
   */
  function setFeeAddress(address feeAddress_) external onlyOwner {
    require(feeAddress_ != address(0), "zero address");

    feeAddress = feeAddress_;
    emit SetFeeAddress(feeAddress_);
  }

  /**
   * @dev Add or remove exemptedAddresses
   *
   * Must only be called by the owner
   */
  function setExemptedAddress(address exemptedAddress, bool isExempted) external onlyOwner {
    require(exemptedAddress != address(0), "zero address");

    if(isExempted) _exemptedAddresses.add(exemptedAddress);
    else _exemptedAddresses.remove(exemptedAddress);

    emit SetExemptedAddress(exemptedAddress, isExempted);
  }

  /**
   * @dev Set emergencyRecoveryAddress
   *
   * Must only be called by the owner
   */
  function setEmergencyRecoveryAddress(address emergencyRecoveryAddress_) external onlyOwner {
    require(emergencyRecoveryAddress_ != address(0), "zero address");

    emergencyRecoveryAddress = emergencyRecoveryAddress_;
    emit SetEmergencyRecoveryAddress(emergencyRecoveryAddress_);
  }


  /********************************************************/
  /****************** INTERNAL FUNCTIONS ******************/
  /********************************************************/

  /**
   * @dev Utility function to get the current block timestamp
   */
  function _currentBlockTimestamp() internal view virtual returns (uint256) {
    /* solhint-disable not-rely-on-time */
    return block.timestamp;
  }
}