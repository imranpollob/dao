# Roles

| Role | Held by | Can do | Cannot do |
|---|---|---|---|
| Timelock (Treasury owner, Registry owner) | Itself | Create/approve/reject grants via proposals, rotate roles, unpause, change policy | Act without a passed proposal |
| Treasury | Contract owned by Timelock | Validate and execute registry-bound payouts, record payouts/funding/cancel/revoke | Pay arbitrary targets or tokens not backed by a grant |
| Governor | DAO voters | Queue/execute passed proposals, guardian rotation via governance | Bypass timelock delay |
| Guardian | Multisig | Pause outflows, veto Pending/Active/Succeeded/Queued proposals | Move funds, unpause, extend an active pause; can start a new pause after expiry |
| Recipient | Per grant | Submit evidence, release vested funds | Change grant terms, choose payout recipient/token |
| Reviewer | Advisory metadata only | Nothing on-chain | Approve or reject milestones |

Only the Timelock can call `GrantRegistry.createGrant`, `approveMilestone`,
`rejectMilestone`, and Treasury policy setters. The Treasury is the only address
that can call `recordPayout`, `recordVestingFunding`, `cancelGrant`, or
`revokeGrant` on the registry.

Guardian pause is time-bounded (`maxPauseDuration`, default 7 days) and
extendable only by the Timelock. Pause blocks Treasury outflows, never deposits,
cancellation, or vesting revocation; already-vested releases from a vesting
wallet remain available to its beneficiary. Guardian and Governor roles are
rotatable by governance; `RotateGuardian.s.sol` updates both
`Governor.setGuardian` and `Treasury.setPauser`. The deployer retains no roles
after deployment (asserted in `Deploy.s.sol`).
