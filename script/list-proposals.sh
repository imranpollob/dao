#!/bin/bash

# Source environment variables if .env exists
if [ -f ".env" ]; then
  source .env
fi

# Usage: ./list-proposals.sh [governor_address] [rpc_url]
# Default values
GOVERNOR=${1:-${GOVERNOR:-$GOVERNOR_ADDRESS}}
RPC_URL=${2:-"http://localhost:8545"}

if [ -z "$GOVERNOR" ]; then
  echo "Error: GOVERNOR address not provided. Set GOVERNOR env var or pass as first argument."
  exit 1
fi

echo "Fetching proposals from Governor: $GOVERNOR on $RPC_URL"

# Get proposal count
COUNT_HEX=$(cast call $GOVERNOR "proposalCount()" --rpc-url $RPC_URL)
COUNT=$(cast --to-dec $COUNT_HEX)

echo "Total proposals: $COUNT"

if [ "$COUNT" -eq 0 ]; then
  echo "No proposals found."
  exit 0
fi

for ((i=0; i<COUNT; i++)); do
  # Call proposalDetailsAt(i)
  RESULT=$(cast call $GOVERNOR "proposalDetailsAt(uint256)" $i --rpc-url $RPC_URL)

  # Remove 0x prefix
  DATA=${RESULT#0x}

  # First 64 characters (32 bytes) are the proposalId
  PROPOSAL_ID_HEX=0x${DATA:0:64}

  echo "Proposal $i: $PROPOSAL_ID_HEX"
done