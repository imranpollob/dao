// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {GrantToken} from "../src/GrantToken.sol";
import {Treasury} from "../src/Treasury.sol";
import {GrantGovernor} from "../src/GrantGovernor.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

contract Deploy is Script {
    // ---- PARAMETERS: tweak here or pass via env/CLI ----
    uint256 public constant INITIAL_SUPPLY = 10_000_000e18; // 10M GDT
    uint256 public constant TIMELOCK_DELAY = 2 days;

    // Governance params (block-based; adjust for your chain)
    uint256 public constant PROPOSAL_THRESHOLD = 100_000e18; // absolute tokens (e.g., 1% of 10M)
    uint256 public constant VOTING_DELAY = 7200;   // ~1 day on 12s blocks
    uint256 public constant VOTING_PERIOD = 21600; // ~3 days
    uint256 public constant QUORUM_PERCENT = 4;    // 4% quorum

    address[] proposers;
    address[] executors;

    function run() external {
        uint256 deployerPK = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPK);

        vm.startBroadcast(deployerPK);

        // 1) Token (mint to deployer for airdrops; you can mint to treasury instead if you wish)
        GrantToken token = new GrantToken(INITIAL_SUPPLY, deployer);

        // 2) Timelock (no proposers/executors at deploy; set roles after Governor is deployed)
        TimelockController timelock =
            new TimelockController(TIMELOCK_DELAY, proposers, executors, deployer);

        // 3) Governor wired to token + timelock
        GrantGovernor governor = new GrantGovernor(
            IVotes(address(token)),
            timelock,
            PROPOSAL_THRESHOLD,
            VOTING_DELAY,
            VOTING_PERIOD,
            QUORUM_PERCENT
        );

        // 4) Treasury owned by Timelock
        Treasury treasury = new Treasury(address(timelock));

        // 5) Grant roles:
        //    - PROPOSER_ROLE -> Governor
        //    - EXECUTOR_ROLE -> address(0) (open execution) or set to Governor for stricter execution
        bytes32 PROPOSER_ROLE = timelock.PROPOSER_ROLE();
        bytes32 EXECUTOR_ROLE = timelock.EXECUTOR_ROLE();
        bytes32 TIMELOCK_ADMIN_ROLE = timelock.TIMELOCK_ADMIN_ROLE();

        timelock.grantRole(PROPOSER_ROLE, address(governor));
        timelock.grantRole(EXECUTOR_ROLE, address(0)); // anyone can execute after delay

        // 6) Renounce Timelock admin from deployer to remove backdoor
        timelock.renounceRole(TIMELOCK_ADMIN_ROLE, deployer);

        // 7) Optional: delegate deployer’s voting power to self (so you can propose/vote)
        //    Users MUST delegate to have voting power.
        token.delegate(deployer);

        vm.stopBroadcast();

        // Log addresses
        console2.log("GrantToken:", address(token));
        console2.log("Timelock  :", address(timelock));
        console2.log("Governor  :", address(governor));
        console2.log("Treasury  :", address(treasury));
        console2.log("Deployer  :", deployer);
    }
}
