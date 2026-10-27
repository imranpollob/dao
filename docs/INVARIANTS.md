# Invariants

Proven by `test/invariants/TreasuryInvariants.t.sol` (handler fuzz) and unit
tests (`Registry`, `TreasuryPolicy`, `test/attacks/`, `ProposalRisk`).

1. Treasury balance never drops below `treasuryFloor` via the typed payout path.
2. Cumulative typed payouts never exceed initial funding minus current balance.
3. `GrantRegistry.recordPayout` only succeeds for an approved milestone or within
   the grant remainder; replays revert.
4. Only the Treasury can record payouts, vesting funding, cancellation, or
   revocation. `committed[token]` equals the unpaid/unfunded remainder and
   decreases exactly once per payout/funding/cancel/revoke.
5. Vesting: for assets funded only through `fund`/`fundERC20`,
   `released + revoked <= funded` for ETH and each ERC20; revocation freezes the
   vested amount, returns unvested funds to Treasury, and later releases cannot
   underflow or lock. Forced ETH (selfdestruct) or direct token donations are
   outside that accounting and are forwarded to Treasury on revocation.
6. Pause blocks `payGrant`, `payMilestone`, `payMilestoneBatch`, `fundVesting`,
   and `fundVestingERC20`; deposits, cancellation, and vesting revocation still
   work.
7. No raw arbitrary-value execution path exists on Treasury; typed payouts derive
   recipient/token/amount from the registry.
8. `releasedETH`/`releasedERC20` never exceed `vestedETH`/`vestedERC20` at the
   applicable timestamp (current or revocation freeze).

Echidna/Medusa campaigns are future work; the handler is written to port directly
(see `docs/ADRs.md`). Halmos 0.3.3 was installed and attempted: it cannot execute
these suites because the forge-std `Test` setup path uses the `deployCode`
cheatcode, which Halmos does not support. Dedicated Halmos-native specs (no
forge-std `Test` base) are the follow-up. The current Foundry handler campaign
runs 256 runs x 128k calls with zero reverts. Certora remains optional.
