# 🚀 Grant DAO - Ultra-Fast Demo Guide (2 minutes)

This demo showcases the complete DAO governance flow with optimized parameters for quick demonstration.

## 📚 Related Documentation

- **[Main README](README.md)** - Project overview and setup
- **[Blog Post](blog-post1.md)** - Detailed DAO concepts and implementation
- **[Testing Guide](TESTING_README.md)** - Complete testing procedures

---

## 🚀 Demo Overview

This demo uses optimized parameters for quick demonstration:
- **Proposal Threshold**: 100 tokens (was 100K)
- **Voting Delay**: 1 block (~2 seconds, was ~1 day)
- **Voting Period**: 5 blocks (~10 seconds, was ~3 days)
- **Timelock Delay**: 10 seconds (was 2 days)
- **Quorum**: 1% (was 4%)

---

## 🔧 Prerequisites

1. Anvil running: `anvil`
2. Contracts deployed: `npm run deploy` (or see [Testing Guide](TESTING_README.md))
3. Environment updated: `node script/update-env.js`
4. Frontend running: `cd frontend && npm run dev`

---

## 🗳️ Manual Demo Steps

1. **Create Proposal** (Frontend)
   - Visit http://localhost:3000
   - Connect wallet
   - Create an ETH grant proposal (0.1 ETH to any address)
   - Submit proposal

2. **Wait for Voting Delay** (~2 seconds)
   - Proposal becomes active

3. **Vote on Proposal** (Frontend)
   - Click "Vote For" on the proposal
   - Confirm transaction

4. **Wait for Voting Period** (~10 seconds)
   - Voting period ends

5. **Queue Proposal** (Frontend)
   - Click "Queue" button
   - Confirm transaction

6. **Wait for Timelock** (10 seconds)
   - Timelock delay passes

7. **Execute Proposal** (Frontend)
   - Click "Execute" button
   - Confirm transaction

---

## ✅ Expected Results
- ✅ Proposal created successfully
- ✅ Vote cast and counted
- ✅ Proposal queued after voting
- ✅ Proposal executed after timelock
- ✅ Treasury balance updated

---

## ⏱️ Demo Timeline
- **Total Time**: ~25 seconds
- **Proposal Creation**: Instant
- **Voting Delay**: 2 seconds
- **Voting Period**: 10 seconds
- **Timelock Delay**: 10 seconds
- **Execution**: Instant

---

## 🔧 Troubleshooting

- If proposal creation fails: Check token balance (>100 tokens needed)
- If voting fails: Wait for voting delay to pass
- If execution fails: Ensure timelock delay has passed
- Frontend not loading: Check contract addresses in `.env.local`

For more comprehensive troubleshooting, see the **[Testing Guide](TESTING_README.md)**.

---

## 🔄 Reset Demo

To reset the demo environment:
```bash
# Stop Anvil and restart
# Redeploy contracts
npm run deploy
node script/update-env.js
```