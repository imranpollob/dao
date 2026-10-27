// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Proposal risk scanner (pure, off-chain friendly)
/// @notice Flags dangerous selectors and out-of-policy amounts without
/// imposing on-chain allowlist policy. Used by scripts and tests.
library ProposalRisk {
    bytes4 internal constant TRANSFER_OWNERSHIP = 0xf2fde38b;
    bytes4 internal constant GRANT_ROLE = 0x2f2ff15d;
    bytes4 internal constant REVOKE_ROLE = 0xd547741f;
    bytes4 internal constant UPGRADE_TO = 0x3659cfe6;
    bytes4 internal constant APPROVE = 0x095ea7b3;
    bytes4 internal constant SET_APPROVAL_ALL = 0xa22cb465;

    struct ScanResult {
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

    function scan(address[] memory targets, bytes[] memory calldatas, uint256[] memory values)
        internal
        pure
        returns (ScanResult memory r)
    {
        for (uint256 i = 0; i < calldatas.length; i++) {
            bytes memory data = calldatas[i];
            bytes4 sel = selectorOf(data);
            // Unknown low-level call with value to an EOA-like target: possible drain.
            if (data.length < 4 && values[i] > 0) r.hasEmptyCalldataDrain = true;
            if (sel == TRANSFER_OWNERSHIP) r.hasOwnershipChange = true;
            else if (sel == GRANT_ROLE || sel == REVOKE_ROLE) r.hasRoleChange = true;
            else if (sel == UPGRADE_TO) r.hasUpgrade = true;
            else if (sel == APPROVE || sel == SET_APPROVAL_ALL) r.hasApproval = true;
            // delegatecall cannot appear as a direct selector here; flag via target-calldata
            // heuristic in scripts. On-chain, Treasury never delegatecalls.
            targets;
        }
    }

    function isClean(ScanResult memory r) internal pure returns (bool) {
        return
            !r.hasOwnershipChange && !r.hasRoleChange && !r.hasUpgrade && !r.hasEmptyCalldataDrain;
    }
}
