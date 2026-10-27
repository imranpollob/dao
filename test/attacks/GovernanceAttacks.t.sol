// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {GrantToken} from "../../src/GrantToken.sol";
import {GrantGovernor} from "../../src/GrantGovernor.sol";
import {Treasury} from "../../src/Treasury.sol";
import {GrantRegistry} from "../../src/GrantRegistry.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {GrantTestBase} from "../helpers/GrantTestBase.sol";

/// @notice Governance attack proofs: flashloan fails, borrow-and-hold is the
/// real vector, typed payouts contain it, and the raw execute path is gone.
contract GovernanceAttacks is GrantTestBase {
    GrantToken token;
    TimelockController timelock;
    GrantGovernor governor;
    Treasury treasury;
    GrantRegistry registry;

    address deployer = address(this);
    address attacker = makeAddr("attacker");
    address payable drain = payable(makeAddr("drain"));
    uint256 drainGrantId;

    uint256 constant SUPPLY = 1_000_000e18;

    function setUp() public {
        token = new GrantToken(SUPPLY, deployer);
        timelock = new TimelockController(2 days, new address[](0), new address[](0), deployer);
        governor = new GrantGovernor(
            IVotes(address(token)), timelock, 40_000e18, 1, 5, 4, makeAddr("guardian")
        );
        registry = new GrantRegistry(address(timelock));
        treasury = new Treasury(address(timelock), registry);
        vm.prank(address(timelock));
        registry.setTreasury(address(treasury));

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        timelock.renounceRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);
        token.delegate(deployer);
        vm.roll(block.number + 1);
        vm.deal(address(treasury), 100 ether);
        vm.prank(address(timelock));
        treasury.setCaps(50 ether, 200 ether, 500_000e18, 2_000_000e18);
        vm.prank(address(timelock));
        treasury.setTreasuryFloor(10 ether);

        drainGrantId = createImmediate(registry, address(timelock), drain, address(0), 100 ether);
    }

    function _proposeDrain(uint256 amount)
        internal
        view
        returns (address[] memory, uint256[] memory, bytes[] memory, bytes32)
    {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        targets[0] = address(treasury);
        calldatas[0] = abi.encodeWithSelector(Treasury.payGrant.selector, drainGrantId, amount);
        bytes32 h = keccak256(bytes("drain"));
        return (targets, values, calldatas, h);
    }

    function testPureFlashloanVoteFails() public {
        (address[] memory t, uint256[] memory v, bytes[] memory c, bytes memory _d) =
            _proposeArgs(1 ether);
        string memory desc = string(_d);
        uint256 pid = governor.propose(t, v, c, desc);
        uint256 snapshot = governor.proposalSnapshot(pid);
        vm.roll(snapshot + 1);
        token.transfer(attacker, 500_000e18);
        vm.prank(attacker);
        token.delegate(attacker);
        vm.roll(block.number + 1);
        assertEq(token.getPastVotes(attacker, snapshot), 0);
    }

    function testBorrowAndHoldIsRealVectorButTypedCapContains() public {
        token.transfer(attacker, 500_000e18);
        vm.prank(attacker);
        token.delegate(attacker);
        vm.roll(block.number + 2);

        (address[] memory t, uint256[] memory vals, bytes[] memory c, bytes32 h) =
            _proposeDrain(51 ether);
        string memory desc = "drain";
        uint256 pid = _proposeRaw(desc, t, vals, c);
        assertEq(h, keccak256(bytes(desc)));
        vm.roll(block.number + 2);
        vm.prank(attacker);
        governor.castVote(pid, 1);
        vm.roll(block.number + 10);
        assertEq(uint256(governor.state(pid)), uint256(IGovernor.ProposalState.Succeeded));
        governor.queue(t, vals, c, h);
        vm.warp(block.timestamp + 2 days + 1);
        vm.expectRevert();
        governor.execute(t, vals, c, h);
    }

    function testRawExecutePathRemoved() public {
        token.transfer(attacker, 500_000e18);
        vm.prank(attacker);
        token.delegate(attacker);
        vm.roll(block.number + 2);

        address[] memory t = new address[](1);
        uint256[] memory vals = new uint256[](1);
        bytes[] memory c = new bytes[](1);
        t[0] = address(treasury);
        c[0] = abi.encodeWithSelector(
            bytes4(keccak256("execute(address,uint256,bytes)")), drain, 90 ether, bytes("")
        );
        uint256 pid = governor.propose(t, vals, c, "raw drain");
        bytes32 h = keccak256(bytes("raw drain"));
        vm.roll(block.number + 2);
        vm.prank(attacker);
        governor.castVote(pid, 1);
        vm.roll(block.number + 10);
        governor.queue(t, vals, c, h);
        vm.warp(block.timestamp + 2 days + 1);
        vm.expectRevert();
        governor.execute(t, vals, c, h);
        assertEq(drain.balance, 0);
    }

    function testVoteBySigReplayReverts() public {
        (address[] memory t, uint256[] memory vals, bytes[] memory c, bytes memory _d) =
            _proposeArgs(1 ether);
        uint256 pid = governor.propose(t, vals, c, string(_d));
        vm.roll(block.number + 2);
        uint256 sk = 0x1234;
        address voter = vm.addr(sk);
        token.transfer(voter, 100_000e18);
        vm.prank(voter);
        token.delegate(voter);
        vm.roll(block.number + 1);
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes("GrantGovernor")),
                keccak256(bytes("1")),
                block.chainid,
                address(governor)
            )
        );
        (uint8 vv, bytes32 rr, bytes32 ss) = vm.sign(
            sk,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    domainSeparator,
                    keccak256(
                        abi.encode(governor.BALLOT_TYPEHASH(), pid, uint8(1), voter, uint256(0))
                    )
                )
            )
        );
        governor.castVoteBySig(pid, 1, voter, abi.encodePacked(rr, ss, vv));
        vm.expectRevert();
        governor.castVoteBySig(pid, 1, voter, abi.encodePacked(rr, ss, vv));
    }

    function _proposeArgs(uint256 amount)
        internal
        view
        returns (address[] memory, uint256[] memory, bytes[] memory, bytes memory)
    {
        address[] memory t = new address[](1);
        uint256[] memory vals = new uint256[](1);
        bytes[] memory c = new bytes[](1);
        t[0] = address(treasury);
        c[0] = abi.encodeWithSelector(Treasury.payGrant.selector, drainGrantId, amount);
        return (t, vals, c, bytes("grant"));
    }

    function _proposeRaw(
        string memory desc,
        address[] memory t,
        uint256[] memory vals,
        bytes[] memory c
    ) internal returns (uint256) {
        vm.prank(attacker);
        return governor.propose(t, vals, c, desc);
    }
}
