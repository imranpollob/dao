// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {GrantToken} from "../src/GrantToken.sol";
import {Treasury} from "../src/Treasury.sol";
import {GrantGovernor} from "../src/GrantGovernor.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

contract TreasurySmoke is Test {
    GrantToken token;
    TimelockController timelock;
    GrantGovernor governor;
    Treasury treasury;

    address deployer = makeAddr("deployer");
    address voter1 = makeAddr("voter1");
    address payee = makeAddr("payee");

    function setUp() public {
        vm.startPrank(deployer);

        token = new GrantToken(1_000_000e18, deployer);
        timelock = new TimelockController(2 days, new address[](0), new address[](0), deployer);
        governor = new GrantGovernor(
            IVotes(address(token)),
            timelock,
            10_000e18, // threshold
            1, // votingDelay
            5, // votingPeriod
            4 // quorum %
        );
        treasury = new Treasury(address(timelock));

        // Roles and admin renounce
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        timelock.renounceRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);

        // delegate votes
        token.transfer(voter1, 100_000e18);
        vm.stopPrank();
        vm.prank(voter1);
        token.delegate(voter1);

        // fund treasury
        vm.deal(address(treasury), 10 ether);
    }

    function test_snapshot_compile() public {
        // Basic deployment checks
        assertTrue(address(governor) != address(0));
        assertTrue(address(treasury) != address(0));
        assertTrue(address(timelock) != address(0));
        assertTrue(address(token) != address(0));

        // Check initial token distribution
        assertEq(token.balanceOf(deployer), 900_000e18); // 1M - 100k transferred
        assertEq(token.balanceOf(voter1), 100_000e18);

        // Check treasury funding
        assertEq(address(treasury).balance, 10 ether);

        // Check ownership and roles
        assertEq(treasury.owner(), address(timelock));
        assertTrue(timelock.hasRole(timelock.PROPOSER_ROLE(), address(governor)));
        assertTrue(timelock.hasRole(timelock.EXECUTOR_ROLE(), address(0)));
        assertFalse(timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), deployer)); // renounced

        // Check governor configuration
        assertEq(governor.proposalThreshold(), 10_000e18);
        assertEq(governor.votingDelay(), 1);
        assertEq(governor.votingPeriod(), 5);
        assertEq(governor.quorumNumerator(), 4);
    }

    function testTreasury_ReceiveEther() public {
        // Test that treasury can receive ETH
        uint256 initialBalance = address(treasury).balance;
        vm.deal(address(this), 5 ether);

        // Send ETH to treasury
        payable(address(treasury)).transfer(2 ether);

        assertEq(address(treasury).balance, initialBalance + 2 ether, "Treasury should receive ETH");
    }

    function testTreasury_Execute_RevertsForNonOwner() public {
        // Test that execute reverts when called by non-owner
        vm.expectRevert();
        treasury.execute(address(0), 0, "");
    }

    function testTreasury_Execute_SucceedsForOwner() public {
        // Test that execute works when called by owner (timelock)
        // We'll test a simple ETH transfer
        address recipient = makeAddr("recipient");
        uint256 amount = 1 ether;
        bytes memory callData = "";

        uint256 treasuryBalanceBefore = address(treasury).balance;
        uint256 recipientBalanceBefore = recipient.balance;

        // Execute the transfer via timelock (owner)
        vm.prank(address(timelock));
        treasury.execute(recipient, amount, callData);

        uint256 treasuryBalanceAfter = address(treasury).balance;
        uint256 recipientBalanceAfter = recipient.balance;

        assertEq(
            treasuryBalanceAfter, treasuryBalanceBefore - amount, "Treasury balance should decrease"
        );
        assertEq(
            recipientBalanceAfter, recipientBalanceBefore + amount, "Recipient should receive ETH"
        );
    }

    function testTreasury_ReentrancyProtection() public {
        // Test that treasury execute is protected against reentrancy
        ReentrancyAttacker attacker = new ReentrancyAttacker(address(treasury));
        vm.deal(address(attacker), 1 ether);

        // Fund treasury
        vm.deal(address(treasury), 5 ether);

        // Attempt reentrant call should fail
        vm.expectRevert();
        vm.prank(address(timelock));
        treasury.execute(address(attacker), 1 ether, abi.encodeWithSignature("attack()"));
    }
}

// Helper contract for reentrancy testing
contract ReentrancyAttacker {
    address public treasury;
    bool public attacked;

    constructor(address _treasury) {
        treasury = _treasury;
    }

    function attack() external payable {
        if (!attacked) {
            attacked = true;
            // Try to re-enter treasury.execute
            Treasury(payable(treasury)).execute(address(this), 0.5 ether, "");
        }
    }

    receive() external payable {}
}
