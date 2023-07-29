// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/projects/IARRToken.sol";


/*
 * ARR is AtDex's native ERC20 token.
 * It has an hard cap and manages its own emissions and allocations.
 */
contract ARRToken is Ownable, ERC20("Arroba token", "ARR"), IARRToken {
  using SafeMath for uint256;

  uint256 public constant MAX_EMISSION_RATE = 100 ether;
  uint256 public constant MAX_SUPPLY_LIMIT = 400_000_000 ether;
  uint256 public elasticMaxSupply; // Once deployed, controlled through governance only
  uint256 public emissionRate; // Token emission per second

  uint256 public override lastEmissionTime;
  uint256 public pipelineReserve; // Pending rewards for the pipeline

  uint256 public constant ALLOCATION_PRECISION = 100;
  // Allocations emitted over time. When < 100%, the rest is minted into the treasury (default 15%)
  uint256 public farmingAllocation = 50; // = 50%

  address public pipelineAddress;
  address public treasuryAddress;

  address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

  constructor(uint256 maxSupply_, uint256 initialSupply, uint256 initialEmissionRate, address treasuryAddress_) {
    require(initialEmissionRate <= MAX_EMISSION_RATE, "invalid emission rate");
    require(maxSupply_ <= MAX_SUPPLY_LIMIT, "invalid initial maxSupply");
    require(initialSupply < maxSupply_, "invalid initial supply");
    require(treasuryAddress_ != address(0), "invalid treasury address");

    elasticMaxSupply = maxSupply_;
    emissionRate = initialEmissionRate;
    treasuryAddress = treasuryAddress_;

    _mint(msg.sender, initialSupply);
  }


  /********************************************/
  /****************** EVENTS ******************/
  /********************************************/

  event ClaimPipelineRewards(uint256 amount);
  event AllocationsDistributed(uint256 pipelineShare, uint256 treasuryShare);
  event InitializePipelineAddress(address pipelineAddress);
  event InitializeEmissionStart(uint256 startTime);
  event UpdateAllocations(uint256 farmingAllocation, uint256 treasuryAllocation);
  event UpdateEmissionRate(uint256 previousEmissionRate, uint256 newEmissionRate);
  event UpdateMaxSupply(uint256 previousMaxSupply, uint256 newMaxSupply);
  event UpdateTreasuryAddress(address previousTreasuryAddress, address newTreasuryAddress);

  /***********************************************/
  /****************** MODIFIERS ******************/
  /***********************************************/

  /*
   * @dev Throws error if called by any account other than the pipeline
   */
  modifier onlyPipeline() {
    require(msg.sender == pipelineAddress, "ArrToken: caller is not the pipeline");
    _;
  }


  /**************************************************/
  /****************** PUBLIC VIEWS ******************/
  /**************************************************/

  /**
   * @dev Returns total pipeline allocation
   */
  function pipelineAllocation() public view returns (uint256) {
    return farmingAllocation;
  }

  /**
   * @dev Returns pipeline emission rate
   */
  function pipelineEmissionRate() public view override returns (uint256) {
    return emissionRate.mul(farmingAllocation).div(ALLOCATION_PRECISION);
  }

  /**
   * @dev Returns treasury allocation
   */
  function treasuryAllocation() public view returns (uint256) {
    return uint256(ALLOCATION_PRECISION).sub(pipelineAllocation());
  }


  /*****************************************************************/
  /******************  EXTERNAL PUBLIC FUNCTIONS  ******************/
  /*****************************************************************/

  /**
   * @dev Mint rewards and distribute it between pipeline and treasury
   *
   * Treasury share is directly minted to the treasury address
   * Pipeline incentives are minted into this contract and claimed later by the pipeline contract
   */
  function emitAllocations() public {
    uint256 circulatingSupply = totalSupply();
    uint256 currentBlockTimestamp = _currentBlockTimestamp();

    uint256 _lastEmissionTime = lastEmissionTime; // gas saving
    uint256 _maxSupply = elasticMaxSupply; // gas saving

    // if already up to date or not started
    if (currentBlockTimestamp <= _lastEmissionTime || _lastEmissionTime == 0) {
      return;
    }

    // if max supply is already reached or emissions deactivated
    if (_maxSupply <= circulatingSupply || emissionRate == 0) {
      lastEmissionTime = currentBlockTimestamp;
      return;
    }

    uint256 newEmissions = currentBlockTimestamp.sub(_lastEmissionTime).mul(emissionRate);

    // cap new emissions if exceeding max supply
    if(_maxSupply < circulatingSupply.add(newEmissions)) {
      newEmissions = _maxSupply.sub(circulatingSupply);
    }

    // calculate pipeline and treasury shares from new emissions
    uint256 pipelineShare = newEmissions.mul(pipelineAllocation()).div(ALLOCATION_PRECISION);
    // sub to avoid rounding errors
    uint256 treasuryShare = newEmissions.sub(pipelineShare);

    lastEmissionTime = currentBlockTimestamp;

    // add pipeline shares to its claimable reserve
    pipelineReserve = pipelineReserve.add(pipelineShare);
    // mint shares
    _mint(address(this), pipelineShare);
    _mint(treasuryAddress, treasuryShare);

    emit AllocationsDistributed(pipelineShare, treasuryShare);
  }

  /**
   * @dev Sends to Pipeline contract the asked "amount" from pipelineReserve
   *
   * Can only be called by the PipelineContract
   */
  function claimPipelineRewards(uint256 amount) external override onlyPipeline returns (uint256 effectiveAmount) {
    // update emissions
    emitAllocations();

    // cap asked amount with available reserve
    effectiveAmount = Math.min(pipelineReserve, amount);

    // if no rewards to transfer
    if (effectiveAmount == 0) {
      return effectiveAmount;
    }

    // remove claimed rewards from reserve and transfer to pipeline
    pipelineReserve = pipelineReserve.sub(effectiveAmount);
    _transfer(address(this), pipelineAddress, effectiveAmount);
    emit ClaimPipelineRewards(effectiveAmount);
  }

  /**
   * @dev Burns "amount" of ARR by sending it to BURN_ADDRESS
   */
  function burn(uint256 amount) external override {
    _transfer(msg.sender, BURN_ADDRESS, amount);
  }

  /*****************************************************************/
  /****************** EXTERNAL OWNABLE FUNCTIONS  ******************/
  /*****************************************************************/

  /**
   * @dev Setup Pipeline contract address
   *
   * Can only be initialized once
   * Must only be called by the owner
   */
  function initializePipelineAddress(address pipelineAddress_) external onlyOwner {
    require(pipelineAddress == address(0), "initializePipelineAddress: pipeline already initialized");
    require(pipelineAddress_ != address(0), "initializePipelineAddress: pipeline initialized to zero address");

    pipelineAddress = pipelineAddress_;
    emit InitializePipelineAddress(pipelineAddress_);
  }

  /**
   * @dev Set emission start time
   *
   * Can only be initialized once
   * Must only be called by the owner
   */
  function initializeEmissionStart(uint256 startTime) external onlyOwner {
    require(lastEmissionTime == 0, "initializeEmissionStart: emission start already initialized");
    require(_currentBlockTimestamp() < startTime, "initializeEmissionStart: invalid");

    lastEmissionTime = startTime;
    emit InitializeEmissionStart(startTime);
  }

  /**
   * @dev Updates emission allocations between farming incentives, legacy holders and treasury (remaining share)
   *
   * Must only be called by the owner
   */
  function updateAllocations(uint256 farmingAllocation_) external onlyOwner {
    // apply emissions before changes
    emitAllocations();

    // total sum of allocations can't be > 100%
    uint256 totalAllocationsSet = farmingAllocation_;
    require(totalAllocationsSet <= 100, "updateAllocations: total allocation is too high");

    // set new allocations
    farmingAllocation = farmingAllocation_;

    emit UpdateAllocations(farmingAllocation_, treasuryAllocation());
  }

  /**
   * @dev Updates ARR emission rate per second
   *
   * Must only be called by the owner
   */
  function updateEmissionRate(uint256 emissionRate_) external onlyOwner {
    require(emissionRate_ <= MAX_EMISSION_RATE, "updateEmissionRate: can't exceed maximum");

    // apply emissions before changes
    emitAllocations();

    emit UpdateEmissionRate(emissionRate, emissionRate_);
    emissionRate = emissionRate_;
  }

  /**
   * @dev Updates ARR max supply
   *
   * Must only be called by the owner
   */
  function updateMaxSupply(uint256 maxSupply_) external onlyOwner {
    require(maxSupply_ >= totalSupply(), "updateMaxSupply: can't be lower than current circulating supply");
    require(maxSupply_ <= MAX_SUPPLY_LIMIT, "updateMaxSupply: invalid maxSupply");

    emit UpdateMaxSupply(elasticMaxSupply, maxSupply_);
    elasticMaxSupply = maxSupply_;
  }

  /**
   * @dev Updates treasury address
   *
   * Must only be called by owner
   */
  function updateTreasuryAddress(address treasuryAddress_) external onlyOwner {
    require(treasuryAddress_ != address(0), "updateTreasuryAddress: invalid address");

    emit UpdateTreasuryAddress(treasuryAddress, treasuryAddress_);
    treasuryAddress = treasuryAddress_;
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