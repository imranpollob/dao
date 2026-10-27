// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {Treasury} from "../src/Treasury.sol";
import {GrantGovernor} from "../src/GrantGovernor.sol";

/// @notice Propose rotating the guardian in both places it is held:
/// Governor veto authority and the Treasury pauser role.
contract RotateGuardian is Script {
    function run() external {
        address governorAddr = vm.envAddress("GOVERNOR");
        address treasuryAddr = vm.envAddress("TREASURY");
        address newGuardian = vm.envAddress("GUARDIAN_ADDRESS");
        GrantGovernor governor = GrantGovernor(payable(governorAddr));
        require(newGuardian != address(0), "guardian=0");
        require(newGuardian.code.length > 0, "guardian must be contract");
        require(
            newGuardian != governorAddr && newGuardian != treasuryAddr
                && newGuardian != governor.timelock(),
            "guardian role conflict"
        );

        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory calldatas = new bytes[](2);
        targets[0] = governorAddr;
        targets[1] = treasuryAddr;
        calldatas[0] = abi.encodeWithSelector(GrantGovernor.setGuardian.selector, newGuardian);
        calldatas[1] = abi.encodeWithSelector(Treasury.setPauser.selector, newGuardian);

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        uint256 proposalId =
            governor.propose(targets, values, calldatas, vm.envString("DESCRIPTION"));
        vm.stopBroadcast();

        console2.log("proposalId:", proposalId);
        console2.log("new guardian:", newGuardian);
    }
}
