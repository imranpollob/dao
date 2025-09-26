// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {GrantGovernor} from "../src/GrantGovernor.sol";

contract ExecuteProposal is Script {
    function run() external {
        address payable governorAddr = payable(vm.envAddress("GOVERNOR"));
        uint256 proposalId = vm.envUint("PROPOSAL_ID");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        GrantGovernor(payable(governorAddr)).execute(proposalId);

        console2.log("Executed proposal", proposalId);

        vm.stopBroadcast();
    }
}
