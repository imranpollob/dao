// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {GrantToken} from "../src/GrantToken.sol";
import {GrantGovernor} from "../src/GrantGovernor.sol";
import {Treasury} from "../src/Treasury.sol";
import {GrantRegistry} from "../src/GrantRegistry.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {ProposalBuilder} from "../src/utils/ProposalBuilder.sol";
import {GrantTestBase} from "./helpers/GrantTestBase.sol";

/// @notice One-command local lifecycle evidence: deploy -> grant -> propose ->
/// vote -> queue -> timelock -> execute -> registry/runway report.
/// Run with: forge test --match-contract DemoLifecycle -vv
contract DemoLifecycle is GrantTestBase {
    GrantToken token;
    TimelockController timelock;
    GrantGovernor governor;
    Treasury treasury;
    GrantRegistry registry;

    address voter = address(0xA11CE);
    address payable recipient = payable(address(0xBEEF));

    function testFullLifecycle() public {
        token = new GrantToken(1_000_000e18, address(this));
        timelock = new TimelockController(2 days, new address[](0), new address[](0), address(this));
        governor =
            new GrantGovernor(IVotes(address(token)), timelock, 0, 1, 5, 4, makeAddr("guardian"));
        registry = new GrantRegistry(address(timelock));
        treasury = new Treasury(address(timelock), registry);
        vm.prank(address(timelock));
        registry.setTreasury(address(treasury));

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        timelock.renounceRole(timelock.DEFAULT_ADMIN_ROLE(), address(this));

        token.delegate(address(this));
        vm.prank(voter);
        token.delegate(voter);
        token.transfer(voter, 200_000e18);

        vm.deal(address(treasury), 100 ether);
        vm.prank(address(timelock));
        treasury.setCaps(50 ether, 200 ether, 500_000e18, 2_000_000e18);
        vm.prank(address(timelock));
        treasury.setProposalCaps(100 ether, 1_000_000e18);
        vm.prank(address(timelock));
        treasury.setTreasuryFloor(10 ether);

        uint256 grantId =
            createImmediate(registry, address(timelock), recipient, address(0), 10 ether);
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = ProposalBuilder.buildImmediatePayout(treasury, grantId, 10 ether, "Demo grant: 10 ETH");

        uint256 proposalId = governor.propose(targets, values, calldatas, desc);
        vm.roll(block.number + 2);
        vm.prank(voter);
        governor.castVote(proposalId, 1);
        governor.castVote(proposalId, 1);
        vm.roll(block.number + 6);

        bytes32 descriptionHash = keccak256(bytes(desc));
        governor.queue(targets, values, calldatas, descriptionHash);
        vm.warp(block.timestamp + 2 days + 1);
        uint256 recipientBefore = recipient.balance;
        governor.execute(targets, values, calldatas, descriptionHash);

        GrantRegistry.Grant memory g = registry.grants(grantId);
        console2.log("token:", address(token));
        console2.log("timelock:", address(timelock));
        console2.log("governor:", address(governor));
        console2.log("treasury:", address(treasury));
        console2.log("registry:", address(registry));
        console2.log("proposalId:", proposalId);
        console2.log("grantId:", grantId);
        console2.log("recipient delta:", recipient.balance - recipientBefore);
        console2.log("grant paid:", g.paid);
        console2.log("registry committed:", registry.committed(address(0)));
        console2.log(
            "treasury available:", registry.availableFor(address(0), address(treasury).balance)
        );

        assertEq(recipient.balance - recipientBefore, 10 ether);
        assertEq(g.paid, 10 ether);
        assertEq(uint256(g.status), uint256(GrantRegistry.GrantStatus.Completed));
        assertEq(registry.committed(address(0)), 0);
    }
}
