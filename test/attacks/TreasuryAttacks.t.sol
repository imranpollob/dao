// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {Treasury} from "../../src/Treasury.sol";
import {GrantRegistry} from "../../src/GrantRegistry.sol";
import {GrantVestingRevocable} from "../../src/GrantVestingRevocable.sol";
import {GrantToken} from "../../src/GrantToken.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {GrantTestBase} from "../helpers/GrantTestBase.sol";

contract ReentrantPayee {
    Treasury public treasury;
    uint256 public grantId;
    uint256 public count;

    constructor(Treasury _t, uint256 _grantId) {
        treasury = _t;
        grantId = _grantId;
    }

    receive() external payable {
        if (count == 0) {
            count = 1;
            treasury.payGrant(grantId, 1 ether);
        }
    }
}

contract TreasuryAttacks is GrantTestBase {
    Treasury treasury;
    GrantRegistry registry;
    TimelockController timelock;
    address guardian = makeAddr("guardian");
    address payable payee = payable(makeAddr("payee"));

    function setUp() public {
        timelock = new TimelockController(1 days, new address[](0), new address[](0), address(this));
        registry = new GrantRegistry(address(timelock));
        treasury = new Treasury(address(timelock), registry);
        vm.prank(address(timelock));
        registry.setTreasury(address(treasury));
        vm.deal(address(treasury), 100 ether);
        vm.prank(address(timelock));
        treasury.setCaps(50 ether, 60 ether, 500_000e18, 2_000_000e18);
        vm.prank(address(timelock));
        treasury.setTreasuryFloor(10 ether);
        vm.prank(address(timelock));
        treasury.setPauser(guardian);
    }

    function testReentrantPayeeCannotDrain() public {
        ReentrantPayee attacker = new ReentrantPayee(treasury, 0);
        uint256 id =
            createImmediate(registry, address(timelock), address(attacker), address(0), 5 ether);
        attacker = new ReentrantPayee(treasury, id);
        // The attacker contract is the recipient; recreate with the right id.
        // (The first deployment above consumes a nonce and is not the payee.)
        id = createImmediate(registry, address(timelock), address(attacker), address(0), 5 ether);

        vm.prank(address(timelock));
        vm.expectRevert();
        treasury.payGrant(id, 5 ether);
    }

    function testImmediateReplayReverts() public {
        uint256 id = createImmediate(registry, address(timelock), payee, address(0), 10 ether);
        vm.prank(address(timelock));
        treasury.payGrant(id, 10 ether);
        vm.prank(address(timelock));
        vm.expectRevert();
        treasury.payGrant(id, 1 ether);
    }

    function testBatchDuplicateMilestoneRevertsAtomically() public {
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1 ether;
        uint64[] memory dues = new uint64[](1);
        uint256 id = createMilestone(registry, address(timelock), payee, address(0), amounts, dues);
        submitAndApprove(registry, address(timelock), payee, id, 0);

        uint256[] memory ids = new uint256[](2);
        ids[0] = id;
        ids[1] = id;
        uint256[] memory indexes = new uint256[](2);

        vm.prank(address(timelock));
        vm.expectRevert();
        treasury.payMilestoneBatch(ids, indexes);

        assertEq(payee.balance, 0);
        assertEq(
            uint256(registry.milestone(id, 0).status),
            uint256(GrantRegistry.MilestoneStatus.Approved)
        );
    }

    function testMilestoneReplayReverts() public {
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 10 ether;
        uint64[] memory dues = new uint64[](1);
        dues[0] = uint64(block.timestamp + 1 days);
        uint256 id = createMilestone(registry, address(timelock), payee, address(0), amounts, dues);
        submitAndApprove(registry, address(timelock), payee, id, 0);

        vm.prank(address(timelock));
        treasury.payMilestone(id, 0);
        assertEq(payee.balance, 10 ether);

        vm.prank(address(timelock));
        vm.expectRevert();
        treasury.payMilestone(id, 0);
    }

    function testCapBypassViaRepeatedCallsRevertsOnDailyCap() public {
        uint256 id1 = createImmediate(registry, address(timelock), payee, address(0), 40 ether);
        uint256 id2 = createImmediate(registry, address(timelock), payee, address(0), 30 ether);

        vm.prank(address(timelock));
        treasury.payGrant(id1, 40 ether);
        vm.prank(address(timelock));
        vm.expectRevert(Treasury.DailyCapExceeded.selector);
        treasury.payGrant(id2, 30 ether);
    }

    function testPauseBypassRevertsOnTypedPayout() public {
        uint256 id = createImmediate(registry, address(timelock), payee, address(0), 10 ether);
        vm.prank(guardian);
        treasury.pause(1 hours);
        vm.prank(address(timelock));
        vm.expectRevert(Treasury.PausedOutflows.selector);
        treasury.payGrant(id, 1 ether);
    }

    function testUnauthorizedPayoutReverts() public {
        uint256 id = createImmediate(registry, address(timelock), payee, address(0), 10 ether);
        vm.expectRevert();
        treasury.payGrant(id, 1 ether);
    }

    function testVestingDoubleReleaseReverts() public {
        GrantVestingRevocable v = new GrantVestingRevocable(
            payee, address(treasury), address(treasury), uint64(block.timestamp), 1000, 100
        );
        uint256 grantId =
            createVesting(registry, address(timelock), payee, address(0), 10 ether, address(v));
        vm.prank(address(timelock));
        treasury.fundVesting(grantId, 10 ether);
        vm.warp(block.timestamp + 600);
        v.release();
        vm.expectRevert();
        v.release();
    }

    function testReleaseAfterRevokeUsesFrozenSchedule() public {
        GrantVestingRevocable v = new GrantVestingRevocable(
            payee, address(treasury), address(treasury), uint64(block.timestamp), 1000, 100
        );
        uint256 grantId =
            createVesting(registry, address(timelock), payee, address(0), 10 ether, address(v));
        vm.prank(address(timelock));
        treasury.fundVesting(grantId, 10 ether);

        vm.warp(block.timestamp + 600); // 6 ETH vested, none released
        vm.prank(address(timelock));
        treasury.revokeVesting(grantId, "revoked");

        // At t=700 the old implementation would try to release 7 ETH while
        // only 6 ETH remained, reverting forever. The frozen schedule pays 6.
        vm.warp(block.timestamp + 100);
        v.release();
        assertEq(payee.balance, 6 ether);
        vm.expectRevert();
        v.release();
    }

    function testERC20RevocationIsPerAsset() public {
        // A vesting wallet with ETH revoked can still revoke an ERC20 asset.
        GrantVestingRevocable v = new GrantVestingRevocable(
            payee, address(timelock), address(treasury), uint64(block.timestamp), 1000, 0
        );
        vm.prank(address(timelock));
        v.revoke();
        assertTrue(v.revoked());
        GrantToken erc20 = new GrantToken(1_000e18, address(this));
        vm.prank(address(timelock));
        v.revokeERC20(address(erc20));
        assertTrue(v.erc20Revoked(address(erc20)));
    }
}
