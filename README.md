# Grant DAO

A governance-first grants system: token holders approve grants, the Treasury
pays only registry-backed obligations, and vesting grants can be revoked with
unvested funds returned to the Treasury.

Built with Solidity 0.8.24, Foundry, and OpenZeppelin v5.

## Security model in one minute

- **No arbitrary Treasury execution.** `execute`, `recoverERC20`, and
  caller-specified recipients/tokens are gone from the grant surface.
- **Registry-bound payouts.** `Treasury.payGrant`, `payMilestone`,
  `payMilestoneBatch`, `fundVesting`, and `fundVestingERC20` derive recipient,
  token, and milestone amounts from `GrantRegistry`. Only the Treasury can
  record payouts, funding, cancel, or revoke.
- **Stored spend policy.** Per-call, daily, and per-Treasury-call proposal caps,
  plus optional per-token policy, treasury floor, and a default-on ERC20
  allowlist. Batch totals are charged before any external call.
- **Governance-only milestones.** Only the Timelock can approve or reject
  evidence. The `reviewer` field is advisory metadata.
- **Guardian veto.** A guardian multisig can pause Treasury grant outflows
  (time-bounded) and cancel proposals in Pending, Active, Succeeded, or Queued
  states. Already-vested releases from a vesting wallet remain a beneficiary
  right during a pause.
- **Revocable vesting by default.** Vesting is per-asset; revocation freezes the
  already-vested amount and returns unvested funds to the Treasury. The vesting
  admin and immutable refund treasury must be the Treasury, and its beneficiary
  must match the grant recipient, so funding, revocation, and registry
  accounting stay atomic.
- **Deployment safety.** Production deploy requires a guardian contract
  distinct from the deployer and a separate token holder. The holder must
  self-delegate; `DelegateToken.s.sol` is provided. The deployer renounces all
  roles and the Timelock is self-administered.

## Architecture

| Contract | Responsibility |
|---|---|
| `GrantToken` | ERC20 + Permit + Votes governance token |
| `GrantGovernor` | OZ Governor (Settings, Counting, Storage, Votes, Quorum, TimelockControl) plus guardian veto |
| `Treasury` | The only value-moving grant path; validates against registry and enforces stored policy |
| `GrantRegistry` | Grant/milestone lifecycle, commitment accounting, Treasury-only payout recording |
| `GrantVestingRevocable` | Cliff + linear vesting, per-asset revocation, unvested return to Treasury |
| `ProposalBuilder` | Typed proposal builders for create/approve/reject/pay/fund/revoke/cancel |
| `ProposalRisk` | Preflight scanner for approvals, unknown selectors, role/upgrade/ownership changes |

## Attack table

| Attack | Result | Evidence |
|---|---|---|
| Pure flashloan vote | Fails (checkpoint) | `GovernanceAttacks.testPureFlashloanVoteFails` |
| Borrow-and-hold quorum | Vote can pass; stored caps/floor contain payout | `GovernanceAttacks.testBorrowAndHoldIsRealVectorButTypedCapContains` |
| Raw `execute` drain | Path removed; proposal targeting old selector reverts | `GovernanceAttacks.testRawExecutePathRemoved` |
| Reentrant recipient | Reverts | `TreasuryAttacks.testReentrantPayeeCannotDrain` |
| Double payout / replay | Reverts | `TreasuryAttacks.testImmediateReplayReverts`, `testMilestoneReplayReverts` |
| Cap bypass via repeated calls | Daily cap blocks | `TreasuryAttacks.testCapBypassViaRepeatedCallsRevertsOnDailyCap` |
| Fee-on-transfer token | Rejected on deposit and payout | `TreasuryPolicy` tests |
| Release after revoke | Frozen schedule; no underflow/lock | `TreasuryAttacks.testReleaseAfterRevokeUsesFrozenSchedule` |
| Guardian veto | Pending/Active/Succeeded/Queued cancel | `SecurityAndVesting` guardian tests |

## Local demo

```bash
anvil &
make demo          # DeployLocal: token, timelock, governor, registry, treasury
make demo-test     # Full lifecycle with report: deploy -> grant -> vote -> queue -> execute
```

`make demo-test` runs `test/DemoLifecycle.t.sol` and prints addresses, grant id,
recipient delta, registry paid/committed, and available Treasury balance.

## Production deployment

Required inputs:

1. `GUARDIAN_ADDRESS`: a multisig/contract, not the deployer.
2. `TOKEN_HOLDER`: a separate account/contract that can self-delegate.
3. Allowed ERC20 tokens and per-token caps. ETH-only deployment needs no token
   allowlist entries.
4. Treasury funding.

```bash
cp .env.example .env
# set PRIVATE_KEY, RPC_URL, GUARDIAN_ADDRESS, TOKEN_HOLDER
forge script script/Deploy.s.sol --rpc-url "$RPC_URL" --broadcast

# Run from the token holder account. A multisig must submit the equivalent
# token.delegate(holder) transaction.
TOKEN=... TOKEN_HOLDER_PRIVATE_KEY=... forge script script/DelegateToken.s.sol --rpc-url "$RPC_URL" --broadcast

make doctor
```

The deploy script **does not fake delegation** by calling
`token.delegate(tokenHolder)` from the deployer. Until the holder self-delegates,
the DAO has no quorum. `Doctor` reports `token holder votes` so this is visible.

## Scripts

| Script | Purpose |
|---|---|
| `Deploy.s.sol` | Production profile with required guardian/token holder and post-deploy assertions |
| `DeployLocal.s.sol` | Local profile; deployer is holder/guardian and self-delegates |
| `DelegateToken.s.sol` | Token holder self-delegation (or Safe equivalent) |
| `CreateGrant.s.sol` | Propose a grant (`GRANT_TYPE`, `RECIPIENT`, `TOTAL`, `TOKEN`, `VESTING`, milestone CSV) |
| `ProposeEthGrant.s.sol` / `ProposeErc20Grant.s.sol` | Propose an Immediate grant payout by `GRANT_ID` |
| `SubmitEvidence.s.sol` | Recipient submits milestone evidence (`GRANT_ID`, `MILESTONE_ID`, `EVIDENCE_URI`) |
| `ProposeMilestoneApproval.s.sol` / `ProposeMilestoneRejection.s.sol` | Propose milestone approval or rejection (`GRANT_ID`, `MILESTONE_ID`, `REASON`) |
| `ReleaseVesting.s.sol` | Beneficiary releases vested ETH or ERC20 (`VESTING`, `TOKEN=0` for ETH) |
| `ProposeVestingFunding.s.sol` / `ProposeVestingRevoke.s.sol` | Propose vesting funding (ETH `AMOUNT_WEI` or ERC20 `AMOUNT`) or revocation |
| `ProposeCancelGrant.s.sol` | Propose cancelling an unfunded grant (`GRANT_ID`, `REASON`) |
| `RotateGuardian.s.sol` | Propose rotating both Governor guardian and Treasury pauser |
| `CastVote`, `QueueProposal`, `ExecuteProposal`, `QueueAndExecute` | Voting and execution; `QueueAndExecute` reads stored proposal details |
| `SimulateProposal.s.sol` | Load stored proposal, scan calldata, print policy, fail on risk flags |
| `CancelProposal.s.sol` | Proposer/guardian cancel path |
| `DeployVesting.s.sol` | Deploy revocable vesting; admin/treasury must equal Treasury and beneficiary must match the grant recipient |
| `Doctor.s.sol`, `Roles.s.sol` | Health and role reports |

## Known limitations

- A "per-proposal" cap is enforced at each Treasury call because the Treasury
  does not receive the Governor proposal id. Multiple calls in one proposal are
  still bounded by the daily cap and per-grant remainder.
- `payMilestoneBatch` is ETH-only; ERC20 milestones are paid one at a time with
  `payMilestone`.
- The protocol has no frontend or indexer by design; reads are on-chain views.
- Borrow-and-hold quorum is economic, not eliminated by code.
- An external audit and formal verification are still outstanding.

## Testing

```bash
forge test
forge coverage
make security
```

The suite includes governance lifecycle, Treasury policy/attack tests, registry
state tests, vesting revocation tests, proposal-risk tests, and a handler-based
invariant campaign.
