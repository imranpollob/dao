// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {Treasury} from "../src/Treasury.sol";
import {GrantRegistry} from "../src/GrantRegistry.sol";
import {ProposalBuilder} from "../src/utils/ProposalBuilder.sol";
import {ProposalRisk} from "../src/utils/ProposalRisk.sol";

contract ProposalBuilderTest is Test {
    address constant REGISTRY = address(0x1001);
    address constant TREASURY = address(0x1002);

    function _treasury() internal pure returns (Treasury) {
        return Treasury(payable(TREASURY));
    }

    function _assertSingle(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory desc,
        address target,
        bytes4 selector
    ) internal pure {
        assertEq(targets.length, 1);
        assertEq(values.length, 1);
        assertEq(calldatas.length, 1);
        assertEq(targets[0], target);
        assertEq(values[0], 0);
        assertEq(uint256(uint32(ProposalRisk.selectorOf(calldatas[0]))), uint256(uint32(selector)));
        assertEq(desc, "desc");
    }

    function testCreateGrantBuilder() public pure {
        GrantRegistry.CreateGrantParams memory p;
        uint256[] memory amounts = new uint256[](1);
        uint64[] memory due = new uint64[](1);
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = ProposalBuilder.buildCreateGrant(
            GrantRegistry(REGISTRY), p, "uri", amounts, due, "desc"
        );
        _assertSingle(
            targets, values, calldatas, desc, REGISTRY, GrantRegistry.createGrant.selector
        );
    }

    function testMilestoneApprovalBuilders() public pure {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = ProposalBuilder.buildApproveMilestone(GrantRegistry(REGISTRY), 1, 0, "desc");
        _assertSingle(
            targets, values, calldatas, desc, REGISTRY, GrantRegistry.approveMilestone.selector
        );

        (targets, values, calldatas, desc) =
            ProposalBuilder.buildRejectMilestone(GrantRegistry(REGISTRY), 1, 0, "bad", "desc");
        _assertSingle(
            targets, values, calldatas, desc, REGISTRY, GrantRegistry.rejectMilestone.selector
        );
    }

    function testPayoutBuilders() public pure {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = ProposalBuilder.buildImmediatePayout(_treasury(), 1, 1 ether, "desc");
        _assertSingle(targets, values, calldatas, desc, TREASURY, Treasury.payGrant.selector);

        (targets, values, calldatas, desc) =
            ProposalBuilder.buildMilestonePayout(_treasury(), 1, 0, "desc");
        _assertSingle(targets, values, calldatas, desc, TREASURY, Treasury.payMilestone.selector);

        uint256[] memory ids = new uint256[](1);
        (targets, values, calldatas, desc) =
            ProposalBuilder.buildMilestoneBatch(_treasury(), ids, ids, "desc");
        _assertSingle(
            targets, values, calldatas, desc, TREASURY, Treasury.payMilestoneBatch.selector
        );
    }

    function testVestingBuilders() public pure {
        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        ) = ProposalBuilder.buildVestingFunding(_treasury(), 1, 1 ether, "desc");
        _assertSingle(targets, values, calldatas, desc, TREASURY, Treasury.fundVesting.selector);

        (targets, values, calldatas, desc) =
            ProposalBuilder.buildVestingFundingERC20(_treasury(), 1, 1e18, "desc");
        _assertSingle(
            targets, values, calldatas, desc, TREASURY, Treasury.fundVestingERC20.selector
        );

        (targets, values, calldatas, desc) =
            ProposalBuilder.buildVestingRevoke(_treasury(), 1, "reason", "desc");
        _assertSingle(targets, values, calldatas, desc, TREASURY, Treasury.revokeVesting.selector);

        (targets, values, calldatas, desc) =
            ProposalBuilder.buildCancelGrant(_treasury(), 1, "reason", "desc");
        _assertSingle(targets, values, calldatas, desc, TREASURY, Treasury.cancelGrant.selector);
    }
}
