# Runbook

## Local demo

```bash
anvil &
make demo          # deploy local profile to Anvil
make demo-test     # full lifecycle with printed report, no Anvil needed
```

`make demo` deploys `GrantToken`, `TimelockController`, `GrantGovernor`,
`GrantRegistry`, and `Treasury` with explicit caps. It does **not** create a
grant or vote. `make demo-test` runs `test/DemoLifecycle.t.sol`, which creates a
grant, proposes, votes, queues, waits out the timelock, executes, and prints the
registry/runway report.

## Production deployment checklist

1. `GUARDIAN_ADDRESS` is a multisig/contract, not the deployer. `Deploy.s.sol`
   rejects EOAs and the deployer address.
2. `TOKEN_HOLDER` is a separate account/contract. Run
   `DelegateToken.s.sol` from the holder (or submit the equivalent Safe
   transaction) before proposing. The deploy script does not fake delegation.
3. Decide the ERC20 allowlist and per-token caps. ETH-only deployment can leave
   the allowlist empty; any ERC20 payout requires a governance proposal to call
   `Treasury.setTokenAllowed` and `Treasury.setTokenPolicy`.
4. Fund the Treasury.
5. Run `make doctor` with `TOKEN`, `TIMELOCK`, `GOVERNOR`, `TREASURY`,
   `REGISTRY`, `GUARDIAN_ADDRESS`, `TOKEN_HOLDER`.

```bash
cp .env.example .env
forge script script/Deploy.s.sol --rpc-url "$RPC_URL" --broadcast
TOKEN=... TOKEN_HOLDER_PRIVATE_KEY=... \
  forge script script/DelegateToken.s.sol --rpc-url "$RPC_URL" --broadcast
make doctor
```

## Scripts

| Command | Script / env |
|---|---|
| Create grant | `CreateGrant` (`GRANT_TYPE`, `RECIPIENT`, `TOTAL`, `TOKEN`, `VESTING`, milestone CSV) |
| Create grant payout proposal | `ProposeEthGrant` / `ProposeErc20Grant` (`GRANT_ID`, `AMOUNT_WEI`/`AMOUNT`) |
| Submit milestone evidence | `SubmitEvidence` (`GRANT_ID`, `MILESTONE_ID`, `EVIDENCE_URI`; run as recipient) |
| Milestone approval / rejection | `ProposeMilestoneApproval` / `ProposeMilestoneRejection` (`GRANT_ID`, `MILESTONE_ID`, `REASON`) |
| Vesting funding / revocation | `ProposeVestingFunding` / `ProposeVestingRevoke` (`GRANT_ID`, `AMOUNT_WEI` or `AMOUNT`, `REASON`) |
| Vesting release | `ReleaseVesting` (`VESTING`, `TOKEN=0` for ETH; run as beneficiary) |
| Cancel unfunded grant | `ProposeCancelGrant` (`GRANT_ID`, `REASON`) |
| Rotate guardian | `RotateGuardian` (`GUARDIAN_ADDRESS`; updates Governor and Treasury pauser) |
| Vote | `CastVote` (`PROPOSAL_ID`, `SUPPORT`) |
| Queue / execute | `QueueProposal`, `ExecuteProposal`, or `QueueAndExecute` (`PROPOSAL_ID`) |
| Cancel proposal | `CancelProposal` (`PROPOSAL_ID`) as proposer or guardian |
| Preflight | `SimulateProposal` (`GOVERNOR`, `TREASURY`, `PROPOSAL_ID`); fails on risk flags |
| Health | `Doctor` (`TOKEN`, `TIMELOCK`, `GOVERNOR`, `TREASURY`, `REGISTRY`) |
| Roles | `Roles` (`TIMELOCK`, `GOVERNOR`, `TREASURY`, `GUARDIAN_ADDRESS`) |
| Vesting deploy | `DeployVesting` (`VESTING_BENEFICIARY` must be the grant recipient, `VESTING_TREASURY` and admin must equal Treasury) |

## Grant operations

- Create: `CreateGrant` proposes `GrantRegistry.createGrant`. Set `GRANT_TYPE`
  to `0` (Immediate), `1` (Milestone), or `2` (Vesting). For Milestone, set
  `MILESTONE_AMOUNTS` and `MILESTONE_DUE_DATES` to comma-separated base-unit
  integers with no spaces; leave both empty for other grant types.
- Immediate: `ProposeEthGrant` or `ProposeErc20Grant` proposes
  `Treasury.payGrant(grantId, amount)`.
- Milestone: the recipient submits evidence with `SubmitEvidence`;
  `ProposeMilestoneApproval` (or `ProposeMilestoneRejection`) resolves it, then
  `Treasury.payMilestone` pays it.
- Vesting: deploy with Treasury as admin, create the Vesting grant, fund with
  `ProposeVestingFunding`, release vested funds with `ReleaseVesting`, and revoke
  with `ProposeVestingRevoke` if needed.
- Cancel an unfunded grant with `ProposeCancelGrant`; funded vesting grants use
  revocation instead.
- No ERC20 token can be paid until governance allowlists it and sets its policy.

## Incident response

1. Guardian calls `Treasury.pause(duration)` and cancels the malicious proposal
   through `Governor.cancel` (works while Pending, Active, Succeeded, or Queued).
2. Verify with `Doctor` (paused, balances, roles, registry wiring) and `Roles`.
3. Root-cause with the attack/invariant suites and a fork simulation.
4. Timelock unpauses after the fix proposal executes. The guardian cannot
   extend an active pause; only governance can.
