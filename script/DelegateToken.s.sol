// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {GrantToken} from "../src/GrantToken.sol";

/// @notice Run from the token holder account after production deployment.
/// A multisig must submit the equivalent `delegate(holder)` transaction.
contract DelegateToken is Script {
    function run() external {
        address tokenAddr = vm.envAddress("TOKEN");
        uint256 holderPK = vm.envUint("TOKEN_HOLDER_PRIVATE_KEY");
        address holder = vm.addr(holderPK);

        vm.startBroadcast(holderPK);
        GrantToken(tokenAddr).delegate(holder);
        vm.stopBroadcast();

        console2.log("Delegated token holder votes to:", holder);
        console2.log("Votes:", GrantToken(tokenAddr).getVotes(holder));
    }
}
