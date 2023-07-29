// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6;

interface IExtendPoolFactory {
  function emergencyRecoveryAddress() external view returns (address);
  function feeAddress() external view returns (address);
  function getExtendPoolFee(address nitroPoolAddress, address ownerAddress) external view returns (uint256);
  function publishExtendPool(address nftAddress) external;
  function setExtendPoolOwner(address previousOwner, address newOwner) external;
}