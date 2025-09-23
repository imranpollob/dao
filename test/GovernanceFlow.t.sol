// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {GrantToken} from "../src/GrantToken.sol";
import {GrantGovernor} from "../src/GrantGovernor.sol";
import {Treasury} from "../src/Treasury.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {ProposalBuilder} from "../src/utils/ProposalBuilder.sol";

contract GovernanceFlow is Test {
    GrantToken token;
    TimelockController timelock;
    GrantGovernor governor;
    Treasury treasury;

    address deployer = address(this);
    address voterA = address(0xA11CE);
    address payable grantee = payable(address(0xBEEF));

    uint256 constant INIT_SUPPLY = 1_000_000e18;
    uint256 constant PROPOSAL_THRESHOLD = 10_000e18;
    uint256 constant VOTING_DELAY = 1;    // small for test
    uint256 constant VOTING_PERIOD = 5;   // small for test
    uint256 constant QUORUM_PERCENT = 4;  // 4%
    uint256 constant TIMELOCK_DELAY = 2 days;

    function setUp() public {
        token = new GrantToken(INIT_SUPPLY, deployer);
        timelock = new TimelockController(TIMELOCK_DELAY, new address, new address, deployer);
        governor = new GrantGovernor(
            IVotes(address(token)),
            timelock,
            PROPOSAL_THRESHOLD,
            VOTING_DELAY,
            VOTING_PERIOD,
            QUORUM_PERCENT
        );
        treasury = new Treasury(address(timelock));

        // Roles + renounce admin
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        timelock.renounceRole(timelock.TIMELOCK_ADMIN_ROLE(), deployer);

        // delegate votes
        token.transfer(voterA, 200_000e18);
        token.delegate(deployer);
        vm.prank(voterA);
        token.delegate(voterA);

        // fund treasury
        vm.deal(address(treasury), 10 ether);
    }

    function testEndToEnd_EthGrant() public {
        // Build ETH grant proposal
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory desc) =
            ProposalBuilder.buildEthGrant(treasury, grantee, 5 ether, "Grant: 5 ETH to BEEF");

        // Propose (deployer has delegated votes ≥ threshold)
        uint256 proposalId = governor.propose(targets, values, calldatas, desc);

        // At this point: state = Pending; move to Active (after delay)
        vm.roll(block.number + VOTING_DELAY + 1);

        // Cast votes (For wins)
        vm.prank(voterA);
        governor.castVote(proposalId, 1); // For
        governor.castVote(proposalId, 1); // deployer For

        // Advance beyond voting period
        vm.roll(block.number + VOTING_PERIOD + 1);

        // Should be Succeeded → Queue
        // OZ v5 shortcut: queue by proposalId
        governor.queue(proposalId);

        // Wait timelock
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);

        // Execute
        uint256 balBefore = grantee.balance;
        governor.execute(proposalId);
        uint256 balAfter = grantee.balance;

        assertEq(balAfter - balBefore, 5 ether, "Grantee did not receive 5 ETH");
    }
}
