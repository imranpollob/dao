// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {GrantGovernor} from "../src/GrantGovernor.sol";

contract CastVote is Script {
    function run() external {
        address payable governorAddr = payable(vm.envAddress("GOVERNOR"));
        uint256 proposalId = vm.envUint("PROPOSAL_ID");
        uint8 support = uint8(vm.envUint("SUPPORT")); // 0=Against, 1=For, 2=Abstain
        string memory reason = vm.envString("REASON");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        GrantGovernor(payable(governorAddr)).castVoteWithReason(proposalId, support, reason);

        console2.log("Voted on proposal", proposalId, "with support:", support);

        vm.stopBroadcast();
    }
}
