import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { mainnet, sepolia } from 'wagmi/chains';

// Define Anvil local network
const anvil = {
  id: 31337,
  name: 'Anvil',
  network: 'anvil',
  nativeCurrency: {
    decimals: 18,
    name: 'Ether',
    symbol: 'ETH',
  },
  rpcUrls: {
    default: { http: ['http://localhost:8545'] },
    public: { http: ['http://localhost:8545'] },
  },
  blockExplorers: {
    default: { name: 'Anvil', url: 'http://localhost:8545' },
  },
  testnet: true,
};

export const config = getDefaultConfig({
  appName: 'Grant DAO',
  projectId: 'grant-dao-demo', // Get from WalletConnect Cloud
  chains: [mainnet, sepolia, anvil],
  ssr: true,
});