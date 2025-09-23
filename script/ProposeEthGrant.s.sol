// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {GrantGovernor} from "../src/GrantGovernor.sol";
import {Treasury} from "../src/Treasury.sol";
import {ProposalBuilder} from "../src/utils/ProposalBuilder.sol";

contract ProposeEthGrant is Script {
    function run() external {
        address governorAddr = vm.envAddress("GOVERNOR");
        address treasuryAddr = vm.envAddress("TREASURY");
        address payable recipient = payable(vm.envAddress("RECIPIENT"));
        uint256 amountWei = vm.envUint("AMOUNT_WEI");
        string memory description = vm.envString("DESCRIPTION"); // e.g., "Grant: 5 ETH to Project X"

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory desc) =
            ProposalBuilder.buildEthGrant(Treasury(treasuryAddr), recipient, amountWei, description);

        uint256 proposalId = GrantGovernor(governorAddr).propose(targets, values, calldatas, desc);
        console2.log("Proposed ETH grant. proposalId:", proposalId);

        vm.stopBroadcast();
    }
}
