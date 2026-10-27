// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import {
    GovernorCountingSimple
} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorStorage} from "@openzeppelin/contracts/governance/extensions/GovernorStorage.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {
    GovernorVotesQuorumFraction
} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {
    GovernorTimelockControl
} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/// @title Grant DAO Governor
/// @notice OZ Governor wired with Votes, QuorumFraction, Settings, and Timelock
contract GrantGovernor is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorStorage,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl
{
    /// @param token    Governance token (ERC20Votes)
    /// @param timelock Deployed TimelockController
    /// @param proposalThresholdTokens absolute amount required to propose (not %)
    /// @param votingDelayBlocks       delay after proposal creation before voting starts
    /// @param votingPeriodBlocks      duration voting stays open
    /// @param quorumPercent           e.g., 4 = 4%
    /// @param guardian_               emergency veto address; required
    constructor(
        IVotes token,
        TimelockController timelock,
        uint256 proposalThresholdTokens,
        uint256 votingDelayBlocks,
        uint256 votingPeriodBlocks,
        uint256 quorumPercent,
        address guardian_
    )
        Governor("GrantGovernor")
        GovernorSettings(
            uint48(votingDelayBlocks), // votingDelay
            uint32(votingPeriodBlocks), // votingPeriod
            proposalThresholdTokens // proposalThreshold (absolute)
        )
        GovernorVotes(token)
        GovernorVotesQuorumFraction(quorumPercent)
        GovernorTimelockControl(timelock)
    {
        if (guardian_ == address(0)) {
            revert ZeroAddress();
        }
        _guardian = guardian_;
    }

    address private _guardian;

    error ZeroAddress();
    event GuardianUpdated(address indexed oldGuardian, address indexed newGuardian);

    function guardian() external view returns (address) {
        return _guardian;
    }

    /// @notice Rotate the guardian through governance.
    function setGuardian(address next) external onlyGovernance {
        if (next == address(0)) revert ZeroAddress();
        address old = _guardian;
        _guardian = next;
        emit GuardianUpdated(old, next);
    }

    // -------- Required overrides because of multiple inheritance --------
    function votingDelay() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingDelay();
    }

    function votingPeriod() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingPeriod();
    }

    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    function state(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        override(Governor, GovernorTimelockControl)
        returns (address)
    {
        return super._executor();
    }

    function _propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        address proposer
    ) internal override(Governor, GovernorStorage) returns (uint256) {
        return super._propose(targets, values, calldatas, description, proposer);
    }

    function proposalNeedsQueuing(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (bool)
    {
        return super.proposalNeedsQueuing(proposalId);
    }

    /// @dev Guardian can veto Pending, Active, Succeeded, or Queued proposals.
    /// Queued vetoes require this Governor to hold the Timelock CANCELLER_ROLE.
    function _validateCancel(uint256 proposalId, address caller)
        internal
        view
        override
        returns (bool)
    {
        if (_guardian != address(0) && caller == _guardian) {
            ProposalState s = state(proposalId);
            return s == ProposalState.Pending || s == ProposalState.Active
                || s == ProposalState.Succeeded || s == ProposalState.Queued;
        }
        return super._validateCancel(proposalId, caller);
    }

    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        return
            uint48(super._queueOperations(proposalId, targets, values, calldatas, descriptionHash));
    }

    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }
}
