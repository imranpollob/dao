// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {GrantGovernor} from "../src/GrantGovernor.sol";
import {GrantRegistry} from "../src/GrantRegistry.sol";
import {ProposalBuilder} from "../src/utils/ProposalBuilder.sol";

/// @notice Propose rejection of a submitted milestone.
contract ProposeMilestoneRejection is Script {
    function run() external {
        address governorAddr = vm.envAddress("GOVERNOR");
        address registryAddr = vm.envAddress("REGISTRY");
        uint256 grantId = vm.envUint("GRANT_ID");
        uint256 milestoneId = vm.envUint("MILESTONE_ID");
        string memory reason = vm.envString("REASON");
        string memory description = vm.envString("DESCRIPTION");

        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = ProposalBuilder.buildRejectMilestone(
            GrantRegistry(registryAddr), grantId, milestoneId, reason, description
        );

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        uint256 proposalId =
            GrantGovernor(payable(governorAddr)).propose(targets, values, calldatas, desc);
        vm.stopBroadcast();

        console2.log("proposalId:", proposalId);
        console2.log("grantId:", grantId);
        console2.log("milestoneId:", milestoneId);
    }
}
