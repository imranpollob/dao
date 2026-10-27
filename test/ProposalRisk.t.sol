// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {ProposalRisk} from "../src/utils/ProposalRisk.sol";
import {Treasury} from "../src/Treasury.sol";

contract ProposalRiskTest is Test {
    function testKnownTreasuryPayoutIsClean() public pure {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        targets[0] = address(0x1234);
        calldatas[0] = abi.encodeWithSelector(Treasury.payGrant.selector, 1, 1 ether);
        ProposalRisk.ScanResult memory r = ProposalRisk.scan(targets, calldatas, values);
        assertTrue(ProposalRisk.isClean(r));
    }

    function testApprovalFlagged() public pure {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] =
            abi.encodeWithSelector(bytes4(0x095ea7b3), address(0xBEEF), type(uint256).max);
        ProposalRisk.ScanResult memory r = ProposalRisk.scan(targets, calldatas, values);
        assertTrue(r.hasApproval);
        assertFalse(ProposalRisk.isClean(r));
    }

    function testUnknownSelectorFlagged() public pure {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(bytes4(0xdeadbeef));
        ProposalRisk.ScanResult memory r = ProposalRisk.scan(targets, calldatas, values);
        assertTrue(r.hasUnknownSelector);
        assertFalse(ProposalRisk.isClean(r));
    }

    function testEmptyCalldataValueDrainFlagged() public pure {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        values[0] = 1 ether;
        ProposalRisk.ScanResult memory r = ProposalRisk.scan(targets, calldatas, values);
        assertTrue(r.hasEmptyCalldataDrain);
        assertFalse(ProposalRisk.isClean(r));
    }

    function testOwnershipRoleAndUpgradeFlagged() public pure {
        address[] memory targets = new address[](3);
        uint256[] memory values = new uint256[](3);
        bytes[] memory calldatas = new bytes[](3);
        calldatas[0] = abi.encodeWithSelector(bytes4(0xf2fde38b), address(0xBEEF));
        calldatas[1] = abi.encodeWithSelector(bytes4(0x2f2ff15d), bytes32(0), address(0xBEEF));
        calldatas[2] = abi.encodeWithSelector(bytes4(0x3659cfe6), address(0xBEEF));
        ProposalRisk.ScanResult memory r = ProposalRisk.scan(targets, calldatas, values);
        assertTrue(r.hasOwnershipChange);
        assertTrue(r.hasRoleChange);
        assertTrue(r.hasUpgrade);
        assertFalse(ProposalRisk.isClean(r));
    }

    function testMalformedArraysFlagged() public pure {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](0);
        bytes[] memory calldatas = new bytes[](0);
        ProposalRisk.ScanResult memory r = ProposalRisk.scan(targets, calldatas, values);
        assertTrue(r.malformed);
        assertFalse(ProposalRisk.isClean(r));
    }
}
