// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { ILiquidationSource } from "pt-v5-liquidator-interfaces/ILiquidationSource.sol";
import { ILiquidationPair } from "pt-v5-liquidator-interfaces/ILiquidationPair.sol";
import { IFlashSwapCallback } from "pt-v5-liquidator-interfaces/IFlashSwapCallback.sol";

/// @notice Thrown when the actual swap amount in exceeds the user defined maximum amount in
/// @param amountInMax The user-defined max amount in
/// @param amountIn The actual amount in
error SwapExceedsMax(uint256 amountInMax, uint256 amountIn);

contract TpdaLiquidationPair is ILiquidationPair {

    ILiquidationSource public immutable source;
    uint256 public immutable targetAuctionPeriod;
    IERC20 internal immutable _tokenIn;
    IERC20 internal immutable _tokenOut;
    uint256 public immutable smoothingFactor;    

    uint64 public lastAuctionAt;
    uint192 public lastAuctionPrice;  

    constructor (
        ILiquidationSource _source,
        address __tokenIn,
        address __tokenOut,
        uint256 _targetAuctionPeriod,
        uint192 _targetAuctionPrice,
        uint256 _smoothingFactor
    ) {
        source = _source;
        _tokenIn = IERC20(__tokenIn);
        _tokenOut = IERC20(__tokenOut);
        targetAuctionPeriod = _targetAuctionPeriod;
        smoothingFactor = _smoothingFactor;
        require(smoothingFactor < 1e18, "less tan 1");

        lastAuctionAt = uint64(block.timestamp);
        lastAuctionPrice = _targetAuctionPrice;
    }

  /**
   * @notice Returns the token that is used to pay for auctions.
   * @return address of the token coming in
   */
  function tokenIn() external view returns (address) {
    return address(_tokenIn);
  }

  /**
   * @notice Returns the token that is being auctioned.
   * @return address of the token coming out
   */
  function tokenOut() external view returns (address) {
    return address(_tokenOut);
  }

  /**
   * @notice Get the address that will receive `tokenIn`.
   * @return Address of the target
   */
  function target() external returns (address) {
    return source.targetOf(address(_tokenIn));
  }

  /**
   * @notice Gets the maximum amount of tokens that can be swapped out from the source.
   * @return The maximum amount of tokens that can be swapped out.
   */
  function maxAmountOut() external returns (uint256) {  
    return _availableBalance();
  }

  /**
   * @notice Swaps the given amount of tokens out and ensures the amount of tokens in doesn't exceed the given maximum.
   * @dev The amount of tokens being swapped in must be sent to the target before calling this function.
   * @param _receiver The address to send the tokens to.
   * @param _amountInMax The maximum amount of tokens to send in.
   * @param _flashSwapData If non-zero, the _receiver is called with this data prior to
   * @return The amount of tokens sent in.
   */
  function swapExactAmountOut(
    address _receiver,
    uint256 /* _amountOut */,
    uint256 _amountInMax,
    bytes calldata _flashSwapData
  ) external returns (uint256) {
    uint192 swapAmountIn = _computePrice();

    if (swapAmountIn > _amountInMax) {
      revert SwapExceedsMax(_amountInMax, swapAmountIn);
    }

    lastAuctionAt = uint64(block.timestamp);
    lastAuctionPrice = swapAmountIn;

    uint256 amountOut = _availableBalance();
    if (amountOut == 0) {
      revert("no way jose");
    }

    bytes memory transferTokensOutData = source.transferTokensOut(
      msg.sender,
      _receiver,
      address(_tokenOut),
      amountOut
    );

    if (_flashSwapData.length > 0) {
      IFlashSwapCallback(_receiver).flashSwapCallback(
        msg.sender,
        swapAmountIn,
        amountOut,
        _flashSwapData
      );
    }

    source.verifyTokensIn(address(_tokenIn), swapAmountIn, transferTokensOutData);

    return swapAmountIn;
  }

  /**
   * @notice Computes the exact amount of tokens to send in for the given amount of tokens to receive out.
   * @return The amount of tokens to send in.
   */
  function computeExactAmountIn(uint256) external view returns (uint256) {
    return _computePrice();
  }

  function computeTimeForPrice(uint256 price) external view returns (uint256) {
      // p2/p1 = t/e => e = t*p1/p2
      return lastAuctionAt + (targetAuctionPeriod*lastAuctionPrice)/price;
  }

  function _availableBalance() internal returns (uint256) {
    return ((1e18 - smoothingFactor) * source.liquidatableBalanceOf(address(_tokenOut))) / 1e18;
  }

  function _computePrice() internal view returns (uint192) {
      uint256 elapsedTime = block.timestamp - lastAuctionAt;
      if (elapsedTime == 0) {
          return type(uint192).max;
      }
      return uint192((targetAuctionPeriod * lastAuctionPrice) / elapsedTime);
  }

}
