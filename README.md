# 🏛️ Grant DAO – Community Grants Governance

A **Decentralized Autonomous Organization (DAO)** where members holding governance tokens (`GDT`) can propose, vote, and fund community projects from a shared treasury.  
This project is built with **Foundry** and **OpenZeppelin Contracts v5**, implementing modern governance best practices (Governor + Timelock + Treasury vault).

---

## ✨ Features

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
  - End-to-end governance flow: propose → vote → queue → execute → funds transferred

---

## 📂 Project Structure

```

.
├── src
│   ├── GrantToken.sol         # ERC20Votes governance token
│   ├── Treasury.sol           # Vault owned by Timelock
│   ├── GrantGovernor.sol      # Governor with Timelock integration
│   └── utils
│       └── ProposalBuilder.sol # Helpers for ETH/ERC20 grant proposals
│
├── script
│   ├── Deploy.s.sol           # Deploys all contracts and wires roles
│   ├── ProposeEthGrant.s.sol  # Create proposal to send ETH from Treasury
│   ├── ProposeErc20Grant.s.sol# Create proposal to send ERC20 tokens
│   └── QueueAndExecute.s.sol  # Queues + executes a passed proposal
│
├── test
│   ├── GovernanceFlow\.t.sol   # Full end-to-end governance flow test
│   └── TreasurySmoke.t.sol    # Basic deployment and wiring sanity test
│
├── foundry.toml
├── remappings.txt
└── README.md

````

---

## ⚙️ Setup

### Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation) (`forge`, `cast`, `anvil`)  
- Git + Node.js (optional for frontend work)

### Install
```bash
git clone <this-repo>
cd grant-dao
forge install openzeppelin/openzeppelin-contracts@v5.0.2 foundry-rs/forge-std@v1.9.6 --no-commit
````

### Build

```bash
forge build
```

### Test

```bash
forge test -vv
```

---

## 🚀 Deployment

1. Create `.env` file:

```bash
RPC_URL=https://your.rpc.endpoint
PRIVATE_KEY=0xabc123... # funded account
```

2. Deploy full stack:

```bash
forge script script/Deploy.s.sol:Deploy \
  --rpc-url $RPC_URL --broadcast -vvvv
```

3. The script will log deployed addresses:

```
GrantToken: 0x...
Timelock  : 0x...
Governor  : 0x...
Treasury  : 0x...
```

---

## 🗳️ Governance Workflow

1. **Acquire GDT**

   * Airdrop or transfer from deployer.
   * Delegate to yourself:

     ```solidity
     token.delegate(msg.sender)
     ```

     Without delegation, you have **0 voting power**.

2. **Create Proposal**

   * Example: fund a project with 5 ETH.
   * Run:

     ```bash
     export GOVERNOR=0x...
     export TREASURY=0x...
     export RECIPIENT=0xRecipient
     export AMOUNT_WEI=5000000000000000000
     export DESCRIPTION="Grant: 5 ETH to Project X"

     forge script script/ProposeEthGrant.s.sol:ProposeEthGrant \
       --rpc-url $RPC_URL --broadcast -vvvv
     ```
   * Record the `proposalId` from logs.

3. **Vote**

   * After voting delay passes, token holders can vote:

     ```bash
     cast send $GOVERNOR "castVote(uint256,uint8)" <proposalId> 1 \
       --private-key $PRIVATE_KEY --rpc-url $RPC_URL
     ```
   * Vote options: 0 = Against, 1 = For, 2 = Abstain.

4. **Queue Proposal**

   * If quorum met and majority For:

     ```bash
     export PROPOSAL_ID=<proposalId>
     export TIMELOCK_DELAY=172800   # 2 days
     export LOCAL_CHAIN=true        # if testing with Anvil
     forge script script/QueueAndExecute.s.sol:QueueAndExecute \
       --rpc-url $RPC_URL --broadcast -vvvv
     ```

5. **Execute Proposal**

   * After timelock delay, execution transfers funds from Treasury.

---

## 🧪 Example Test Flow (Local with Anvil)

```bash
# Start local chain
anvil -b 12 &

# Deploy contracts
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast

# Fund Treasury with ETH
cast send <TREASURY> --value 10ether --private-key $PRIVATE_KEY --rpc-url http://127.0.0.1:8545

# Propose, vote, queue, execute (see steps above)
```

---

## 📜 Contracts Overview

* **GrantToken**

  * `ERC20`, `ERC20Permit`, `ERC20Votes`
  * Snapshotted voting power

* **GrantGovernor**

  * Inherits `Governor`, `GovernorSettings`, `GovernorCountingSimple`, `GovernorVotes`, `GovernorVotesQuorumFraction`, `GovernorTimelockControl`
  * Configurable threshold, quorum, voting delay/period
  * Works with Timelock

* **Treasury**

  * Minimal vault
  * `execute(target, value, data)` callable only by Timelock

* **TimelockController (OZ)**

  * Holds Treasury ownership
  * Enforces execution delay
  * Governor is proposer, anyone can execute

---

## 🔒 Security Considerations

* Only **Timelock** can own Treasury.
* Timelock admin role is renounced post-deploy → no EOA backdoors.
* Voting power is snapshot-based → prevents vote-buy attacks.
* Delay gives community reaction window before execution.
* Treasury execute is guarded by `nonReentrant`.

---

## 📚 References

* [OpenZeppelin Governor docs](https://docs.openzeppelin.com/contracts/5.x/governance)
* [Foundry Book](https://book.getfoundry.sh/)
* [ERC20Votes](https://docs.openzeppelin.com/contracts/5.x/api/token/erc20#ERC20Votes)

---

## 👨‍💻 Future Work

* Add a **frontend dApp** (Next.js + wagmi/viem) for UX.
* Support **grant categories** (public goods, developer tooling, art).
* Add **off-chain proposal metadata** (IPFS/Arweave).
* Consider **upgradeable pattern** if governance wants flexibility.
* Integrate **GovernorCompatibilityBravo** for tooling like Tally.


