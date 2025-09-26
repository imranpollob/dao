#!/bin/bash

# DAO Demo Script - Complete flow in under 2 minutes
# This script demonstrates the full DAO governance flow with ultra-fast parameters

echo "🚀 Starting DAO Demo - Complete governance flow in under 2 minutes!"
echo "=================================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
RPC_URL="http://localhost:8545"
PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

echo -e "${BLUE}📋 Demo Parameters:${NC}"
echo "   • Proposal Threshold: 100 tokens"
echo "   • Voting Delay: 1 block (~2 seconds)"
echo "   • Voting Period: 5 blocks (~10 seconds)"
echo "   • Timelock Delay: 10 seconds"
echo "   • Quorum: 1%"
echo ""

# Function to wait for blocks
wait_blocks() {
    local blocks=$1
    echo -e "${YELLOW}⏳ Waiting for $blocks block(s)...${NC}"
    sleep $((blocks * 2))  # ~2 seconds per block
}

# Function to wait for seconds
wait_seconds() {
    local seconds=$1
    echo -e "${YELLOW}⏳ Waiting $seconds seconds...${NC}"
    sleep $seconds
}

# Create proposal
cd /Users/imranpollob/Coding/dao
PROPOSAL_OUTPUT=$(RECIPIENT=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 AMOUNT_WEI=100000000000000000 DESCRIPTION="Demo: Grant 0.1 ETH to development team" forge script script/ProposeEthGrant.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY)

# Extract proposal ID from output
PROPOSAL_ID=$(echo "$PROPOSAL_OUTPUT" | grep "proposalId:" | sed 's/.*proposalId: //' | tr -d '\n')

echo "Created proposal with ID: $PROPOSAL_ID"

echo ""
echo -e "${GREEN}Step 2: Wait for voting delay${NC}"
wait_blocks 1

echo ""
echo -e "${GREEN}Step 3: Cast a vote${NC}"
echo "Voting 'For' on the proposal..."

# Cast vote (support = 1 for "For")
cd /Users/imranpollob/Coding/dao
PROPOSAL_ID=$PROPOSAL_ID \
SUPPORT=1 \
REASON="Supporting development team funding" \
forge script script/CastVote.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY

echo ""
echo -e "${GREEN}Step 4: Wait for voting period to end${NC}"
wait_blocks 5

echo ""
echo -e "${GREEN}Step 5: Queue the proposal${NC}"
echo "Queueing the successful proposal..."

# Queue proposal
cd /Users/imranpollob/Coding/dao
PROPOSAL_ID=$PROPOSAL_ID \
forge script script/QueueProposal.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY

echo ""
echo -e "${GREEN}Step 6: Wait for timelock delay${NC}"
wait_seconds 10

echo ""
echo -e "${GREEN}Step 7: Execute the proposal${NC}"
echo "Executing the queued proposal..."

# Execute proposal
cd /Users/imranpollob/Coding/dao
PROPOSAL_ID=$PROPOSAL_ID \
forge script script/ExecuteProposal.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY

echo ""
echo -e "${GREEN}🎉 Demo Complete!${NC}"
echo "Check the frontend at http://localhost:3001 to see the proposal lifecycle"
echo ""
echo -e "${BLUE}Summary of what happened:${NC}"
echo "1. ✅ Created proposal (ETH grant) - ID: $PROPOSAL_ID"
echo "2. ✅ Waited for voting delay"
echo "3. ✅ Cast vote (For)"
echo "4. ✅ Waited for voting period"
echo "5. ✅ Queued proposal"
echo "6. ✅ Waited for timelock"
echo "7. ✅ Executed proposal"
echo ""
echo -e "${YELLOW}Total time: ~25 seconds${NC}"