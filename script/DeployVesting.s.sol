// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {GrantVesting} from "../src/GrantVesting.sol";

contract DeployVesting is Script {
    function run() external {
        uint256 deployerPK = vm.envUint("PRIVATE_KEY");
        // address deployer = vm.addr(deployerPK);

        // Params from env or defaults
        address beneficiary = vm.envAddress("VESTING_BENEFICIARY");
        uint64 start = uint64(vm.envOr("VESTING_START", block.timestamp));
        uint64 duration = uint64(
            vm.envOr("VESTING_DURATION", uint256(365 days))
        );

        vm.startBroadcast(deployerPK);

        GrantVesting vesting = new GrantVesting(beneficiary, start, duration);

        console2.log("GrantVesting deployed at:", address(vesting));
        console2.log("Beneficiary:", beneficiary);
        console2.log("Start:", start);
        console2.log("Duration:", duration);

        vm.stopBroadcast();
    }
}
