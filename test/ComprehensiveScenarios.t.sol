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

contract ComprehensiveScenarios is GrantTestBase {
    GrantToken token;
    TimelockController timelock;
    GrantGovernor governor;
    Treasury treasury;
    GrantRegistry registry;

    address deployer = address(this);
    address voterA = address(0xA11CE);
    address voterB = address(0xB22EF);
    address voterC = address(0xC33ED);
    address payable grantee = payable(address(0xBEEF));
    address nonVoter = address(0xDEAD);

    uint256 constant INIT_SUPPLY = 1_000_000e18;
    uint256 constant PROPOSAL_THRESHOLD = 0;
    uint256 constant VOTING_DELAY = 1;
    uint256 constant VOTING_PERIOD = 5;
    uint256 constant QUORUM_PERCENT = 4;
    uint256 constant TIMELOCK_DELAY = 2 days;

    MockERC20 testToken;

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
            QUORUM_PERCENT,
            makeAddr("guardian")
        );
        registry = new GrantRegistry(address(timelock));
        treasury = new Treasury(address(timelock), registry);
        vm.prank(address(timelock));
        registry.setTreasury(address(treasury));

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        timelock.renounceRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);

        token.delegate(deployer);
        vm.prank(voterA);
        token.delegate(voterA);
        vm.prank(voterB);
        token.delegate(voterB);
        vm.prank(voterC);
        token.delegate(voterC);

        token.transfer(voterA, 200_000e18);
        token.transfer(voterB, 150_000e18);
        token.transfer(voterC, 100_000e18);

        vm.deal(address(treasury), 100 ether);
        vm.prank(address(timelock));
        treasury.setCaps(100 ether, 1_000 ether, 1_000_000e18, 5_000_000e18);
        vm.prank(address(timelock));
        treasury.setTreasuryFloor(0);

        testToken = new MockERC20("Test Token", "TEST", 1_000_000e18);
        testToken.transfer(address(treasury), 500_000e18);
        vm.prank(address(timelock));
        treasury.setTokenAllowed(address(testToken), true);
    }

    function _buildEth(address payable recipient, uint256 amount, string memory desc)
        internal
        returns (address[] memory, uint256[] memory, bytes[] memory, string memory)
    {
        uint256 id = createImmediate(registry, address(timelock), recipient, address(0), amount);
        return ProposalBuilder.buildImmediatePayout(treasury, id, amount, desc);
    }

    function _buildErc20(address recipient, uint256 amount, string memory desc)
        internal
        returns (address[] memory, uint256[] memory, bytes[] memory, string memory)
    {
        uint256 id = createImmediate(
            registry, address(timelock), recipient, address(testToken), amount
        );
        return ProposalBuilder.buildImmediatePayout(treasury, id, amount, desc);
    }

    function testScenario_SuccessfulEthGrant() public {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = _buildEth(grantee, 10 ether, "ETH Grant to BEEF");

        uint256 proposalId = governor.propose(targets, values, calldatas, desc);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Pending));

        vm.roll(block.number + VOTING_DELAY + 1);
        vm.prank(voterA);
        governor.castVote(proposalId, 1);
        vm.prank(voterB);
        governor.castVote(proposalId, 1);
        governor.castVote(proposalId, 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        bytes32 descHash = keccak256(bytes(desc));
        governor.queue(targets, values, calldatas, descHash);
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);
        uint256 balBefore = grantee.balance;
        governor.execute(targets, values, calldatas, descHash);
        assertEq(grantee.balance - balBefore, 10 ether);
    }

    function testScenario_SuccessfulErc20Grant() public {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = _buildErc20(grantee, 50_000e18, "ERC20 Grant to BEEF");

        uint256 proposalId = governor.propose(targets, values, calldatas, desc);
        vm.roll(block.number + VOTING_DELAY + 1);
        vm.prank(voterA);
        governor.castVote(proposalId, 1);
        vm.prank(voterB);
        governor.castVote(proposalId, 1);
        governor.castVote(proposalId, 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        bytes32 descHash = keccak256(bytes(desc));
        governor.queue(targets, values, calldatas, descHash);
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);
        uint256 balBefore = testToken.balanceOf(grantee);
        governor.execute(targets, values, calldatas, descHash);
        assertEq(testToken.balanceOf(grantee) - balBefore, 50_000e18);
    }

    function testScenario_MultipleProposals() public {
        (
            address[] memory targets1,
            uint256[] memory values1,
            bytes[] memory calldatas1,
            string memory desc1
        ) = _buildEth(grantee, 5 ether, "Grant 1");
        (
            address[] memory targets2,
            uint256[] memory values2,
            bytes[] memory calldatas2,
            string memory desc2
        ) = _buildEth(payable(voterC), 3 ether, "Grant 2");

        uint256 propId1 = governor.propose(targets1, values1, calldatas1, desc1);
        uint256 propId2 = governor.propose(targets2, values2, calldatas2, desc2);

        vm.roll(block.number + VOTING_DELAY + 1);
        vm.prank(voterA);
        governor.castVote(propId1, 1);
        vm.prank(voterA);
        governor.castVote(propId2, 1);
        governor.castVote(propId1, 1);
        governor.castVote(propId2, 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        governor.queue(targets1, values1, calldatas1, keccak256(bytes(desc1)));
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);
        governor.execute(targets1, values1, calldatas1, keccak256(bytes(desc1)));

        governor.queue(targets2, values2, calldatas2, keccak256(bytes(desc2)));
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);
        governor.execute(targets2, values2, calldatas2, keccak256(bytes(desc2)));

        assertEq(grantee.balance, 5 ether);
        assertEq(voterC.balance, 3 ether);
    }

    function testScenario_ProposalRejected_InsufficientVotes() public {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = _buildEth(grantee, 10 ether, "Rejected Grant");

        uint256 proposalId = governor.propose(targets, values, calldatas, desc);
        vm.roll(block.number + VOTING_DELAY + 1);
        vm.prank(voterA);
        governor.castVote(proposalId, 0);
        vm.prank(voterB);
        governor.castVote(proposalId, 0);
        governor.castVote(proposalId, 0);
        vm.roll(block.number + VOTING_PERIOD + 1);

        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Defeated));
        vm.expectRevert();
        governor.queue(targets, values, calldatas, keccak256(bytes(desc)));
    }

    function testScenario_ProposalRejected_NoQuorum() public {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = _buildEth(grantee, 10 ether, "No Quorum Grant");

        uint256 proposalId = governor.propose(targets, values, calldatas, desc);
        vm.roll(block.number + VOTING_DELAY + 1);
        vm.prank(nonVoter);
        governor.castVote(proposalId, 1);
        vm.roll(block.number + VOTING_PERIOD + 1);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Defeated));
    }

    function testScenario_ProposalWithZeroThreshold() public {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = _buildEth(grantee, 1 ether, "Low Threshold Grant");
        uint256 proposalId = governor.propose(targets, values, calldatas, desc);
        assertGt(proposalId, 0);
    }

    function testScenario_ExecuteBeforeTimelock() public {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = _buildEth(grantee, 5 ether, "Early Execute");
        uint256 proposalId = governor.propose(targets, values, calldatas, desc);
        vm.roll(block.number + VOTING_DELAY + 1);
        vm.prank(voterA);
        governor.castVote(proposalId, 1);
        governor.castVote(proposalId, 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        bytes32 descHash = keccak256(bytes(desc));
        governor.queue(targets, values, calldatas, descHash);
        vm.expectRevert();
        governor.execute(targets, values, calldatas, descHash);
    }

    function testScenario_QueueBeforeSucceeded() public {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = _buildEth(grantee, 5 ether, "Queue Too Early");
        governor.propose(targets, values, calldatas, desc);
        vm.roll(block.number + VOTING_DELAY + 1);
        vm.expectRevert();
        governor.queue(targets, values, calldatas, keccak256(bytes(desc)));
    }

    function testScenario_DoubleExecution() public {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = _buildEth(grantee, 5 ether, "Double Execute");
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
        vm.expectRevert();
        governor.execute(targets, values, calldatas, descHash);
    }

    function testScenario_TreasuryPayout_Unauthorized() public {
        uint256 id = createImmediate(registry, address(timelock), grantee, address(0), 10 ether);
        vm.expectRevert();
        treasury.payGrant(id, 1 ether);
    }

    function testScenario_TreasuryPayout_FailedCall() public {
        FailingContract failer = new FailingContract();
        uint256 id =
            createImmediate(registry, address(timelock), address(failer), address(0), 5 ether);
        vm.prank(address(timelock));
        vm.expectRevert();
        treasury.payGrant(id, 5 ether);
    }

    function testScenario_TreasuryPayout_InsufficientFunds() public {
        uint256 id = createImmediate(registry, address(timelock), grantee, address(0), 200 ether);
        vm.prank(address(timelock));
        vm.expectRevert();
        treasury.payGrant(id, 200 ether);
    }

    function testScenario_VoteAbstain() public {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = _buildEth(grantee, 5 ether, "Abstain Test");
        uint256 proposalId = governor.propose(targets, values, calldatas, desc);
        vm.roll(block.number + VOTING_DELAY + 1);
        vm.prank(voterA);
        governor.castVote(proposalId, 1);
        vm.prank(voterB);
        governor.castVote(proposalId, 2);
        governor.castVote(proposalId, 0);
        (uint256 against, uint256 forVotes, uint256 abstain) = governor.proposalVotes(proposalId);
        assertGt(forVotes, 0);
        assertGt(against, 0);
        assertGt(abstain, 0);
    }

    function testScenario_VoteTwice() public {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = _buildEth(grantee, 5 ether, "Double Vote");
        uint256 proposalId = governor.propose(targets, values, calldatas, desc);
        vm.roll(block.number + VOTING_DELAY + 1);
        vm.prank(voterA);
        governor.castVote(proposalId, 1);
        vm.prank(voterA);
        vm.expectRevert();
        governor.castVote(proposalId, 0);
    }

    function testScenario_VoteAfterDeadline() public {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = _buildEth(grantee, 5 ether, "Late Vote");
        uint256 proposalId = governor.propose(targets, values, calldatas, desc);
        vm.roll(block.number + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);
        vm.prank(voterA);
        vm.expectRevert();
        governor.castVote(proposalId, 1);
    }

    function testScenario_ZeroAmountGrantRejected() public {
        uint256 id = createImmediate(registry, address(timelock), grantee, address(0), 1 ether);
        vm.prank(address(timelock));
        vm.expectRevert(Treasury.ZeroAmount.selector);
        treasury.payGrant(id, 0);
    }

    function testScenario_ProposalCancel() public {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = _buildEth(grantee, 5 ether, "Cancel Test");
        uint256 proposalId = governor.propose(targets, values, calldatas, desc);
        governor.cancel(targets, values, calldatas, keccak256(bytes(desc)));
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Canceled));
    }

    function testScenario_TreasuryReceiveEther() public {
        uint256 initialBalance = address(treasury).balance;
        vm.deal(address(this), 5 ether);
        payable(address(treasury)).transfer(3 ether);
        assertEq(address(treasury).balance, initialBalance + 3 ether);
    }
}

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
