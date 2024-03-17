// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ILiquidationSource } from "pt-v5-liquidator-interfaces/interfaces/ILiquidationSource.sol";
import { ILiquidationPair } from "pt-v5-liquidator-interfaces/interfaces/ILiquidationPair.sol";

/// @notice Thrown when the actual swap amount in exceeds the user defined maximum amount in
/// @param amountInMax The user-defined max amount in
/// @param amountIn The actual amount in
error SwapExceedsMax(uint256 amountInMax, uint256 amountIn);

contract FixedLiquidationPair is ILiquidationPair {

    ILiquidationSource public immutable source;
    uint32 public immutable targetAuctionPeriod;
    uint224 public immutable minimumAuctionAmount;
    IERC20 internal immutable _tokenIn;

    uint48 public lastAuctionAt;
    uint192 public lastAuctionPrice;  

    constructor (
        ILiquidationSource _source,
        address __tokenIn,
        address __tokenOut,
        uint256 _targetAuctionPeriod,
        uint256 _minimumAuctionAmount
    ) {
        source = _source;
        _tokenIn = __tokenIn;
        targetAuctionPeriod = _targetAuctionPeriod;
        minimumAuctionAmount = _minimumAuctionAmount;

        lastAuctionAt = block.timestamp;
        lastAuctionPrice = _minimumAuctionAmount;
    }

    function _computePrice() internal view returns (uint256) {
        uint256 elapsedTime = block.timestamp - lastAuctionAt;
        if (elapsedTime == 0) {
            return type(uint).max;
        }
        return (targetAuctionPeriod * lastAuctionPrice) / elapsedTime;
    }

  /**
   * @notice Returns the token that is used to pay for auctions.
   * @return address of the token coming in
   */
  function tokenIn() external returns (address) {
    return address(_tokenIn);
  }

  /**
   * @notice Returns the token that is being auctioned.
   * @return address of the token coming out
   */
  function tokenOut() external returns (address) {
    return address(_tokenOut);
  }

  /**
   * @notice Get the address that will receive `tokenIn`.
   * @return Address of the target
   */
  function target() external returns (address) {
    return source.targetOf(_tokenIn);
  }

  /**
   * @notice Gets the maximum amount of tokens that can be swapped out from the source.
   * @return The maximum amount of tokens that can be swapped out.
   */
  function maxAmountOut() external returns (uint256) {  
    return source.liquidatableBalanceOf(_tokenOut);
  }

  /**
   * @notice Swaps the given amount of tokens out and ensures the amount of tokens in doesn't exceed the given maximum.
   * @dev The amount of tokens being swapped in must be sent to the target before calling this function.
   * @param _receiver The address to send the tokens to.
   * @param _amountOut The amount of tokens to receive out.
   * @param _amountInMax The maximum amount of tokens to send in.
   * @param _flashSwapData If non-zero, the _receiver is called with this data prior to
   * @return The amount of tokens sent in.
   */
  function swapExactAmountOut(
    address _receiver,
    uint256 _amountOut,
    uint256 _amountInMax,
    bytes calldata _flashSwapData
  ) external returns (uint256) {
    uint swapAmountIn = _computePrice();

    if (swapAmountIn > _amountInMax) {
      revert SwapExceedsMax(_amountInMax, swapAmountIn);
    }

    bytes memory transferTokensOutData = source.transferTokensOut(
      msg.sender,
      _receiver,
      _tokenOut,
      _amountOut
    );

    if (_flashSwapData.length > 0) {
      IFlashSwapCallback(_receiver).flashSwapCallback(
        msg.sender,
        swapAmountIn,
        _amountOut,
        _flashSwapData
      );
    }

    source.verifyTokensIn(_tokenIn, swapAmountIn, transferTokensOutData);

  }

  /**
   * @notice Computes the exact amount of tokens to send in for the given amount of tokens to receive out.
   * @param _amountOut The amount of tokens to receive out.
   * @return The amount of tokens to send in.
   */
  function computeExactAmountIn(uint256 _amountOut) external returns (uint256) {
    return _computePrice();
  }
}