// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Treasury} from "../Treasury.sol";
import {GrantRegistry} from "../GrantRegistry.sol";

/// @title Governance proposal builders for the grant lifecycle
/// @notice Every value-moving target is Treasury, which validates and records
/// against GrantRegistry. Grant creation is a separate Registry proposal.
library ProposalBuilder {
    function _single(address target, bytes memory data, string memory description)
        private
        pure
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        )
    {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        targets[0] = target;
        calldatas[0] = data;
        desc = description;
    }

    /// @notice Create a grant. The Timelock owns the Registry and executes this.
    function buildCreateGrant(
        GrantRegistry registry,
        GrantRegistry.CreateGrantParams memory params,
        string memory metadataURI,
        uint256[] memory milestoneAmounts,
        uint64[] memory milestoneDueDates,
        string memory description
    )
        internal
        pure
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        )
    {
        return _single(
            address(registry),
            abi.encodeWithSelector(
                GrantRegistry.createGrant.selector,
                params,
                metadataURI,
                milestoneAmounts,
                milestoneDueDates
            ),
            description
        );
    }

    /// @notice Pay an Immediate grant.
    function buildImmediatePayout(
        Treasury treasury,
        uint256 grantId,
        uint256 amount,
        string memory description
    )
        internal
        pure
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        )
    {
        return _single(
            address(treasury),
            abi.encodeWithSelector(Treasury.payGrant.selector, grantId, amount),
            description
        );
    }

    /// @notice Approve submitted milestone evidence. Timelock-owned registry call.
    function buildApproveMilestone(
        GrantRegistry registry,
        uint256 grantId,
        uint256 milestoneId,
        string memory description
    )
        internal
        pure
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        )
    {
        return _single(
            address(registry),
            abi.encodeWithSelector(GrantRegistry.approveMilestone.selector, grantId, milestoneId),
            description
        );
    }

    /// @notice Reject submitted milestone evidence.
    function buildRejectMilestone(
        GrantRegistry registry,
        uint256 grantId,
        uint256 milestoneId,
        string memory reason,
        string memory description
    )
        internal
        pure
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        )
    {
        return _single(
            address(registry),
            abi.encodeWithSelector(
                GrantRegistry.rejectMilestone.selector, grantId, milestoneId, reason
            ),
            description
        );
    }

    /// @notice Pay one approved milestone. Amount is taken from the registry.
    function buildMilestonePayout(
        Treasury treasury,
        uint256 grantId,
        uint256 milestoneId,
        string memory description
    )
        internal
        pure
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        )
    {
        return _single(
            address(treasury),
            abi.encodeWithSelector(Treasury.payMilestone.selector, grantId, milestoneId),
            description
        );
    }

    /// @notice Pay multiple approved ETH milestones atomically.
    function buildMilestoneBatch(
        Treasury treasury,
        uint256[] memory grantIds,
        uint256[] memory milestoneIds,
        string memory description
    )
        internal
        pure
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        )
    {
        require(grantIds.length == milestoneIds.length, "length mismatch");
        return _single(
            address(treasury),
            abi.encodeWithSelector(Treasury.payMilestoneBatch.selector, grantIds, milestoneIds),
            description
        );
    }

    /// @notice Fund a Vesting grant from Treasury.
    function buildVestingFunding(
        Treasury treasury,
        uint256 grantId,
        uint256 amount,
        string memory description
    )
        internal
        pure
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        )
    {
        return _single(
            address(treasury),
            abi.encodeWithSelector(Treasury.fundVesting.selector, grantId, amount),
            description
        );
    }

    /// @notice Fund a Vesting grant with an ERC20 from Treasury.
    function buildVestingFundingERC20(
        Treasury treasury,
        uint256 grantId,
        uint256 amount,
        string memory description
    )
        internal
        pure
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        )
    {
        return _single(
            address(treasury),
            abi.encodeWithSelector(Treasury.fundVestingERC20.selector, grantId, amount),
            description
        );
    }

    /// @notice Revoke a Vesting grant and return unvested funds to Treasury.
    function buildVestingRevoke(
        Treasury treasury,
        uint256 grantId,
        string memory reason,
        string memory description
    )
        internal
        pure
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        )
    {
        return _single(
            address(treasury),
            abi.encodeWithSelector(Treasury.revokeVesting.selector, grantId, reason),
            description
        );
    }

    /// @notice Cancel an unfunded Immediate/Milestone grant.
    function buildCancelGrant(
        Treasury treasury,
        uint256 grantId,
        string memory reason,
        string memory description
    )
        internal
        pure
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        )
    {
        return _single(
            address(treasury),
            abi.encodeWithSelector(Treasury.cancelGrant.selector, grantId, reason),
            description
        );
    }
}
