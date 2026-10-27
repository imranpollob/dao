// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {GrantRegistry} from "../../src/GrantRegistry.sol";

/// @notice Shared helpers for creating registry grants in tests.
abstract contract GrantTestBase is Test {
    function createImmediate(
        GrantRegistry registry,
        address timelock,
        address recipient,
        address token,
        uint256 total
    ) internal returns (uint256 id) {
        GrantRegistry.CreateGrantParams memory p = GrantRegistry.CreateGrantParams({
            recipient: recipient,
            token: token,
            total: total,
            grantType: GrantRegistry.GrantType.Immediate,
            proposalId: 1,
            vesting: address(0),
            reviewer: address(0)
        });
        vm.prank(timelock);
        id = registry.createGrant(p, "ipfs://grant", new uint256[](0), new uint64[](0));
    }

    function createMilestone(
        GrantRegistry registry,
        address timelock,
        address recipient,
        address token,
        uint256[] memory amounts,
        uint64[] memory dues
    ) internal returns (uint256 id) {
        uint256 total;
        for (uint256 i = 0; i < amounts.length; i++) {
            total += amounts[i];
        }
        GrantRegistry.CreateGrantParams memory p = GrantRegistry.CreateGrantParams({
            recipient: recipient,
            token: token,
            total: total,
            grantType: GrantRegistry.GrantType.Milestone,
            proposalId: 1,
            vesting: address(0),
            reviewer: address(0)
        });
        vm.prank(timelock);
        id = registry.createGrant(p, "ipfs://milestones", amounts, dues);
    }

    function createVesting(
        GrantRegistry registry,
        address timelock,
        address recipient,
        address token,
        uint256 total,
        address vesting
    ) internal returns (uint256 id) {
        GrantRegistry.CreateGrantParams memory p = GrantRegistry.CreateGrantParams({
            recipient: recipient,
            token: token,
            total: total,
            grantType: GrantRegistry.GrantType.Vesting,
            proposalId: 1,
            vesting: vesting,
            reviewer: address(0)
        });
        vm.prank(timelock);
        id = registry.createGrant(p, "ipfs://vesting", new uint256[](0), new uint64[](0));
    }

    function submitAndApprove(
        GrantRegistry registry,
        address timelock,
        address recipient,
        uint256 grantId,
        uint256 milestoneIdx
    ) internal {
        vm.prank(recipient);
        registry.submitEvidence(grantId, milestoneIdx, "ipfs://evidence");
        vm.prank(timelock);
        registry.approveMilestone(grantId, milestoneIdx);
    }
}
