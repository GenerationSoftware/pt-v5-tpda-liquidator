# Target Period Dutch Auction Liquidation Pair

[![Code Coverage](https://github.com/generationsoftware/pt-v5-tpda-liquidator/actions/workflows/coverage.yml/badge.svg)](https://github.com/generationsoftware/pt-v5-tpda-liquidator/actions/workflows/coverage.yml?)
![MIT license](https://img.shields.io/badge/license-MIT-blue)

The TpdaLiquidationPair is designed to periodically liquidate accrued yield on PoolTogether V5 vaults.  The Target Period Dutch Auction adjusts the price so that an auction occurs every X seconds.

## Motivation

In PoolTogether V5, Vaults must contribute to each draw in order to be eligible to win prizes. We needed a pricing algorithm that tries to ensure that vault yield is liquidated every X number of seconds.

## How it works

Each auction is for the entire liquidatable balance of tokens. Assuming:

- $targetTime$ is a constant which is the target auction period
- $elapsedTime$ is the time that has elapsed since the last auction
- $previousPrice$ is the last auction price

The current auction price is determined like so:

$$price = {targetTime \over elapsedTime} * previousPrice$$

If a sale occurs in 2 days but the target time was 1 day, then the price will be half. Likewise, if a sale occurs in 1 day but the target was 2 days, then the price will be doubled.

In this way, the algorithm will adjust the price until it stabilizes at the target time period.

## Smoothing

The TPDA Liquidation Pair offers smoothing, so that spikes in yield do not disrupt the auction price.

Some yield sources may accrue in bursts; this means there would be periods of time where there is no yield, then large bursts of yield. This is not ideal, as the algorithm works best with consistent auction sizes.

For example, the Prize Pool in PoolTogether V5 will accrue reserve when the draw occurs. For a daily draw, this means that the reserve increases once per day.

The TPDA Liquidation Pair also takes a "smoothing" parameter during construction. Smoothing is applied as a multiplier of the currently available balance.

$$auctionTokens = (1 - smoothing) * availableBalance$$

For example, if smoothing = 0.9 and there are 100 tokens available to auction, then only 10 will be auctioned. Each subsequent auction will be for 10% of the remaining tokens.
