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

contract GovernanceFlow is GrantTestBase {
    GrantToken token;
    TimelockController timelock;
    GrantGovernor governor;
    Treasury treasury;
    GrantRegistry registry;

    address deployer = address(this);
    address voterA = address(0xA11CE);
    address payable grantee = payable(address(0xBEEF));

    uint256 constant INIT_SUPPLY = 1_000_000e18;
    uint256 constant PROPOSAL_THRESHOLD = 0;
    uint256 constant VOTING_DELAY = 1;
    uint256 constant VOTING_PERIOD = 5;
    uint256 constant QUORUM_PERCENT = 4;
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
        token.transfer(voterA, 200_000e18);

        vm.deal(address(treasury), 10 ether);
        vm.prank(address(timelock));
        treasury.setCaps(10 ether, 100 ether, 1_000_000e18, 5_000_000e18);
        vm.prank(address(timelock));
        treasury.setTreasuryFloor(0);
    }

    function testEndToEnd_EthGrant() public {
        uint256 grantId = createImmediate(registry, address(timelock), grantee, address(0), 5 ether);
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = ProposalBuilder.buildImmediatePayout(treasury, grantId, 5 ether, "Grant: 5 ETH");

        uint256 proposalId = governor.propose(targets, values, calldatas, desc);
        vm.roll(block.number + VOTING_DELAY + 1);

        vm.prank(voterA);
        governor.castVote(proposalId, 1);
        governor.castVote(proposalId, 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        bytes32 descriptionHash = keccak256(bytes(desc));
        governor.queue(targets, values, calldatas, descriptionHash);
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);

        uint256 balBefore = grantee.balance;
        governor.execute(targets, values, calldatas, descriptionHash);
        assertEq(grantee.balance - balBefore, 5 ether);
        assertEq(
            uint256(registry.grants(grantId).status), uint256(GrantRegistry.GrantStatus.Completed)
        );
    }

    function testEndToEnd_Erc20Grant() public {
        MockERC20 erc20 = new MockERC20("Test Token", "TEST", 1_000_000e18);
        erc20.transfer(address(treasury), 100_000e18);
        vm.prank(address(timelock));
        treasury.setTokenAllowed(address(erc20), true);
        uint256 grantId =
            createImmediate(registry, address(timelock), grantee, address(erc20), 10_000e18);

        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = ProposalBuilder.buildImmediatePayout(treasury, grantId, 10_000e18, "Grant: 10k TEST");

        uint256 proposalId = governor.propose(targets, values, calldatas, desc);
        vm.roll(block.number + VOTING_DELAY + 1);
        vm.prank(voterA);
        governor.castVote(proposalId, 1);
        governor.castVote(proposalId, 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        bytes32 descriptionHash = keccak256(bytes(desc));
        governor.queue(targets, values, calldatas, descriptionHash);
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);

        uint256 balBefore = erc20.balanceOf(grantee);
        governor.execute(targets, values, calldatas, descriptionHash);
        assertEq(erc20.balanceOf(grantee) - balBefore, 10_000e18);
    }

    function testProposalRejection_InsufficientVotes() public {
        uint256 grantId = createImmediate(registry, address(timelock), grantee, address(0), 5 ether);
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = ProposalBuilder.buildImmediatePayout(treasury, grantId, 5 ether, "Grant: 5 ETH");

        uint256 proposalId = governor.propose(targets, values, calldatas, desc);
        vm.roll(block.number + VOTING_DELAY + 1);
        vm.prank(voterA);
        governor.castVote(proposalId, 0);
        governor.castVote(proposalId, 0);
        vm.roll(block.number + VOTING_PERIOD + 1);

        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Defeated));
        vm.expectRevert();
        governor.queue(targets, values, calldatas, keccak256(bytes(desc)));
    }
}

// Minimal ERC20 used by the treasury path.
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
