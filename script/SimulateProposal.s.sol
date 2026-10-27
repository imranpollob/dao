// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {Treasury} from "../src/Treasury.sol";
import {GrantGovernor} from "../src/GrantGovernor.sol";
import {ProposalRisk} from "../src/utils/ProposalRisk.sol";

/// @notice Read-only preflight: load the exact stored proposal, scan its
/// calldata, print Treasury policy, and fail on a risk flag.
contract SimulateProposal is Script {
    function run() external view {
        address treasuryAddr = vm.envAddress("TREASURY");
        address governorAddr = vm.envAddress("GOVERNOR");
        uint256 proposalId = vm.envUint("PROPOSAL_ID");

        Treasury treasury = Treasury(payable(treasuryAddr));
        GrantGovernor governor = GrantGovernor(payable(governorAddr));
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            bytes32 descriptionHash
        ) = governor.proposalDetails(proposalId);
        require(descriptionHash != bytes32(0), "unknown proposal");

        ProposalRisk.ScanResult memory r = ProposalRisk.scan(targets, calldatas, values);
        console2.log("treasury ETH:", treasuryAddr.balance);
        console2.log("treasury paused:", treasury.paused());
        console2.log("eth per-call cap:", treasury.ethPerCallCap());
        console2.log("eth daily cap:", treasury.ethDailyCap());
        console2.log("eth proposal cap:", treasury.ethPerProposalCap());
        console2.log("erc20 per-call cap:", treasury.erc20PerCallCap());
        console2.log("erc20 daily cap:", treasury.erc20DailyCap());
        console2.log("erc20 proposal cap:", treasury.erc20PerProposalCap());
        console2.log("treasury floor:", treasury.treasuryFloor());
        console2.log("targets:", targets.length);
        console2.log("malformed:", r.malformed);
        console2.log("approval:", r.hasApproval);
        console2.log("unknown selector:", r.hasUnknownSelector);
        console2.log("ownership change:", r.hasOwnershipChange);
        console2.log("role change:", r.hasRoleChange);
        console2.log("upgrade:", r.hasUpgrade);
        console2.log("empty-calldata value:", r.hasEmptyCalldataDrain);
        require(ProposalRisk.isClean(r), "risk scanner flagged proposal");
        console2.log("simulate: clean");
    }
}
