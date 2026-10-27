// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {GrantToken} from "../src/GrantToken.sol";
import {Treasury} from "../src/Treasury.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/// @notice Doctor: read-only health check for chain, code, roles, balances, pause.
contract Doctor is Script {
    function run() external view {
        address tokenAddr = vm.envAddress("TOKEN");
        address timelockAddr = vm.envAddress("TIMELOCK");
        address governorAddr = vm.envAddress("GOVERNOR");
        address treasuryAddr = vm.envAddress("TREASURY");

        TimelockController timelock = TimelockController(payable(timelockAddr));
        Treasury treasury = Treasury(payable(treasuryAddr));

        console2.log("chainId:", block.chainid);
        console2.log("token code:", tokenAddr.code.length);
        console2.log("governor code:", governorAddr.code.length);
        console2.log("treasury code:", treasuryAddr.code.length);
        console2.log("treasury owner:", treasury.owner());
        console2.log("treasury paused:", treasury.paused());
        console2.log("treasury ETH:", treasuryAddr.balance);
        console2.log("timelock delay:", timelock.getMinDelay());
        console2.log("proposer=governor:", timelock.hasRole(timelock.PROPOSER_ROLE(), governorAddr));
        console2.log("executor=open:", timelock.hasRole(timelock.EXECUTOR_ROLE(), address(0)));
        GrantToken(tokenAddr);
    }
}
