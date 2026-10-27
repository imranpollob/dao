// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Treasury} from "../Treasury.sol";
import {GrantRegistry} from "../GrantRegistry.sol";

/// @title Proposal risk scanner (pure, off-chain friendly)
/// @notice Flags dangerous selectors, approvals, unknown calls, and malformed
/// proposal arrays. It is a preflight signal, not an on-chain security boundary.
library ProposalRisk {
    bytes4 internal constant TRANSFER = 0xa9059cbb;
    bytes4 internal constant TRANSFER_FROM = 0x23b872dd;
    bytes4 internal constant APPROVE = 0x095ea7b3;
    bytes4 internal constant SET_APPROVAL_ALL = 0xa22cb465;
    bytes4 internal constant TRANSFER_OWNERSHIP = 0xf2fde38b;
    bytes4 internal constant GRANT_ROLE = 0x2f2ff15d;
    bytes4 internal constant REVOKE_ROLE = 0xd547741f;
    bytes4 internal constant UPGRADE_TO = 0x3659cfe6;

    struct ScanResult {
        bool malformed;
        bool hasDelegatecall;
        bool hasOwnershipChange;
        bool hasRoleChange;
        bool hasUpgrade;
        bool hasApproval;
        bool hasUnknownSelector;
        bool hasEmptyCalldataDrain;
    }

    function selectorOf(bytes memory data) internal pure returns (bytes4 sel) {
        if (data.length >= 4) {
            assembly {
                sel := mload(add(data, 32))
            }
        }
    }

    function _known(bytes4 sel) internal pure returns (bool) {
        return sel == TRANSFER || sel == TRANSFER_FROM || sel == APPROVE || sel == SET_APPROVAL_ALL
            || sel == TRANSFER_OWNERSHIP || sel == GRANT_ROLE || sel == REVOKE_ROLE
            || sel == UPGRADE_TO || sel == Treasury.payGrant.selector
            || sel == Treasury.payMilestone.selector || sel == Treasury.payMilestoneBatch.selector
            || sel == Treasury.fundVesting.selector || sel == Treasury.fundVestingERC20.selector
            || sel == Treasury.revokeVesting.selector || sel == Treasury.cancelGrant.selector
            || sel == Treasury.setCaps.selector || sel == Treasury.setProposalCaps.selector
            || sel == Treasury.setTokenPolicy.selector || sel == Treasury.setTreasuryFloor.selector
            || sel == Treasury.setTokenAllowed.selector
            || sel == Treasury.setEnforceAllowlist.selector || sel == Treasury.setPauser.selector
            || sel == Treasury.setMaxPauseDuration.selector || sel == Treasury.unpause.selector
            || sel == GrantRegistry.createGrant.selector
            || sel == GrantRegistry.approveMilestone.selector
            || sel == GrantRegistry.rejectMilestone.selector;
    }

    function scan(address[] memory targets, bytes[] memory calldatas, uint256[] memory values)
        internal
        pure
        returns (ScanResult memory r)
    {
        if (targets.length != calldatas.length || targets.length != values.length) {
            r.malformed = true;
            return r;
        }
        for (uint256 i = 0; i < calldatas.length; i++) {
            bytes memory data = calldatas[i];
            bytes4 sel = selectorOf(data);
            if (data.length < 4 && values[i] > 0) r.hasEmptyCalldataDrain = true;
            if (sel == TRANSFER_OWNERSHIP) r.hasOwnershipChange = true;
            else if (sel == GRANT_ROLE || sel == REVOKE_ROLE) r.hasRoleChange = true;
            else if (sel == UPGRADE_TO) r.hasUpgrade = true;
            else if (sel == APPROVE || sel == SET_APPROVAL_ALL) r.hasApproval = true;
            else if (data.length >= 4 && !_known(sel)) r.hasUnknownSelector = true;
            // delegatecall cannot appear as a direct selector here; Treasury
            // never delegatecalls. Off-chain tooling can add target heuristics.
            targets[i];
        }
    }

    function isClean(ScanResult memory r) internal pure returns (bool) {
        return !r.malformed && !r.hasDelegatecall && !r.hasOwnershipChange && !r.hasRoleChange
            && !r.hasUpgrade && !r.hasApproval && !r.hasUnknownSelector && !r.hasEmptyCalldataDrain;
    }
}
