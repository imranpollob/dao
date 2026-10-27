// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {GrantGovernor} from "../src/GrantGovernor.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

/// @notice Queue a succeeded proposal or execute a queued one using the
/// proposal parameters stored by GovernorStorage.
contract QueueAndExecute is Script {
    function run() external {
        address payable governorAddr = payable(vm.envAddress("GOVERNOR"));
        uint256 proposalId = vm.envUint("PROPOSAL_ID");
        bool tryExecute = vm.envOr("TRY_EXECUTE", true);

        GrantGovernor governor = GrantGovernor(governorAddr);
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 descriptionHash
        ) = governor.proposalDetails(proposalId);

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        IGovernor.ProposalState s = governor.state(proposalId);
        console2.log("initial state:", uint256(s));
        if (s == IGovernor.ProposalState.Succeeded) {
            governor.queue(targets, values, calldatas, descriptionHash);
            s = governor.state(proposalId);
            console2.log("queued; state:", uint256(s));
        }
        if (tryExecute && s == IGovernor.ProposalState.Queued) {
            uint256 eta = governor.proposalEta(proposalId);
            if (eta > block.timestamp) {
                console2.log("not executed; timelock ETA:", eta);
            } else {
                governor.execute(targets, values, calldatas, descriptionHash);
                console2.log("executed");
            }
        } else {
            console2.log("not executed; rerun after the timelock delay");
        }

        vm.stopBroadcast();
    }
}
