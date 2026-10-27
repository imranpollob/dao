// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title Grant registry with milestone lifecycle and commitment accounting
/// @notice Owned by the timelock. Value-moving changes happen only via
/// proposals; reads stay off-chain. Tracks committed vs paid per token so
/// the treasury runway view is exact.
contract GrantRegistry is Ownable {
    enum GrantType {
        Immediate,
        Milestone,
        Vesting
    }
    enum Status {
        Active,
        Submitted,
        Approved,
        Paid,
        Completed,
        Rejected,
        Cancelled,
        Revoked
    }

    struct Milestone {
        uint256 amount;
        uint64 dueDate;
        string evidenceURI;
        Status status;
        uint64 approvedAt;
        uint64 paidAt;
    }

    struct Grant {
        address recipient;
        address token; // address(0) = ETH
        uint256 total;
        uint256 paid;
        GrantType grantType;
        Status status;
        uint256 proposalId;
        address vesting;
        address reviewer;
        string metadataURI;
    }

    uint256 public nextGrantId = 1;
    mapping(uint256 => Grant) private _grants;
    mapping(uint256 => Milestone[]) private _milestones;
    // token (address(0) = ETH) => committed (total - paid over open grants)
    mapping(address => uint256) public committed;

    event GrantCreated(
        uint256 indexed grantId,
        address indexed recipient,
        address token,
        uint256 total,
        GrantType grantType
    );
    event EvidenceSubmitted(uint256 indexed grantId, uint256 milestoneIdx, string evidenceURI);
    event MilestoneApproved(uint256 indexed grantId, uint256 milestoneIdx);
    event PayoutRecorded(
        uint256 indexed grantId, uint256 milestoneIdx, uint256 amount, uint256 paidTotal
    );
    event GrantCancelled(uint256 indexed grantId, string reason);
    event GrantRevoked(uint256 indexed grantId, string reason);
    event GrantCompleted(uint256 indexed grantId);

    error OnlyReviewer();
    error OnlyRecipient();
    error BadState();
    error AmountMismatch();

    constructor(address timelock) Ownable(timelock) {}

    function grants(uint256 grantId) external view returns (Grant memory) {
        return _grants[grantId];
    }

    function milestones(uint256 grantId) external view returns (Milestone[] memory) {
        return _milestones[grantId];
    }

    function milestoneCount(uint256 grantId) external view returns (uint256) {
        return _milestones[grantId].length;
    }

    function availableFor(address token, uint256 balance) external view returns (uint256) {
        uint256 c = committed[token];
        return balance > c ? balance - c : 0;
    }

    struct CreateGrantParams {
        address recipient;
        address token;
        uint256 total;
        GrantType grantType;
        uint256 proposalId;
        address vesting;
        address reviewer;
    }

    function createGrant(
        CreateGrantParams calldata p,
        string calldata metadataURI,
        uint256[] calldata milestoneAmounts,
        uint64[] calldata milestoneDueDates
    ) external onlyOwner returns (uint256 grantId) {
        require(p.recipient != address(0), "recipient=0");
        require(p.total > 0, "total=0");
        require(milestoneAmounts.length == milestoneDueDates.length, "milestone len");
        if (p.grantType == GrantType.Milestone) {
            require(milestoneAmounts.length > 0, "no milestones");
            uint256 sum = 0;
            for (uint256 i = 0; i < milestoneAmounts.length; i++) {
                sum += milestoneAmounts[i];
            }
            if (sum != p.total) revert AmountMismatch();
        }
        grantId = nextGrantId++;
        Grant storage g = _grants[grantId];
        g.recipient = p.recipient;
        g.token = p.token;
        g.total = p.total;
        g.grantType = p.grantType;
        g.status = Status.Active;
        g.proposalId = p.proposalId;
        g.vesting = p.vesting;
        g.reviewer = p.reviewer;
        g.metadataURI = metadataURI;
        _addMilestones(grantId, milestoneAmounts, milestoneDueDates);
        committed[p.token] += p.total;
        emit GrantCreated(grantId, p.recipient, p.token, p.total, p.grantType);
    }

    function _addMilestones(uint256 grantId, uint256[] calldata amounts, uint64[] calldata dueDates)
        internal
    {
        for (uint256 i = 0; i < amounts.length; i++) {
            _milestones[grantId].push(
                Milestone({
                    amount: amounts[i],
                    dueDate: dueDates[i],
                    evidenceURI: "",
                    status: Status.Active,
                    approvedAt: 0,
                    paidAt: 0
                })
            );
        }
    }

    function submitEvidence(uint256 grantId, uint256 milestoneIdx, string calldata evidenceURI)
        external
    {
        Grant storage g = _grants[grantId];
        if (msg.sender != g.recipient) revert OnlyRecipient();
        Milestone storage m = _milestones[grantId][milestoneIdx];
        if (m.status != Status.Active) revert BadState();
        m.evidenceURI = evidenceURI;
        m.status = Status.Submitted;
        emit EvidenceSubmitted(grantId, milestoneIdx, evidenceURI);
    }

    function approveMilestone(uint256 grantId, uint256 milestoneIdx) external {
        Grant storage g = _grants[grantId];
        if (msg.sender != g.reviewer && msg.sender != owner()) revert OnlyReviewer();
        Milestone storage m = _milestones[grantId][milestoneIdx];
        if (m.status != Status.Submitted) revert BadState();
        m.status = Status.Approved;
        m.approvedAt = uint64(block.timestamp);
        emit MilestoneApproved(grantId, milestoneIdx);
    }

    /// @notice Record a payout performed by Treasury in the same proposal batch.
    function recordPayout(uint256 grantId, uint256 milestoneIdx, uint256 amount)
        external
        onlyOwner
    {
        Grant storage g = _grants[grantId];
        if (g.status == Status.Cancelled || g.status == Status.Revoked) revert BadState();
        if (g.grantType == GrantType.Milestone) {
            Milestone storage m = _milestones[grantId][milestoneIdx];
            if (m.status != Status.Approved) revert BadState();
            if (m.amount != amount) revert AmountMismatch();
            m.status = Status.Paid;
            m.paidAt = uint64(block.timestamp);
        } else {
            if (g.paid + amount > g.total) revert AmountMismatch();
        }
        g.paid += amount;
        committed[g.token] -= amount;
        if (g.paid == g.total) {
            g.status = Status.Completed;
            emit GrantCompleted(grantId);
        } else {
            g.status = Status.Paid;
        }
        emit PayoutRecorded(grantId, milestoneIdx, amount, g.paid);
    }

    function cancelGrant(uint256 grantId, string calldata reason) external onlyOwner {
        Grant storage g = _grants[grantId];
        if (g.status == Status.Completed || g.status == Status.Cancelled) revert BadState();
        uint256 remaining = g.total - g.paid;
        committed[g.token] -= remaining;
        g.status = Status.Cancelled;
        emit GrantCancelled(grantId, reason);
    }

    function revokeGrant(uint256 grantId, string calldata reason) external onlyOwner {
        Grant storage g = _grants[grantId];
        if (g.status == Status.Completed || g.status == Status.Revoked) revert BadState();
        uint256 remaining = g.total - g.paid;
        committed[g.token] -= remaining;
        g.status = Status.Revoked;
        emit GrantRevoked(grantId, reason);
    }
}
