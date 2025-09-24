'use client';

import { useState } from 'react';
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { parseEther } from 'viem';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { Loader2, Coins, ArrowLeft } from 'lucide-react';
import { CONTRACT_ADDRESSES, CONTRACT_ABIS } from '@/lib/contracts';

interface EthGrantFormProps {
  onBack: () => void;
}

export default function EthGrantForm({ onBack }: EthGrantFormProps) {
  const { address, chain } = useAccount();
  const [recipient, setRecipient] = useState('');
  const [amount, setAmount] = useState('');
  const [description, setDescription] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const { writeContract, isPending, error, data: hash } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!recipient || !amount || !description) {
      alert('Please fill in all fields');
      return;
    }

    if (!address) {
      alert('Please connect your wallet');
      return;
    }

    try {
      setIsSubmitting(true);

      // Encode the proposal data
      const targets = [CONTRACT_ADDRESSES.anvil.treasury];
      const values = [parseEther(amount)];
      const calldatas = ['0x']; // Empty calldata for ETH transfer
      const descriptionWithPrefix = `# ETH Grant\n\n${description}`;

      writeContract({
        address: CONTRACT_ADDRESSES.anvil.grantGovernor,
        abi: CONTRACT_ABIS.GrantGovernor,
        functionName: 'propose',
        args: [targets, values, calldatas, descriptionWithPrefix],
      });
    } catch (err) {
      console.error('Error creating proposal:', err);
      alert('Error creating proposal. Check console for details.');
    } finally {
      setIsSubmitting(false);
    }
  };

  if (isSuccess) {
    return (
      <Card className="max-w-2xl mx-auto">
        <CardHeader>
          <CardTitle className="text-green-600">Proposal Created Successfully! 🎉</CardTitle>
          <CardDescription>
            Your ETH grant proposal has been submitted to the DAO.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <Alert>
            <AlertDescription>
              Transaction Hash: <code className="bg-gray-100 px-1 rounded">{hash}</code>
            </AlertDescription>
          </Alert>
          <div className="space-y-2">
            <p><strong>Recipient:</strong> {recipient}</p>
            <p><strong>Amount:</strong> {amount} ETH</p>
            <p><strong>Description:</strong> {description}</p>
          </div>
          <Button onClick={onBack} className="w-full">
            <ArrowLeft className="w-4 h-4 mr-2" />
            Back to Dashboard
          </Button>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card className="max-w-2xl mx-auto">
      <CardHeader>
        <CardTitle className="flex items-center space-x-2">
          <Coins className="w-5 h-5" />
          <span>Create ETH Grant Proposal</span>
        </CardTitle>
        <CardDescription>
          Propose to send ETH from the treasury to a recipient address.
        </CardDescription>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit} className="space-y-6">
          <div className="space-y-2">
            <Label htmlFor="recipient">Recipient Address</Label>
            <Input
              id="recipient"
              type="text"
              placeholder="0x..."
              value={recipient}
              onChange={(e) => setRecipient(e.target.value)}
              required
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="amount">Amount (ETH)</Label>
            <Input
              id="amount"
              type="number"
              step="0.000000000000000001"
              placeholder="0.0"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              required
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="description">Proposal Description</Label>
            <Textarea
              id="description"
              placeholder="Describe why this grant should be approved..."
              value={description}
              onChange={(e: React.ChangeEvent<HTMLTextAreaElement>) => setDescription(e.target.value)}
              rows={4}
              required
            />
          </div>

          {error && (
            <Alert variant="destructive">
              <AlertDescription>
                Error: {error.message}
              </AlertDescription>
            </Alert>
          )}

          <div className="flex space-x-4">
            <Button
              type="button"
              variant="outline"
              onClick={onBack}
              className="flex-1"
            >
              <ArrowLeft className="w-4 h-4 mr-2" />
              Back
            </Button>
            <Button
              type="submit"
              disabled={isSubmitting || isConfirming || !address}
              className="flex-1"
            >
              {isSubmitting || isConfirming ? (
                <>
                  <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                  {isConfirming ? 'Confirming...' : 'Creating Proposal...'}
                </>
              ) : (
                'Create Proposal'
              )}
            </Button>
          </div>
        </form>
      </CardContent>
    </Card>
  );
}