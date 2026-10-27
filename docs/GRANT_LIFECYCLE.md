# Grant Lifecycle

Three grant types: `Immediate`, `Milestone`, `Vesting`.

## State model

`GrantStatus`: `Active`, `Completed`, `Cancelled`, `Revoked`.

`MilestoneStatus`: `Pending`, `Submitted`, `Approved`, `Paid`, `Rejected`.

Milestone approval is governance-only. The `reviewer` field on a grant is
advisory metadata and has no authorization power.

## Grant creation

A proposal calls `GrantRegistry.createGrant` (the Timelock owns the registry).
For `Milestone`, milestone amounts must sum to the grant total. For `Vesting`,
the vesting wallet address is required and must have code. Creation increases
`committed[token]` by the grant total.

## Immediate grants

1. Create the grant.
2. A proposal calls `Treasury.payGrant(grantId, amount)`.
3. The Treasury derives recipient and token from the registry, charges stored
   caps, records the payout, then transfers.
4. Partial payments are allowed; the grant completes when `paid + funded == total`.
   A replay after completion reverts.

## Milestone grants

1. Create the grant with amounts and due dates.
2. Recipient calls `GrantRegistry.submitEvidence(grantId, idx, uri)`.
3. Timelock calls `approveMilestone` or `rejectMilestone`. Rejected evidence can
   be resubmitted.
4. A proposal calls `Treasury.payMilestone(grantId, idx)` or
   `Treasury.payMilestoneBatch(grantIds, indexes)` (ETH only; ERC20 milestones
   are paid one at a time).
5. The Treasury reads the approved amount from the registry; the caller cannot
   substitute an amount, token, or recipient. A paid milestone cannot be replayed.

## Vesting grants

1. Deploy `GrantVestingRevocable(beneficiary, treasury, treasury, start,
   duration, cliff)`. The admin **must** be the Treasury, and the beneficiary
   must be the grant recipient.
2. Create the Vesting grant with that vesting address.
3. Governance calls `Treasury.fundVesting(grantId, amount)` (ETH) or
   `fundVestingERC20(grantId, amount)`. Funding rejects a vesting wallet whose
   admin is not the Treasury (`VestingAdminMismatch`), whose immutable
   `treasury` is not the Treasury (`VestingTreasuryMismatch`), or whose
   beneficiary is not the grant recipient (`VestingBeneficiaryMismatch`), so
   funds cannot be parked in a wallet the Treasury cannot revoke, whose unvested
   refund would go elsewhere, or whose beneficiary is not the approved grantee.
4. Beneficiary releases vested funds with `release()` / `releaseERC20(token)`.
5. Governance calls `Treasury.revokeVesting(grantId, reason)`. The vesting
   wallet freezes the already-vested amount, returns unvested funds to the
   Treasury, and the registry marks the grant `Revoked`.

Revocation is per asset: revoking ETH does not block an ERC20 allocation.
`released + revoked <= funded` holds per asset when funding only uses the typed
`fund`/`fundERC20` path (forced ETH or direct token donations are outside that
accounting and are forwarded to Treasury on revocation).

## Cancellation

`Treasury.cancelGrant(grantId, reason)` cancels an unfunded grant. A funded
vesting grant must be revoked instead. Cancellation releases the unpaid
commitment and rejects open milestones; paid funds are never clawed back.

## Accounting

- `committed[token]` is the unfunded Treasury obligation.
- Direct payouts reduce both `committed` and `paid`.
- Vesting funding reduces `committed` and increases `funded`; the funds are now
  in the vesting wallet, not the Treasury.
- Cancellation subtracts the remaining unfunded amount.
- Revocation subtracts any unfunded remainder; unvested funds returned by the
  vesting wallet become uncommitted Treasury balance.
- `availableFor(token, balance)` is `max(balance - committed, 0)`.

No silent amendments: changing recipient, amount, token, or schedule requires a
new proposal.
