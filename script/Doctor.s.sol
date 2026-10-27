// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {GrantToken} from "../src/GrantToken.sol";
import {Treasury} from "../src/Treasury.sol";
import {GrantRegistry} from "../src/GrantRegistry.sol";
import {GrantGovernor} from "../src/GrantGovernor.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/// @notice Doctor: read-only health check for code, wiring, roles, balances,
/// pause, guardian, and token-holder voting power.
contract Doctor is Script {
    function run() external view {
        address tokenAddr = vm.envAddress("TOKEN");
        address timelockAddr = vm.envAddress("TIMELOCK");
        address governorAddr = vm.envAddress("GOVERNOR");
        address treasuryAddr = vm.envAddress("TREASURY");
        address registryAddr = vm.envAddress("REGISTRY");
        address guardian = vm.envOr("GUARDIAN_ADDRESS", address(0));
        address tokenHolder = vm.envOr("TOKEN_HOLDER", address(0));

        TimelockController timelock = TimelockController(payable(timelockAddr));
        Treasury treasury = Treasury(payable(treasuryAddr));
        GrantRegistry registry = GrantRegistry(registryAddr);
        GrantGovernor governor = GrantGovernor(payable(governorAddr));
        GrantToken token = GrantToken(tokenAddr);

        console2.log("chainId:", block.chainid);
        console2.log("token code:", tokenAddr.code.length);
        console2.log("governor code:", governorAddr.code.length);
        console2.log("treasury code:", treasuryAddr.code.length);
        console2.log("registry code:", registryAddr.code.length);
        console2.log("treasury owner:", treasury.owner());
        console2.log("registry owner:", registry.owner());
        console2.log("treasury registry:", address(treasury.registry()));
        console2.log("registry treasury:", registry.treasury());
        console2.log(
            "wiring ok:",
            address(treasury.registry()) == registryAddr && registry.treasury() == treasuryAddr
        );
        console2.log("treasury paused:", treasury.paused());
        console2.log("treasury ETH:", treasuryAddr.balance);
        console2.log("treasury floor:", treasury.treasuryFloor());
        console2.log("timelock delay:", timelock.getMinDelay());
        console2.log("proposer=governor:", timelock.hasRole(timelock.PROPOSER_ROLE(), governorAddr));
        console2.log("executor=open:", timelock.hasRole(timelock.EXECUTOR_ROLE(), address(0)));
        console2.log(
            "timelock self-admin:", timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), timelockAddr)
        );
        console2.log(
            "governor canceller:", timelock.hasRole(timelock.CANCELLER_ROLE(), governorAddr)
        );
        console2.log("guardian:", governor.guardian());
        if (guardian != address(0)) {
            console2.log("guardian env matches:", guardian == governor.guardian());
            console2.log("guardian is treasury pauser:", guardian == treasury.pauser());
            console2.log(
                "guardian direct canceller:", timelock.hasRole(timelock.CANCELLER_ROLE(), guardian)
            );
        }
        if (tokenHolder != address(0)) {
            console2.log("token holder balance:", token.balanceOf(tokenHolder));
            console2.log("token holder votes:", token.getVotes(tokenHolder));
        }
    }
}
