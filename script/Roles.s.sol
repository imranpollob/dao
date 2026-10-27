// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/// @notice Print role holders and admin state for review.
contract Roles is Script {
    function run() external view {
        address timelockAddr = vm.envAddress("TIMELOCK");
        address governorAddr = vm.envAddress("GOVERNOR");
        address guardian = vm.envAddress("GUARDIAN_ADDRESS");
        TimelockController timelock = TimelockController(payable(timelockAddr));
        console2.log(
            "admin=timelock:", timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), timelockAddr)
        );
        console2.log("proposer=governor:", timelock.hasRole(timelock.PROPOSER_ROLE(), governorAddr));
        console2.log("executor=open:", timelock.hasRole(timelock.EXECUTOR_ROLE(), address(0)));
        console2.log("guardian canceller:", timelock.hasRole(timelock.CANCELLER_ROLE(), guardian));
        console2.log("minDelay:", timelock.getMinDelay());
    }
}
