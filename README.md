# 🏛️ Grant DAO – Community Grants Governance

## 📚 Documentation Overview

This project includes comprehensive documentation to help you understand and use the Grant DAO system. Here's how the documentation is organized:

- **[Main README](README.md)** - This file: Overview and quick start
- **[Blog Post](blog-post1.md)** - Detailed explanation of DAO concepts and how this project works
- **[Testing Guide](TESTING_README.md)** - Complete testing procedures and manual testing steps
- **[Demo Guide](DEMO_README.md)** - Ultra-fast 2-minute demo setup and workflow


---

## 🏗️ Architecture

### Core Contracts
- **Governance Token (`GDT`)** - ERC20 with `ERC20Permit` (gasless approvals) and `ERC20Votes` (checkpointed voting power)
- **Treasury Vault** - Holds ETH and ERC20 tokens, only callable by the Timelock
- **Governor** - OpenZeppelin Governor with proposal threshold, voting delays, periods, and quorum
- **Timelock** - Enforces mandatory delay between proposal success and execution, owns the Treasury

### Key Features
- Propose ETH or ERC20 token grants
- Vote using checkpointed token balances
- Timelock protection for executed proposals
- Reentrancy protection for treasury operations
- Full governance workflow: propose → vote → queue → execute

---

## 📋 Prerequisites

### Required Tools
- **[Foundry](https://book.getfoundry.sh/getting-started/installation)** (`forge`, `cast`, `anvil`)
- **[Node.js](https://nodejs.org/)** (v18 or higher) + npm
- **[Git](https://git-scm.com/)**

### Verify Installation
```bash
# Check Foundry
forge --version  # Should show version 0.2.x
anvil --version  # Should show version info

# Check Node.js
node --version   # Should show v18.x or higher
npm --version    # Should show version info
```

---

## ⚙️ Smart Contracts Setup

For detailed setup instructions and advanced configuration, see the **[Testing Guide](TESTING_README.md)**.

### Install Dependencies
```bash
forge install
```

### Build Contracts
```bash
forge build
```

### Run Tests
```bash
forge test -vv
```

### Deploy Locally
```bash
# Start Anvil first
anvil

# Deploy in new terminal
source .env
forge script script/Deploy.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast -vvvv
```

---

## 🌐 Frontend Setup

For detailed frontend configuration and advanced setup, see the **[Testing Guide](TESTING_README.md)**.

### Install Dependencies
```bash
cd frontend
npm install
```

### Configure Environment
Create a `.env.local` file in the frontend directory with your contract addresses:

```bash
# Contract Addresses for different networks
# Update these with your deployed contract addresses

# Mainnet (Ethereum Mainnet)
NEXT_PUBLIC_MAINNET_GRANT_TOKEN=0x0000000000000000000000000000000000000000
NEXT_PUBLIC_MAINNET_GRANT_GOVERNOR=0x0000000000000000000000000000000000000000
NEXT_PUBLIC_MAINNET_TREASURY=0x0000000000000000000000000000000000000000
NEXT_PUBLIC_MAINNET_TIMELOCK=0x0000000000000000000000000000000000000000

# Sepolia Testnet
NEXT_PUBLIC_SEPOLIA_GRANT_TOKEN=0x0000000000000000000000000000000000000000
NEXT_PUBLIC_SEPOLIA_GRANT_GOVERNOR=0x0000000000000000000000000000000000000000
NEXT_PUBLIC_SEPOLIA_TREASURY=0x0000000000000000000000000000000000000000
NEXT_PUBLIC_SEPOLIA_TIMELOCK=0x0000000000000000000000000000000000000000

# Local Development (Anvil)
NEXT_PUBLIC_ANVIL_GRANT_TOKEN=0x5FbDB2315678afecb367f032d93F642f64180aa3
NEXT_PUBLIC_ANVIL_GRANT_GOVERNOR=0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
NEXT_PUBLIC_ANVIL_TREASURY=0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9
NEXT_PUBLIC_ANVIL_TIMELOCK=0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
```

**Note**: Environment variables must be prefixed with `NEXT_PUBLIC_` to be accessible in the browser. The `.env.local` file is automatically gitignored by Next.js for security.

### Start Development Server
```bash
npm run dev
```
- Local: `http://localhost:3000`
- Network: `http://192.168.x.x:3000`

### Build for Production
```bash
npm run build
npm start
```

---

## 👨‍💻 Future Work

- Support **grant categories** (public goods, developer tooling, art)
- Add **off-chain proposal metadata** (IPFS/Arweave)
- Consider **upgradeable pattern** if governance wants flexibility
