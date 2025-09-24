# 🏛️ Grant DAO – Comm---

## 🚀 Quick Commands

### Get Help
```bash
# Show all available commands
npm run help
```

### Essential Commands
```bash
# Start full development environment (blockchain + frontend)
npm run dev

# Start only blockchain
npm run blockchain

# Start only frontend (requires blockchain running)
npm run frontend

# Deploy contracts to local blockchain
npm run deploy

# Test smart contracts
npm run test

# Build frontend
npm run build

# Clean caches and builds
npm run clean
```

---

## �📜 Contracts Overviewty Grants Governance

A **Decentralized Autonomous Organization (DAO)** where members holding governance tokens (`GDT`) can propose, vote, and fund community projects from a shared treasury.

Read this **[detailed blog post](blog-post1.md)** to get familiar with DAOs and how this project works.

---

## � Table of Contents

- [Contracts Overview](#-contracts-overview)
- [Prerequisites](#-prerequisites)
- [Quick Start (Full System)](#-quick-start-full-system)
- [Smart Contracts Setup](#-smart-contracts-setup)
- [Frontend Setup](#-frontend-setup)
- [Testing the System](#-testing-the-system)
- [Governance Workflow](#-governance-workflow)
- [Deployment](#-deployment)
- [Security Considerations](#-security-considerations)
- [References](#-references)
- [Future Work](#-future-work)

---

## �📜 Contracts Overview

- **Governance Token (`GDT`)**
  - ERC20 with `ERC20Permit` (gasless approvals)
  - ERC20Votes (checkpointed voting power)
  - Voting power is snapshotted at proposal creation

- **Treasury Vault**
  - Holds ETH and ERC20 tokens
  - Only callable by the Timelock
  - Executes arbitrary transactions approved by governance

- **Governor**
  - OpenZeppelin Governor with:
    - Proposal threshold (absolute tokens required to propose)
    - Voting delay (blocks)
    - Voting period (blocks)
    - Quorum fraction (percentage of supply)
    - Counting: For / Against / Abstain
  - Integrated with Timelock for queued execution

- **Timelock**
  - Enforces mandatory delay between proposal success and execution
  - Owns the Treasury
  - Governor is the proposer, anyone can execute (configurable)

- **Proposal Builder Helpers**
  - Encode ETH grants and ERC20 token grants easily

- **Scripts**
  - Deploy full stack (`GrantToken`, `Treasury`, `Governor`, `Timelock`)
  - Propose ETH or ERC20 grants
  - Queue and Execute proposals

- **Tests**
  - **TreasurySmoke.t.sol**: Deployment validation, role configuration, treasury security (access control, reentrancy protection)
  - **GovernanceFlow.t.sol**: End-to-end governance flows including ETH grants, ERC20 grants, and proposal rejection scenarios
  - Comprehensive coverage: propose → vote → queue → execute → funds transferred
  - Security testing: access controls, reentrancy protection, proper state transitions

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

## 🚀 Quick Start (Full System)

Get the entire Grant DAO system running in 5 minutes!

### Step 1: Clone and Setup
```bash
git clone <your-repo-url>
cd dao

# Install smart contract dependencies
forge install

# Install frontend dependencies
cd frontend && npm install && cd ..
```

### Step 2: Create Environment File
```bash
# In the root directory, create .env
cat > .env << EOF
# Local development
RPC_URL=http://127.0.0.1:8545
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Deployed contract addresses (will be filled after deployment)
TREASURY=0x0000000000000000000000000000000000000000
GOVERNOR=0x0000000000000000000000000000000000000000
GRANT_TOKEN=0x0000000000000000000000000000000000000000
TIMELOCK=0x0000000000000000000000000000000000000000
EOF
```

### Step 3: Start Local Blockchain
```bash
# Terminal 1: Start Anvil (local Ethereum network)
anvil
```
Anvil will start at `http://127.0.0.1:8545` with pre-funded accounts.

### Step 4: Deploy Smart Contracts
```bash
# Terminal 2: Deploy all contracts
source .env
forge script script/Deploy.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast -vvvv
```
**Save the deployed addresses** from the output:
```
GrantToken: 0x959922bE3CAee4b8Cd9a407cc3ac1C251C2007B1
Timelock  : 0x9A9f2CCfdE556A7E9Ff0848998Aa4a0CFD8863AE
Governor  : 0x68B1D87F95878fE05B998F19b66F4baba5De1aed
Treasury  : 0x3Aa5ebB10DC797CAC828524e59A333d0A371443c
```

### Step 5: Update Environment Variables
```bash
# Update .env with deployed addresses
sed -i '' 's/TREASURY=.*/TREASURY=0x3Aa5ebB10DC797CAC828524e59A333d0A371443c/' .env
sed -i '' 's/GOVERNOR=.*/GOVERNOR=0x68B1D87F95878fE05B998F19b66F4baba5De1aed/' .env
sed -i '' 's/GRANT_TOKEN=.*/GRANT_TOKEN=0x959922bE3CAee4b8Cd9a407cc3ac1C251C2007B1/' .env
sed -i '' 's/TIMELOCK=.*/TIMELOCK=0x9A9f2CCfdE556A7E9Ff0848998Aa4a0CFD8863AE/' .env
```

### Step 6: Update Frontend Configuration
```bash
# Update frontend contract addresses
cd frontend/src/lib/contracts
# Edit index.ts to replace anvil addresses with deployed ones
```

### Step 7: Start Frontend
```bash
# Terminal 3: Start the frontend
cd frontend
npm run dev
```
Frontend will be available at `http://localhost:3000`

### Step 8: Test the System
1. Open `http://localhost:3000` in your browser
2. Connect MetaMask to Anvil network:
   - Network Name: `Anvil`
   - RPC URL: `http://127.0.0.1:8545`
   - Chain ID: `31337`
   - Currency Symbol: `ETH`
3. Import Anvil account: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`
4. View balances and interact with the DAO!

---

## ⚙️ Smart Contracts Setup

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

## 🧪 Testing the System

### Run All Tests
```bash
forge test -vv
```

### Manual Testing Steps

1. **Fund Treasury**
```bash
source .env
cast send $TREASURY --value 10ether --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

2. **Delegate Voting Power**
```bash
# Get some tokens first (from deployer)
cast send $GRANT_TOKEN "transfer(address,uint256)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 1000000000000000000000 --private-key $PRIVATE_KEY --rpc-url $RPC_URL

# Delegate to yourself
cast send $GRANT_TOKEN "delegate(address)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

3. **Create Proposal**
```bash
forge script script/ProposeEthGrant.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast -vvvv
```

4. **Vote on Proposal**
```bash
cast send $GOVERNOR "castVote(uint256,uint8)" <proposalId> 1 --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

5. **Queue and Execute**
```bash
forge script script/QueueAndExecute.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --sig "run(uint256)" <proposalId>
```

---

## 🚀 Deployment

### To Testnet (Sepolia)
1. Update `.env`:
```bash
RPC_URL=https://rpc.sepolia.org
PRIVATE_KEY=0xabc123... # Your funded Sepolia account
```

2. Deploy:
```bash
forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast -vvvv
```

3. Update frontend contract addresses for Sepolia network.

### To Mainnet
1. Update `.env` with mainnet RPC and funded account
2. Deploy with same script
3. Update frontend configuration

---

## 🗳️ Governance Workflow

1. **Acquire GDT**
   - Airdrop or transfer from deployer
   - Delegate to yourself: `token.delegate(msg.sender)`
   - **Without delegation, you have 0 voting power**

2. **Create Proposal**
   - Example: fund project with 5 ETH
   ```bash
   export RECIPIENT=0xRecipient
   export AMOUNT_WEI=5000000000000000000
   export DESCRIPTION="Grant: 5 ETH to Project X"
   forge script script/ProposeEthGrant.s.sol --rpc-url $RPC_URL --broadcast -vvvv
   ```

3. **Vote**
   - After voting delay: `cast send $GOVERNOR "castVote(uint256,uint8)" <proposalId> 1`
   - Options: 0=Against, 1=For, 2=Abstain

4. **Queue Proposal**
   - If quorum met and majority For
   ```bash
   forge script script/QueueAndExecute.s.sol --rpc-url $RPC_URL --broadcast -vvvv
   ```

5. **Execute Proposal**
   - After timelock delay, funds transfer from Treasury

---

## 🔒 Security Considerations

- Only **Timelock** can own Treasury
- Timelock admin role is renounced post-deploy → no EOA backdoors
- Voting power is snapshot-based → prevents vote-buy attacks
- Delay gives community reaction window before execution
- Treasury execute is guarded by `nonReentrant`

---

## 📚 References

- [OpenZeppelin Governor docs](https://docs.openzeppelin.com/contracts/5.x/governance)
- [Foundry Book](https://book.getfoundry.sh/)
- [ERC20Votes](https://docs.openzeppelin.com/contracts/5.x/api/token/erc20#ERC20Votes)

---

## 👨‍💻 Future Work

- Add a **frontend dApp** (Next.js + wagmi/viem) for UX ✅
- Support **grant categories** (public goods, developer tooling, art)
- Add **off-chain proposal metadata** (IPFS/Arweave)
- Consider **upgradeable pattern** if governance wants flexibility
- Integrate **GovernorCompatibilityBravo** for tooling like Tally


