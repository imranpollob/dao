// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {GrantGovernor} from "../src/GrantGovernor.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/// @notice Cancel a proposal. Proposer cancels while Pending; guardian vetoes via timelock after queue.
contract CancelProposal is Script {
    function run() external {
        address governorAddr = vm.envAddress("GOVERNOR");
        uint256 proposalId = vm.envUint("PROPOSAL_ID");
        string memory reason = vm.envOr("REASON", string("cancelled"));
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        // Governor cancel path (works while Pending / before execution).
        GrantGovernor(payable(governorAddr)).cancel(proposalId);
        console2.log("Cancelled proposal:", proposalId);
        console2.log(reason);
        vm.stopBroadcast();
    }
}
