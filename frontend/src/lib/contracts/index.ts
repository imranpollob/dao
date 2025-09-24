/* eslint-disable @typescript-eslint/no-explicit-any */

import { Address } from 'viem';

// Contract addresses (update these with deployed addresses)
export const CONTRACT_ADDRESSES = {
  // Mainnet addresses
  mainnet: {
    grantToken: '0x0000000000000000000000000000000000000000' as Address,
    grantGovernor: '0x0000000000000000000000000000000000000000' as Address,
    treasury: '0x0000000000000000000000000000000000000000' as Address,
    timelock: '0x0000000000000000000000000000000000000000' as Address,
  },
  // Local development (Anvil)
  anvil: {
    grantToken: '0x959922bE3CAee4b8Cd9a407cc3ac1C251C2007B1' as Address,
    grantGovernor: '0x68B1D87F95878fE05B998F19b66F4baba5De1aed' as Address,
    treasury: '0x3Aa5ebB10DC797CAC828524e59A333d0A371443c' as Address,
    timelock: '0x9A9f2CCfdE556A7E9Ff0848998Aa4a0CFD8863AE' as Address,
  },
} as const;

// Import ABIs
const GrantTokenABI: any[] = [];
const GrantGovernorABI: any[] = [];
const TreasuryABI: any[] = [];
const TimelockControllerABI: any[] = [];

export const CONTRACT_ABIS = {
  GrantToken: GrantTokenABI,
  GrantGovernor: GrantGovernorABI,
  Treasury: TreasuryABI,
  TimelockController: TimelockControllerABI,
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