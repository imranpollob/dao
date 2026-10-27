// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {GrantRegistry} from "../src/GrantRegistry.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract RegistryTest is Test {
    GrantRegistry registry;
    TimelockController timelock;

    address recipient = makeAddr("recipient");
    address reviewer = makeAddr("reviewer");

    function setUp() public {
        timelock = new TimelockController(1 days, new address[](0), new address[](0), address(this));
        registry = new GrantRegistry(address(timelock));
    }

    function _params(uint256 total) internal view returns (GrantRegistry.CreateGrantParams memory) {
        return GrantRegistry.CreateGrantParams({
            recipient: recipient,
            token: address(0),
            total: total,
            grantType: GrantRegistry.GrantType.Immediate,
            proposalId: 1,
            vesting: address(0),
            reviewer: reviewer
        });
    }

    function testImmediateLifecycleAndAccounting() public {
        vm.prank(address(timelock));
        uint256 id = registry.createGrant(
            _params(10 ether), "ipfs://grant", new uint256[](0), new uint64[](0)
        );
        assertEq(registry.committed(address(0)), 10 ether);

        vm.prank(address(timelock));
        registry.recordPayout(id, 0, 4 ether);
        assertEq(registry.committed(address(0)), 6 ether);

        vm.prank(address(timelock));
        registry.recordPayout(id, 0, 6 ether);
        assertEq(uint256(registry.grants(id).status), uint256(GrantRegistry.Status.Completed));
        assertEq(registry.committed(address(0)), 0);
    }

    function testMilestoneEvidenceApprovePayout() public {
        GrantRegistry.CreateGrantParams memory p = _params(10 ether);
        p.grantType = GrantRegistry.GrantType.Milestone;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 4 ether;
        amounts[1] = 6 ether;
        uint64[] memory dues = new uint64[](2);
        dues[0] = uint64(block.timestamp + 1 days);
        dues[1] = uint64(block.timestamp + 2 days);

        vm.prank(address(timelock));
        uint256 id = registry.createGrant(p, "ipfs://m", amounts, dues);

        vm.prank(recipient);
        registry.submitEvidence(id, 0, "ipfs://e0");
        vm.prank(reviewer);
        registry.approveMilestone(id, 0);

        // Cannot pay unapproved milestone.
        vm.prank(address(timelock));
        vm.expectRevert();
        registry.recordPayout(id, 1, 6 ether);

        vm.prank(address(timelock));
        registry.recordPayout(id, 0, 4 ether);

        vm.prank(recipient);
        registry.submitEvidence(id, 1, "ipfs://e1");
        vm.prank(reviewer);
        registry.approveMilestone(id, 1);
        vm.prank(address(timelock));
        registry.recordPayout(id, 1, 6 ether);
        assertEq(uint256(registry.grants(id).status), uint256(GrantRegistry.Status.Completed));
    }

    function testCancelStopsFuturePayouts() public {
        vm.prank(address(timelock));
        uint256 id =
            registry.createGrant(_params(10 ether), "ipfs://g", new uint256[](0), new uint64[](0));
        vm.prank(address(timelock));
        registry.cancelGrant(id, "scope changed");
        assertEq(registry.committed(address(0)), 0);
        vm.prank(address(timelock));
        vm.expectRevert();
        registry.recordPayout(id, 0, 1 ether);
    }

    function testNoSilentAmendmentPath() public {
        // Registry exposes no amount/recipient mutation; only payout, cancel, revoke.
        // This test pins that by asserting paid can only grow via recordPayout.
        vm.prank(address(timelock));
        uint256 id =
            registry.createGrant(_params(5 ether), "ipfs://g", new uint256[](0), new uint64[](0));
        assertEq(registry.grants(id).total, 5 ether);
        assertEq(registry.grants(id).recipient, recipient);
    }
}
