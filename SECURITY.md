# Security Policy

## Reporting

Do not open a public issue for a suspected vulnerability. Email the maintainers
with: affected contract, impact, steps to reproduce, and any working proof of
concept. Expect acknowledgement within 72 hours.

## Scope

In scope: `src/Treasury.sol`, `src/GrantRegistry.sol`,
`src/GrantVestingRevocable.sol`, `src/GrantGovernor.sol`,
`src/utils/ProposalBuilder.sol`, `src/utils/ProposalRisk.sol`, deployment
scripts, and the test suite.

Out of scope: frontends, indexers, network-level denial of service, third-party
token contracts, and governance outcomes the timelock correctly executed.

## Trust model

The trust model lives in `docs/THREAT_MODEL.md`. In short: the timelock is the
only privileged contract actor; the Treasury is the only value-moving path and
the only registry payout recorder; the guardian is a multisig that can pause and
veto but never move funds; the token holder must self-delegate for quorum.

## Guarantees and non-guarantees

What the code guarantees:

- No arbitrary Treasury `execute`/recovery path; payouts are registry-bound.
- Stored per-call, daily, and per-Treasury-call proposal caps; per-token policy
  overrides; treasury floor; default-on ERC20 allowlist.
- Time-bounded guardian pause; the guardian cannot extend an active pause, but
  can start another after expiry (documented liveness residual).
- Governance-only milestone approval and Treasury-only registry recording.
- Revocable vesting per asset with frozen post-revocation release and unvested
  funds returned to Treasury.
- `released + revoked <= funded` for normally funded ETH and ERC20 (forced ETH
  or unsolicited token donations are outside this accounting; revocation
  forwards them to Treasury).

What it does not guarantee:

- Protection against an attacker who legitimately holds quorum (borrow-and-hold).
- A true per-Governor-proposal cap across multiple Treasury calls; the daily cap
  is the aggregate bound.
- Safe ERC20 allowlist/per-token values chosen by governance.
- That a production token holder has self-delegated; `Doctor` makes it visible.
- External audit or formal verification. See `docs/AUDIT_REPORT.md`.
