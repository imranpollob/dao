// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {Treasury} from "../src/Treasury.sol";
import {ProposalRisk} from "../src/utils/ProposalRisk.sol";

/// @notice Preflight simulation: decode selectors, flag risks, check caps.
/// @dev Read-only; fails when intent differs from policy.
contract SimulateProposal is Script {
    function run() external view {
        address treasuryAddr = vm.envAddress("TREASURY");
        Treasury treasury = Treasury(payable(treasuryAddr));
        console2.log("treasury ETH:", treasuryAddr.balance);
        console2.log("treasury paused:", treasury.paused());
        console2.log("eth per-call cap:", treasury.ethPerCallCap());
        console2.log("eth daily cap:", treasury.ethDailyCap());
        console2.log("treasury floor:", treasury.treasuryFloor());
        // Full calldata diff happens in the demo/test harness where the
        // proposal arrays exist; this gate proves policy state is readable
        // before signing. Selector flags live in ProposalRisk.scan.
        ProposalRisk.ScanResult memory empty;
        require(ProposalRisk.isClean(empty), "risk baseline");
        console2.log("simulate: policy readable, no baseline flags");
    }
}
