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
    grantToken: (process.env.NEXT_PUBLIC_ANVIL_GRANT_TOKEN as Address) || '0x959922be3caee4b8cd9a407cc3ac1c251c2007b1',
    grantGovernor: (process.env.NEXT_PUBLIC_ANVIL_GRANT_GOVERNOR as Address) || '0x68b1d87f95878fe05b998f19b66f4baba5de1aed',
    treasury: (process.env.NEXT_PUBLIC_ANVIL_TREASURY as Address) || '0x3aa5ebb10dc797cac828524e59a333d0a371443c',
    timelock: (process.env.NEXT_PUBLIC_ANVIL_TIMELOCK as Address) || '0x9a9f2ccfde556a7e9ff0848998aa4a0cfd8863ae',
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