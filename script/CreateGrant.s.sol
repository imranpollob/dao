// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {GrantGovernor} from "../src/GrantGovernor.sol";
import {GrantRegistry} from "../src/GrantRegistry.sol";
import {ProposalBuilder} from "../src/utils/ProposalBuilder.sol";

/// @notice Propose a registry grant. Timelock execution creates the grant.
/// @dev GRANT_TYPE: 0 = Immediate, 1 = Milestone, 2 = Vesting.
/// Milestone CSV inputs are comma-separated base-unit integers with no spaces,
/// e.g. "1000000000000000000,2000000000000000000". Keep them empty for
/// Immediate/Vesting grants.
contract CreateGrant is Script {
    function run() external {
        address governorAddr = vm.envAddress("GOVERNOR");
        address registryAddr = vm.envAddress("REGISTRY");

        uint256 grantTypeRaw = vm.envUint("GRANT_TYPE");
        require(grantTypeRaw <= 2, "grant type");
        GrantRegistry.GrantType grantType = GrantRegistry.GrantType(grantTypeRaw);

        uint256[] memory milestoneAmounts =
            _parseUintArray(vm.envOr("MILESTONE_AMOUNTS", string("")));
        uint256[] memory dueRaw = _parseUintArray(vm.envOr("MILESTONE_DUE_DATES", string("")));
        require(milestoneAmounts.length == dueRaw.length, "milestone len");

        uint64[] memory milestoneDueDates = new uint64[](dueRaw.length);
        for (uint256 i = 0; i < dueRaw.length; i++) {
            require(dueRaw[i] <= type(uint64).max, "due date overflow");
            milestoneDueDates[i] = uint64(dueRaw[i]);
        }

        GrantRegistry.CreateGrantParams memory p = GrantRegistry.CreateGrantParams({
            recipient: vm.envAddress("RECIPIENT"),
            token: vm.envOr("TOKEN", address(0)),
            total: vm.envUint("TOTAL"),
            grantType: grantType,
            proposalId: vm.envOr("PROPOSAL_REF", uint256(0)),
            vesting: vm.envOr("VESTING", address(0)),
            reviewer: vm.envOr("REVIEWER", address(0))
        });
        require(p.total > 0, "total=0");

        if (grantType == GrantRegistry.GrantType.Milestone) {
            require(milestoneAmounts.length > 0, "milestones required");
            require(p.vesting == address(0), "vesting for milestone");
            uint256 sum;
            for (uint256 i = 0; i < milestoneAmounts.length; i++) {
                sum += milestoneAmounts[i];
            }
            require(sum == p.total, "milestone total");
        } else {
            require(milestoneAmounts.length == 0, "milestones not allowed");
            if (grantType == GrantRegistry.GrantType.Vesting) {
                require(p.vesting != address(0), "vesting required");
            } else {
                require(p.vesting == address(0), "vesting for immediate");
            }
        }

        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = ProposalBuilder.buildCreateGrant(
            GrantRegistry(registryAddr),
            p,
            vm.envString("METADATA_URI"),
            milestoneAmounts,
            milestoneDueDates,
            vm.envString("DESCRIPTION")
        );

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        uint256 proposalId =
            GrantGovernor(payable(governorAddr)).propose(targets, values, calldatas, desc);
        vm.stopBroadcast();

        console2.log("proposalId:", proposalId);
        console2.log("grant type:", grantTypeRaw);
        console2.log("recipient:", p.recipient);
        console2.log("total:", p.total);
    }

    function _parseUintArray(string memory csv) internal pure returns (uint256[] memory out) {
        bytes memory b = bytes(csv);
        if (b.length == 0) return new uint256[](0);

        uint256 count = 1;
        for (uint256 i = 0; i < b.length; i++) {
            if (b[i] == ",") count++;
        }
        out = new uint256[](count);

        uint256 index;
        uint256 current;
        bool hasDigit;
        for (uint256 i = 0; i < b.length; i++) {
            bytes1 c = b[i];
            if (c == ",") {
                require(hasDigit, "empty csv item");
                out[index++] = current;
                current = 0;
                hasDigit = false;
            } else {
                require(c >= "0" && c <= "9", "csv digits only");
                current = current * 10 + (uint256(uint8(c)) - 48);
                hasDigit = true;
            }
        }
        require(hasDigit, "empty csv item");
        out[index] = current;
    }
}
