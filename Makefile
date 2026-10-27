-include .env

FOUNDRY_BIN ?= $(HOME)/.foundry/bin
export PATH := $(FOUNDRY_BIN):$(PATH)
RPC_URL ?= http://localhost:8545
SLITHER ?= $(shell if [ -x .venv/bin/slither ]; then echo .venv/bin/slither; else echo slither; fi)

.PHONY: all test clean deploy-anvil demo demo-test seed-demo doctor roles security

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
slither :; $(SLITHER) .

# Demo: deploy the local profile to Anvil. This does not create a grant.
demo :; forge script script/DeployLocal.s.sol --rpc-url $(RPC_URL) --broadcast

# One-command lifecycle evidence: deploy -> grant -> vote -> queue -> execute.
demo-test :; forge test --match-contract DemoLifecycle -vv

# Optional: fund the local Treasury and distribute demo tokens.
seed-demo :; forge script script/SeedDemo.s.sol --rpc-url $(RPC_URL) --broadcast

# Security reports
security :; mkdir -p reports && forge coverage --report summary > reports/coverage.txt 2>&1; forge coverage --report lcov > reports/lcov.info 2>&1; cp reports/lcov.info lcov.info; forge test --gas-report > reports/gas.txt 2>&1; $(SLITHER) . --filter-paths "lib/|test/|script/" --json reports/slither.json > reports/slither.txt 2>&1; echo done

# Roles / health
doctor :; forge script script/Doctor.s.sol --rpc-url $(RPC_URL)
roles :; forge script script/Roles.s.sol --rpc-url $(RPC_URL)

# Deploy to Anvil (production profile: requires a guardian contract and separate token holder)
deploy-anvil :; forge script script/Deploy.s.sol:Deploy --rpc-url $(RPC_URL) --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast

# Deploy to Sepolia (requires .env)
deploy-sepolia :; forge script script/Deploy.s.sol:Deploy --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
