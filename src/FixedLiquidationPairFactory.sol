// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { ILiquidationSource, FixedLiquidationPair } from "./FixedLiquidationPair.sol";

/// @title FixedLiquidationPairFactory
/// @author G9 Software Inc.
/// @notice Factory contract for deploying FixedLiquidationPair contracts.
contract FixedLiquidationPairFactory {
  /* ============ Events ============ */

  /// @notice Emitted when a new FixedLiquidationPair is created
  /// @param pair The address of the new pair
  /// @param source The liquidation source that the pair is using
  /// @param tokenIn The input token for the pair
  /// @param tokenOut The output token for the pair
  /// @param targetAuctionPeriod The duration of auctions
  /// @param minimumAuctionAmount The minimum auction size in output tokens
  event PairCreated(
    FixedLiquidationPair indexed pair,
    ILiquidationSource source,
    address indexed tokenIn,
    address indexed tokenOut,
    uint256 targetAuctionPeriod,
    uint192 minimumAuctionAmount
  );

  /* ============ Variables ============ */

  /// @notice Tracks an array of all pairs created by this factory
  FixedLiquidationPair[] public allPairs;

  /* ============ Mappings ============ */

  /**
   * @notice Mapping to verify if a FixedLiquidationPair has been deployed via this factory.
   * @dev FixedLiquidationPair address => boolean
   */
  mapping(FixedLiquidationPair => bool) public deployedPairs;

  /// @notice Creates a new FixedLiquidationPair and registers it within the factory
  /// @param _source The liquidation source that the pair will use
  /// @param _tokenIn The input token for the pair
  /// @param _tokenOut The output token for the pair
  /// @param _targetAuctionPeriod The duration of auctions
  /// @param _minimumAuctionAmount The minimum auction size in output tokens
  /// @return The address of the new pair
  function createPair(
    ILiquidationSource _source,
    address _tokenIn,
    address _tokenOut,
    uint256 _targetAuctionPeriod,
    uint192 _minimumAuctionAmount
  ) external returns (FixedLiquidationPair) {
    FixedLiquidationPair _FixedliquidationPair = new FixedLiquidationPair(
      _source,
      _tokenIn,
      _tokenOut,
      _targetAuctionPeriod,
      _minimumAuctionAmount
    );

    allPairs.push(_FixedliquidationPair);
    deployedPairs[_FixedliquidationPair] = true;

    emit PairCreated(
      _FixedliquidationPair,
      _source,
      _tokenIn,
      _tokenOut,
      _targetAuctionPeriod,
      _minimumAuctionAmount
    );

    return _FixedliquidationPair;
  }

  /**
   * @notice Total number of FixedLiquidationPair deployed by this factory.
   * @return Number of FixedLiquidationPair deployed by this factory.
   */
  function totalPairs() external view returns (uint256) {
    return allPairs.length;
  }
}
