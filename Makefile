-include .env

.PHONY: all test clean deploy-anvil

all: clean remove install update build

# Clean the repo
clean :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

# Install the Modules
install :; forge install foundry-rs/forge-std --no-commit && forge install openzeppelin/openzeppelin-contracts --no-commit

# Update Dependencies
update:; forge update

# Build
build:; forge build

# Test
test :; forge test

# Snapshot
snapshot :; forge snapshot

# Format
format :; forge fmt

# Slither
slither :; slither .

# Demo (local Anvil + deploy + seed)
demo :; forge script script/DeployLocal.s.sol --rpc-url http://localhost:8545 --broadcast

# Security reports
security :; mkdir -p reports && forge coverage --report lcov > reports/coverage.txt 2>&1; forge test --gas-report > reports/gas.txt 2>&1; .venv/bin/slither . --filter-paths "lib/|test/|script/" --json reports/slither.json > reports/slither.txt 2>&1; echo done

# Roles / health
doctor :; forge script script/Doctor.s.sol --rpc-url $(RPC_URL)
roles :; forge script script/Roles.s.sol --rpc-url $(RPC_URL)

# Deploy to Anvil
deploy-anvil :; forge script script/Deploy.s.sol:Deploy --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast

# Deploy to Sepolia (requires .env)
deploy-sepolia :; forge script script/Deploy.s.sol:Deploy --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
