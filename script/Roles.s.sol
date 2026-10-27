// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {Treasury} from "../src/Treasury.sol";
import {GrantGovernor} from "../src/GrantGovernor.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/// @notice Print role holders and admin state for review.
contract Roles is Script {
    function run() external view {
        address timelockAddr = vm.envAddress("TIMELOCK");
        address governorAddr = vm.envAddress("GOVERNOR");
        address treasuryAddr = vm.envAddress("TREASURY");
        address guardian = vm.envAddress("GUARDIAN_ADDRESS");
        TimelockController timelock = TimelockController(payable(timelockAddr));
        Treasury treasury = Treasury(payable(treasuryAddr));
        GrantGovernor governor = GrantGovernor(payable(governorAddr));

        console2.log("governor guardian:", governor.guardian());
        console2.log(
            "admin=timelock:", timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), timelockAddr)
        );
        console2.log("proposer=governor:", timelock.hasRole(timelock.PROPOSER_ROLE(), governorAddr));
        console2.log("executor=open:", timelock.hasRole(timelock.EXECUTOR_ROLE(), address(0)));
        console2.log(
            "governor canceller:", timelock.hasRole(timelock.CANCELLER_ROLE(), governorAddr)
        );
        console2.log("treasury owner:", treasury.owner());
        console2.log("treasury pauser:", treasury.pauser());
        console2.log("guardian env matches:", guardian == governor.guardian());
        console2.log("guardian is treasury pauser:", guardian == treasury.pauser());
        console2.log(
            "guardian direct canceller:", timelock.hasRole(timelock.CANCELLER_ROLE(), guardian)
        );
        console2.log("minDelay:", timelock.getMinDelay());
    }
}
