// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {GrantToken} from "../src/GrantToken.sol";
import {Treasury} from "../src/Treasury.sol";

/// @notice Seed Anvil demo: fund treasury, distribute tokens, delegate.
/// @dev No privileged calls; grant creation stays governance-only.
contract SeedDemo is Script {
    function run() external {
        address tokenAddr = vm.envAddress("TOKEN");
        address payable treasuryAddr = payable(vm.envAddress("TREASURY"));
        address recipient = vm.envAddress("RECIPIENT");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        GrantToken token = GrantToken(tokenAddr);
        token.transfer(recipient, 100_000e18);
        token.delegate(vm.addr(pk));
        (bool ok,) = treasuryAddr.call{value: 10 ether}("");
        require(ok, "fund failed");
        vm.stopBroadcast();
        console2.log("seeded treasury:", treasuryAddr.balance);
        console2.log("recipient GDT:", token.balanceOf(recipient));
    }
}
