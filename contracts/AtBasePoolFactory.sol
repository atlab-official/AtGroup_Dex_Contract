// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IAtBasePipeline.sol";
import "./interfaces/projects/IesARRToken.sol";
import "./BasePool.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";


contract AtBasePoolFactory {
  IAtBasePipeline public immutable pipeline; // Address of the pipeline
  IERC20 public immutable arrToken;
  IesARRToken public immutable esArrToken;
  IERC721 public immutable gNft;

  mapping(address => address) public getPool;
  address[] public pools;

  constructor(
    IAtBasePipeline pipeline_,
    IERC20 arrToken_,
    IesARRToken esArrToken_,
    IERC721 gNft_
  ) {
    pipeline = pipeline_;
    arrToken = arrToken_;
    esArrToken = esArrToken_;
    gNft = gNft_;
  }

  event PoolCreated(address indexed lpToken, address pool);

  function poolsLength() external view returns (uint256) {
    return pools.length;
  }

  function createPool(address lpToken) external returns (address pool){
    require(getPool[lpToken] == address(0), "pool exists");

    bytes memory bytecode_ = _bytecode();
    bytes32 salt = keccak256(abi.encodePacked(lpToken));
    /* solhint-disable no-inline-assembly */
    assembly {
        pool := create2(0, add(bytecode_, 32), mload(bytecode_), salt)
    }
    require(pool != address(0), "failed");

    BasePool(pool).initialize(pipeline, arrToken, esArrToken, IERC20(lpToken), gNft);
    getPool[lpToken] = pool;
    pools.push(pool);

    emit PoolCreated(lpToken, pool);
  }

  function _bytecode() internal pure virtual returns (bytes memory) {
    return type(BasePool).creationCode;
  }
}