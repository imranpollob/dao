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

contract GovernanceFlow is Test {
    GrantToken token;
    TimelockController timelock;
    GrantGovernor governor;
    Treasury treasury;

    address deployer = address(this);
    address voterA = address(0xA11CE);
    address payable grantee = payable(address(0xBEEF));

    uint256 constant INIT_SUPPLY = 1_000_000e18;
    uint256 constant PROPOSAL_THRESHOLD = 0; // small for test
    uint256 constant VOTING_DELAY = 1; // small for test
    uint256 constant VOTING_PERIOD = 5; // small for test
    uint256 constant QUORUM_PERCENT = 4; // 4%
    uint256 constant TIMELOCK_DELAY = 2 days;

    function setUp() public {
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

        // Roles + renounce admin
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        timelock.renounceRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);

        // delegate votes
        token.delegate(deployer);
        vm.prank(voterA);
        token.delegate(voterA);
        token.transfer(voterA, 200_000e18);

        // fund treasury
        vm.deal(address(treasury), 10 ether);
    }

    function testEndToEnd_EthGrant() public {
        // Build ETH grant proposal
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = ProposalBuilder.buildEthGrant(treasury, grantee, 5 ether, "Grant: 5 ETH to BEEF");

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
        // OZ v5: queue with full params
        bytes32 descriptionHash = keccak256(bytes(desc));
        governor.queue(targets, values, calldatas, descriptionHash);

        // Wait timelock
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);

        // Execute
        uint256 balBefore = grantee.balance;
        governor.execute(targets, values, calldatas, descriptionHash);
        uint256 balAfter = grantee.balance;

        assertEq(balAfter - balBefore, 5 ether, "Grantee did not receive 5 ETH");
    }

    function testEndToEnd_Erc20Grant() public {
        // Create a mock ERC20 token for testing
        MockERC20 erc20 = new MockERC20("Test Token", "TEST", 1_000_000e18);
        erc20.transfer(address(treasury), 100_000e18); // Fund treasury with ERC20

        // Build ERC20 grant proposal
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = ProposalBuilder.buildErc20Grant(
            treasury, address(erc20), grantee, 10_000e18, "Grant: 10k TEST to BEEF"
        );

        // Propose
        uint256 proposalId = governor.propose(targets, values, calldatas, desc);

        // Move to voting phase
        vm.roll(block.number + VOTING_DELAY + 1);

        // Cast votes
        vm.prank(voterA);
        governor.castVote(proposalId, 1); // For
        governor.castVote(proposalId, 1); // deployer For

        // Advance beyond voting period
        vm.roll(block.number + VOTING_PERIOD + 1);

        // Queue
        bytes32 descriptionHash = keccak256(bytes(desc));
        governor.queue(targets, values, calldatas, descriptionHash);

        // Wait timelock
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);

        // Execute
        uint256 balBefore = erc20.balanceOf(grantee);
        governor.execute(targets, values, calldatas, descriptionHash);
        uint256 balAfter = erc20.balanceOf(grantee);

        assertEq(balAfter - balBefore, 10_000e18, "Grantee did not receive 10k TEST tokens");
    }

    function testProposalRejection_InsufficientVotes() public {
        // Build ETH grant proposal
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = ProposalBuilder.buildEthGrant(treasury, grantee, 5 ether, "Grant: 5 ETH to BEEF");

        // Propose
        uint256 proposalId = governor.propose(targets, values, calldatas, desc);

        // Move to voting phase
        vm.roll(block.number + VOTING_DELAY + 1);

        // Cast against votes (should fail)
        vm.prank(voterA);
        governor.castVote(proposalId, 0); // Against
        governor.castVote(proposalId, 0); // deployer Against

        // Advance beyond voting period
        vm.roll(block.number + VOTING_PERIOD + 1);

        // Check proposal state is Defeated
        assertEq(
            uint256(governor.state(proposalId)),
            uint256(IGovernor.ProposalState.Defeated),
            "Proposal should be defeated"
        );

        // Should not be able to queue
        bytes32 descriptionHash = keccak256(bytes(desc));
        vm.expectRevert();
        governor.queue(targets, values, calldatas, descriptionHash);
    }
}

// Mock ERC20 for testing
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
