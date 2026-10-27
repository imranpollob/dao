# ADRs

## ADR-001: Typed payouts only; remove raw execution

The Treasury has no `execute` or `recoverERC20` path. Grant value moves only
through `payGrant`, `payMilestone`, `payMilestoneBatch`, `fundVesting`, and
`fundVestingERC20`; each derives recipient/token/milestone amount from
`GrantRegistry`. Rationale: removing the arbitrary target/value surface is
worth the loss of generic composability in the MVP. Typed batch payout remains
for approved milestones.

## ADR-002: Governance-only milestones

No council or escrow in the MVP. Only the Timelock can approve or reject
milestone evidence; the per-grant `reviewer` is advisory metadata. Every
value-moving step is a proposal. Rationale: preserves the on-chain security
story; council/optimistic approval is deferred to P2.

## ADR-003: Revocable vesting with Treasury as admin

Grants fund `GrantVestingRevocable`; unvested funds return to Treasury on
revoke. The vesting admin and refund treasury must be the Treasury, and the
beneficiary must match the grant recipient, so `Treasury.revokeVesting` can
freeze the vested amount, return unvested funds, and update registry accounting
atomically. Non-revocable grants are not the default and the legacy
`GrantVesting` contract was removed.

## ADR-004: CLI-first, no protocol frontend

Demo and operations are `forge script` plus `make` targets. A read-only
dashboard is P2 stretch. The local lifecycle evidence is `make demo-test`.

## ADR-005: Guardian veto and bounded pause

The guardian is a production-required multisig with `Treasury.pauser` and the
Governor guardian role. It can cancel Pending/Active/Succeeded/Queued proposals
through `Governor.cancel` and pause outflows for a bounded duration. It cannot
unpause, extend an active pause, or move funds. The Governor, not the guardian,
holds the Timelock `CANCELLER_ROLE`, so guardian rotation cannot leave a stale
direct-cancel privilege behind.

## ADR-006: Token holder self-delegation

Production deploy mints to a separate token holder and does not call
`token.delegate(holder)` from the deployer. That call gives the holder no votes.
The holder must self-delegate via `DelegateToken.s.sol` or an equivalent Safe
transaction. A distributor contract may replace this operational step in P2.
