// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {GrantToken} from "../src/GrantToken.sol";
import {GrantGovernor} from "../src/GrantGovernor.sol";
import {Treasury} from "../src/Treasury.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {ProposalBuilder} from "../src/utils/ProposalBuilder.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ComprehensiveScenarios is Test {
    GrantToken token;
    TimelockController timelock;
    GrantGovernor governor;
    Treasury treasury;

    // Test addresses
    address deployer = address(this);
    address voterA = address(0xA11CE);
    address voterB = address(0xB22EF);
    address voterC = address(0xC33ED);
    // This variable represents the recipient of a grant in the various test scenarios.
    address payable grantee = payable(address(0xBEEF));
    address nonVoter = address(0xDEAD);

    // Test constants
    uint256 constant INIT_SUPPLY = 1_000_000e18;
    
    // This is the minimum number of votes (i.e., tokens) an account must hold to be able to create a new proposal.
    // Set to 0 for testing all scenarios
    uint256 constant PROPOSAL_THRESHOLD = 0; 

    // This defines the delay, in blocks, between when a proposal is created and when voting on it can begin. A value of 1 means voting starts one block after the proposal is submitted. This delay gives voters a chance to review the proposal before the voting period opens.
    uint256 constant VOTING_DELAY = 1;
    
    // This sets the duration of the voting period, in blocks. A value of 5 means that once voting starts, it will remain open for 5 blocks. 
    uint256 constant VOTING_PERIOD = 5;

    // This is the minimum percentage of the total token supply that must participate in a vote for the proposal to be considered valid. A 4% quorum means that at least 4% of all governance tokens must be used to vote on a proposal for it to pass or fail based on the vote counts. If the quorum is not met, the proposal is automatically defeated. This ensures that a small group of voters cannot pass proposals without a minimum level of community engagement.
    uint256 constant QUORUM_PERCENT = 4; // 4%

    // This is the mandatory waiting period between when a proposal is successfully passed and queued, and when it can be executed. The 2 days value is a convenient time unit provided by Solidity. This delay acts as a final safeguard, giving the community time to react to the outcome and take any emergency actions (like exiting their positions) if they strongly disagree with an approved proposal.
    uint256 constant TIMELOCK_DELAY = 2 days;

    // Mock ERC20 for testing
    MockERC20 testToken;

    function setUp() public {
        // Deploy contracts
        token = new GrantToken(INIT_SUPPLY, deployer);
        timelock =
            new TimelockController(TIMELOCK_DELAY, new address[](0), new address[](0), deployer);
        governor = new GrantGovernor(
            IVotes(address(token)),
            timelock,
            PROPOSAL_THRESHOLD,
            VOTING_DELAY,
            VOTING_PERIOD,
            QUORUM_PERCENT
        );
        treasury = new Treasury(address(timelock));

        // Setup timelock roles
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        timelock.renounceRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);

        // Setup voting power
        token.delegate(deployer);
        vm.prank(voterA);
        token.delegate(voterA);
        vm.prank(voterB);
        token.delegate(voterB);
        vm.prank(voterC);
        token.delegate(voterC);

        // Distribute tokens
        token.transfer(voterA, 200_000e18);
        token.transfer(voterB, 150_000e18);
        token.transfer(voterC, 100_000e18);

        // Fund treasury
        vm.deal(address(treasury), 100 ether);

        // Deploy test ERC20
        testToken = new MockERC20("Test Token", "TEST", 1_000_000e18);
        testToken.transfer(address(treasury), 500_000e18);
    }

    // ============ SUCCESS SCENARIOS ============

    /// @notice Tests a complete successful ETH grant proposal flow:
    /// - Propose an ETH grant to a recipient
    /// - Vote in favor with sufficient quorum
    /// - Queue the proposal after voting succeeds
    /// - Execute after timelock delay
    /// - Verify recipient receives the ETH
    function testScenario_SuccessfulEthGrant() public {
        // Build proposal
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = ProposalBuilder.buildEthGrant(treasury, grantee, 10 ether, "ETH Grant to BEEF");

        // Propose
        uint256 proposalId = governor.propose(targets, values, calldatas, desc);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Pending));

        // Move to voting
        vm.roll(block.number + VOTING_DELAY + 1);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Active));

        // Vote
        vm.prank(voterA);
        governor.castVote(proposalId, 1); // For
        vm.prank(voterB);
        governor.castVote(proposalId, 1); // For
        governor.castVote(proposalId, 1); // Deployer For

        // Check quorum and votes
        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) =
            governor.proposalVotes(proposalId);
        assertGt(forVotes, 0);
        assertEq(againstVotes, 0);
        assertEq(abstainVotes, 0);

        // Move to succeeded
        vm.roll(block.number + VOTING_PERIOD + 1);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Succeeded));

        // Queue
        bytes32 descHash = keccak256(bytes(desc));
        governor.queue(targets, values, calldatas, descHash);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Queued));

        // Execute after timelock
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);
        uint256 balBefore = grantee.balance;
        governor.execute(targets, values, calldatas, descHash);
        uint256 balAfter = grantee.balance;

        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Executed));
        assertEq(balAfter - balBefore, 10 ether);
    }

    /// @notice Tests a complete successful ERC20 token grant proposal flow:
    /// - Propose an ERC20 token grant to a recipient
    /// - Vote in favor with sufficient quorum
    /// - Queue and execute the proposal
    /// - Verify recipient receives the tokens
    function testScenario_SuccessfulErc20Grant() public {
        // Build proposal
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = ProposalBuilder.buildErc20Grant(
            treasury, address(testToken), grantee, 50_000e18, "ERC20 Grant to BEEF"
        );

        // Propose
        uint256 proposalId = governor.propose(targets, values, calldatas, desc);

        // Vote
        vm.roll(block.number + VOTING_DELAY + 1);
        vm.prank(voterA);
        governor.castVote(proposalId, 1);
        vm.prank(voterB);
        governor.castVote(proposalId, 1);
        governor.castVote(proposalId, 1);

        // Queue and execute
        vm.roll(block.number + VOTING_PERIOD + 1);
        bytes32 descHash = keccak256(bytes(desc));
        governor.queue(targets, values, calldatas, descHash);
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);

        uint256 balBefore = testToken.balanceOf(grantee);
        governor.execute(targets, values, calldatas, descHash);
        uint256 balAfter = testToken.balanceOf(grantee);

        assertEq(balAfter - balBefore, 50_000e18);
    }

    /// @notice Tests handling multiple concurrent proposals:
    /// - Create two separate ETH grant proposals
    /// - Vote on both proposals
    /// - Execute both proposals sequentially
    /// - Verify both recipients receive their grants
    function testScenario_MultipleProposals() public {
        // Create two proposals
        (
            address[] memory targets1,
            uint256[] memory values1,
            bytes[] memory calldatas1,
            string memory desc1
        ) = ProposalBuilder.buildEthGrant(treasury, grantee, 5 ether, "Grant 1");
        (
            address[] memory targets2,
            uint256[] memory values2,
            bytes[] memory calldatas2,
            string memory desc2
        ) = ProposalBuilder.buildEthGrant(treasury, payable(voterC), 3 ether, "Grant 2");

        uint256 propId1 = governor.propose(targets1, values1, calldatas1, desc1);
        uint256 propId2 = governor.propose(targets2, values2, calldatas2, desc2);

        // Vote on both
        vm.roll(block.number + VOTING_DELAY + 1);
        vm.prank(voterA);
        governor.castVote(propId1, 1);
        vm.prank(voterA);
        governor.castVote(propId2, 1);
        governor.castVote(propId1, 1);
        governor.castVote(propId2, 1);

        // Move to succeeded state
        vm.roll(block.number + VOTING_PERIOD + 1);

        // Queue and execute first proposal
        governor.queue(targets1, values1, calldatas1, keccak256(bytes(desc1)));
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);
        governor.execute(targets1, values1, calldatas1, keccak256(bytes(desc1)));

        // Queue and execute second proposal after additional delay
        governor.queue(targets2, values2, calldatas2, keccak256(bytes(desc2)));
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);
        governor.execute(targets2, values2, calldatas2, keccak256(bytes(desc2)));

        assertEq(grantee.balance, 5 ether);
        assertEq(voterC.balance, 3 ether);
    }

    // ============ FAILURE SCENARIOS ============

    /// @notice Tests proposal rejection when majority votes against:
    /// - Propose an ETH grant
    /// - Vote against the proposal
    /// - Verify proposal is defeated and cannot be queued
    function testScenario_ProposalRejected_InsufficientVotes() public {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = ProposalBuilder.buildEthGrant(treasury, grantee, 10 ether, "Rejected Grant");

        uint256 proposalId = governor.propose(targets, values, calldatas, desc);
        vm.roll(block.number + VOTING_DELAY + 1);

        // Vote against
        vm.prank(voterA);
        governor.castVote(proposalId, 0); // Against
        vm.prank(voterB);
        governor.castVote(proposalId, 0); // Against
        governor.castVote(proposalId, 0); // Against

        vm.roll(block.number + VOTING_PERIOD + 1);

        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Defeated));

        // Cannot queue defeated proposal
        bytes32 descHash = keccak256(bytes(desc));
        vm.expectRevert();
        governor.queue(targets, values, calldatas, descHash);
    }

    /// @notice Tests proposal rejection when quorum is not reached:
    /// - Propose an ETH grant
    /// - Only non-voting accounts participate (insufficient voting power)
    /// - Verify proposal is defeated due to lack of quorum
    function testScenario_ProposalRejected_NoQuorum() public {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = ProposalBuilder.buildEthGrant(treasury, grantee, 10 ether, "No Quorum Grant");

        uint256 proposalId = governor.propose(targets, values, calldatas, desc);
        vm.roll(block.number + VOTING_DELAY + 1);

        // Use nonVoter who has no voting power
        vm.prank(nonVoter);
        governor.castVote(proposalId, 1);

        vm.roll(block.number + VOTING_PERIOD + 1);

        // Should be defeated due to no quorum (only nonVoter voted, who has 0 votes)
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Defeated));
    }

    /// @notice Tests proposal creation with low voting power:
    /// - Attempt to propose with an account that has no tokens
    /// - With threshold set to 0, proposal should succeed
    /// - Verify proposal can be created even by token-less accounts
    function testScenario_ProposalBelowThreshold() public {
        // Since threshold is 0, this should work
        vm.prank(nonVoter); // No tokens but threshold is 0
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = ProposalBuilder.buildEthGrant(treasury, grantee, 1 ether, "Low Threshold Grant");

        // Should succeed because threshold is 0
        uint256 proposalId = governor.propose(targets, values, calldatas, desc);
        assertGt(proposalId, 0);
    }

    /// @notice Tests timelock enforcement for proposal execution:
    /// - Propose and approve an ETH grant
    /// - Queue the proposal
    /// - Attempt to execute before timelock delay expires
    /// - Verify execution is blocked until delay passes
    function testScenario_ExecuteBeforeTimelock() public {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = ProposalBuilder.buildEthGrant(treasury, grantee, 5 ether, "Early Execute");

        uint256 proposalId = governor.propose(targets, values, calldatas, desc);
        vm.roll(block.number + VOTING_DELAY + 1);

        vm.prank(voterA);
        governor.castVote(proposalId, 1);
        governor.castVote(proposalId, 1);

        vm.roll(block.number + VOTING_PERIOD + 1);
        bytes32 descHash = keccak256(bytes(desc));
        governor.queue(targets, values, calldatas, descHash);

        // Try to execute before timelock delay
        vm.expectRevert();
        governor.execute(targets, values, calldatas, descHash);
    }

    /// @notice Tests proper proposal state transitions:
    /// - Propose an ETH grant
    /// - Attempt to queue before voting period ends
    /// - Verify queuing is blocked until proposal succeeds
    function testScenario_QueueBeforeSucceeded() public {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = ProposalBuilder.buildEthGrant(treasury, grantee, 5 ether, "Queue Too Early");

        uint256 proposalId = governor.propose(targets, values, calldatas, desc);
        vm.roll(block.number + VOTING_DELAY + 1);

        // Don't wait for voting to end
        bytes32 descHash = keccak256(bytes(desc));
        vm.expectRevert();
        governor.queue(targets, values, calldatas, descHash);
    }

    /// @notice Tests execution replay protection:
    /// - Propose, approve, and execute an ETH grant
    /// - Attempt to execute the same proposal again
    /// - Verify double execution is prevented
    function testScenario_DoubleExecution() public {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = ProposalBuilder.buildEthGrant(treasury, grantee, 5 ether, "Double Execute");

        uint256 proposalId = governor.propose(targets, values, calldatas, desc);
        vm.roll(block.number + VOTING_DELAY + 1);

        vm.prank(voterA);
        governor.castVote(proposalId, 1);
        governor.castVote(proposalId, 1);

        vm.roll(block.number + VOTING_PERIOD + 1);
        bytes32 descHash = keccak256(bytes(desc));
        governor.queue(targets, values, calldatas, descHash);
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);

        governor.execute(targets, values, calldatas, descHash);

        // Try to execute again
        vm.expectRevert();
        governor.execute(targets, values, calldatas, descHash);
    }

    // ============ TREASURY FAILURE SCENARIOS ============

    /// @notice Tests treasury access control:
    /// - Attempt to execute treasury operations directly (not through governance)
    /// - Verify only the timelock (governance) can execute treasury operations
    function testScenario_TreasuryExecute_Unauthorized() public {
        // Non-owner cannot execute
        vm.expectRevert();
        treasury.execute(grantee, 1 ether, "");
    }

    /// @notice Tests treasury execution of failing operations:
    /// - Propose a treasury operation that calls a contract that will fail
    /// - Approve and attempt to execute the proposal
    /// - Verify execution fails gracefully when the called contract reverts
    function testScenario_TreasuryExecute_FailedCall() public {
        // Create a failing contract
        FailingContract failer = new FailingContract();

        // Build proposal to call failing contract
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(treasury);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(
            Treasury.execute.selector, address(failer), 0, abi.encodeWithSignature("fail()")
        );

        string memory desc = "Failing execution";

        // Propose and execute
        uint256 proposalId = governor.propose(targets, values, calldatas, desc);
        vm.roll(block.number + VOTING_DELAY + 1);
        vm.prank(voterA);
        governor.castVote(proposalId, 1);
        governor.castVote(proposalId, 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        bytes32 descHash = keccak256(bytes(desc));
        governor.queue(targets, values, calldatas, descHash);
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);

        // Execution should fail
        vm.expectRevert();
        governor.execute(targets, values, calldatas, descHash);
    }

    /// @notice Tests treasury fund limitations:
    /// - Propose an ETH grant larger than treasury balance
    /// - Approve and attempt to execute the proposal
    /// - Verify execution fails when treasury lacks sufficient funds
    function testScenario_TreasuryExecute_InsufficientFunds() public {
        // Try to send more ETH than treasury has
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = ProposalBuilder.buildEthGrant(treasury, grantee, 200 ether, "Too much ETH");

        uint256 proposalId = governor.propose(targets, values, calldatas, desc);
        vm.roll(block.number + VOTING_DELAY + 1);
        vm.prank(voterA);
        governor.castVote(proposalId, 1);
        governor.castVote(proposalId, 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        bytes32 descHash = keccak256(bytes(desc));
        governor.queue(targets, values, calldatas, descHash);
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);

        // Should fail due to insufficient funds
        vm.expectRevert();
        governor.execute(targets, values, calldatas, descHash);
    }

    // ============ VOTING SCENARIOS ============

    /// @notice Tests abstain voting functionality:
    /// - Propose an ETH grant
    /// - Cast a mix of For, Against, and Abstain votes
    /// - Verify all vote types are recorded correctly
    function testScenario_VoteAbstain() public {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = ProposalBuilder.buildEthGrant(treasury, grantee, 5 ether, "Abstain Test");

        uint256 proposalId = governor.propose(targets, values, calldatas, desc);
        vm.roll(block.number + VOTING_DELAY + 1);

        // Mix of votes
        vm.prank(voterA);
        governor.castVote(proposalId, 1); // For
        vm.prank(voterB);
        governor.castVote(proposalId, 2); // Abstain
        governor.castVote(proposalId, 0); // Against

        (uint256 against, uint256 forVotes, uint256 abstain) = governor.proposalVotes(proposalId);
        assertGt(forVotes, 0);
        assertGt(against, 0);
        assertGt(abstain, 0);
    }

    /// @notice Tests double voting prevention:
    /// - Propose an ETH grant
    /// - Cast a vote from one account
    /// - Attempt to vote again from the same account
    /// - Verify double voting is prevented
    function testScenario_VoteTwice() public {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = ProposalBuilder.buildEthGrant(treasury, grantee, 5 ether, "Double Vote");

        uint256 proposalId = governor.propose(targets, values, calldatas, desc);
        vm.roll(block.number + VOTING_DELAY + 1);

        vm.prank(voterA);
        governor.castVote(proposalId, 1);

        // Try to vote again
        vm.prank(voterA);
        vm.expectRevert();
        governor.castVote(proposalId, 0);
    }

    /// @notice Tests voting period enforcement:
    /// - Propose an ETH grant
    /// - Wait until voting period ends
    /// - Attempt to vote after deadline
    /// - Verify late voting is prevented
    function testScenario_VoteAfterDeadline() public {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = ProposalBuilder.buildEthGrant(treasury, grantee, 5 ether, "Late Vote");

        uint256 proposalId = governor.propose(targets, values, calldatas, desc);
        vm.roll(block.number + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_PERIOD + 1); // Voting ended

        vm.prank(voterA);
        vm.expectRevert();
        governor.castVote(proposalId, 1);
    }

    // ============ EDGE CASES ============

    /// @notice Tests zero-amount grant proposals:
    /// - Propose an ETH grant with 0 amount
    /// - Approve and execute the proposal
    /// - Verify the proposal succeeds but no funds are transferred
    function testScenario_ZeroAmountGrant() public {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = ProposalBuilder.buildEthGrant(treasury, grantee, 0, "Zero ETH Grant");

        uint256 proposalId = governor.propose(targets, values, calldatas, desc);
        vm.roll(block.number + VOTING_DELAY + 1);

        vm.prank(voterA);
        governor.castVote(proposalId, 1);
        governor.castVote(proposalId, 1);

        vm.roll(block.number + VOTING_PERIOD + 1);
        bytes32 descHash = keccak256(bytes(desc));
        governor.queue(targets, values, calldatas, descHash);
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);

        governor.execute(targets, values, calldatas, descHash);
        // Should succeed but transfer 0
        assertEq(grantee.balance, 0);
    }

    /// @notice Tests proposal cancellation:
    /// - Propose an ETH grant
    /// - Cancel the proposal before voting starts
    /// - Verify proposal state changes to Canceled
    function testScenario_ProposalCancel() public {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = ProposalBuilder.buildEthGrant(treasury, grantee, 5 ether, "Cancel Test");

        uint256 proposalId = governor.propose(targets, values, calldatas, desc);

        // Cancel before voting starts
        governor.cancel(targets, values, calldatas, keccak256(bytes(desc)));
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Canceled));
    }

    /// @notice Tests treasury's ability to receive ETH:
    /// - Send ETH directly to the treasury contract
    /// - Verify treasury balance increases correctly
    function testScenario_TreasuryReceiveEther() public {
        uint256 initialBalance = address(treasury).balance;

        // Send ETH to treasury
        vm.deal(address(this), 5 ether);
        payable(address(treasury)).transfer(3 ether);

        assertEq(address(treasury).balance, initialBalance + 3 ether);
    }
}

// Mock contracts for testing
contract MockERC20 {
    string public name;
    string public symbol;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _name, string memory _symbol, uint256 _totalSupply) {
        name = _name;
        symbol = _symbol;
        totalSupply = _totalSupply;
        balanceOf[msg.sender] = _totalSupply;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
}

contract FailingContract {
    function fail() external pure {
        revert("Intentional failure");
    }
}
