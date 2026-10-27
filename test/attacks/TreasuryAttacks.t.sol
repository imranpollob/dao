// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {Treasury} from "../../src/Treasury.sol";
import {GrantRegistry} from "../../src/GrantRegistry.sol";
import {GrantVestingRevocable} from "../../src/GrantVestingRevocable.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract ReentrantPayee {
    Treasury public treasury;
    uint256 public count;

    constructor(Treasury _t) {
        treasury = _t;
    }

    receive() external payable {
        if (count == 0) {
            count = 1;
            // Re-enter the payout path: must revert (nonReentrant + pause/CEI order).
            treasury.sendETH(payable(address(this)), 1 ether, 1, 0);
        }
    }
}

contract TreasuryAttacks is Test {
    Treasury treasury;
    GrantRegistry registry;
    TimelockController timelock;
    address guardian = makeAddr("guardian");
    address payable payee = payable(makeAddr("payee"));

    function setUp() public {
        timelock = new TimelockController(1 days, new address[](0), new address[](0), address(this));
        treasury = new Treasury(address(timelock));
        registry = new GrantRegistry(address(timelock));
        vm.deal(address(treasury), 100 ether);
        vm.prank(address(timelock));
        treasury.setCaps(50 ether, 60 ether, 500_000e18, 2_000_000e18);
        vm.prank(address(timelock));
        treasury.setTreasuryFloor(10 ether);
        vm.prank(address(timelock));
        treasury.setPauser(guardian);
    }

    function testReentrantPayeeCannotDrain() public {
        ReentrantPayee attacker = new ReentrantPayee(treasury);
        vm.prank(address(timelock));
        vm.expectRevert();
        treasury.sendETH(payable(address(attacker)), 5 ether, 1, 0);
    }

    function testDoublePayoutAndMilestoneReplayRevert() public {
        GrantRegistry.CreateGrantParams memory p = GrantRegistry.CreateGrantParams({
            recipient: payee,
            token: address(0),
            total: 10 ether,
            grantType: GrantRegistry.GrantType.Milestone,
            proposalId: 1,
            vesting: address(0),
            reviewer: address(this)
        });
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 10 ether;
        uint64[] memory dues = new uint64[](1);
        dues[0] = uint64(block.timestamp + 1 days);
        vm.prank(address(timelock));
        uint256 id = registry.createGrant(p, "ipfs://m", amounts, dues);

        vm.prank(payee);
        registry.submitEvidence(id, 0, "ipfs://e");
        registry.approveMilestone(id, 0);
        vm.prank(address(timelock));
        registry.recordPayout(id, 0, 10 ether);
        // Replay the same milestone: reverts (already Paid).
        vm.prank(address(timelock));
        vm.expectRevert();
        registry.recordPayout(id, 0, 10 ether);
    }

    function testCapBypassViaBatchRevertsOnDailyCap() public {
        // Each call is under per-call cap, but the day total exceeds daily cap.
        vm.prank(address(timelock));
        treasury.sendETH(payee, 40 ether, 1, 0);
        vm.prank(address(timelock));
        vm.expectRevert(Treasury.DailyCapExceeded.selector);
        treasury.sendETH(payee, 30 ether, 2, 0);
    }

    function testPauseBypassRevertsOnExecuteAndTyped() public {
        vm.prank(guardian);
        treasury.pause(1 hours);
        vm.prank(address(timelock));
        vm.expectRevert(Treasury.PausedOutflows.selector);
        treasury.sendETH(payee, 1 ether, 1, 0);
        vm.prank(address(timelock));
        vm.expectRevert(Treasury.PausedOutflows.selector);
        treasury.execute(payee, 1 ether, bytes(""));
    }

    function testUnauthorizedPayoutReverts() public {
        vm.expectRevert();
        treasury.sendETH(payee, 1 ether, 1, 0);
    }

    function testVestingDoubleReleaseAndReleaseAfterRevoke() public {
        GrantVestingRevocable v =
            new GrantVestingRevocable(payee, address(timelock), uint64(block.timestamp), 1000, 100);
        vm.prank(address(timelock));
        treasury.fundVesting(payable(address(v)), 10 ether, 1);
        vm.warp(block.timestamp + 600);
        v.release();
        // Nothing left vested at the same timestamp: second release reverts.
        vm.expectRevert();
        v.release();
        // Revoke after full vesting returns nothing but marks revoked.
        vm.warp(block.timestamp + 1000);
        vm.prank(address(timelock));
        v.revoke();
        assertTrue(v.revoked());
    }
}
