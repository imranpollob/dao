// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {GrantRegistry} from "../src/GrantRegistry.sol";

/// @notice Submit evidence for a Milestone grant as its recipient.
contract SubmitEvidence is Script {
    function run() external {
        address registryAddr = vm.envAddress("REGISTRY");
        uint256 grantId = vm.envUint("GRANT_ID");
        uint256 milestoneId = vm.envUint("MILESTONE_ID");
        string memory evidenceURI = vm.envString("EVIDENCE_URI");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        GrantRegistry(registryAddr).submitEvidence(grantId, milestoneId, evidenceURI);
        vm.stopBroadcast();

        console2.log("grantId:", grantId);
        console2.log("milestoneId:", milestoneId);
        console2.log("evidenceURI:", evidenceURI);
    }
}
