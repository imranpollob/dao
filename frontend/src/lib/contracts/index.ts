/* eslint-disable @typescript-eslint/no-explicit-any */

import { Address } from 'viem';

// Contract addresses from environment variables
export const CONTRACT_ADDRESSES = {
  // Mainnet addresses
  mainnet: {
    grantToken: (process.env.NEXT_PUBLIC_MAINNET_GRANT_TOKEN as Address) || '0x0000000000000000000000000000000000000000',
    grantGovernor: (process.env.NEXT_PUBLIC_MAINNET_GRANT_GOVERNOR as Address) || '0x0000000000000000000000000000000000000000',
    treasury: (process.env.NEXT_PUBLIC_MAINNET_TREASURY as Address) || '0x0000000000000000000000000000000000000000',
    timelock: (process.env.NEXT_PUBLIC_MAINNET_TIMELOCK as Address) || '0x0000000000000000000000000000000000000000',
  },
  // Sepolia testnet addresses
  sepolia: {
    grantToken: (process.env.NEXT_PUBLIC_SEPOLIA_GRANT_TOKEN as Address) || '0x0000000000000000000000000000000000000000',
    grantGovernor: (process.env.NEXT_PUBLIC_SEPOLIA_GRANT_GOVERNOR as Address) || '0x0000000000000000000000000000000000000000',
    treasury: (process.env.NEXT_PUBLIC_SEPOLIA_TREASURY as Address) || '0x0000000000000000000000000000000000000000',
    timelock: (process.env.NEXT_PUBLIC_SEPOLIA_TIMELOCK as Address) || '0x0000000000000000000000000000000000000000',
  },
  // Local development (Anvil)
  anvil: {
    grantToken: (process.env.NEXT_PUBLIC_ANVIL_GRANT_TOKEN as Address) || '0x5FbDB2315678afecb367f032d93F642f64180aa3',
    grantGovernor: (process.env.NEXT_PUBLIC_ANVIL_GRANT_GOVERNOR as Address) || '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0',
    treasury: (process.env.NEXT_PUBLIC_ANVIL_TREASURY as Address) || '0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9',
    timelock: (process.env.NEXT_PUBLIC_ANVIL_TIMELOCK as Address) || '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512',
  },
} as const;

// Import ABIs
import GrantTokenABI from '../abis/GrantToken.json';
import GrantGovernorABI from '../abis/GrantGovernor.json';
import TreasuryABI from '../abis/Treasury.json';
import TimelockControllerABI from '../abis/TimelockController.json';

export const CONTRACT_ABIS = {
  GrantToken: GrantTokenABI as any,
  GrantGovernor: GrantGovernorABI as any,
  Treasury: TreasuryABI as any,
  TimelockController: TimelockControllerABI as any,
} as const;

// Contract configurations
export const CONTRACT_CONFIG = {
  GrantToken: {
    address: CONTRACT_ADDRESSES,
    abi: CONTRACT_ABIS.GrantToken,
  },
  GrantGovernor: {
    address: CONTRACT_ADDRESSES,
    abi: CONTRACT_ABIS.GrantGovernor,
  },
  Treasury: {
    address: CONTRACT_ADDRESSES,
    abi: CONTRACT_ABIS.Treasury,
  },
  TimelockController: {
    address: CONTRACT_ADDRESSES,
    abi: CONTRACT_ABIS.TimelockController,
  },
} as const;