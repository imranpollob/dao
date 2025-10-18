# 🧪 Grant DAO - Complete Testing Guide

This guide provides step-by-step instructions to test all features of the Grant DAO project from the terminal. The project includes smart contracts for governance, treasury management, and a Next.js frontend for user interactions.

## 📚 Related Documentation

- **[Main README](README.md)** - Project overview and quick start
- **[Blog Post](blog-post1.md)** - Detailed DAO concepts and implementation
- **[Demo Guide](DEMO_README.md)** - Ultra-fast 2-minute demo setup

---

## 🛠️ Prerequisites

- **Foundry**: For smart contract development and testing
  ```bash
  curl -L https://foundry.paradigm.xyz | bash
  foundryup
  ```

- **Node.js** (v18+): For frontend development
  ```bash
  # Install via nvm or download from nodejs.org
  nvm install 18
  nvm use 18
  ```

- **Git**: For version control

---

## 🚀 Project Setup

1. **Clone and navigate to the project**:
   ```bash
   git clone <repository-url>
   cd dao
   ```

2. **Install smart contract dependencies**:
   ```bash
   forge install
   ```

3. **Install frontend dependencies**:
   ```bash
   cd frontend
   npm install
   cd ..
   ```

4. **Generate ABI for frontend**:
   ```bash
   node script/generate-abi.js
   ```

---

## 🧪 Testing All Features

### 1. Start Local Blockchain

Start Anvil (Foundry's local Ethereum network) in the background:
```bash
anvil
```
This starts a local blockchain on `http://localhost:8545` with pre-funded accounts.

### 2. Deploy Contracts

Deploy all DAO contracts with optimized demo parameters (fast timelock and voting periods):
```bash
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

The deployment script will output contract addresses. Update the environment files:
```bash
# Backend .env
echo "GOVERNOR_ADDRESS=<governor-address>" > .env
echo "TREASURY_ADDRESS=<treasury-address>" >> .env
echo "GRANT_TOKEN_ADDRESS=<token-address>" >> .env

# Frontend .env.local
echo "NEXT_PUBLIC_GOVERNOR_ADDRESS=<governor-address>" > frontend/.env.local
echo "NEXT_PUBLIC_TREASURY_ADDRESS=<treasury-address>" >> frontend/.env.local
echo "NEXT_PUBLIC_GRANT_TOKEN_ADDRESS=<token-address>" >> frontend/.env.local
```

Or use the automated script to update environment files:
```bash
node script/update-env.js
```

Then source the environment variables:
```bash
source .env
```

### 3. Manual Feature Testing

**Important**: Make sure to source your environment variables first:
```bash
source .env
```

**Delegate voting tokens** (required for proposal creation):
```bash
# Delegate tokens to yourself to get voting power
cast send $GRANT_TOKEN "delegate(address)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Advance blocks to ensure delegation takes effect
cast rpc anvil_mine 1 --rpc-url http://localhost:8545
```

#### Check Contract Parameters
Verify the demo parameters are set correctly:
```bash
# Voting delay (should be 1 block)
cast call $GOVERNOR "votingDelay()" --rpc-url http://localhost:8545 | cast --to-dec

# Voting period (should be 5 blocks)
cast call $GOVERNOR "votingPeriod()" --rpc-url http://localhost:8545 | cast --to-dec

# Timelock delay (should be 10 seconds)
cast call $TIMELOCK "getMinDelay()" --rpc-url http://localhost:8545 | cast --to-dec

# Proposal threshold (should be 100 tokens) 100 x 1e18
cast call $GOVERNOR "proposalThreshold()" --rpc-url http://localhost:8545 | cast --to-dec
```

#### Create Proposals Manually

**ETH Grant Proposal**:
Need to set proposal parameters as environment variables:
```bash
export RECIPIENT=0x70997970C51812dc3A010C7d01b50e0d17dc79C8  # Example recipient address, anvil 2nd account
export AMOUNT_WEI=1000000000000000000  # 1 ETH in wei
export DESCRIPTION="Test ETH grant proposal"

forge script script/ProposeEthGrant.s.sol --rpc-url http://localhost:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# check recipient balance
cast balance $RECIPIENT --rpc-url http://localhost:8545 | cast --to-dec

```

**ERC20 Grant Proposal**:
```bash
export ERC20=$GRANT_TOKEN  # Use the deployed grant token
export TO=0x70997970C51812dc3A010C7d01b50e0d17dc79C8  # Example recipient address
export AMOUNT=100000000000000000000  # 100 tokens in wei
export DESCRIPTION="Test ERC20 grant proposal"

forge script script/ProposeErc20Grant.s.sol --rpc-url http://localhost:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

#### List All Proposals
To see all created proposal IDs:
```bash
npm run list-proposals
```
This will output the total number of proposals and their IDs.

#### Vote on Proposals
Get total proposal count:
```bash
cast call $GOVERNOR "proposalCount()" --rpc-url http://localhost:8545 | cast --to-dec
```

Set voting parameters and cast votes (replace PROPOSAL_ID with actual ID):
```bash
export PROPOSAL_ID=<actual-proposal-id-here>
export SUPPORT=1  # 1=For, 0=Against, 2=Abstain
export REASON="I support this proposal"
```
Check proposal state:

States: 0=Pending, 1=Active, 2=Canceled, 3=Defeated, 4=Succeeded, 5=Queued, 6=Expired, 7=Executed
```bash
cast call $GOVERNOR "state(uint256)" $PROPOSAL_ID --rpc-url http://localhost:8545 | cast --to-dec
```

Advance 1 block to pass the voting delay:
```bash
cast rpc anvil_mine 1 --rpc-url http://localhost:8545
```

Cast votes:

Vote in favor (support = 1)
```bash
forge script script/CastVote.s.sol --rpc-url http://localhost:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --sig "run(uint256,uint8)" $PROPOSAL_ID 1
```

Vote against (support = 0)
```bash
forge script script/CastVote.s.sol --rpc-url http://localhost:8545 --broadcast --private-key 0x59c6995e998f97a5a0044966f0945389dc9e86dae75c2a9ea38422a9dcf8c80a  --sig "run(uint256,uint8)" $PROPOSAL_ID 0
```

Check state again:
```bash
# Current block
cast block-number --rpc-url http://localhost:8545

# Deadline
cast call $GOVERNOR "proposalDeadline(uint256)" $PROPOSAL_ID --rpc-url http://localhost:8545 | cast --to-dec

# Advance blocks to end voting period (5 blocks)
cast rpc anvil_mine 6 --rpc-url http://localhost:8545

# Check final state (should be 4 = Succeeded)
cast call $GOVERNOR "state(uint256)" $PROPOSAL_ID --rpc-url http://localhost:8545 | cast --to-dec
```

#### Check vote counts
```bash
cast call $GOVERNOR "proposalVotes(uint256)" $PROPOSAL_ID --rpc-url http://localhost:8545 
```

#### Queue and Execute Proposals
After voting period ends (advance blocks if needed):
```bash
# Queue proposal
forge script script/QueueProposal.s.sol --rpc-url http://localhost:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --sig "run(uint256)" $PROPOSAL_ID

# Check proposal status
cast call $GOVERNOR "state(uint256)" $PROPOSAL_ID --rpc-url http://localhost:8545 | cast --to-dec

# Advance time for timelock delay (10 seconds on Anvil)
# 10 seconds buffer time to execute a queued proposal
cast rpc evm_increaseTime 10 --rpc-url http://localhost:8545
cast rpc evm_mine --rpc-url http://localhost:8545

# Fund treasury for ETH grants (skip for ERC20 grants)
cast send $TREASURY --value 1ether --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Execute proposal
forge script script/ExecuteProposal.s.sol --rpc-url http://localhost:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --sig "run(uint256)" $PROPOSAL_ID

# Check proposal status
cast call $GOVERNOR "state(uint256)" $PROPOSAL_ID --rpc-url http://localhost:8545 | cast --to-dec
```

#### Check Balance
Verify funds were transferred:
```bash
# Check ETH balance
cast balance $TREASURY --rpc-url http://localhost:8545

# Check ERC20 token balance (if applicable)
cast call $GRANT_TOKEN "balanceOf(address)" $TREASURY --rpc-url http://localhost:8545 | cast --to-dec

# Check recipient balance
cast balance $RECIPIENT --rpc-url http://localhost:8545 | cast --to-dec
```

### 4. Frontend Testing

Start the Next.js development server:
```bash
cd frontend
npm run dev
```

Open `http://localhost:3000` in your browser and test:

- **Proposal Creation**: Create ETH and ERC20 grant proposals
- **Proposal Listing**: View active proposals with details
- **Voting Interface**: Cast votes on proposals
- **Treasury Display**: Check treasury balances and transaction history

### 5. Comprehensive Test Suite

Run the full test suite:
```bash
forge test
```

Run specific test files:
```bash
forge test --match-path test/GovernanceFlow.t.sol
forge test --match-path test/TreasurySmoke.t.sol
forge test --match-path test/ComprehensiveScenarios.t.sol
```

### 6. Troubleshooting

- **Contract deployment fails**: Ensure Anvil is running and RPC URL is correct
- **Script execution fails**: Check private key and contract addresses in environment
- **Environment variables not set**: Run `node script/update-env.js` and `source .env`
- **Frontend not loading**: Verify environment variables and contract addresses
- **Voting fails**: Ensure proposal is in active state and voting period hasn't ended
- **Execution fails**: Check timelock delay and proposal state
- **isOperationReady returns false after advancing time**: Ensure `$TIMELOCK` is set correctly and blockchain time has been advanced with `cast rpc evm_increaseTime 10` followed by `cast rpc evm_mine`
- **Execution fails with OutOfFunds**: For ETH grants, fund the treasury first: `cast send $TREASURY --value 1ether --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`

For additional resources and concepts, see the **[Blog Post](blog-post1.md)**.

## Contract Addresses (Example)

After deployment, your addresses will be similar to:
- Governor: 0x9fe46736679d2d9a65f0992f2272de9f3c7fa6e0
- Treasury: 0xcf7ed3acca5a467e9e704c703e8d87f634fb0fc9
- GrantToken: 0x5fbdb2315678afecb367f032d93f642f64180aa3

Update these in your environment files for testing.