// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {GrantGovernor} from "../src/GrantGovernor.sol";

contract QueueAndExecute is Script {
    // If your Timelock delay is known, pass it via env for local `warp`
    function run() external {
        address governorAddr = vm.envAddress("GOVERNOR");
        uint256 proposalId = vm.envUint("PROPOSAL_ID");
        uint256 timelockDelay = vm.envOr("TIMELOCK_DELAY", uint256(0)); // seconds; only used for local warp
        bool isLocal = vm.envOr("LOCAL_CHAIN", true); // set false on live networks

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        // 1) Queue (uses GovernorTimelockControl's queue)
        bytes32 descriptionHash = GrantGovernor(governorAddr).proposalVotes(proposalId); // placeholder to force interface load
        // NOTE: We can't get descriptionHash from Governor directly by proposalId.
        // Standard pattern: during propose you know targets/values/calldatas/description; compute descriptionHash = keccak256(bytes(description)).
        // For simplicity in scripts, Governor exposes queue(proposalId) in OZ >= v5 via proposal operations.
        // We'll just call queue(proposalId) here:
        GrantGovernor(governorAddr).queue(proposalId);
        console2.log("Queued proposal:", proposalId);

        if (isLocal && timelockDelay > 0) {
            // For local testing, advance time past timelock
            vm.warp(block.timestamp + timelockDelay + 1);
        }

        // 2) Execute
        GrantGovernor(governorAddr).execute(proposalId);
        console2.log("Executed proposal:", proposalId);

        vm.stopBroadcast();
    }
}
