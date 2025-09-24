#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// Get the latest deployment file
const broadcastDir = path.join(__dirname, '..', 'broadcast', 'Deploy.s.sol', '31337');
const files = fs.readdirSync(broadcastDir).filter(f => f.endsWith('.json'));
const latestFile = files.sort().reverse()[0];
const broadcastPath = path.join(broadcastDir, latestFile);

console.log('Reading deployment from:', broadcastPath);

// Read the broadcast file
const broadcast = JSON.parse(fs.readFileSync(broadcastPath, 'utf8'));

// Extract contract addresses from logs
let grantToken = '';
let timelock = '';
let governor = '';
let treasury = '';

for (const log of broadcast.logs || []) {
  if (log.topics && log.topics[0] === '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef') {
    // This is a Transfer event, likely from token deployment
    if (!grantToken) {
      grantToken = log.address;
    }
  }
}

// Try to extract from transactions (more reliable)
for (const tx of broadcast.transactions || []) {
  if (tx.contractName === 'GrantToken') {
    grantToken = tx.contractAddress;
  } else if (tx.contractName === 'TimelockController') {
    timelock = tx.contractAddress;
  } else if (tx.contractName === 'GrantGovernor') {
    governor = tx.contractAddress;
  } else if (tx.contractName === 'Treasury') {
    treasury = tx.contractAddress;
  }
}

// Fallback: try to extract from logs
if (!grantToken || !timelock || !governor || !treasury) {
  const logs = broadcast.logs || [];
  for (const log of logs) {
    const decodedLog = log.decoded || {};
    if (decodedLog.eventName === 'Transfer' && decodedLog.args && decodedLog.args.from === '0x0000000000000000000000000000000000000000') {
      if (!grantToken) grantToken = log.address;
    }
  }
}

console.log('Extracted addresses:');
console.log('GrantToken:', grantToken);
console.log('Timelock:', timelock);
console.log('Governor:', governor);
console.log('Treasury:', treasury);

// Update root .env file
const rootEnvPath = path.join(__dirname, '..', '.env');
if (fs.existsSync(rootEnvPath)) {
  let rootEnv = fs.readFileSync(rootEnvPath, 'utf8');
  rootEnv = rootEnv.replace(/GRANT_TOKEN=.*/, `GRANT_TOKEN=${grantToken}`);
  rootEnv = rootEnv.replace(/TIMELOCK=.*/, `TIMELOCK=${timelock}`);
  rootEnv = rootEnv.replace(/GOVERNOR=.*/, `GOVERNOR=${governor}`);
  rootEnv = rootEnv.replace(/TREASURY=.*/, `TREASURY=${treasury}`);
  fs.writeFileSync(rootEnvPath, rootEnv);
  console.log('✅ Root .env file updated!');
}

// Update frontend .env.local file
const frontendEnvPath = path.join(__dirname, '..', 'frontend', '.env.local');
if (fs.existsSync(frontendEnvPath)) {
  let frontendEnv = fs.readFileSync(frontendEnvPath, 'utf8');
  frontendEnv = frontendEnv.replace(/NEXT_PUBLIC_ANVIL_GRANT_TOKEN=.*/, `NEXT_PUBLIC_ANVIL_GRANT_TOKEN=${grantToken}`);
  frontendEnv = frontendEnv.replace(/NEXT_PUBLIC_ANVIL_TIMELOCK=.*/, `NEXT_PUBLIC_ANVIL_TIMELOCK=${timelock}`);
  frontendEnv = frontendEnv.replace(/NEXT_PUBLIC_ANVIL_GRANT_GOVERNOR=.*/, `NEXT_PUBLIC_ANVIL_GRANT_GOVERNOR=${governor}`);
  frontendEnv = frontendEnv.replace(/NEXT_PUBLIC_ANVIL_TREASURY=.*/, `NEXT_PUBLIC_ANVIL_TREASURY=${treasury}`);
  fs.writeFileSync(frontendEnvPath, frontendEnv);
  console.log('✅ Frontend .env.local file updated!');
}

console.log('\n🎉 Environment files updated with deployed contract addresses!');