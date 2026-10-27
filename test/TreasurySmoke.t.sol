// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {GrantToken} from "../src/GrantToken.sol";
import {Treasury} from "../src/Treasury.sol";
import {GrantRegistry} from "../src/GrantRegistry.sol";
import {GrantGovernor} from "../src/GrantGovernor.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {GrantTestBase} from "./helpers/GrantTestBase.sol";

contract TreasurySmoke is GrantTestBase {
    GrantToken token;
    TimelockController timelock;
    GrantGovernor governor;
    Treasury treasury;
    GrantRegistry registry;

    address deployer = makeAddr("deployer");
    address voter1 = makeAddr("voter1");
    address payee = makeAddr("payee");

    function setUp() public {
        vm.startPrank(deployer);
        token = new GrantToken(1_000_000e18, deployer);
        timelock = new TimelockController(2 days, new address[](0), new address[](0), deployer);
        governor = new GrantGovernor(
            IVotes(address(token)), timelock, 10_000e18, 1, 5, 4, makeAddr("guardian")
        );
        registry = new GrantRegistry(address(timelock));
        treasury = new Treasury(address(timelock), registry);
        vm.stopPrank();

        vm.prank(address(timelock));
        registry.setTreasury(address(treasury));

        vm.startPrank(deployer);
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        timelock.renounceRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);
        token.transfer(voter1, 100_000e18);
        vm.stopPrank();

        vm.prank(voter1);
        token.delegate(voter1);

        vm.deal(address(treasury), 10 ether);
        vm.prank(address(timelock));
        treasury.setCaps(10 ether, 100 ether, 1_000_000e18, 5_000_000e18);
        vm.prank(address(timelock));
        treasury.setTreasuryFloor(0);
    }

    function test_snapshot_compile() public view {
        assertTrue(address(governor) != address(0));
        assertTrue(address(treasury) != address(0));
        assertTrue(address(timelock) != address(0));
        assertTrue(address(token) != address(0));
        assertEq(token.balanceOf(deployer), 900_000e18);
        assertEq(token.balanceOf(voter1), 100_000e18);
        assertEq(address(treasury).balance, 10 ether);
        assertEq(treasury.owner(), address(timelock));
        assertTrue(timelock.hasRole(timelock.PROPOSER_ROLE(), address(governor)));
        assertTrue(timelock.hasRole(timelock.EXECUTOR_ROLE(), address(0)));
        assertFalse(timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), deployer));
        assertEq(governor.proposalThreshold(), 10_000e18);
        assertEq(governor.votingDelay(), 1);
        assertEq(governor.votingPeriod(), 5);
        assertEq(governor.quorumNumerator(), 4);
    }

    function testTreasury_ReceiveEther() public {
        uint256 initialBalance = address(treasury).balance;
        vm.deal(address(this), 5 ether);
        payable(address(treasury)).transfer(2 ether);
        assertEq(address(treasury).balance, initialBalance + 2 ether);
    }

    function testTreasury_PayGrant_RevertsForNonOwner() public {
        uint256 id = createImmediate(registry, address(timelock), payee, address(0), 1 ether);
        vm.expectRevert();
        treasury.payGrant(id, 1 ether);
    }

    function testTreasury_PayGrant_SucceedsForOwner() public {
        uint256 id = createImmediate(registry, address(timelock), payee, address(0), 1 ether);
        vm.prank(address(timelock));
        treasury.payGrant(id, 1 ether);
        assertEq(payee.balance, 1 ether);
        assertEq(registry.grants(id).paid, 1 ether);
    }

    function testTreasury_ReentrancyProtection() public {
        ReentrancyAttacker attacker = new ReentrancyAttacker(treasury);
        uint256 id =
            createImmediate(registry, address(timelock), address(attacker), address(0), 1 ether);
        attacker.setGrantId(id);
        vm.prank(address(timelock));
        vm.expectRevert();
        treasury.payGrant(id, 1 ether);
    }
}

contract ReentrancyAttacker {
    Treasury public treasury;
    uint256 public grantId;
    bool public attacked;

    constructor(Treasury _treasury) {
        treasury = _treasury;
    }

    function setGrantId(uint256 id) external {
        grantId = id;
    }

    receive() external payable {
        if (!attacked) {
            attacked = true;
            treasury.payGrant(grantId, 0.5 ether);
        }
    }
}
