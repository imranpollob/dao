// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {VestingWallet} from "@openzeppelin/contracts/finance/VestingWallet.sol";

/// @title Grant Vesting Wallet
/// @notice Holds tokens/ETH for a beneficiary and releases them according to a linear schedule.
contract GrantVesting is VestingWallet {
    constructor(
        address beneficiary,
        uint64 startTimestamp,
        uint64 durationSeconds
    ) VestingWallet(beneficiary, startTimestamp, durationSeconds) {}
}
