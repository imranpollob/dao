// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {Treasury} from "../src/Treasury.sol";
import {GrantGovernor} from "../src/GrantGovernor.sol";
import {GrantRegistry} from "../src/GrantRegistry.sol";
import {ProposalBuilder} from "../src/utils/ProposalBuilder.sol";

/// @notice Propose funding a Vesting grant. ETH grants use AMOUNT_WEI;
/// ERC20 grants use AMOUNT. The token is read from the registry.
contract ProposeVestingFunding is Script {
    function run() external {
        address governorAddr = vm.envAddress("GOVERNOR");
        address treasuryAddr = vm.envAddress("TREASURY");
        address registryAddr = vm.envAddress("REGISTRY");
        uint256 grantId = vm.envUint("GRANT_ID");
        string memory description = vm.envString("DESCRIPTION");

        GrantRegistry.Grant memory g = GrantRegistry(registryAddr).grants(grantId);
        require(g.grantType == GrantRegistry.GrantType.Vesting, "not a vesting grant");

        uint256 amount = g.token == address(0) ? vm.envUint("AMOUNT_WEI") : vm.envUint("AMOUNT");
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = g.token == address(0)
            ? ProposalBuilder.buildVestingFunding(
                Treasury(payable(treasuryAddr)), grantId, amount, description
            )
            : ProposalBuilder.buildVestingFundingERC20(
                Treasury(payable(treasuryAddr)), grantId, amount, description
            );

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        uint256 proposalId =
            GrantGovernor(payable(governorAddr)).propose(targets, values, calldatas, desc);
        vm.stopBroadcast();

        console2.log("proposalId:", proposalId);
        console2.log("grantId:", grantId);
        console2.log("amount:", amount);
        console2.log("token:", g.token);
    }
}
