// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

import {
    FixedLiquidationPair,
    IERC20,
    ILiquidationSource
} from "../src/FixedLiquidationPair.sol";

contract FixedLiquidationPairTest is Test {

    FixedLiquidationPair pair;

    ILiquidationSource source;
    IERC20 tokenIn;
    IERC20 tokenOut;
    uint256 targetAuctionPeriod;
    uint192 minimumAuctionAmount;

    address receiver;

    function setUp() public {
        source = ILiquidationSource(makeAddr("ILiquidationSource"));
        vm.etch(address(source), "source"); // ensure call failures if not mocked
        tokenIn = IERC20(makeAddr("tokenIn"));
        vm.etch(address(tokenIn), "tokenIn"); // ensure call failures if not mocked
        tokenOut = IERC20(makeAddr("tokenOut"));
        vm.etch(address(tokenOut), "tokenOut"); // ensure call failures if not mocked
        targetAuctionPeriod = 1 hours;
        minimumAuctionAmount = 0.01e18;
        pair = new FixedLiquidationPair(
            source,
            address(tokenIn),
            address(tokenOut),
            targetAuctionPeriod,
            minimumAuctionAmount,
            0
        );

        receiver = makeAddr("receiver");
    }

    function test_computePrice_twice_as_long() public {
        vm.warp(block.timestamp + targetAuctionPeriod * 2);
        assertEq(pair.computeExactAmountIn(0), minimumAuctionAmount / 2, "min auction size is halved");
    }

    function test_computePrice_half_as_long() public {
        vm.warp(block.timestamp + targetAuctionPeriod / 2);
        assertEq(pair.computeExactAmountIn(0), minimumAuctionAmount * 2, "min auction size is doubled");
    }

    function test_computePrice_onTarget() public {
        vm.warp(block.timestamp + targetAuctionPeriod);
        assertEq(pair.computeExactAmountIn(0), minimumAuctionAmount, "target achieved");
    }

    function test_computeTimeForPrice() public {
        assertEq(pair.computeTimeForPrice(minimumAuctionAmount), block.timestamp + targetAuctionPeriod, "target");
        assertEq(pair.computeTimeForPrice(minimumAuctionAmount*2), block.timestamp + targetAuctionPeriod/2, "half time");
    }

    function test_swapExactAmountOut() public {
        mockTransferTokensOut(1234e18);

        uint firstTime = block.timestamp + 4 weeks;

        vm.warp(firstTime);
        console2.log("sale price: ", pair.computeExactAmountIn(0));
        uint price = pair.swapExactAmountOut(receiver, 0, 100e18, "");

        vm.warp(firstTime + targetAuctionPeriod/4);
        console2.log("secnd swap price: ", pair.computeExactAmountIn(0));
        pair.swapExactAmountOut(receiver, 0, 100e18, "");

        vm.warp(firstTime + targetAuctionPeriod);
        console2.log("third swap price: ", pair.computeExactAmountIn(0));
        pair.swapExactAmountOut(receiver, 0, 100e18, ""); // at target, so no change
    }

    function mockTransferTokensOut(uint256 balance) internal {
        vm.mockCall(address(source), abi.encodeWithSelector(source.liquidatableBalanceOf.selector, address(tokenOut)), abi.encode(balance));
        vm.mockCall(address(source), abi.encodeWithSelector(source.transferTokensOut.selector, address(this), receiver, address(tokenOut), balance), abi.encode(""));
    }

    function mockVerify(uint amount) internal {
        vm.mockCall(address(source), abi.encodeWithSelector(source.verifyTokensIn.selector, address(tokenIn), amount, ""), abi.encode(""));
    }

}