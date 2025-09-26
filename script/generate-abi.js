const fs = require('fs');
const path = require('path');

// List of contracts to generate ABIs for
const contracts = [
  { name: 'GrantGovernor', file: 'GrantGovernor.sol' },
  { name: 'GrantToken', file: 'GrantToken.sol' },
  { name: 'Treasury', file: 'Treasury.sol' },
];

contracts.forEach(({ name, file }) => {
  const artifactPath = path.join(__dirname, '..', 'out', file, `${name}.json`);
  const abiOutputPath = path.join(__dirname, '..', 'frontend', 'src', 'lib', 'abis', `${name}.json`);

  try {
    // Read the artifact
    const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf8'));

    // Extract the ABI
    const abi = artifact.abi;

    // Write the ABI to the frontend location
    fs.writeFileSync(abiOutputPath, JSON.stringify(abi, null, 2));

    console.log(`ABI generated successfully for ${name} at: ${abiOutputPath}`);
  } catch (error) {
    console.error(`Error generating ABI for ${name}:`, error.message);
  }
});