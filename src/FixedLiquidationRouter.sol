// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import { IFlashSwapCallback } from "pt-v5-liquidator-interfaces/IFlashSwapCallback.sol";
import { FixedLiquidationPair } from "./FixedLiquidationPair.sol";
import { FixedLiquidationPairFactory } from "./FixedLiquidationPairFactory.sol";

/// @notice Thrown when the liquidation pair factory is the zero address
error UndefinedFixedLiquidationPairFactory();

/// @notice Throw when the liquidation pair was not created by the liquidation pair factory
error UnknownFixedLiquidationPair(FixedLiquidationPair liquidationPair);

/// @notice Thrown when a swap deadline has passed
error SwapExpired(uint256 deadline);

/// @notice Thrown when the router is used as a receiver in a swap by another EOA or contract
error InvalidSender(address sender);

/// @title FixedLiquidationRouter
/// @author G9 Software Inc.
/// @notice Serves as the user-facing swapping interface for Liquidation Pairs.
contract FixedLiquidationRouter is IFlashSwapCallback {
  using SafeERC20 for IERC20;

  /* ============ Events ============ */

  /// @notice Emitted when the router is created
  event LiquidationRouterCreated(FixedLiquidationPairFactory indexed liquidationPairFactory);

  /// @notice Emitted after a swap occurs
  /// @param liquidationPair The pair that was swapped against
  /// @param sender The address that initiated the swap
  /// @param receiver The address that received the output tokens
  /// @param amountOut The amount of output tokens received
  /// @param amountInMax The maximum amount of input tokens that could have been used
  /// @param amountIn The amount of input tokens that were actually used
  event SwappedExactAmountOut(
    FixedLiquidationPair indexed liquidationPair,
    address indexed sender,
    address indexed receiver,
    uint256 amountOut,
    uint256 amountInMax,
    uint256 amountIn,
    uint256 deadline
  );

  /* ============ Variables ============ */

  /// @notice The FixedLiquidationPairFactory that this router uses.
  /// @dev FixedLiquidationPairs will be checked to ensure they were created by the factory
  FixedLiquidationPairFactory internal immutable _liquidationPairFactory;

  /// @notice Constructs a new LiquidationRouter
  /// @param liquidationPairFactory_ The factory that pairs will be verified to have been created by
  constructor(FixedLiquidationPairFactory liquidationPairFactory_) {
    if (address(liquidationPairFactory_) == address(0)) {
      revert UndefinedFixedLiquidationPairFactory();
    }
    _liquidationPairFactory = liquidationPairFactory_;

    emit LiquidationRouterCreated(liquidationPairFactory_);
  }

  /* ============ External Methods ============ */

  /// @notice Swaps the given amount of output tokens for at most input tokens
  /// @param _liquidationPair The pair to swap against
  /// @param _receiver The account to receive the output tokens
  /// @param _amountOut The exact amount of output tokens expected
  /// @param _amountInMax The maximum of input tokens to spend
  /// @param _deadline The timestamp that the swap must be completed by
  /// @return The actual number of input tokens used
  function swapExactAmountOut(
    FixedLiquidationPair _liquidationPair,
    address _receiver,
    uint256 _amountOut,
    uint256 _amountInMax,
    uint256 _deadline
  ) external onlyTrustedFixedLiquidationPair(_liquidationPair) returns (uint256) {
    if (block.timestamp > _deadline) {
      revert SwapExpired(_deadline);
    }

    uint256 amountIn = _liquidationPair.swapExactAmountOut(
      address(this),
      _amountOut,
      _amountInMax,
      abi.encode(msg.sender)
    );

    IERC20(_liquidationPair.tokenOut()).safeTransfer(_receiver, _amountOut);

    emit SwappedExactAmountOut(
      _liquidationPair,
      msg.sender,
      _receiver,
      _amountOut,
      _amountInMax,
      amountIn,
      _deadline
    );

    return amountIn;
  }

  /// @inheritdoc IFlashSwapCallback
  function flashSwapCallback(
    address _sender,
    uint256 _amountIn,
    uint256,
    bytes calldata _flashSwapData
  ) external override onlyTrustedFixedLiquidationPair(FixedLiquidationPair(msg.sender)) onlySelf(_sender) {
    address _originalSender = abi.decode(_flashSwapData, (address));
    IERC20(FixedLiquidationPair(msg.sender).tokenIn()).safeTransferFrom(
      _originalSender,
      FixedLiquidationPair(msg.sender).target(),
      _amountIn
    );
  }

  /// @notice Checks that the given pair was created by the factory
  /// @param _liquidationPair The pair to check
  modifier onlyTrustedFixedLiquidationPair(FixedLiquidationPair _liquidationPair) {
    if (!_liquidationPairFactory.deployedPairs(_liquidationPair)) {
      revert UnknownFixedLiquidationPair(_liquidationPair);
    }
    _;
  }

  /// @notice Checks that the given address matches this contract
  /// @param _sender The address that called the liquidation pair
  modifier onlySelf(address _sender) {
    if (_sender != address(this)) {
      revert InvalidSender(_sender);
    }
    _;
  }
}
