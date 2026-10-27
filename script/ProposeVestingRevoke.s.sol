// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {Treasury} from "../src/Treasury.sol";
import {GrantGovernor} from "../src/GrantGovernor.sol";
import {ProposalBuilder} from "../src/utils/ProposalBuilder.sol";

/// @notice Propose revoking a funded Vesting grant.
contract ProposeVestingRevoke is Script {
    function run() external {
        address governorAddr = vm.envAddress("GOVERNOR");
        address treasuryAddr = vm.envAddress("TREASURY");
        uint256 grantId = vm.envUint("GRANT_ID");
        string memory reason = vm.envString("REASON");
        string memory description = vm.envString("DESCRIPTION");

        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = ProposalBuilder.buildVestingRevoke(
            Treasury(payable(treasuryAddr)), grantId, reason, description
        );

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        uint256 proposalId =
            GrantGovernor(payable(governorAddr)).propose(targets, values, calldatas, desc);
        vm.stopBroadcast();

        console2.log("proposalId:", proposalId);
        console2.log("grantId:", grantId);
    }
}
