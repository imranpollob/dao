# Governance

`GrantGovernor` is an OpenZeppelin Governor with Settings, CountingSimple,
Storage, Votes, QuorumFraction, and TimelockControl over `GrantToken`
(ERC20 + Permit + Votes).

## Parameters

Production (`script/Deploy.s.sol`): 10M supply, 100k propose threshold, 7200
voting delay, 50400 voting period, 4% quorum, 2-day timelock.

Local (`script/DeployLocal.s.sol`): 1M supply, zero threshold, delay 1, period 10,
60-second timelock.

## Flow

Propose -> vote -> queue -> timelock delay -> execute.

- The proposer can cancel only while `Pending`.
- The guardian can cancel `Pending`, `Active`, `Succeeded`, or `Queued`.
- Queued guardian cancellation runs through `Governor.cancel`; the Governor,
  not the guardian, holds the Timelock `CANCELLER_ROLE`.
- Guardian rotation requires a passed proposal that calls both
  `Governor.setGuardian(newGuardian)` and `Treasury.setPauser(newGuardian)`.
  `RotateGuardian.s.sol` builds both calls atomically; rotating only the
  Governor would leave the old guardian able to pause Treasury outflows.

## Guardrails

- Treasury payouts are typed and registry-bound; there is no raw arbitrary
  `execute` proposal path.
- The Treasury enforces stored per-call, daily, and per-Treasury-call proposal
  caps, per-token policy overrides, a treasury floor, and a default-on token
  allowlist.
- Milestone approval is Timelock-only. Per-grant `reviewer` is advisory.
- The guardian can pause outflows for a bounded duration (default max 7 days).
  It cannot extend an active pause; only governance can. After expiry it can
  start another pause, so a persistent guardian is a liveness residual;
  monitoring and guardian rotation are required. It cannot unpause or move
  funds.

## Token distribution / delegation

Production deployment mints the supply to a separate `TOKEN_HOLDER`. The
deployer must not call `token.delegate(tokenHolder)`; that gives the holder no
votes. The holder must self-delegate (`DelegateToken.s.sol` or the equivalent
Safe transaction). Until then, quorum is unavailable; `Doctor` reports the
holder's votes.

## Roles

Timelock holds `DEFAULT_ADMIN_ROLE` (self-administered, so governance can rotate
roles). `PROPOSER_ROLE` is the Governor, `EXECUTOR_ROLE` is open
(`address(0)`), and `CANCELLER_ROLE` is held only by the Governor. The guardian
cancels through `Governor.cancel`. Post-deploy assertions prove the deployer
retains no role and the guardian has no direct Timelock cancel privilege.
