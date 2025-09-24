'use client';

/* eslint-disable @typescript-eslint/no-explicit-any */

import { useState, useEffect, useCallback } from 'react';
import { useAccount, useReadContract, usePublicClient, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { formatEther, formatUnits } from 'viem';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Progress } from '@/components/ui/progress';
import { Loader2, Vote, Clock, CheckCircle, XCircle } from 'lucide-react';
import { CONTRACT_ADDRESSES, CONTRACT_ABIS } from '@/lib/contracts';

interface Proposal {
  id: bigint;
  proposer: string;
  targets: readonly string[];
  values: readonly bigint[];
  calldatas: readonly string[];
  description: string;
  startBlock: bigint;
  endBlock: bigint;
  state: number;
  forVotes: bigint;
  againstVotes: bigint;
  abstainVotes: bigint;
}

interface ProposalCardProps {
  proposal: Proposal;
  onVote: (proposalId: bigint, support: number) => void;
  isVoting: boolean;
  isVoteConfirming: boolean;
}

function ProposalCard({ proposal, onVote, isVoting: globalIsVoting, isVoteConfirming }: ProposalCardProps) {
  const { address } = useAccount();
  const [hasVoted, setHasVoted] = useState(false);

  // Check if user has already voted
  const { data: hasVotedData } = useReadContract({
    address: CONTRACT_ADDRESSES.anvil.grantGovernor,
    abi: CONTRACT_ABIS.GrantGovernor,
    functionName: 'hasVoted',
    args: [proposal.id, address || '0x0000000000000000000000000000000000000000'],
  });

  useEffect(() => {
    if (hasVotedData !== undefined) {
      setHasVoted(Boolean(hasVotedData));
    }
  }, [hasVotedData]);

  const getProposalState = (state: number) => {
    const states = [
      'Pending',
      'Active',
      'Canceled',
      'Defeated',
      'Succeeded',
      'Queued',
      'Expired',
      'Executed'
    ];
    return states[state] || 'Unknown';
  };

  const getStateColor = (state: number) => {
    switch (state) {
      case 0: return 'bg-yellow-500'; // Pending
      case 1: return 'bg-blue-500'; // Active
      case 2: return 'bg-gray-500'; // Canceled
      case 3: return 'bg-red-500'; // Defeated
      case 4: return 'bg-green-500'; // Succeeded
      case 5: return 'bg-purple-500'; // Queued
      case 6: return 'bg-orange-500'; // Expired
      case 7: return 'bg-emerald-500'; // Executed
      default: return 'bg-gray-500';
    }
  };

  const totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
  const forPercentage = totalVotes > BigInt(0) ? Number((proposal.forVotes * BigInt(100)) / totalVotes) : 0;
  const againstPercentage = totalVotes > BigInt(0) ? Number((proposal.againstVotes * BigInt(100)) / totalVotes) : 0;
  const abstainPercentage = totalVotes > BigInt(0) ? Number((proposal.abstainVotes * BigInt(100)) / totalVotes) : 0;

  const handleVote = async (support: number) => {
    try {
      await onVote(proposal.id, support);
      setHasVoted(true);
    } catch (error) {
      console.error('Voting error:', error);
    }
  };

  const isActive = proposal.state === 1; // Active state

  return (
    <Card className="w-full">
      <CardHeader>
        <div className="flex justify-between items-start">
          <div>
            <CardTitle className="text-lg">Proposal #{proposal.id.toString()}</CardTitle>
            <CardDescription className="mt-1">
              {proposal.description.split('\n')[0]}
            </CardDescription>
          </div>
          <Badge className={`${getStateColor(proposal.state)} text-white`}>
            {getProposalState(proposal.state)}
          </Badge>
        </div>
      </CardHeader>
      <CardContent className="space-y-4">
        {/* Proposal Details */}
        <div className="grid grid-cols-2 gap-4 text-sm">
          <div>
            <span className="font-medium">Proposer:</span>
            <p className="font-mono text-xs break-all">{proposal.proposer}</p>
          </div>
          <div>
            <span className="font-medium">Value:</span>
            <p>{proposal.values[0] ? formatEther(proposal.values[0]) : '0'} ETH</p>
          </div>
        </div>

        {/* Voting Results */}
        <div className="space-y-2">
          <div className="flex justify-between text-sm">
            <span>For: {formatUnits(proposal.forVotes, 18)} ({forPercentage}%)</span>
            <span>Against: {formatUnits(proposal.againstVotes, 18)} ({againstPercentage}%)</span>
            <span>Abstain: {formatUnits(proposal.abstainVotes, 18)} ({abstainPercentage}%)</span>
          </div>
          <div className="space-y-1">
            <div className="flex justify-between text-xs">
              <span>For</span>
              <span>{forPercentage}%</span>
            </div>
            <Progress value={forPercentage} className="h-2" />
          </div>
        </div>

        {/* Voting Actions */}
        {isActive && !hasVoted && (
          <div className="flex space-x-2">
            <Button
              size="sm"
              onClick={() => handleVote(1)}
              disabled={globalIsVoting || isVoteConfirming}
              className="flex-1"
            >
              {globalIsVoting || isVoteConfirming ? <Loader2 className="w-4 h-4 animate-spin" /> : <CheckCircle className="w-4 h-4 mr-1" />}
              For
            </Button>
            <Button
              size="sm"
              variant="outline"
              onClick={() => handleVote(0)}
              disabled={globalIsVoting || isVoteConfirming}
              className="flex-1"
            >
              {globalIsVoting || isVoteConfirming ? <Loader2 className="w-4 h-4 animate-spin" /> : <XCircle className="w-4 h-4 mr-1" />}
              Against
            </Button>
            <Button
              size="sm"
              variant="secondary"
              onClick={() => handleVote(2)}
              disabled={globalIsVoting || isVoteConfirming}
              className="flex-1"
            >
              {globalIsVoting || isVoteConfirming ? <Loader2 className="w-4 h-4 animate-spin" /> : <Clock className="w-4 h-4 mr-1" />}
              Abstain
            </Button>
          </div>
        )}

        {hasVoted && (
          <div className="text-center text-green-600 text-sm font-medium">
            ✓ You have already voted on this proposal
          </div>
        )}
      </CardContent>
    </Card>
  );
}

export default function ProposalList() {
  const { address } = useAccount();
  const publicClient = usePublicClient();
  const [proposals, setProposals] = useState<Proposal[]>([]);
  const [loading, setLoading] = useState(true);

  // Voting hooks
  const { writeContract: castVote, data: voteTxHash, isPending: isVoting } = useWriteContract();
  const { isLoading: isVoteConfirming } = useWaitForTransactionReceipt({
    hash: voteTxHash,
  });

  // Get proposal count
  const { data: proposalCount, isLoading: isCountLoading, isError: isCountError } = useReadContract({
    address: CONTRACT_ADDRESSES.anvil.grantGovernor,
    abi: CONTRACT_ABIS.GrantGovernor,
    functionName: 'proposalCount',
  });

  const fetchProposalData = useCallback(async (proposalId: bigint): Promise<Proposal | null> => {
    if (!publicClient) return null;

    try {
      // Get proposal details
      const proposal = await publicClient.readContract({
        address: CONTRACT_ADDRESSES.anvil.grantGovernor,
        abi: CONTRACT_ABIS.GrantGovernor,
        functionName: 'proposals',
        args: [proposalId],
      }) as any; // Contract returns complex tuple type

      // Get proposal state
      const state = await publicClient.readContract({
        address: CONTRACT_ADDRESSES.anvil.grantGovernor,
        abi: CONTRACT_ABIS.GrantGovernor,
        functionName: 'state',
        args: [proposalId],
      }) as any as number;

      // Get proposal votes
      const votes = await publicClient.readContract({
        address: CONTRACT_ADDRESSES.anvil.grantGovernor,
        abi: CONTRACT_ABIS.GrantGovernor,
        functionName: 'proposalVotes',
        args: [proposalId],
      }) as any; // Contract returns tuple of three bigints

      return {
        id: proposalId,
        proposer: proposal[0] as string,
        targets: proposal[1] as readonly string[],
        values: proposal[2] as readonly bigint[],
        calldatas: proposal[3] as readonly string[],
        description: proposal[4] as string,
        startBlock: proposal[5] as bigint,
        endBlock: proposal[6] as bigint,
        state,
        forVotes: votes[0] as bigint,
        againstVotes: votes[1] as bigint,
        abstainVotes: votes[2] as bigint,
      };
    } catch (error) {
      console.error('Error fetching proposal data:', error);
      return null;
    }
  }, [publicClient]);

  const loadProposals = useCallback(async () => {
    if (!proposalCount) return;

    const proposalList: Proposal[] = [];
    const count = Number(proposalCount);

    for (let i = 1; i <= count; i++) {
      try {
        // Get proposal data
        const proposalData = await fetchProposalData(BigInt(i));
        if (proposalData) {
          proposalList.push(proposalData);
        }
      } catch (error) {
        console.error(`Error loading proposal ${i}:`, error);
      }
    }

    setProposals(proposalList);
    setLoading(false);
  }, [proposalCount, fetchProposalData]);

  // Load proposals when count is available
  useEffect(() => {
    if (!isCountLoading) {
      if (proposalCount && Number(proposalCount) > 0) {
        loadProposals();
      } else {
        setLoading(false);
      }
    }
  }, [proposalCount, isCountLoading, loadProposals]);

  const handleVote = async (proposalId: bigint, support: number) => {
    if (!address) {
      alert('Please connect your wallet to vote');
      return;
    }

    try {
      castVote({
        address: CONTRACT_ADDRESSES.anvil.grantGovernor,
        abi: CONTRACT_ABIS.GrantGovernor,
        functionName: 'castVote',
        args: [proposalId, support],
      });
    } catch (error) {
      console.error('Error casting vote:', error);
      alert('Failed to cast vote. Please try again.');
    }
  };

  if (isCountError) {
    return (
      <Card>
        <CardHeader>
          <CardTitle>Active Proposals</CardTitle>
          <CardDescription>
            View and vote on active governance proposals.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="text-center py-8 text-re
          d-500">
            <XCircle className="h-12 w-12 mx-auto mb-4" />
            <p>Failed to load proposals.</p>
            <p className="text-sm">Please check your connection and try again.</p>
          </div>
        </CardContent>
      </Card>
    );
  }

  if (loading) {
    return (
      <div className="flex justify-center items-center py-8">
        <Loader2 className="w-8 h-8 animate-spin" />
        <span className="ml-2">Loading proposals...</span>
      </div>
    );
  }

  if (proposals.length === 0) {
    return (
      <Card>
        <CardHeader>
          <CardTitle>Active Proposals</CardTitle>
          <CardDescription>
            View and vote on active governance proposals.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="text-center py-8 text-gray-500">
            <Vote className="h-12 w-12 mx-auto mb-4" />
            <p>No active proposals at the moment.</p>
            <p className="text-sm">Check back later or create a new proposal.</p>
          </div>
        </CardContent>
      </Card>
    );
  }

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <h2 className="text-2xl font-bold">Active Proposals</h2>
        <Badge variant="secondary">{proposals.length} proposals</Badge>
      </div>
      {proposals.map((proposal) => (
        <ProposalCard
          key={proposal.id.toString()}
          proposal={proposal}
          onVote={handleVote}
          isVoting={isVoting}
          isVoteConfirming={isVoteConfirming}
        />
      ))}
    </div>
  );
}