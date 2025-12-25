// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {GrantToken} from "../src/GrantToken.sol";
import {GrantGovernor} from "../src/GrantGovernor.sol";
import {Treasury} from "../src/Treasury.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {GrantVesting} from "../src/GrantVesting.sol";
import {ProposalBuilder} from "../src/utils/ProposalBuilder.sol";

contract SecurityAndVestingTest is Test {
    GrantToken token;
    TimelockController timelock;
    GrantGovernor governor;
    Treasury treasury;
    GrantVesting vesting;

    address deployer = address(this);
    address guardian = address(0xBAD);
    address beneficiary = address(0xBEEF);

    uint256 constant INIT_SUPPLY = 1_000_000e18;
    uint256 constant TIMELOCK_DELAY = 1 days;

    function setUp() public {
        token = new GrantToken(INIT_SUPPLY, deployer);
        timelock = new TimelockController(
            TIMELOCK_DELAY,
            new address[](0),
            new address[](0),
            deployer
        );
        governor = new GrantGovernor(
            IVotes(address(token)),
            timelock,
            0, // threshold
            1, // delay
            5, // period
            0 // quorum
        );
        treasury = new Treasury(address(timelock));

        // Roles
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        timelock.grantRole(timelock.CANCELLER_ROLE(), guardian); // Guardian Setup
        timelock.renounceRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);

        token.delegate(deployer);
    }

    function testGuardianCancellation() public {
        // 1. Propose
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = ProposalBuilder.buildEthGrant(
                treasury,
                payable(beneficiary),
                1 ether,
                "Grant"
            );

        uint256 pid = governor.propose(targets, values, calldatas, desc);

        // 2. Pass vote
        vm.roll(block.number + 2);
        governor.castVote(pid, 1);
        vm.roll(block.number + 6);

        // 3. Queue and capture ID
        bytes32 descriptionHash = keccak256(bytes(desc));

        vm.recordLogs();
        governor.queue(targets, values, calldatas, descriptionHash);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 opId;
        // Find the CallScheduled or similar event from Timelock
        // Event signature: CallScheduled(bytes32 indexed id, uint256 indexed index, address target, uint256 value, bytes data, bytes32 predecessor, uint256 delay)
        bytes32 CALL_SCHEDULED_SIG = keccak256(
            "CallScheduled(bytes32,uint256,address,uint256,bytes,bytes32,uint256)"
        );

        for (uint i = 0; i < entries.length; i++) {
            if (entries[i].emitter == address(timelock)) {
                // We accept the first ID we see from Timelock
                if (entries[i].topics.length > 1) {
                    opId = entries[i].topics[1]; // indexed id is topic 1 (topic 0 is signature)
                }
            }
        }

        console2.log("Captured OpId:");
        console2.logBytes32(opId);

        // 4. Guardian Cancels using Timelock directly
        vm.prank(guardian);
        timelock.cancel(opId);

        // 5. Verify state
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);

        vm.expectRevert(); // Should revert because proposal was cancelled in timelock
        governor.execute(targets, values, calldatas, descriptionHash);
    }

    function testVestingWallet() public {
        uint64 start = uint64(block.timestamp);
        uint64 duration = 1000;
        vesting = new GrantVesting(beneficiary, start, duration);

        // Fund vesting
        vm.deal(address(vesting), 1000 ether);

        // Check release
        vm.warp(start + 500); // 50%
        uint256 released = vesting.releasable(); // ETH
        assertEq(released, 500 ether);

        vesting.release(); // Release ETH
        assertEq(beneficiary.balance, 500 ether);
    }
}
