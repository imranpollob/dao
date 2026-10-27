# Local Demo Evidence

Date: 2026-10-27. Foundry/Anvil toolchain. This is the post-remediation
evidence set.

## 1. Local deploy

Command: `RPC_URL=http://127.0.0.1:8546 make demo` against a fresh Anvil
(`--port 8546` in this run).

```text
GrantToken: 0x5FbDB2315678afecb367f032d93F642f64180aa3
Timelock  : 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
Governor  : 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
Treasury  : 0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9
Registry  : 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9
```

`DeployLocal` wires the registry to the Treasury, sets caps, transfers ownership
to the Timelock, renounces the deployer admin role, and self-delegates the
deployer's token balance so the local profile has votes.

## 2. Seed

Command: `RPC_URL=http://127.0.0.1:8546 make seed-demo` with `TOKEN`,
`TREASURY`, `RECIPIENT`, and `PRIVATE_KEY` set.

```text
seeded treasury: 10000000000000000000
recipient GDT: 100000000000000000000000
```

## 3. Doctor

`RPC_URL=http://127.0.0.1:8546 make doctor` on the same deployment, with the
wiring/role/token-holder environment variables set:

```text
chainId: 31337
token code: 8719
governor code: 23422
treasury code: 16593
registry code: 12069
treasury owner: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
registry owner: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
treasury registry: 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9
registry treasury: 0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9
wiring ok: true
treasury paused: false
treasury ETH: 10000000000000000000
treasury floor: 0
timelock delay: 60
proposer=governor: true
executor=open: true
timelock self-admin: true
governor canceller: true
guardian: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
guardian env matches: true
guardian is treasury pauser: true
guardian direct canceller: false
token holder balance: 900000000000000000000000
token holder votes: 900000000000000000000000
```

## 4. CLI grant proposals

`CreateGrant` was run against the same deployment with the Immediate and
Milestone profiles. It built the registry calldata, called
`GrantGovernor.propose`, and printed the proposal IDs:

```text
Immediate proposalId: 45401808457860559253673871585942323640686633513948212162249681563115516358351
Milestone proposalId: 12760596586284166661681571594684089490269712229687121953173027934703672253910
```

The Milestone run used `MILESTONE_AMOUNTS=1000000000000000000,2000000000000000000`
and `MILESTONE_DUE_DATES=0,0`, exercising the comma-separated CSV parser. Neither
proposal was executed on this deployment; the full lifecycle below is the
executed-path evidence.

## 5. Full lifecycle

Command: `make demo-test` (`test/DemoLifecycle.t.sol`). This is the one-command
lifecycle report: deploy -> create Immediate grant -> propose -> vote -> queue ->
2-day timelock -> execute.

```text
token: 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f
timelock: 0x2e234DAe75C793f67A35089C9d99245E1C58470b
governor: 0xF62849F9A0B5Bf2913b396098F7c7019b51A820a
treasury: 0xc7183455a4C133Ae270771860664b6B7ec320bB1
registry: 0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9
proposalId: 82461960997110208757244402197521909677971349961755355579195908611365357950518
grantId: 1
recipient delta: 10000000000000000000
grant paid: 10000000000000000000
registry committed: 0
treasury available: 90000000000000000000
```

Assertions in the test also prove the grant status is `Completed`, the recipient
delta is exactly 10 ETH, and the registry commitment is zero after payout.

## Notes

- The Anvil node was stopped after the deploy/seed/Doctor/CLI checks.
- `make demo` deploys only; it does not create or execute a grant.
  `make demo-test` is the full lifecycle evidence.
- Production deployment is not exercised here because it deliberately requires a
  guardian contract and a separate token holder who self-delegates.
