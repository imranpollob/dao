// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {GrantVestingRevocable} from "../src/GrantVestingRevocable.sol";

/// @notice Release vested ETH or ERC20 from a revocable vesting wallet.
/// Set TOKEN to the zero address for ETH. Release always pays the beneficiary.
contract ReleaseVesting is Script {
    function run() external {
        address vestingAddr = vm.envAddress("VESTING");
        address token = vm.envOr("TOKEN", address(0));
        GrantVestingRevocable vesting = GrantVestingRevocable(payable(vestingAddr));

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        if (token == address(0)) {
            vesting.release();
        } else {
            vesting.releaseERC20(token);
        }
        vm.stopBroadcast();

        console2.log("vesting:", vestingAddr);
        console2.log("token:", token);
    }
}
