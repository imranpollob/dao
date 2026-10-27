# Security Policy

## Reporting

Do not open a public issue for a suspected vulnerability. Email the
maintainers with: affected contract, impact, steps to reproduce, and any
working proof of concept. Expect acknowledgement within 72 hours.

## Scope

In scope: `src/Treasury.sol`, `src/GrantRegistry.sol`,
`src/GrantVestingRevocable.sol`, `src/GrantGovernor.sol`,
`src/utils/ProposalBuilder.sol`.

Out of scope: frontends, indexers, network-level denial of service,
third-party token contracts, and governance outcomes the timelock
correctly executed.

## Trust model

The trust model lives in `docs/THREAT_MODEL.md`, not here. In short:
the timelock is the only privileged actor, the guardian is a multisig
that can pause and veto but never move funds, and token distribution is
assumed out of attacker control at deployment.

## Guarantees and non-guarantees

What the code guarantees: per-call and daily caps on the typed payout
path, treasury floor, time-bounded pause, revocable vesting with
`released + revoked <= funded`.

What it does not guarantee: protection against an attacker who
legitimately holds quorum (borrow-and-hold), or against malicious
proposals if the allowlist enforcer is left off. See
`docs/AUDIT_REPORT.md` for residual risks.
