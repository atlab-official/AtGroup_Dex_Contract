// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IARRToken is IERC20{
  function lastEmissionTime() external view returns (uint256);

  function claimPipelineRewards(uint256 amount) external returns (uint256 effectiveAmount);
  function pipelineEmissionRate() external view returns (uint256);
  function burn(uint256 amount) external;
}