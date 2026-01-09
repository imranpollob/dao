# Grant DAO Protocol
A standard implementation of OpenZeppelin's Governor, Timelock, and Token standards for decentralized grant management.


## Features
- **Proposal Management**: On-chain proposal creation with calldata for arbitrary execution.
- **Vote Escrow**: Voting power is determined by held tokens at the block snapshot of proposal creation.
- **Timelock Protection**: Successful proposals must sit in a timelock queue for 2 days, allowing for vetoes by a Guardian if malicious.
- **Treasury Control**: All funds are strictly controlled by governance; no external admins have access to funds.
- **Vesting**: Native support for creating vesting schedules for grant recipients.


## Architecture
The protocol uses the standard Governor + Timelock + Token topology:

- **GrantGovernor**: Core governance logic handling proposal creation, voting states, and quorum checks.
- **GrantToken (GDT)**: ERC20 governance token with `ERC20Permit` for signatures and `ERC20Votes` for checkpointed voting power.
- **TimelockController**: The administrative owner of the system. It enforces a mandatory 2-day delay on all successful proposals before they can be executed.
- **Treasury**: A secure holding contract for protocol funds (ETH and ERC20). It allows execution only via the Timelock.
- **GrantVesting**: A linear vesting wallet for controlled release of grant funds to recipients.



## Usage

### Prerequisites
- [Foundry](https://book.getfoundry.sh/)
- [Make](https://www.gnu.org/software/make/)

### Development

```bash
# Install dependencies
make install

# Build contracts
make build

# Run comprehensive tests
make test
```

### Deployment

**Local Anvil Chain**
```bash
# 1. Start Anvil
anvil

# 2. Deploy (in new terminal)
make deploy-anvil
```

**Testnet / Mainnet**
1. Copy the environment template:
   ```bash
   cp .env.example .env
   ```
2. Configure `.env` with your `PRIVATE_KEY` and `RPC_URL`.
3. Deploy to Sepolia (example):
   ```bash
   make deploy-sepolia
   ```

## Governance Parameters

- **Proposal Threshold**: 100,000 GDT (1% of Total Supply)
- **Quorum**: 4% (Minimum token participation)
- **Voting Delay**: 7,200 Blocks (~1 day)
- **Voting Period**: 50,400 Blocks (~1 week)
- **Timelock Delay**: 2 Days

