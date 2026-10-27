// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {GrantVestingRevocable} from "../src/GrantVestingRevocable.sol";

/// @notice Deploy a revocable vesting wallet for a registry Vesting grant.
contract DeployVesting is Script {
    function run() external {
        uint256 deployerPK = vm.envUint("PRIVATE_KEY");

        address beneficiary = vm.envAddress("VESTING_BENEFICIARY");
        address treasury = vm.envAddress("VESTING_TREASURY");
        // Treasury must be the vesting admin so Treasury.revokeVesting can
        // return unvested funds and update the registry atomically.
        address admin = vm.envOr("VESTING_ADMIN", treasury);
        require(admin == treasury, "VESTING_ADMIN must equal VESTING_TREASURY");
        uint64 start = uint64(vm.envOr("VESTING_START", block.timestamp));
        uint64 duration = uint64(vm.envOr("VESTING_DURATION", uint256(365 days)));
        uint64 cliff = uint64(vm.envOr("VESTING_CLIFF", uint256(0)));

        vm.startBroadcast(deployerPK);

        GrantVestingRevocable vesting =
            new GrantVestingRevocable(beneficiary, admin, treasury, start, duration, cliff);

        console2.log("GrantVestingRevocable deployed at:", address(vesting));
        console2.log("Beneficiary:", beneficiary);
        console2.log("Admin:", admin);
        console2.log("Treasury:", treasury);
        console2.log("Start:", start);
        console2.log("Duration:", duration);
        console2.log("Cliff:", cliff);

        vm.stopBroadcast();
    }
}
