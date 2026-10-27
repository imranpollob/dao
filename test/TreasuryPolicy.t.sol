// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {Treasury} from "../src/Treasury.sol";
import {GrantVestingRevocable} from "../src/GrantVestingRevocable.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

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
        // 10% fee kept: recipient gets less (malicious/non-standard).
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

contract TreasuryPolicyTest is Test {
    Treasury treasury;
    TimelockController timelock;
    TestToken token;
    address guardian = makeAddr("guardian");
    address payable payee = payable(makeAddr("payee"));

    function setUp() public {
        timelock = new TimelockController(1 days, new address[](0), new address[](0), address(this));
        treasury = new Treasury(address(timelock));
        token = new TestToken();
        vm.deal(address(treasury), 100 ether);
        token.transfer(address(treasury), 1_000_000e18);
        vm.prank(address(timelock));
        treasury.setCaps(50 ether, 200 ether, 500_000e18, 2_000_000e18);
        vm.prank(address(timelock));
        treasury.setTreasuryFloor(10 ether);
        vm.prank(address(timelock));
        treasury.setPauser(guardian);
    }

    function testTypedEthPayoutEnforcesPerCallCap() public {
        vm.prank(address(timelock));
        vm.expectRevert(Treasury.CapExceeded.selector);
        treasury.sendETH(payee, 51 ether, 1, 0);

        vm.prank(address(timelock));
        treasury.sendETH(payee, 10 ether, 1, 0);
        assertEq(payee.balance, 10 ether);
    }

    function testFloorBlocksDrain() public {
        // Raise per-call cap so the floor (not the cap) is the binding constraint.
        vm.prank(address(timelock));
        treasury.setCaps(100 ether, 200 ether, 500_000e18, 2_000_000e18);
        vm.prank(address(timelock));
        vm.expectRevert(Treasury.FloorViolated.selector);
        treasury.sendETH(payee, 95 ether, 1, 0);
    }

    function testBatchEnforcesPerProposalCap() public {
        address payable[] memory tos = new address payable[](2);
        tos[0] = payee;
        tos[1] = payable(makeAddr("payee2"));
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 5 ether;
        amounts[1] = 6 ether;
        uint256[] memory gids = new uint256[](2);
        gids[0] = 1;
        gids[1] = 2;
        uint256[] memory mids = new uint256[](2);

        vm.prank(address(timelock));
        vm.expectRevert(Treasury.CapExceeded.selector);
        treasury.batchSendETH(tos, amounts, gids, mids, 10 ether);

        vm.prank(address(timelock));
        treasury.batchSendETH(tos, amounts, gids, mids, 11 ether);
        assertEq(payee.balance, 5 ether);
    }

    function testPauseBlocksOutflowsNotDeposits() public {
        vm.prank(guardian);
        treasury.pause(1 hours);
        assertTrue(treasury.paused());

        vm.prank(address(timelock));
        vm.expectRevert(Treasury.PausedOutflows.selector);
        treasury.sendETH(payee, 1 ether, 1, 0);

        // Deposits still work while paused.
        token.approve(address(treasury), 100e18);
        treasury.depositERC20(address(token), 100e18);

        vm.prank(address(timelock));
        treasury.unpause();
        vm.prank(address(timelock));
        treasury.sendETH(payee, 1 ether, 1, 0);
        assertEq(payee.balance, 1 ether);
    }

    function testFeeOnTransferRejected() public {
        FeeToken fee = new FeeToken();
        fee.approve(address(treasury), 1000e18);
        vm.expectRevert(Treasury.FeeOnTransfer.selector);
        treasury.depositERC20(address(fee), 1000e18);
    }

    function testVestingFundingAndRevokeInvariant() public {
        GrantVestingRevocable v =
            new GrantVestingRevocable(payee, address(timelock), uint64(block.timestamp), 1000, 100);
        vm.prank(address(timelock));
        treasury.fundVesting(payable(address(v)), 20 ether, 7);
        assertEq(address(v).balance, 20 ether);

        vm.warp(block.timestamp + 600); // past cliff, 60% vested
        v.release();
        uint256 released = payee.balance;

        vm.prank(address(timelock));
        v.revoke();
        // Invariant: released + revoked <= funded.
        assertLe(released + v.revokedETH(), 20 ether);
        assertTrue(v.revoked());
    }
}
