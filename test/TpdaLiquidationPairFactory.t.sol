// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import { ILiquidationSource } from "pt-v5-liquidator-interfaces/ILiquidationSource.sol";

import { TpdaLiquidationPairFactory } from "../src/TpdaLiquidationPairFactory.sol";
import { TpdaLiquidationPair } from "../src/TpdaLiquidationPair.sol";

contract TpdaLiquidationPairFactoryTest is Test {
  /* ============ Variables ============ */
  TpdaLiquidationPairFactory public factory;
  address public source;
  address public target;
  address tokenIn;
  address tokenOut;
  uint64 targetAuctionPeriod = 1 hours;
  uint192 auctionTargetPrice = 1e18;
  uint256 smoothing = 0.1e18;

  /* ============ Events ============ */

  event PairCreated(
    TpdaLiquidationPair indexed pair,
    ILiquidationSource source,
    address indexed tokenIn,
    address indexed tokenOut,
    uint64 targetAuctionPeriod,
    uint192 targetAuctionPrice,
    uint256 smoothingFactor
  );

  /* ============ Set up ============ */

  function setUp() public {
    // Contract setup
    factory = new TpdaLiquidationPairFactory();
    tokenIn = makeAddr("tokenIn");
    tokenOut = makeAddr("tokenOut");
    source = makeAddr("source");
    vm.etch(source, "ILiquidationSource");
    target = makeAddr("target");
  }

  /* ============ External functions ============ */

  /* ============ createPair ============ */

  function testCreatePair() public {
    vm.expectEmit(false, false, false, true);
    emit PairCreated(
      TpdaLiquidationPair(0x0000000000000000000000000000000000000000),
      ILiquidationSource(source),
      tokenIn,
      tokenOut,
      targetAuctionPeriod,
      auctionTargetPrice,
      smoothing
    );

    mockLiquidatableBalanceOf(0);

    assertEq(factory.totalPairs(), 0, "no pairs exist");

    TpdaLiquidationPair lp = factory.createPair(
      ILiquidationSource(source),
      tokenIn,
      tokenOut,
      targetAuctionPeriod,
      auctionTargetPrice,
      smoothing
    );

    assertEq(factory.totalPairs(), 1, "one pair exists");
    assertEq(address(factory.allPairs(0)), address(lp), "pair is in array");

    assertTrue(factory.deployedPairs(address(lp)));

    assertEq(address(lp.source()), source);
    assertEq(address(lp.tokenIn()), tokenIn);
    assertEq(address(lp.tokenOut()), tokenOut);
    assertEq(lp.targetAuctionPeriod(), targetAuctionPeriod);
    assertEq(lp.lastAuctionPrice(), auctionTargetPrice);
  }

  function mockLiquidatableBalanceOf(uint256 amount) public {
    vm.mockCall(
      address(source),
      abi.encodeWithSelector(ILiquidationSource.liquidatableBalanceOf.selector, tokenOut),
      abi.encode(amount)
    );
  }
}
