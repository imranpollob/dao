# DAO Project Testing Guide

This guide provides step-by-step instructions to test all features of the DAO project from the terminal. The project # Vote in favor (support = 1)
forge script script/CastVote.s.sol --rpc-url http://localhost:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --sig "run(uint256,uint8)" $PROPOSAL_ID 1

# Vote against (support = 0)
forge script script/CastVote.s.sol --rpc-url http://localhost:8545 --broadcast --private-key 0x59c6995e998f97a5a0044966f0945389dc9e86dae75c2a9ea38422a9dcf8c80a  --sig "run(uint256,uint8)" $PROPOSAL_ID 0des smart contracts for governance, treasury management, and a Next.js frontend for user interactions.

## Prerequisites

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

## Project Setup

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

## Testing All Features

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
```

**ERC20 Grant Proposal**:
```bash
export ERC20=$GRANT_TOKEN  # Use the deployed grant token
export TO=0x70997970C51812dc3A010C7d01b50e0d17dc79C8  # Example recipient address
export AMOUNT=100000000000000000000  # 100 tokens in wei
export DESCRIPTION="Test ERC20 grant proposal"

forge script script/ProposeErc20Grant.s.sol --rpc-url http://localhost:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

#### Vote on Proposals
Get the latest proposal ID:
```bash
cast call $GOVERNOR "proposalCount()" --rpc-url http://localhost:8545 | cast --to-dec
```

Set voting parameters and cast votes (replace PROPOSAL_ID with actual ID):
```bash
export PROPOSAL_ID=<actual-proposal-id-here>  # Replace with actual proposal ID from creation output
export SUPPORT=1  # 1=For, 0=Against, 2=Abstain
export REASON="I support this proposal"
```
Check proposal state:
```bash
# States: 0=Pending, 1=Active, 2=Canceled, 3=Defeated, 4=Succeeded, 5=Queued, 6=Expired, 7=Executed
cast call $GOVERNOR "state(uint256)" $PROPOSAL_ID --rpc-url http://localhost:8545 | cast --to-dec
```

**Note**: After creating a proposal, the script will output the proposal ID. Copy that ID and use it for voting, queuing, and execution. The proposal ID is a long hexadecimal number (hash).
Voting:

```bash
# Vote in favor (support = 1)
forge script script/CastVote.s.sol --rpc-url http://localhost:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --sig "run(uint256,uint8)" PROPOSAL_ID 1

# Vote against (support = 0)
forge script script/CastVote.s.sol --rpc-url http://localhost:8545 --broadcast --private-key 0x59c6995e998f97a5a0044966f0945389dc9e86dae75c2a9ea38422a9dcf8c80a  --sig "run(uint256,uint8)" PROPOSAL_ID 0
```

#### Queue and Execute Proposals
After voting period ends (advance blocks if needed):
```bash
# Advance blocks to end voting period
cast rpc anvil_mine 6 --rpc-url http://localhost:8545

# Queue proposal
forge script script/QueueProposal.s.sol --rpc-url http://localhost:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --sig "run(uint256)" $PROPOSAL_ID

# Wait for timelock (10 seconds)
sleep 10

# Execute proposal
forge script script/ExecuteProposal.s.sol --rpc-url http://localhost:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --sig "run(uint256)" $PROPOSAL_ID
```

#### Check Treasury Balance
Verify funds were transferred:
```bash
# Check ETH balance
cast balance $TREASURY --rpc-url http://localhost:8545

# Check ERC20 token balance (if applicable)
cast call $GRANT_TOKEN "balanceOf(address)" $TREASURY --rpc-url http://localhost:8545 | cast --to-dec
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
- **Frontend not loading**: Verify environment variables and contract addresses
- **Voting fails**: Ensure proposal is in active state and voting period hasn't ended
- **Execution fails**: Check timelock delay and proposal state

## Contract Addresses (Example)

After deployment, your addresses will be similar to:
- Governor: 0x9fe46736679d2d9a65f0992f2272de9f3c7fa6e0
- Treasury: 0xcf7ed3acca5a467e9e704c703e8d87f634fb0fc9
- GrantToken: 0x5fbdb2315678afecb367f032d93f642f64180aa3

Update these in your environment files for testing.