// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {GrantToken} from "../src/GrantToken.sol";
import {Treasury} from "../src/Treasury.sol";
import {GrantRegistry} from "../src/GrantRegistry.sol";
import {GrantGovernor} from "../src/GrantGovernor.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

/// @notice Local demo profile: short delays, open caps, self-admin timelock.
contract DeployLocal is Script {
    function run() external {
        uint256 deployerPK = vm.envOr(
            "PRIVATE_KEY",
            uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80)
        );
        address deployer = vm.addr(deployerPK);

        vm.startBroadcast(deployerPK);

        GrantToken token = new GrantToken(1_000_000e18, deployer);
        TimelockController timelock =
            new TimelockController(60, new address[](0), new address[](0), deployer);
        GrantGovernor governor = new GrantGovernor(IVotes(address(token)), timelock, 0, 1, 10, 4);
        Treasury treasury = new Treasury(deployer);
        GrantRegistry registry = new GrantRegistry(address(timelock));

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        timelock.grantRole(timelock.CANCELLER_ROLE(), deployer);
        treasury.setPauser(deployer);
        treasury.setTreasuryFloor(0);
        treasury.transferOwnership(address(timelock));
        timelock.grantRole(timelock.DEFAULT_ADMIN_ROLE(), address(timelock));
        timelock.renounceRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);

        token.delegate(deployer);

        vm.stopBroadcast();

        console2.log("GrantToken:", address(token));
        console2.log("Timelock  :", address(timelock));
        console2.log("Governor  :", address(governor));
        console2.log("Treasury  :", address(treasury));
        console2.log("Registry  :", address(registry));
    }
}
