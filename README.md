# Grant DAO

A decentralized autonomous organization (DAO) governance system for managing grants and treasury funds. Built with Solidity and Foundry, leveraging OpenZeppelin's battle-tested governance contracts.

## Overview

Grant DAO enables token holders to propose, vote on, and execute grant distributions from a managed treasury. The system implements a robust governance framework with timelock controls, ensuring transparent and democratic fund allocation.

## Core Features

### 🗳️ **Governance System**
- **Token-Based Voting**: ERC20Votes governance token (GDT) with checkpointed voting power
- **Proposal Creation**: Token holders can create proposals for fund distribution
- **Democratic Voting**: Simple counting mechanism (For/Against/Abstain)
- **Quorum Requirements**: Configurable quorum percentage to ensure sufficient participation
- **Timelock Protection**: All approved proposals execute through a timelock delay for security

### 💰 **Treasury Management**
- **ETH Grant Proposals**: Distribute native ETH from the treasury
- **ERC20 Grant Proposals**: Distribute any ERC20 tokens held by the treasury
- **Secure Execution**: Only timelock-controlled execution of treasury operations
- **Reentrancy Protection**: Built-in security measures for all treasury operations

### ⏱️ **Vesting Schedules**
- **Linear Vesting**: Create vesting wallets for beneficiaries
- **Flexible Configuration**: Customizable start times and durations
- **Token & ETH Support**: Vest both native ETH and ERC20 tokens

### 🔐 **Security Features**
- **Timelock Controller**: Mandatory delay before proposal execution
- **Role-Based Access**: Granular permission system for governance operations
- **Proposal Thresholds**: Minimum token requirements to create proposals
- **Voting Delays & Periods**: Configurable timing for fair participation

## Architecture

- **GrantToken**: ERC20 governance token with permit and voting extensions
- **GrantGovernor**: OpenZeppelin Governor with Settings, Counting, Votes, Quorum, and Timelock
- **Treasury**: Secure vault for DAO funds, controlled exclusively by the Timelock
- **GrantVesting**: Vesting wallet implementation for scheduled token releases
- **ProposalBuilder**: Utility library for constructing proposal transactions

## Technology Stack

- **Solidity**: ^0.8.24
- **Foundry**: Development framework and testing
- **OpenZeppelin Contracts**: v5.4.0 for governance and security primitives
- **EVM**: Cancun compatible

## Getting Started

### Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation)

### Build
```bash
forge build
```

### Test
```bash
forge test
```

### Deploy
```bash
forge script script/Deploy.s.sol --rpc-url <RPC_URL> --broadcast
```

## Scripts

The project includes ready-to-use scripts for common operations:
- `Deploy.s.sol`: Deploy complete DAO system
- `ProposeEthGrant.s.sol`: Create ETH grant proposals
- `ProposeErc20Grant.s.sol`: Create ERC20 grant proposals
- `CastVote.s.sol`: Vote on active proposals
- `QueueProposal.s.sol`: Queue approved proposals
- `ExecuteProposal.s.sol`: Execute queued proposals
- `DeployVesting.s.sol`: Create vesting wallets

## Testing

Comprehensive test suite covering:
- Complete governance flow (propose → vote → queue → execute)
- Treasury security and access controls
- Vesting functionality
- Edge cases and failure scenarios

## License

MIT
