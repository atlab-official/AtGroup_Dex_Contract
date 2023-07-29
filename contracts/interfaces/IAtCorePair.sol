pragma solidity >=0.5.0;
interface IAtCorePair {


    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint16 token0feePercent, uint16 token1FeePercent);
    function getAmountOut(uint amountIn, address tokenIn) external view returns (uint);
    function kLast() external view returns (uint);

    function setFeePercent(uint16 token0FeePercent, uint16 token1FeePercent) external;
    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data, address referrer) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}