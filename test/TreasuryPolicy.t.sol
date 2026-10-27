// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {Treasury} from "../src/Treasury.sol";
import {GrantRegistry} from "../src/GrantRegistry.sol";
import {GrantVestingRevocable} from "../src/GrantVestingRevocable.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {GrantTestBase} from "./helpers/GrantTestBase.sol";

contract TestToken is ERC20 {
    constructor() ERC20("Test", "TST") {
        _mint(msg.sender, 10_000_000e18);
    }
}

contract FeeToken is ERC20 {
    constructor() ERC20("Fee", "FEE") {
        _mint(msg.sender, 10_000_000e18);
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        uint256 fee = amount / 10;
        _transfer(msg.sender, address(this), fee);
        _transfer(msg.sender, to, amount - fee);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        uint256 fee = amount / 10;
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, address(this), fee);
        _transfer(from, to, amount - fee);
        return true;
    }
}

contract TreasuryPolicyTest is GrantTestBase {
    Treasury treasury;
    GrantRegistry registry;
    TimelockController timelock;
    TestToken token;
    address guardian = makeAddr("guardian");
    address payable payee = payable(makeAddr("payee"));

    function setUp() public {
        timelock = new TimelockController(1 days, new address[](0), new address[](0), address(this));
        registry = new GrantRegistry(address(timelock));
        treasury = new Treasury(address(timelock), registry);
        vm.prank(address(timelock));
        registry.setTreasury(address(treasury));
        token = new TestToken();
        vm.deal(address(treasury), 100 ether);
        token.transfer(address(treasury), 1_000_000e18);
        vm.prank(address(timelock));
        treasury.setCaps(50 ether, 200 ether, 500_000e18, 2_000_000e18);
        vm.prank(address(timelock));
        treasury.setTreasuryFloor(10 ether);
        vm.prank(address(timelock));
        treasury.setPauser(guardian);
        vm.prank(address(timelock));
        treasury.setTokenAllowed(address(token), true);
    }

    function testTypedEthPayoutEnforcesPerCallCap() public {
        uint256 id = createImmediate(registry, address(timelock), payee, address(0), 100 ether);

        vm.prank(address(timelock));
        vm.expectRevert(Treasury.CapExceeded.selector);
        treasury.payGrant(id, 51 ether);

        vm.prank(address(timelock));
        treasury.payGrant(id, 10 ether);
        assertEq(payee.balance, 10 ether);
    }

    function testFloorBlocksDrain() public {
        uint256 id = createImmediate(registry, address(timelock), payee, address(0), 100 ether);
        vm.prank(address(timelock));
        treasury.setCaps(100 ether, 200 ether, 500_000e18, 2_000_000e18);
        vm.prank(address(timelock));
        vm.expectRevert(Treasury.FloorViolated.selector);
        treasury.payGrant(id, 95 ether);
    }

    function testBatchPaysTwoApprovedMilestones() public {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1 ether;
        amounts[1] = 2 ether;
        uint64[] memory dues = new uint64[](2);
        uint256 id = createMilestone(registry, address(timelock), payee, address(0), amounts, dues);
        submitAndApprove(registry, address(timelock), payee, id, 0);
        submitAndApprove(registry, address(timelock), payee, id, 1);

        uint256[] memory ids = new uint256[](2);
        ids[0] = id;
        ids[1] = id;
        uint256[] memory indexes = new uint256[](2);
        indexes[0] = 0;
        indexes[1] = 1;

        vm.prank(address(timelock));
        treasury.payMilestoneBatch(ids, indexes);

        assertEq(payee.balance, 3 ether);
        assertEq(registry.grants(id).paid, 3 ether);
        assertEq(registry.committed(address(0)), 0);
        assertEq(uint256(registry.grants(id).status), uint256(GrantRegistry.GrantStatus.Completed));
    }

    function testBatchEnforcesPerProposalCap() public {
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 5 ether;
        uint64[] memory dues = new uint64[](1);
        dues[0] = uint64(block.timestamp + 1 days);
        uint256 id1 = createMilestone(registry, address(timelock), payee, address(0), amounts, dues);
        submitAndApprove(registry, address(timelock), payee, id1, 0);

        uint256[] memory amounts2 = new uint256[](1);
        amounts2[0] = 6 ether;
        uint256 id2 = createMilestone(
            registry, address(timelock), payable(makeAddr("payee2")), address(0), amounts2, dues
        );
        submitAndApprove(registry, address(timelock), payable(makeAddr("payee2")), id2, 0);

        uint256[] memory gids = new uint256[](2);
        gids[0] = id1;
        gids[1] = id2;
        uint256[] memory mids = new uint256[](2);

        vm.prank(address(timelock));
        treasury.setProposalCaps(10 ether, 2_000_000e18);
        vm.prank(address(timelock));
        vm.expectRevert(Treasury.CapExceeded.selector);
        treasury.payMilestoneBatch(gids, mids);

        vm.prank(address(timelock));
        treasury.setProposalCaps(11 ether, 2_000_000e18);
        vm.prank(address(timelock));
        treasury.payMilestoneBatch(gids, mids);
        assertEq(payee.balance, 5 ether);
    }

    function testPauseBlocksOutflowsNotDeposits() public {
        uint256 id = createImmediate(registry, address(timelock), payee, address(0), 10 ether);
        vm.prank(guardian);
        treasury.pause(1 hours);
        assertTrue(treasury.paused());

        vm.prank(address(timelock));
        vm.expectRevert(Treasury.PausedOutflows.selector);
        treasury.payGrant(id, 1 ether);

        token.approve(address(treasury), 100e18);
        treasury.depositERC20(address(token), 100e18);

        vm.prank(address(timelock));
        treasury.unpause();
        vm.prank(address(timelock));
        treasury.payGrant(id, 1 ether);
        assertEq(payee.balance, 1 ether);
    }

    function testGuardianCannotExtendPauseButGovernanceCan() public {
        vm.prank(guardian);
        treasury.pause(1 hours);
        vm.warp(block.timestamp + 30 minutes);
        vm.prank(guardian);
        vm.expectRevert(Treasury.PauseAlreadyActive.selector);
        treasury.pause(1 hours);

        vm.prank(address(timelock));
        treasury.pause(2 hours);
        assertEq(treasury.pauseExpiresAt(), uint64(block.timestamp + 2 hours));
    }

    function testFeeOnTransferDepositRejected() public {
        FeeToken fee = new FeeToken();
        fee.approve(address(treasury), 1000e18);
        vm.expectRevert(Treasury.FeeOnTransfer.selector);
        treasury.depositERC20(address(fee), 1000e18);
    }

    function testFeeOnTransferPayoutRejected() public {
        FeeToken fee = new FeeToken();
        fee.transfer(address(treasury), 1000e18); // Treasury receives 900
        vm.prank(address(timelock));
        treasury.setTokenAllowed(address(fee), true);
        uint256 id = createImmediate(registry, address(timelock), payee, address(fee), 100e18);

        vm.prank(address(timelock));
        vm.expectRevert(Treasury.FeeOnTransfer.selector);
        treasury.payGrant(id, 100e18);
    }

    function testVestingFundingAndRevokeInvariant() public {
        GrantVestingRevocable v = new GrantVestingRevocable(
            payee, address(treasury), address(treasury), uint64(block.timestamp), 1000, 100
        );
        uint256 grantId =
            createVesting(registry, address(timelock), payee, address(0), 20 ether, address(v));

        vm.prank(address(timelock));
        treasury.fundVesting(grantId, 20 ether);
        assertEq(address(v).balance, 20 ether);
        assertEq(registry.committed(address(0)), 0);
        assertEq(registry.grants(grantId).funded, 20 ether);

        vm.warp(block.timestamp + 600); // past cliff, 60% vested
        v.release();
        uint256 released = payee.balance;

        vm.prank(address(timelock));
        treasury.revokeVesting(grantId, "revoked");
        assertLe(released + v.revokedETH(), 20 ether);
        assertTrue(v.revoked());
        assertEq(
            uint256(registry.grants(grantId).status), uint256(GrantRegistry.GrantStatus.Revoked)
        );
        assertEq(address(treasury).balance, 100 ether - 20 ether + v.revokedETH());
    }

    function testPerTokenPolicyOverridesDefault() public {
        TestToken t2 = new TestToken();
        t2.transfer(address(treasury), 1_000e18);
        vm.prank(address(timelock));
        treasury.setTokenAllowed(address(t2), true);
        vm.prank(address(timelock));
        treasury.setTokenPolicy(address(t2), 100e18, 500e18, 150e18);
        uint256 id = createImmediate(registry, address(timelock), payee, address(t2), 200e18);

        vm.prank(address(timelock));
        vm.expectRevert(Treasury.CapExceeded.selector);
        treasury.payGrant(id, 160e18);

        vm.prank(address(timelock));
        treasury.payGrant(id, 100e18);
        assertEq(t2.balanceOf(payee), 100e18);
    }

    function testErc20VestingFundingAndRevoke() public {
        TestToken t2 = new TestToken();
        t2.transfer(address(treasury), 1_000e18);
        vm.prank(address(timelock));
        treasury.setTokenAllowed(address(t2), true);
        GrantVestingRevocable v = new GrantVestingRevocable(
            payee, address(treasury), address(treasury), uint64(block.timestamp), 1000, 0
        );
        uint256 grantId =
            createVesting(registry, address(timelock), payee, address(t2), 100e18, address(v));

        vm.prank(address(timelock));
        treasury.fundVestingERC20(grantId, 100e18);
        assertEq(t2.balanceOf(address(v)), 100e18);
        assertEq(registry.grants(grantId).funded, 100e18);

        vm.warp(block.timestamp + 500);
        v.releaseERC20(address(t2));
        assertEq(t2.balanceOf(payee), 50e18);

        vm.prank(address(timelock));
        treasury.revokeVesting(grantId, "revoked");
        assertTrue(v.erc20Revoked(address(t2)));
        assertEq(t2.balanceOf(address(treasury)), 950e18);
        assertEq(
            uint256(registry.grants(grantId).status), uint256(GrantRegistry.GrantStatus.Revoked)
        );
    }

    function testVestingFundingRejectsWrongAdmin() public {
        GrantVestingRevocable v = new GrantVestingRevocable(
            payee, address(timelock), address(treasury), uint64(block.timestamp), 1000, 0
        );
        uint256 grantId =
            createVesting(registry, address(timelock), payee, address(0), 10 ether, address(v));

        vm.prank(address(timelock));
        vm.expectRevert(Treasury.VestingAdminMismatch.selector);
        treasury.fundVesting(grantId, 5 ether);
    }

    function testVestingFundingRejectsWrongBeneficiary() public {
        GrantVestingRevocable v = new GrantVestingRevocable(
            address(0xB0B), address(treasury), address(treasury), uint64(block.timestamp), 1000, 0
        );
        uint256 grantId =
            createVesting(registry, address(timelock), payee, address(0), 10 ether, address(v));

        vm.prank(address(timelock));
        vm.expectRevert(Treasury.VestingBeneficiaryMismatch.selector);
        treasury.fundVesting(grantId, 5 ether);
    }

    function testVestingFundingRejectsWrongTreasury() public {
        GrantVestingRevocable v = new GrantVestingRevocable(
            payee, address(treasury), address(0xDEAD), uint64(block.timestamp), 1000, 0
        );
        uint256 grantId =
            createVesting(registry, address(timelock), payee, address(0), 10 ether, address(v));

        vm.prank(address(timelock));
        vm.expectRevert(Treasury.VestingTreasuryMismatch.selector);
        treasury.fundVesting(grantId, 5 ether);
    }

    function testFundedVestingCannotBeCancelled() public {
        GrantVestingRevocable v = new GrantVestingRevocable(
            payee, address(treasury), address(treasury), uint64(block.timestamp), 1000, 0
        );
        uint256 grantId =
            createVesting(registry, address(timelock), payee, address(0), 10 ether, address(v));
        vm.prank(address(timelock));
        treasury.fundVesting(grantId, 5 ether);

        vm.prank(address(timelock));
        vm.expectRevert(Treasury.MustRevokeVesting.selector);
        treasury.cancelGrant(grantId, "cannot cancel funded vesting");
    }
}
