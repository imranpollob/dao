// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {GrantToken} from "../src/GrantToken.sol";
import {GrantGovernor} from "../src/GrantGovernor.sol";
import {Treasury} from "../src/Treasury.sol";
import {GrantRegistry} from "../src/GrantRegistry.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {ProposalBuilder} from "../src/utils/ProposalBuilder.sol";
import {GrantTestBase} from "./helpers/GrantTestBase.sol";

contract SecurityAndVestingTest is GrantTestBase {
    GrantToken token;
    TimelockController timelock;
    GrantGovernor governor;
    Treasury treasury;
    GrantRegistry registry;

    address deployer = address(this);
    address guardian = address(0xBAD);
    address beneficiary = address(0xBEEF);

    uint256 constant INIT_SUPPLY = 1_000_000e18;
    uint256 constant TIMELOCK_DELAY = 1 days;

    function setUp() public {
        token = new GrantToken(INIT_SUPPLY, deployer);
        timelock =
            new TimelockController(TIMELOCK_DELAY, new address[](0), new address[](0), deployer);
        governor = new GrantGovernor(IVotes(address(token)), timelock, 0, 1, 5, 0, guardian);
        registry = new GrantRegistry(address(timelock));
        treasury = new Treasury(address(timelock), registry);
        vm.prank(address(timelock));
        registry.setTreasury(address(treasury));

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        timelock.renounceRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);

        token.delegate(deployer);
        vm.deal(address(treasury), 10 ether);
        vm.prank(address(timelock));
        treasury.setCaps(10 ether, 100 ether, 1_000_000e18, 5_000_000e18);
        vm.prank(address(timelock));
        treasury.setTreasuryFloor(0);
    }

    function testGuardianCancellation() public {
        uint256 grantId =
            createImmediate(registry, address(timelock), payable(beneficiary), address(0), 1 ether);
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = ProposalBuilder.buildImmediatePayout(treasury, grantId, 1 ether, "Grant");

        uint256 pid = governor.propose(targets, values, calldatas, desc);
        vm.roll(block.number + 2);
        governor.castVote(pid, 1);
        vm.roll(block.number + 6);
        bytes32 descriptionHash = keccak256(bytes(desc));
        governor.queue(targets, values, calldatas, descriptionHash);

        vm.prank(guardian);
        governor.cancel(targets, values, calldatas, descriptionHash);
        assertEq(uint256(governor.state(pid)), uint256(IGovernor.ProposalState.Canceled));
    }

    function testGuardianCannotBeZeroAtConstruction() public {
        vm.expectRevert(GrantGovernor.ZeroAddress.selector);
        new GrantGovernor(IVotes(address(token)), timelock, 0, 1, 5, 0, address(0));
    }

    function testGuardianCanCancelPending() public {
        uint256 grantId =
            createImmediate(registry, address(timelock), payable(beneficiary), address(0), 1 ether);
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = ProposalBuilder.buildImmediatePayout(treasury, grantId, 1 ether, "Grant");
        uint256 pid = governor.propose(targets, values, calldatas, desc);

        vm.prank(guardian);
        governor.cancel(targets, values, calldatas, keccak256(bytes(desc)));
        assertEq(uint256(governor.state(pid)), uint256(IGovernor.ProposalState.Canceled));
    }

    function testGuardianCanCancelActive() public {
        uint256 grantId =
            createImmediate(registry, address(timelock), payable(beneficiary), address(0), 1 ether);
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = ProposalBuilder.buildImmediatePayout(treasury, grantId, 1 ether, "Grant");
        uint256 pid = governor.propose(targets, values, calldatas, desc);
        vm.roll(block.number + 2);
        vm.prank(guardian);
        governor.cancel(targets, values, calldatas, keccak256(bytes(desc)));
        assertEq(uint256(governor.state(pid)), uint256(IGovernor.ProposalState.Canceled));
    }

    function testGuardianCanCancelSucceeded() public {
        uint256 grantId =
            createImmediate(registry, address(timelock), payable(beneficiary), address(0), 1 ether);
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = ProposalBuilder.buildImmediatePayout(treasury, grantId, 1 ether, "Grant");
        uint256 pid = governor.propose(targets, values, calldatas, desc);
        vm.roll(block.number + 2);
        governor.castVote(pid, 1);
        vm.roll(block.number + 6);
        assertEq(uint256(governor.state(pid)), uint256(IGovernor.ProposalState.Succeeded));

        vm.prank(guardian);
        governor.cancel(targets, values, calldatas, keccak256(bytes(desc)));
        assertEq(uint256(governor.state(pid)), uint256(IGovernor.ProposalState.Canceled));
    }

    function testNonGuardianCannotCancelActive() public {
        uint256 grantId =
            createImmediate(registry, address(timelock), payable(beneficiary), address(0), 1 ether);
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = ProposalBuilder.buildImmediatePayout(treasury, grantId, 1 ether, "Grant");
        governor.propose(targets, values, calldatas, desc);
        vm.roll(block.number + 2);
        vm.expectRevert();
        governor.cancel(targets, values, calldatas, keccak256(bytes(desc)));
    }
}
