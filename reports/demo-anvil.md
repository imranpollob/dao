# Live Anvil Demo Evidence

Date: 2026-10-27. Fresh Anvil, `DeployLocal` broadcast, full governance
flow executed with `cast`. Node stopped afterwards.

## Deployment

- GrantToken: 0x5FbDB2315678afecb367f032d93F642f64180aa3
- Timelock: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
- Governor: 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
- Treasury: 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9
- Registry: 0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9

## Flow

1. Funded Treasury with 10 ETH. Proposed typed payout of 1 ETH to
   `0x70997970C51812dc3A010C7d01b50e0d17dc79C8` (grant 1, milestone 0).
2. Proposal `0x40a84d3439e95c33b04aa5acca4285a697de621a927a8abdf5528e54b4bd59f8`:
   Pending (0) -> Active (1) -> voted For -> Succeeded (4) -> Queued (5).
3. Advanced time past the 60s timelock, executed: state Executed (7).
4. Payee balance: 10000 ETH -> 10001 ETH. Treasury down by exactly 1 ETH.

## Notes

- `cast rpc anvil_mine` takes no count argument in this toolchain; mine
  one block per call. `evm_increaseTime` takes a plain number, not an array.
- Reproduces with: `anvil &`, `make demo`, then the `cast` sequence above.

## Ops scripts (second fresh Anvil, same deterministic addresses)

- `Doctor`: chainId 31337, all code present, treasury owner = timelock,
  paused = false, proposer = governor, executor open. Pass.
- `Roles`: admin = timelock, proposer = governor, executor open,
  guardian canceller true, minDelay 60. Pass.
- `SimulateProposal`: policy readable, no baseline flags. Pass.
- `make security`: regenerates `reports/coverage.txt` and `reports/gas.txt`. Pass.
