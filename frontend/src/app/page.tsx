'use client';

import { useState, useEffect } from 'react';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { useAccount, useBalance, useReadContract } from 'wagmi';
import { formatEther, formatUnits } from 'viem';
import { CONTRACT_ADDRESSES, CONTRACT_ABIS } from '@/lib/contracts';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Loader2, Wallet, Coins, Vote, Clock } from 'lucide-react';

export default function Dashboard() {
  const { address, isConnected, chain } = useAccount();
  const [isLoading, setIsLoading] = useState(true);

  // Treasury balance
  const { data: treasuryEthBalance } = useBalance({
    address: CONTRACT_ADDRESSES.anvil.treasury,
    chainId: 31337, // Anvil local network
  });

  // Token balance
  const { data: tokenBalance } = useReadContract({
    address: CONTRACT_ADDRESSES.anvil.grantToken,
    abi: CONTRACT_ABIS.GrantToken,
    functionName: 'balanceOf',
    args: [address || '0x0000000000000000000000000000000000000000'],
    chainId: 31337,
  }) as { data: bigint | undefined };

  // Voting power
  const { data: votingPower } = useReadContract({
    address: CONTRACT_ADDRESSES.anvil.grantToken,
    abi: CONTRACT_ABIS.GrantToken,
    functionName: 'getVotes',
    args: [address || '0x0000000000000000000000000000000000000000'],
    chainId: 31337,
  }) as { data: bigint | undefined };

  // User ETH balance
  const { data: userEthBalance } = useBalance({
    address: address,
  });

  useEffect(() => {
    if (isConnected !== undefined) {
      setIsLoading(false);
    }
  }, [isConnected]);

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100">
      <header className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center py-4">
            <div className="flex items-center space-x-2">
              <Vote className="h-8 w-8 text-blue-600" />
              <h1 className="text-2xl font-bold text-gray-900">Grant DAO</h1>
            </div>
            <ConnectButton />
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {!isConnected ? (
          <div className="text-center py-12">
            <Wallet className="h-16 w-16 text-gray-400 mx-auto mb-4" />
            <h2 className="text-2xl font-semibold text-gray-900 mb-2">
              Connect Your Wallet
            </h2>
            <p className="text-gray-600 mb-6">
              Connect your wallet to participate in governance and view your balances.
            </p>
            <ConnectButton />
          </div>
        ) : (
          <div className="space-y-8">
            {/* Network Status */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center space-x-2">
                  <div className={`h-3 w-3 rounded-full ${chain?.id === 11155111 ? 'bg-green-500' : 'bg-red-500'}`} />
                  <span>Network Status</span>
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="flex items-center justify-between">
                  <span>Current Network:</span>
                  <Badge variant={chain?.id === 31337 ? 'default' : 'destructive'}>
                    {chain?.name || 'Unknown'}
                  </Badge>
                </div>
                {chain?.id !== 31337 && (
                  <p className="text-sm text-red-600 mt-2">
                    Please switch to Anvil local network to interact with the DAO.
                  </p>
                )}
              </CardContent>
            </Card>

            {/* Balances Overview */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
              <Card>
                <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                  <CardTitle className="text-sm font-medium">Your ETH Balance</CardTitle>
                  <Coins className="h-4 w-4 text-muted-foreground" />
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold">
                    {userEthBalance ? formatEther(userEthBalance.value) : '0'} ETH
                  </div>
                </CardContent>
              </Card>

              <Card>
                <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                  <CardTitle className="text-sm font-medium">Grant Tokens</CardTitle>
                  <Coins className="h-4 w-4 text-muted-foreground" />
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold">
                    {tokenBalance ? formatUnits(tokenBalance, 18) : '0'} GT
                  </div>
                </CardContent>
              </Card>

              <Card>
                <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                  <CardTitle className="text-sm font-medium">Voting Power</CardTitle>
                  <Vote className="h-4 w-4 text-muted-foreground" />
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold">
                    {votingPower ? formatUnits(votingPower, 18) : '0'} VP
                  </div>
                </CardContent>
              </Card>

              <Card>
                <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                  <CardTitle className="text-sm font-medium">Treasury Balance</CardTitle>
                  <Coins className="h-4 w-4 text-muted-foreground" />
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold">
                    {treasuryEthBalance ? formatEther(treasuryEthBalance.value) : '0'} ETH
                  </div>
                </CardContent>
              </Card>
            </div>

            {/* Main Actions */}
            <Tabs defaultValue="proposals" className="space-y-4">
              <TabsList className="grid w-full grid-cols-3">
                <TabsTrigger value="proposals">Proposals</TabsTrigger>
                <TabsTrigger value="create">Create Proposal</TabsTrigger>
                <TabsTrigger value="treasury">Treasury</TabsTrigger>
              </TabsList>

              <TabsContent value="proposals" className="space-y-4">
                <Card>
                  <CardHeader>
                    <CardTitle>Active Proposals</CardTitle>
                    <CardDescription>
                      View and vote on active governance proposals.
                    </CardDescription>
                  </CardHeader>
                  <CardContent>
                    <div className="text-center py-8 text-gray-500">
                      <Clock className="h-12 w-12 mx-auto mb-4" />
                      <p>No active proposals at the moment.</p>
                      <p className="text-sm">Check back later or create a new proposal.</p>
                    </div>
                  </CardContent>
                </Card>
              </TabsContent>

              <TabsContent value="create" className="space-y-4">
                <Card>
                  <CardHeader>
                    <CardTitle>Create New Proposal</CardTitle>
                    <CardDescription>
                      Propose grants, changes, or other governance actions.
                    </CardDescription>
                  </CardHeader>
                  <CardContent className="space-y-4">
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                      <Button className="h-20 flex flex-col items-center justify-center space-y-2">
                        <Coins className="h-6 w-6" />
                        <span>ETH Grant Proposal</span>
                      </Button>
                      <Button variant="outline" className="h-20 flex flex-col items-center justify-center space-y-2">
                        <Coins className="h-6 w-6" />
                        <span>ERC20 Grant Proposal</span>
                      </Button>
                    </div>
                  </CardContent>
                </Card>
              </TabsContent>

              <TabsContent value="treasury" className="space-y-4">
                <Card>
                  <CardHeader>
                    <CardTitle>Treasury Overview</CardTitle>
                    <CardDescription>
                      Monitor treasury balances and transactions.
                    </CardDescription>
                  </CardHeader>
                  <CardContent>
                    <div className="space-y-4">
                      <div className="flex justify-between items-center p-4 bg-gray-50 rounded-lg">
                        <span className="font-medium">Total ETH Balance</span>
                        <span className="text-lg font-bold">
                          {treasuryEthBalance ? formatEther(treasuryEthBalance.value) : '0'} ETH
                        </span>
                      </div>
                      <div className="text-center py-4 text-gray-500">
                        <p>Transaction history will be displayed here.</p>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              </TabsContent>
            </Tabs>
          </div>
        )}
      </main>
    </div>
  );
}
