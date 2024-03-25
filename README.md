# Target Period Dutch Auction Liquidation Pair

The TpdaLiquidationPair is designed to periodically liquidate accrued yield on PoolTogether V5 vaults.  The Target Period Dutch Auction adjusts the price so that an auction occurs every X seconds.

## How it works

Each auction is for the entire liquidatable balance of tokens. Assuming:

- $targetTime$ is a constant which is the target auction period
- $elapsedTime$ is the time that has elapsed since the last auction
- $previousPrice$ is the last auction price

The current auction price is determined like so:

$$price = {targetTime \over elapsedTime} * previousPrice$$

If a sale occurs in 2 days but the target time was 1, then the price will be half. Likewise, if a sale occurs in 1 day but the target was 2, then the price will be doubled.

In this way, the algorithm will adjust the price until it stabilizes at the target time period.