# 🏛️ Grant DAO Protocol

Professional governance protocol for decentralized grant management, built on OpenZeppelin's Governor, Timelock, and Token standards.

## 🏗️ Architecture

### Core Contracts
- **GrantToken (`GDT`)**: ERC20 governance token with `ERC20Permit` (gasless approvals) and `ERC20Votes` (checkpointed voting power).
- **GrantGovernor**: OpenZeppelin Governor implementation with configurable settings, quorum, and timelock integration.
- **TimelockController**: Enforces mandatory time delays on all governance actions, owning the Treasury.
- **Treasury**: Secure vault for holding ETH and ERC20 tokens, controllable **only** by the Timelock.
- **GrantVesting**: Vesting wallets for linear release of grant funds.

## 🛠️ Usage

### Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Make](https://www.gnu.org/software/make/)

### Development

```bash
# Install dependencies
make install

# Build contracts
make build

# Run tests
make test
```

### Deployment

**Local Anvil Chain:**
```bash
# Start Anvil in a separate terminal
anvil

# Deploy
make deploy-anvil
```

**Sepolia Testnet:**
1. Copy `.env.example` to `.env` and fill in:
   - `PRIVATE_KEY`
   - `RPC_URL` (or `SEPOLIA_RPC_URL`)
   - `ETHERSCAN_API_KEY`
2. Run deployment:
```bash
make deploy-sepolia
```

## ⚙️ Configuration

Deployment parameters are standard governance defaults (configurable in `script/Deploy.s.sol`):

- **Proposal Threshold**: 100,000 GDT (1% of supply)
- **Voting Delay**: 7200 blocks (~1 day)
- **Voting Period**: 50400 blocks (~1 week)
- **Quorum**: 4%
- **Timelock Delay**: 2 days

## 🔒 Security

- **Timelock Ownership**: The Treasury is owned 100% by the Timelock. No admin keys control funds directly.
- **Guardian**: A guardian role exists on the Timelock to veto malicious proposals during the timelock delay (can be assigned to a multisig).
- **Vesting**: Grants can be streamed via `GrantVesting` to ensure accountability.

## 📄 License
MIT
