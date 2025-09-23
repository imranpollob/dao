// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {GrantGovernor} from "../src/GrantGovernor.sol";
import {Treasury} from "../src/Treasury.sol";
import {ProposalBuilder} from "../src/utils/ProposalBuilder.sol";

contract ProposeErc20Grant is Script {
    function run() external {
        address governorAddr = vm.envAddress("GOVERNOR");
        address treasuryAddr = vm.envAddress("TREASURY");
        address erc20 = vm.envAddress("ERC20");
        address to = vm.envAddress("TO");
        uint256 amount = vm.envUint("AMOUNT"); // token decimals
        string memory description = vm.envString("DESCRIPTION");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory desc) =
            ProposalBuilder.buildErc20Grant(Treasury(treasuryAddr), erc20, to, amount, description);

        uint256 proposalId = GrantGovernor(governorAddr).propose(targets, values, calldatas, desc);
        console2.log("Proposed ERC20 grant. proposalId:", proposalId);

        vm.stopBroadcast();
    }
}
