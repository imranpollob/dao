'use client';

import { useState } from 'react';
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { parseUnits } from 'viem';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { Loader2, Coins, ArrowLeft } from 'lucide-react';
import { CONTRACT_ADDRESSES, CONTRACT_ABIS } from '@/lib/contracts';

interface Erc20GrantFormProps {
  onBack: () => void;
}

export default function Erc20GrantForm({ onBack }: Erc20GrantFormProps) {
  const { address } = useAccount();
  const [tokenAddress, setTokenAddress] = useState('');
  const [recipient, setRecipient] = useState('');
  const [amount, setAmount] = useState('');
  const [decimals, setDecimals] = useState('18');
  const [description, setDescription] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const { writeContract, data: hash, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!tokenAddress || !recipient || !amount || !description) {
      alert('Please fill in all fields');
      return;
    }

    if (!address) {
      alert('Please connect your wallet');
      return;
    }

    try {
      setIsSubmitting(true);

      // Encode the ERC20 transfer call
      const transferCalldata = `0xa9059cbb${recipient.slice(2).padStart(64, '0')}${parseUnits(amount, parseInt(decimals)).toString(16).padStart(64, '0')}`;

      const targets = [tokenAddress];
      const values = [BigInt(0)]; // No ETH value for ERC20 transfer
      const calldatas = [transferCalldata];
      const descriptionWithPrefix = `# ERC20 Grant\n\n${description}`;

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
          <CardTitle className="text-green-600">ERC20 Grant Proposal Created Successfully! 🎉</CardTitle>
          <CardDescription>
            Your ERC20 token grant proposal has been submitted to the DAO.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <Alert>
            <AlertDescription>
              Transaction Hash: <code className="bg-gray-100 px-1 rounded">{hash}</code>
            </AlertDescription>
          </Alert>
          <div className="space-y-2">
            <p><strong>Token:</strong> {tokenAddress}</p>
            <p><strong>Recipient:</strong> {recipient}</p>
            <p><strong>Amount:</strong> {amount} tokens</p>
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
          <span>Create ERC20 Grant Proposal</span>
        </CardTitle>
        <CardDescription>
          Propose to send ERC20 tokens from the treasury to a recipient address.
        </CardDescription>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit} className="space-y-6">
          <div className="space-y-2">
            <Label htmlFor="tokenAddress">Token Contract Address</Label>
            <Input
              id="tokenAddress"
              type="text"
              placeholder="0x..."
              value={tokenAddress}
              onChange={(e) => setTokenAddress(e.target.value)}
              required
            />
          </div>

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

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label htmlFor="amount">Amount</Label>
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
              <Label htmlFor="decimals">Token Decimals</Label>
              <Input
                id="decimals"
                type="number"
                placeholder="18"
                value={decimals}
                onChange={(e) => setDecimals(e.target.value)}
                required
              />
            </div>
          </div>

          <div className="space-y-2">
            <Label htmlFor="description">Proposal Description</Label>
            <Textarea
              id="description"
              placeholder="Describe why this ERC20 grant should be approved..."
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