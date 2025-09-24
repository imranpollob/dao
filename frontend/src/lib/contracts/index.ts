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
    grantToken: (process.env.NEXT_PUBLIC_ANVIL_GRANT_TOKEN as Address) || '0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6',
    grantGovernor: (process.env.NEXT_PUBLIC_ANVIL_GRANT_GOVERNOR as Address) || '0x610178dA211FEF7D417bC0e6FeD39F05609AD788',
    treasury: (process.env.NEXT_PUBLIC_ANVIL_TREASURY as Address) || '0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e',
    timelock: (process.env.NEXT_PUBLIC_ANVIL_TIMELOCK as Address) || '0x8A791620dd6260079BF849Dc5567aDC3F2FdC318',
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