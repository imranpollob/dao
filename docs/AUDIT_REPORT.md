# Self-Audit / Remediation Report

Date: 2026-10-27. Scope: `Treasury`, `GrantRegistry`,
`GrantVestingRevocable`, `GrantGovernor`, `ProposalBuilder`, `ProposalRisk`,
deployment scripts, and the Foundry suite. This report covers the remediation
change set based on HEAD `6fe10a7`.

## Verification snapshot

- `forge test`: **80 passed, 0 failed** (12 suites).
- Handler invariant campaign: **256 runs x 128k calls, 0 reverts**.
- Coverage (summary): Treasury **95.38% lines / 84.47% funcs**, Registry
  **91.67% lines / 80.81% funcs**, Vesting **84.21% lines**, Governor
  **75.68% lines**, ProposalBuilder **100% lines / 100% funcs**, ProposalRisk
  **100% lines / 100% funcs**. Core `src/` line coverage is **91.27%**
  (481/527); the full repo total is 50.13% because 0%-covered scripts and
  partially-covered test helpers are included in that denominator.
- Slither: **no High or Medium findings**. Remaining detectors are informational
  or intentional (see “Accepted Slither output” below).
- Local Anvil deployment and `Doctor` wiring/role/vote checks pass (see
  `reports/demo-anvil.md`).

## Fixed findings

### [High, fixed] Arbitrary Treasury execution and ERC20 recovery

The old `execute` / `recoverERC20` surface let a governance proposal move
arbitrary value to arbitrary targets. It is removed. Treasury value movement is
limited to `payGrant`, `payMilestone`, `payMilestoneBatch`, `fundVesting`, and
`fundVestingERC20`. Recipient, token, and milestone amount are read from the
registry. `GovernanceAttacks.testRawExecutePathRemoved` proves the old selector
path reverts.

### [High, fixed] Unbound payouts and unauthenticated registry accounting

`Treasury` now takes the `GrantRegistry` in its constructor. Only the Treasury
can call `recordPayout`, `recordVestingFunding`, `cancelGrant`, or
`revokeGrant`; only the Timelock owns grant creation, evidence approval, and
policy setters. Direct payouts above the grant remainder, unapproved milestone
payouts, wrong-token paths, and replays revert.

### [High, fixed] Uncapped drain / caller-supplied caps

Caps are stored policy: per-call, daily, and per-Treasury-call proposal caps,
optional per-token policy (`setTokenPolicy`), per-grant remainder, treasury
floor, and a default-on ERC20 allowlist. `payMilestoneBatch` (ETH-only)
validates all items and charges the total before any external call. Repeated calls hit the daily cap;
`testCapBypassViaRepeatedCallsRevertsOnDailyCap` and
`testBatchEnforcesPerProposalCap` cover the paths.

### [High, fixed] Revocable vesting authorization and accounting

`GrantVestingRevocable` has a beneficiary/admin split, cliff + linear vesting,
and per-asset revocation. The admin and immutable `treasury` must both be the
Treasury; funding rejects a wrong admin (`VestingAdminMismatch`), wrong refund
destination (`VestingTreasuryMismatch`), or a beneficiary that differs from the
grant recipient (`VestingBeneficiaryMismatch`). Revocation freezes the vested amount,
returns unvested funds to Treasury, and updates the registry atomically. Release
after revoke uses the frozen schedule. `testReleaseAfterRevokeUsesFrozenSchedule`,
`testVestingFundingAndRevokeInvariant`, and
`testErc20VestingFundingAndRevoke` cover ETH and ERC20.

### [High, fixed] Guardian veto / pause path

The guardian is a required constructor argument (non-zero). It can pause
Treasury grant outflows for a bounded duration and cancel `Pending`, `Active`,
`Succeeded`, or `Queued` proposals. Already-vested releases from a vesting wallet
remain a beneficiary right. Queued cancellation requires the Governor, not the
guardian, to hold the Timelock `CANCELLER_ROLE`; deployment grants it only to the
Governor. The guardian cannot unpause, extend an active pause, or move funds.
Tests cover Pending/Active/Succeeded/Queued cancellation and the non-guardian
revert.

### [High, fixed] Deployer token-delegation bug

The production deploy mints to a separate `TOKEN_HOLDER` and **does not** call
`token.delegate(tokenHolder)` from the deployer. That call would not give the
holder votes. `DelegateToken.s.sol` exists for the holder (or the equivalent Safe
transaction). `Doctor` reports holder balance and votes. The deploy script
requires a guardian contract distinct from the deployer and asserts the deployer
retains no admin role.

### [Medium, fixed] Registry state-machine cleanup

`GrantStatus` and `MilestoneStatus` are separate enums. Milestones support
`Pending -> Submitted -> Approved -> Paid`, rejection with resubmission, and
cancel/revoke release commitments exactly once. `reviewer` is advisory metadata
only. `testCancelAfterRevokeCannotDoubleSubtract` and
`testMilestoneRejectThenResubmit` cover the lifecycle.

### [Medium, fixed] Proposal risk scanner and unsafe builders

The old raw-execute builders were removed. `ProposalRisk` flags approvals,
ownership/role changes, upgrades, unknown selectors, malformed arrays, and
empty-calldata value drains. `SimulateProposal` loads the stored proposal from
GovernorStorage, scans it, prints policy, and fails on a flag.
`ProposalRisk.t.sol` covers each detectable flag. Delegatecall is not a direct
calldata selector; that field is reserved for off-chain heuristics.

## Residual risks

1. **Per-proposal cap semantics.** Treasury does not receive the Governor
   proposal id, so `ethPerProposalCap`/`erc20PerProposalCap` are enforced per
   Treasury call (and the batch total). A single proposal containing multiple
   separate payout calls is still bounded by the daily cap and each grant's
   remainder. This is documented in `docs/THREAT_MODEL.md`.
2. **Borrow-and-hold governance.** An attacker with quorum across the snapshot
   can pass a proposal. Caps, floor, allowlist, and guardian veto contain the
   impact but do not eliminate the economic vector.
3. **Token-holder operations.** Production has no quorum until the holder
   self-delegates. A distributor contract is a P2 improvement.
4. **Guardian key risk.** Production requires a guardian multisig; a single EOA
   is rejected by `Deploy.s.sol`, but key compromise still enables pause/veto
   griefing until governance rotates it. A pause is time-bounded, but the
   guardian can start another pause after expiry, so a persistent guardian can
   maintain a liveness freeze by repeated transactions. It cannot move funds;
   guardian monitoring and timelock rotation are required.
5. **ERC20 policy choices.** The allowlist and per-token values are governance
   inputs. A successful malicious proposal can set unsafe values.
6. **Tooling.** No external audit, Certora, Echidna, or Medusa campaign. Halmos
   cannot execute forge-std suites (`deployCode` unsupported); dedicated
   Halmos-native specs are follow-up work.

## Accepted Slither output

`reports/slither.txt` (generated from the final tree) has no High/Medium
findings. Accepted informational detectors:

- `arbitrary-send-eth` in `Treasury._pay`: recipient is registry-derived and the
  function is Timelock-only; false positive.
- `incorrect-equality` in `GrantVestingRevocable.fundERC20`: intentional
  fee-on-transfer rejection.
- `calls-loop` in `payMilestoneBatch`: registry is trusted and immutable;
  `nonReentrant`; all amounts are charged before calls.
- `reentrancy-events` in `cancelGrant`: external call is to the trusted registry;
  the transaction reverts atomically; no value transfer.
- `timestamp` comparisons: vesting and pause are time-based by design.
- `assembly` in `ProposalRisk.selectorOf`: bounded selector read, off-chain
  signal only.
- low-level calls: necessary ETH sends to registry-derived recipients.
- missing inheritance / naming convention: style only.

## Tool commands

```bash
forge test
forge coverage --report summary
forge test --gas-report
PATH="$HOME/.foundry/bin:$PATH" .venv/bin/slither . \
  --filter-paths "lib/|test/|script/" --json reports/slither.json \
  > reports/slither.txt 2>&1
```

Artifacts: `reports/coverage.txt`, `reports/gas.txt`, `reports/lcov.info`,
`reports/slither.json`, `reports/slither.txt`, `reports/demo-anvil.md`.
