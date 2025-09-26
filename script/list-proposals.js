const { ethers } = require('ethers');

// Replace with your RPC URL and Governor address
const RPC_URL = 'http://localhost:8545';
const GOVERNOR_ADDRESS = process.env.GOVERNOR || '0x9fe46736679d2d9a65f0992f2272de9f3c7fa6e0'; // Update with actual address

async function main() {
  const provider = new ethers.JsonRpcProvider(RPC_URL);

  // ABI for the functions we need
  const abi = [
    'function proposalCount() view returns (uint256)',
    'function proposalDetailsAt(uint256) view returns (uint256, address[], uint256[], bytes[], bytes32)'
  ];

  const governor = new ethers.Contract(GOVERNOR_ADDRESS, abi, provider);

  try {
    const count = await governor.proposalCount();
    console.log(`Total proposals: ${count}`);

    for (let i = 0; i < count; i++) {
      const [proposalId] = await governor.proposalDetailsAt(i);
      console.log(`Proposal ${i}: ${proposalId}`);
    }
  } catch (error) {
    console.error('Error:', error.message);
  }
}

main();