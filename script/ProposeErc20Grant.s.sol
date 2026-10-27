// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {GrantGovernor} from "../src/GrantGovernor.sol";
import {Treasury} from "../src/Treasury.sol";
import {ProposalBuilder} from "../src/utils/ProposalBuilder.sol";

/// @notice Propose a payout for an ERC20 Immediate grant. The token comes
/// from the registry; the caller cannot substitute it.
contract ProposeErc20Grant is Script {
    function run() external {
        address payable governorAddr = payable(vm.envAddress("GOVERNOR"));
        address payable treasuryAddr = payable(vm.envAddress("TREASURY"));
        uint256 grantId = vm.envUint("GRANT_ID");
        uint256 amount = vm.envUint("AMOUNT");
        string memory description = vm.envString("DESCRIPTION");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = ProposalBuilder.buildImmediatePayout(
            Treasury(payable(treasuryAddr)), grantId, amount, description
        );

        uint256 proposalId =
            GrantGovernor(payable(governorAddr)).propose(targets, values, calldatas, desc);
        console2.log("Proposed ERC20 grant payout. proposalId:", proposalId);

        vm.stopBroadcast();
    }
}
