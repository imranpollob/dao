// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title Grant registry with milestone lifecycle and commitment accounting
/// @notice Owned by the timelock for grant creation. Only the Treasury may
/// record payouts, vesting funding, cancellation, or revocation. This makes
/// the Treasury the single value-moving path and keeps committed/paid exact.
contract GrantRegistry is Ownable {
    enum GrantType {
        Immediate,
        Milestone,
        Vesting
    }

    enum GrantStatus {
        Active,
        Completed,
        Cancelled,
        Revoked
    }

    enum MilestoneStatus {
        Pending,
        Submitted,
        Approved,
        Paid,
        Rejected
    }

    struct Milestone {
        uint256 amount;
        uint64 dueDate;
        string evidenceURI;
        MilestoneStatus status;
        uint64 approvedAt;
        uint64 paidAt;
    }

    struct Grant {
        address recipient;
        address token; // address(0) = ETH
        uint256 total;
        uint256 paid; // direct payouts
        uint256 funded; // amount moved into a vesting wallet
        GrantType grantType;
        GrantStatus status;
        uint256 proposalId;
        address vesting;
        address reviewer; // advisory metadata only; approval is governance-only
        string metadataURI;
    }

    uint256 public nextGrantId = 1;
    address public treasury;
    mapping(uint256 => Grant) private _grants;
    mapping(uint256 => Milestone[]) private _milestones;
    // token (address(0) = ETH) => committed Treasury balance
    mapping(address => uint256) public committed;

    event TreasuryUpdated(address indexed treasury);
    event GrantCreated(
        uint256 indexed grantId,
        address indexed recipient,
        address token,
        uint256 total,
        GrantType grantType
    );
    event EvidenceSubmitted(uint256 indexed grantId, uint256 milestoneIdx, string evidenceURI);
    event MilestoneApproved(uint256 indexed grantId, uint256 milestoneIdx);
    event MilestoneRejected(uint256 indexed grantId, uint256 milestoneIdx, string reason);
    event PayoutRecorded(
        uint256 indexed grantId, uint256 milestoneIdx, uint256 amount, uint256 paidTotal
    );
    event VestingFundingRecorded(uint256 indexed grantId, uint256 amount, uint256 fundedTotal);
    event GrantFullyFunded(uint256 indexed grantId);
    event GrantCancelled(uint256 indexed grantId, string reason);
    event GrantRevoked(uint256 indexed grantId, string reason);
    event GrantCompleted(uint256 indexed grantId);

    error OnlyTreasury();
    error TreasuryAlreadySet();
    error ZeroAddress();
    error BadState();
    error AmountMismatch();
    error InvalidVesting();

    constructor(address timelock) Ownable(timelock) {}

    modifier onlyTreasury() {
        if (msg.sender != treasury) revert OnlyTreasury();
        _;
    }

    function setTreasury(address next) external onlyOwner {
        if (treasury != address(0)) revert TreasuryAlreadySet();
        if (next == address(0)) revert ZeroAddress();
        treasury = next;
        emit TreasuryUpdated(next);
    }

    function grants(uint256 grantId) external view returns (Grant memory) {
        return _grants[grantId];
    }

    function milestones(uint256 grantId) external view returns (Milestone[] memory) {
        return _milestones[grantId];
    }

    function milestone(uint256 grantId, uint256 milestoneIdx)
        external
        view
        returns (Milestone memory)
    {
        return _milestones[grantId][milestoneIdx];
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
            require(p.vesting == address(0), "vesting for milestone");
            uint256 sum = 0;
            for (uint256 i = 0; i < milestoneAmounts.length; i++) {
                if (milestoneAmounts[i] == 0) revert AmountMismatch();
                sum += milestoneAmounts[i];
            }
            if (sum != p.total) revert AmountMismatch();
        } else {
            require(milestoneAmounts.length == 0, "milestones for non-milestone");
            if (p.grantType == GrantType.Vesting) {
                if (p.vesting == address(0) || p.vesting.code.length == 0) revert InvalidVesting();
            } else {
                require(p.vesting == address(0), "vesting for immediate");
            }
        }

        grantId = nextGrantId++;
        Grant storage g = _grants[grantId];
        g.recipient = p.recipient;
        g.token = p.token;
        g.total = p.total;
        g.grantType = p.grantType;
        g.status = GrantStatus.Active;
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
                    status: MilestoneStatus.Pending,
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
        if (msg.sender != g.recipient) revert BadState();
        if (g.grantType != GrantType.Milestone || g.status != GrantStatus.Active) {
            revert BadState();
        }
        Milestone storage m = _milestones[grantId][milestoneIdx];
        if (m.status != MilestoneStatus.Pending && m.status != MilestoneStatus.Rejected) {
            revert BadState();
        }
        m.evidenceURI = evidenceURI;
        m.status = MilestoneStatus.Submitted;
        emit EvidenceSubmitted(grantId, milestoneIdx, evidenceURI);
    }

    /// @notice Governance-only approval. `reviewer` is advisory metadata.
    function approveMilestone(uint256 grantId, uint256 milestoneIdx) external onlyOwner {
        Grant storage g = _grants[grantId];
        if (g.grantType != GrantType.Milestone || g.status != GrantStatus.Active) {
            revert BadState();
        }
        Milestone storage m = _milestones[grantId][milestoneIdx];
        if (m.status != MilestoneStatus.Submitted) revert BadState();
        m.status = MilestoneStatus.Approved;
        m.approvedAt = uint64(block.timestamp);
        emit MilestoneApproved(grantId, milestoneIdx);
    }

    function rejectMilestone(uint256 grantId, uint256 milestoneIdx, string calldata reason)
        external
        onlyOwner
    {
        Grant storage g = _grants[grantId];
        if (g.grantType != GrantType.Milestone || g.status != GrantStatus.Active) {
            revert BadState();
        }
        Milestone storage m = _milestones[grantId][milestoneIdx];
        if (m.status != MilestoneStatus.Submitted) revert BadState();
        m.status = MilestoneStatus.Rejected;
        emit MilestoneRejected(grantId, milestoneIdx, reason);
    }

    /// @notice Record a direct payout performed by Treasury.
    function recordPayout(uint256 grantId, uint256 milestoneIdx, uint256 amount)
        external
        onlyTreasury
    {
        Grant storage g = _grants[grantId];
        if (g.status != GrantStatus.Active) revert BadState();
        if (g.grantType == GrantType.Vesting) revert BadState();

        if (g.grantType == GrantType.Milestone) {
            Milestone storage m = _milestones[grantId][milestoneIdx];
            if (m.status != MilestoneStatus.Approved) revert BadState();
            if (m.amount != amount) revert AmountMismatch();
            m.status = MilestoneStatus.Paid;
            m.paidAt = uint64(block.timestamp);
        } else {
            if (milestoneIdx != 0) revert BadState();
            if (amount > g.total - g.paid - g.funded) revert AmountMismatch();
        }

        if (committed[g.token] < amount) revert AmountMismatch();
        g.paid += amount;
        committed[g.token] -= amount;
        if (g.paid + g.funded == g.total) {
            g.status = GrantStatus.Completed;
            emit GrantCompleted(grantId);
        }
        emit PayoutRecorded(grantId, milestoneIdx, amount, g.paid);
    }

    /// @notice Record funds moved from Treasury into the grant's vesting wallet.
    function recordVestingFunding(uint256 grantId, uint256 amount) external onlyTreasury {
        Grant storage g = _grants[grantId];
        if (g.status != GrantStatus.Active || g.grantType != GrantType.Vesting) revert BadState();
        if (amount > g.total - g.paid - g.funded) revert AmountMismatch();
        if (committed[g.token] < amount) revert AmountMismatch();
        g.funded += amount;
        committed[g.token] -= amount;
        emit VestingFundingRecorded(grantId, amount, g.funded);
        if (g.funded == g.total) emit GrantFullyFunded(grantId);
    }

    /// @notice Cancel an unfunded grant. Funded vesting must be revoked first.
    function cancelGrant(uint256 grantId, string calldata reason) external onlyTreasury {
        Grant storage g = _grants[grantId];
        if (g.status != GrantStatus.Active) revert BadState();
        if (g.grantType == GrantType.Vesting && g.funded > 0) revert BadState();
        uint256 remaining = g.total - g.paid - g.funded;
        if (committed[g.token] < remaining) revert AmountMismatch();
        committed[g.token] -= remaining;
        g.status = GrantStatus.Cancelled;
        _rejectOpenMilestones(grantId);
        emit GrantCancelled(grantId, reason);
    }

    /// @notice Revoke a vesting grant after its vesting wallet has been revoked.
    function revokeGrant(uint256 grantId, string calldata reason) external onlyTreasury {
        Grant storage g = _grants[grantId];
        if (g.status != GrantStatus.Active || g.grantType != GrantType.Vesting) revert BadState();
        uint256 remaining = g.total - g.paid - g.funded;
        if (committed[g.token] < remaining) revert AmountMismatch();
        committed[g.token] -= remaining;
        g.status = GrantStatus.Revoked;
        emit GrantRevoked(grantId, reason);
    }

    function _rejectOpenMilestones(uint256 grantId) internal {
        Milestone[] storage ms = _milestones[grantId];
        for (uint256 i = 0; i < ms.length; i++) {
            if (
                ms[i].status == MilestoneStatus.Pending || ms[i].status == MilestoneStatus.Submitted
            ) {
                ms[i].status = MilestoneStatus.Rejected;
            }
        }
    }
}
