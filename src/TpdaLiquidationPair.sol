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

/// @notice Thrown when there is zero available balance to swap
error ZeroAvailableBalance();

/// @notice Thrown when the receiver of the swap is the zero address
error ReceiverIsZero();

/// @notice Thrown when the smoothing parameter is 1 or greater
error SmoothingGteOne();

// The minimum auction price. This ensures the auction cannot get bricked to zero.
uint192 constant MIN_PRICE = 100;

/// @title Target Period Dutch Auction Liquidation Pair
/// @author G9 Software Inc.
/// @notice This contract sells one token for another at a target time interval. The pricing algorithm is designed
/// such that the price of the auction is inversely proportional to the time since the last auction.
/// auctionPrice = (targetAuctionPeriod / elapsedTimeSinceLastAuction) * lastAuctionPrice
contract TpdaLiquidationPair is ILiquidationPair {

    /// @notice Emitted when a swap is made
    /// @param sender The sender of the swap
    /// @param receiver The receiver of the swap
    /// @param amountOut The amount of tokens out
    /// @param amountInMax The maximum amount of tokens in
    /// @param amountIn The actual amount of tokens in
    event SwappedExactAmountOut(
        address indexed sender,
        address indexed receiver,
        uint256 amountOut,
        uint256 amountInMax,
        uint256 amountIn,
        bytes flashSwapData
    );

    /// @notice The liquidation source
    ILiquidationSource public immutable source;

    /// @notice The target time interval between auctions
    uint256 public immutable targetAuctionPeriod;

    /// @notice The token that is being purchased
    IERC20 internal immutable _tokenIn;

    /// @notice The token that is being sold
    IERC20 internal immutable _tokenOut;

    /// @notice The degree of smoothing to apply to the available token balance
    uint256 public immutable smoothingFactor;    

    /// @notice The time at which the last auction occurred
    uint64 public lastAuctionAt;

    /// @notice The price of the last auction
    uint192 public lastAuctionPrice;

    /// @notice Constructors a new TpdaLiquidationPair
    /// @param _source The liquidation source
    /// @param __tokenIn The token that is being purchased
    /// @param __tokenOut The token that is being sold
    /// @param _targetAuctionPeriod The target time interval between auctions
    /// @param _targetAuctionPrice The target price of the auction
    /// @param _smoothingFactor The degree of smoothing to apply to the available token balance
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
        if (smoothingFactor >= 1e18) {
            revert SmoothingGteOne();
        }

        lastAuctionAt = uint64(block.timestamp);
        lastAuctionPrice = _targetAuctionPrice;
    }

    /// @inheritdoc ILiquidationPair
    function tokenIn() external view returns (address) {
        return address(_tokenIn);
    }

    /// @notice Returns the token that is being auctioned.
    /// @return address of the token coming out
    function tokenOut() external view returns (address) {
        return address(_tokenOut);
    }

    /// @inheritdoc ILiquidationPair
    function target() external returns (address) {
        return source.targetOf(address(_tokenIn));
    }

    /// @inheritdoc ILiquidationPair
    function maxAmountOut() external returns (uint256) {  
        return _availableBalance();
    }

    /// @notice Swaps the given amount of tokens out and ensures the amount of tokens in doesn't exceed the given maximum.
    /// @dev The amount of tokens being swapped in must be sent to the target before calling this function.
    /// @param _receiver The address to send the tokens to.
    /// @param _amountInMax The maximum amount of tokens to send in.
    /// @param _flashSwapData If non-zero, the _receiver is called with this data prior to
    /// @return The amount of tokens sent in.
    function swapExactAmountOut(
        address _receiver,
        uint256 /* _amountOut */,
        uint256 _amountInMax,
        bytes calldata _flashSwapData
    ) external returns (uint256) {
        if (_receiver == address(0)) {
            revert ReceiverIsZero();
        }

        uint192 swapAmountIn = _computePrice();

        if (swapAmountIn > _amountInMax) {
            revert SwapExceedsMax(_amountInMax, swapAmountIn);
        }

        lastAuctionAt = uint64(block.timestamp);
        lastAuctionPrice = swapAmountIn;

        uint256 amountOut = _availableBalance();
        if (amountOut == 0) {
            revert ZeroAvailableBalance();
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

        emit SwappedExactAmountOut(msg.sender, _receiver, amountOut, _amountInMax, swapAmountIn, _flashSwapData);

        return swapAmountIn;
    }

    /// @notice Computes the exact amount of tokens to send in for the given amount of tokens to receive out.
    /// @return The amount of tokens to send in.
    function computeExactAmountIn(uint256) external view returns (uint256) {
        return _computePrice();
    }

    /// @notice Computes the time at which the given auction price will occur
    /// @param price The price of the auction
    /// @return The elapsed time since the last auction at which the price will occur
    function computeTimeForPrice(uint256 price) external view returns (uint256) {
    // p2/p1 = t/e => e = t*p1/p2
        return lastAuctionAt + (targetAuctionPeriod*lastAuctionPrice)/price;
    }

    /// @notice Computes the available balance of the tokens to be sold
    /// @return The available balance of the tokens
    function _availableBalance() internal returns (uint256) {
        return ((1e18 - smoothingFactor) * source.liquidatableBalanceOf(address(_tokenOut))) / 1e18;
    }

    /// @notice Computes the current auction price
    /// @return The current auction price
    function _computePrice() internal view returns (uint192) {
        uint256 elapsedTime = block.timestamp - lastAuctionAt;
        if (elapsedTime == 0) {
            return type(uint192).max;
        }
        uint192 price = uint192((targetAuctionPeriod * lastAuctionPrice) / elapsedTime);

        if (price < MIN_PRICE) {
            price = MIN_PRICE;
        }

        return price;
    }

}
