// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {GrantGovernor} from "../src/GrantGovernor.sol";
import {Treasury} from "../src/Treasury.sol";
import {ProposalBuilder} from "../src/utils/ProposalBuilder.sol";

/// @notice Propose an Immediate-grant payout. Create the grant first.
contract ProposeEthGrant is Script {
    function run() external {
        address payable governorAddr = payable(vm.envAddress("GOVERNOR"));
        address payable treasuryAddr = payable(vm.envAddress("TREASURY"));
        uint256 grantId = vm.envUint("GRANT_ID");
        uint256 amountWei = vm.envUint("AMOUNT_WEI");
        string memory description = vm.envString("DESCRIPTION");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = ProposalBuilder.buildImmediatePayout(
            Treasury(payable(treasuryAddr)), grantId, amountWei, description
        );

        uint256 proposalId =
            GrantGovernor(payable(governorAddr)).propose(targets, values, calldatas, desc);
        console2.log("Proposed Immediate grant payout. proposalId:", proposalId);

        vm.stopBroadcast();
    }
}
