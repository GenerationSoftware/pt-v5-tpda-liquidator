// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ILiquidationSource } from "pt-v5-liquidator-interfaces/interfaces/ILiquidationSource.sol";
import { ILiquidationPair } from "pt-v5-liquidator-interfaces/interfaces/ILiquidationPair.sol";

contract FixedLiquidationPair is ILiquidationPair {

    ILiquidationSource public immutable source;
    uint256 public immutable targetAuctionPeriod;
    uint256 public immutable minimumAuctionAmount;

    constructor (
        ILiquidationSource _source,
        uint256 _targetAuctionPeriod,
        uint256 _minimumAuctionAmount) {
        
    }

}