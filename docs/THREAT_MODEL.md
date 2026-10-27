# Threat Model

## Assets

Treasury ETH/ERC20, voting power (GDT), grant commitments, vesting allocations,
governance configuration (roles, delays, caps, allowlist), and the treasury
floor.

## Actors

Voters, recipients, guardian multisig, timelock (the only privileged contract
actor), external attackers, malicious token contracts, and a compromised
deployer or token holder.

## Trust boundaries

- Timelock owns the Treasury and Registry. Treasury owns the value-moving path;
  Registry mutations are Treasury-only for payout/funding/cancel/revoke.
- There is no arbitrary Treasury `execute` or ERC20 recovery function. A
  proposal can only call typed Treasury functions, which derive recipient, token,
  and milestone amount from the registry.
- The guardian can pause and veto but never move funds, unpause, or extend an
  active pause. The guardian is required to be a contract/multisig in production.
- Recipients cannot change grant terms. The per-grant `reviewer` is advisory;
  milestone approval is Timelock-only.
- Token contracts are untrusted: only allowlisted tokens enter the ERC20 path,
  and sender/recipient balance deltas must equal the intended amount.
- The token holder is an operational trust boundary: it must self-delegate for
  quorum to exist. The deployer does not perform a fake delegation.

## Attack trees (tested)

- Governance: pure flashloan (fails, checkpoint), borrow-and-hold across snapshot
  (vote can pass, payout contained by caps/floor), vote buying via delegation,
  phishing calldata vs intent, `castVoteBySig` replay, guardian veto in all
  cancellable states.
- Treasury: reentrant recipient, fee-on-transfer/false-return tokens, double
  payout and milestone replay, cap bypass via repeated calls, pause bypass,
  unauthorized payout, wrong-token substitution, early/double execute.
- Registry: double cancel/revoke accounting, unapproved milestone payout,
  rejected evidence resubmission, Treasury-only recording.
- Roles: escalation via `grantRole`, admin-renounce bricking (self-admin
  timelock), guardian single-EOA (production deploy rejects).
- Vesting: release-after-revoke underflow/lock, double release, per-asset
  revocation, admin/beneficiary mismatch, unvested return to Treasury.

## Risk matrix

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Borrow-and-hold quorum | Medium | High | Caps, floor, allowlist; economic model required |
| Malicious allowlisted token | Low | Medium | Governance allowlist + per-token policy + delta checks |
| Reentrancy on payout | Low | High | `nonReentrant`, charge-before-call, typed path |
| Guardian key compromise | Low | Medium | Multisig, pause-only power, bounded pause |
| Pause DoS | Low | Low | Time-bound per pause; a persistent guardian can re-pause after expiry, so monitoring and guardian rotation are required |
| Token holder never delegates | Medium | High (no quorum) | `DelegateToken.s.sol`, `Doctor` votes check |
| Multiple payout calls in one proposal | Medium | Medium | Daily cap + per-call/proposal cap; documented residual |
| Deployer/guardian misconfiguration | Low | High | Deploy post-assertions, guardian contract requirement |

## Residual risks

- A quorum-holding attacker can pass proposals; contained but not eliminated by
  caps and floor.
- The Treasury's "per-proposal" cap is enforced per Treasury call because it does
  not receive the Governor proposal id. A multi-call proposal is still bounded by
  the daily cap and each grant's remaining amount.
- ERC20 allowlist and per-token caps are governance inputs; unsafe values can
  still be set by a successful malicious proposal.
- No external audit or formal verification yet. Halmos cannot run the forge-std
  suites; Echidna/Medusa campaigns are future work.
