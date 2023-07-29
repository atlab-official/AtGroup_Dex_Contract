// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./interfaces/projects/IesARRToken.sol";

contract LinearWallet is Ownable {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;
  using EnumerableSet for EnumerableSet.AddressSet;

  mapping(address => uint256) public beneficiariesShare;
  EnumerableSet.AddressSet private _beneficiariesWallet;

  IERC20 public immutable arrToken;
  IesARRToken public immutable esArrToken;
  address public reserveWallet;

  bool public inesArr;

  uint256 public constant MAX_TOTAL_SHARE = 10000;
  uint256 public totalShare;

  uint256 public released;

  bool public nonRevocable;

  uint256 public constant START_TIME = 1670457600;
  uint256 public constant DURATION = 3 * 365 days; // 3 years

  constructor (IERC20 arrToken_, IesARRToken esArrToken_, bool inesArr_, address reserveWallet_){
    arrToken = arrToken_;
    esArrToken = esArrToken_;
    inesArr = inesArr_;
    reserveWallet = reserveWallet_;

    if(inesArr_) {
      arrToken_.approve(address(esArrToken_), type(uint256).max);
    }
  }

  event Released(uint256 releasedAmount);
  event RevokeVesting();

  function nbBeneficiaries() external view returns (uint256){
    return _beneficiariesWallet.length();
  }

  function beneficiary(uint256 index) external view returns (address){
    return _beneficiariesWallet.at(index);
  }

  function releasable() public view returns (uint256){
    if (block.timestamp < START_TIME) return 0;
    uint256 _balance = arrToken.balanceOf(address(this));
    if (block.timestamp > START_TIME.add(DURATION)) return _balance;

    return _balance.add(released).mul(block.timestamp.sub(START_TIME)).div(DURATION).sub(released);
  }

  function release() external {
    _release();
  }

  function updateBeneficiary(address wallet, uint256 newShare) external onlyOwner {
    _release();

    totalShare = totalShare.sub(beneficiariesShare[wallet]).add(newShare);
    require(totalShare <= MAX_TOTAL_SHARE, "allocation too high");
    beneficiariesShare[wallet] = newShare;
    if (newShare == 0) _beneficiariesWallet.remove(wallet);
    else _beneficiariesWallet.add(wallet);
  }

  function updateReserveWallet(address newReserveWallet) external onlyOwner {
    reserveWallet = newReserveWallet;
  }


  function setToNonRevocable() external onlyOwner {
    nonRevocable = true;
  }

  function revoke() external onlyOwner {
    require(!nonRevocable, "revoke not allowed");
    uint256 _balance = arrToken.balanceOf(address(this));
    arrToken.transfer(owner(), _balance);
    emit RevokeVesting();
  }

  function _release() internal {
    uint256 nbBeneficiaries_ = _beneficiariesWallet.length();
    uint256 releasable_ = releasable();

    uint256 remaining = releasable_;
    for (uint256 i = 0; i < nbBeneficiaries_; ++i) {
      address wallet = _beneficiariesWallet.at(i);
      uint256 beneficiaryShare = beneficiariesShare[wallet];
      uint256 beneficiaryAmount = releasable_.mul(beneficiaryShare).div(MAX_TOTAL_SHARE);
      remaining = remaining.sub(beneficiaryAmount);
      if(inesArr && beneficiaryAmount > 0) esArrToken.convertTo(beneficiaryAmount, wallet);
      else if(!inesArr) arrToken.safeTransfer(wallet, beneficiaryAmount);
    }

    if (remaining > 0) {
      esArrToken.convertTo(remaining, reserveWallet);
    }
    released = released.add(releasable_);
    emit Released(releasable_);
  }
}