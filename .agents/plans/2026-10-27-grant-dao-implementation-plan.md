# Grant DAO Implementation Plan

## Goal

Make this Grant DAO usable as a real grants system, then harden it as a blockchain security portfolio piece. Usability first, security proofs second, audit readiness third.

Decisions adopted for MVP: governance-only milestone approval, revocable vesting by default, timelock-held admin with governance rotation, CLI-first with one-command demo. Council/escrow, dashboard, and distributor are P2.

## Current Features (verified in repo)

Governance:

- `src/GrantToken.sol`: ERC20 + Permit + Votes, fixed supply minted to initial holder, delegation required for voting power.
- `src/GrantGovernor.sol`: OpenZeppelin Governor with Settings, CountingSimple, Storage, Votes, QuorumFraction, TimelockControl. Name `GrantGovernor`. Absolute proposal threshold, voting delay, voting period, quorum percent.
- `TimelockController`: 2-day delay in `script/Deploy.s.sol`. `PROPOSER_ROLE` to Governor, `EXECUTOR_ROLE` to `address(0)`, `CANCELLER_ROLE` to guardian, admin renounced.
- Deploy defaults: 10M GDT to deployer, deployer self-delegates, guardian defaults to deployer. No post-deploy assertions. This is the deploy-safety gap to fix.

Treasury:

- `src/Treasury.sol`: owned by timelock, `ReentrancyGuard`, `receive()` with `FundsReceived`, arbitrary `execute(target, value, data)` with `onlyOwner` + `nonReentrant` + `Executed` event.
- Holds ETH natively and ERC20 via direct transfers. No accounting, caps, batch, allowlist, or typed payout API. ERC20 path uses raw `transfer` selector without `SafeERC20` or balance-delta checks.

Grants and vesting:

- `src/utils/ProposalBuilder.sol`: `buildEthGrant` and `buildErc20Grant`. Both target Treasury `execute`. Single-grant only, free-form description, no intent binding.
- `src/GrantVesting.sol`: thin `VestingWallet` wrapper. Beneficiary model only, no admin/revoke split, no cliff field, not wired to proposals.
- No registry, milestones, statuses, commitment accounting, or vesting-grant proposal path.

Scripts and tests:

- Scripts: `Deploy`, `ProposeEthGrant`, `ProposeErc20Grant`, `CastVote`, `QueueProposal`, `ExecuteProposal`, `QueueAndExecute`, `DeployVesting`. Env-var driven, no simulate/inspect/doctor commands.
- Tests: `GovernanceFlow`, `ComprehensiveScenarios`, `SecurityAndVesting`, `TreasurySmoke`. Cover propose, vote, queue, execute, defeat, guardian cancel via timelock, vesting release, reentrancy smoke. No borrow-and-hold, vote-buying, token-variant, replay, or cap-bypass tests.

## Success Criteria

- A demo creates, approves, tracks, and pays immediate, milestone, and vesting grants, including batch grants in one proposal.
- Treasury exposes typed payouts with caps, allowlist, and `committed` vs `available` accounting. One proposal cannot drain it.
- Proposal calldata is bound to human-readable intent with simulation and risk scan. Bad proposals can be cancelled or vetoed with reasons.
- Attack, invariant, and formal suites prove the stated claims. Threat model, self-audit, and test matrix are published.
- `forge build`, `forge test`, formatting, and security gates pass. Deployment manifest and role report exist.

## Approach

Keep Governor + Timelock as the core. Add a grant lifecycle layer. Replace the grant path's arbitrary `execute` with typed payouts. Add containment limits. Prove with adversarial tests and tool output. CLI-first, no protocol frontend in MVP.

Reuse: `Treasury.execute` only for allowlisted admin path, `ProposalBuilder`, Governor Storage, `VestingWallet` as vesting base.

Key corrections from review:

- Attack model covers pure flashloan and borrow-and-hold across the snapshot, plus an economic cost model of borrowing quorum vs treasury size. Caps and quorum are mitigations, not guarantees.
- Token distribution moves off the deployer. Production guardian must be a multisig. Post-deploy checks prove no retained privilege.
- Proposal intent is bound by JSON schema plus metadata hash, fork simulation, calldata diff, and risk scanner.

## Steps

### Order 0: Fix unsafe assumptions

1. ERC20 payout: `SafeERC20`, exact balance-delta verification, reject fee-on-transfer, rebasing, and false-return tokens in grant path. Token allowlist.
2. Vesting semantics: separate beneficiary from admin, cliff plus linear, timelock-only `revoke()`, invariant `released + revoked <= funded`. Atomic funding with grant creation.
3. Guardian cancel: document and test proposer-cancel-only-while-`Pending` vs guardian veto across `Pending`, `Active`, `Succeeded`, `Queued`.
4. Cap semantics: per-call, per-grant, per-token daily cap, treasury floor. Batch payouts enforce per-proposal cap. No cap bypass via batching.
5. Role rotation: guardian and governor roles rotatable by governance. Timelock holds admin.

### Phase 1: Usable MVP

1. Registry `src/GrantRegistry.sol`: recipient, token, total, paid, grant type, status, proposal id, vesting address, reviewer, metadata URI/hash. Milestones: amount, due date, evidence URI/hash, status, approved and paid timestamps.
2. States `Active, Submitted, Approved, Paid, Completed, Rejected, Cancelled, Revoked`. Recipient submits evidence, reviewer approves/rejects, Treasury records payouts, timelock cancels/revokes, guardian pauses. No silent amendments to recipient, amount, or schedule.
3. Typed Treasury: `sendETH`, `sendERC20`, `fundVesting`, `recoverERC20`, `depositERC20`. Every payout event carries grant and milestone ids. Pause blocks outflows, not deposits.
4. `ProposalBuilder`: add `buildBatchGrants`, `buildVestingGrant`, `buildMilestoneGrant`. Keep existing builders unchanged until registry cutover.
5. Profiles and demo: `DeployLocal` with short delays, `DeployProduction` with realistic delays. `make demo` starts Anvil, deploys, seeds delegates, creates grant, votes, queues, executes, prints report.
6. CLI: `propose`, `vote`, `queue`, `execute`, `cancel`, `grants`, `simulate`, `inspect`, `doctor`, `roles`. JSON proposal schema plus metadata hash. Preflight fork simulation prints balance, state, event, and gas diffs and fails on intent mismatch.
7. Risk scanner: decode selectors and flag `transferOwnership`, `grantRole`, `revokeRole`, `upgradeTo`, `approve`, `setApprovalForAll`, `delegatecall`, unknown selectors, and out-of-policy amounts.
8. `doctor` checks chain id, contract code, roles, balances, timelock delay, guardian address, and pause status.
9. Deployment safety: assert Treasury and Registry owned by timelock, Governor is proposer, execution is open, guardian holds canceller role, deployer retains no roles. Write manifest with addresses, chain id, block, tx hashes, and config. Verify on Etherscan. Save role report.

### Phase 2: Security hardening

1. Spend policy and pause: per-call, per-grant, per-token daily caps plus treasury floor. Guardian multisig can pause outflows and veto, but cannot move funds. Pause is time-bounded and extendable only by timelock. Timelock unpauses.
2. Proposal validation: reject `delegatecall`, `selfdestruct`, Treasury ownership change, and empty-calldata drains. Allowlisted targets and selectors for any remaining arbitrary path.
3. Attack suite `test/attacks/`: pure flashloan vote attempt, borrow-and-hold across snapshot, vote buying and delegation capture, proposal phishing and calldata-intent mismatch, reentrancy via ETH recipient and ERC20 hooks, false-return and fee-on-transfer and rebasing and malicious tokens, double payout and milestone replay, cap bypass via batch, pause bypass and expiry, unauthorized schedule and early execute and timelock cancel, role escalation and admin-renounce bricking, permit and `delegateBySig` and `castVoteBySig` replay, vesting transfer and release-after-revoke and double release.
4. Economic model: cost to borrow quorum for one voting period vs treasury size, liquidity assumptions, cap sensitivity.
5. Invariants: treasury floor, only timelock calls payout path, registry totals match payouts, vesting `released + revoked <= funded`. Foundry handlers plus Echidna and Medusa campaigns.
6. Formal checks: Halmos for access control and accounting. Certora optional for Treasury and Registry rules.

### Phase 3: Audit readiness

1. Docs: README quick start, architecture and lifecycle diagrams, demo instructions. `docs/GRANT_LIFECYCLE.md`, `docs/GOVERNANCE.md`, `docs/ROLES.md`, `docs/RUNBOOK.md`, `docs/THREAT_MODEL.md`, `docs/INVARIANTS.md`, `docs/AUDIT_REPORT.md`, `docs/ADRs/`. Root `SECURITY.md` stays disclosure policy. Trust model lives in threat-model doc.
2. Threat model: assets, actors, trust boundaries, attack trees, risk matrix, residual risks.
3. Self-audit report with severity, PoC, fix, commit, and status. Test matrix maps every claim to a test, invariant, or tool output.
4. CI gates: build, tests, formatting, coverage threshold, Slither, Aderyn, Semgrep, Solhint, gas snapshot, dependency audit, pre-commit hooks. Reports in `reports/` regenerated by `make security`.
5. Portfolio README: attack table, tool outputs, Anvil and Sepolia demo.

### P2 stretch, deferred

- Grant council with escrow, reviewer multisig, challenge window, guardian veto.
- Read-only dashboard or indexer. Core stays CLI-first.
- Streaming grants, token distributor with Merkle claim and delegation onboarding, Governor extensions such as `GovernorPreventLateQuorum`, `Ownable2Step`, tiered timelock delays.

## Validation Plan

- `forge build`: 0.8.24 Cancun compile.
- `forge test`: full suite green, including attack and invariant suites.
- `forge test --match-contract GovernanceFlow`: lifecycle intact.
- Fork simulation: sample proposals show expected balance, state, event, and gas changes.
- `make security`: coverage, Slither, Aderyn, Echidna, Halmos outputs refresh `reports/`. No high findings or documented false positives.
- Manual `make demo`: Anvil deploy, seed, grant, vote, queue, execute, registry and runway report.

## Risks / Open Questions

- Risk: registry owned by timelock makes status updates proposal-heavy. Mitigation: only value-moving changes go through proposals. Reads stay off-chain.
- Risk: daily caps may block legit large grants. Mitigation: cap raise is itself a timelock proposal.
- Risk: pause can DoS payouts. Mitigation: time-bounded pause, timelock extension only.
- Open: none for MVP. Council model, dashboard scope, streaming, and full distributor design stay P2.

## Non-goals

- No protocol frontend in MVP, no off-chain indexer dependency, no bridge, no tokenomics redesign.

