// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {GrantRegistry} from "./GrantRegistry.sol";

interface IVestingFundable {
    function fund() external payable;
    function fundERC20(address token, uint256 amount) external;
}

interface IVestingRevocable {
    function beneficiary() external view returns (address);
    function admin() external view returns (address);
    function treasury() external view returns (address);
    function revoke() external;
    function revokeERC20(address token) external;
}

/// @title Treasury vault controlled exclusively by Timelock
/// @notice Every grant value movement is validated against GrantRegistry and
/// recorded atomically. There is no arbitrary `execute` or ERC20 recovery path
/// in the grant surface. Caps are stored policy, not caller-supplied values.
contract Treasury is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct TokenPolicy {
        uint256 perCall;
        uint256 daily;
        uint256 perProposal;
        bool set;
    }

    GrantRegistry public immutable registry;

    event FundsReceived(address indexed from, uint256 amount);
    event GrantPaidETH(
        uint256 indexed grantId, uint256 milestoneId, address indexed to, uint256 amount
    );
    event GrantPaidERC20(
        uint256 indexed grantId,
        uint256 milestoneId,
        address indexed token,
        address indexed to,
        uint256 amount
    );
    event VestingFunded(uint256 indexed grantId, address indexed vesting, uint256 amount);
    event VestingFundedERC20(
        uint256 indexed grantId, address indexed token, address indexed vesting, uint256 amount
    );
    event VestingRevoked(uint256 indexed grantId, address indexed vesting, string reason);
    event GrantCancelled(uint256 indexed grantId, string reason);
    event DepositedERC20(address indexed token, address indexed from, uint256 amount);
    event CapsUpdated(
        uint256 ethPerCall, uint256 ethDaily, uint256 erc20PerCall, uint256 erc20Daily
    );
    event ProposalCapsUpdated(uint256 ethPerProposal, uint256 erc20PerProposal);
    event TokenPolicyUpdated(
        address indexed token, uint256 perCall, uint256 daily, uint256 perProposal
    );
    event TreasuryFloorUpdated(uint256 floorWei);
    event TokenAllowlistUpdated(address indexed token, bool allowed);
    event EnforceAllowlistUpdated(bool enforced);
    event PauserUpdated(address indexed oldPauser, address indexed newPauser);
    event MaxPauseDurationUpdated(uint64 maxPauseDuration);
    event Paused(address indexed by, uint64 expiresAt);
    event Unpaused(address indexed by);

    error PausedOutflows();
    error PauseAlreadyActive();
    error NotPauser();
    error ZeroAddress();
    error ZeroAmount();
    error CapExceeded();
    error DailyCapExceeded();
    error FloorViolated();
    error TokenNotAllowed();
    error FeeOnTransfer();
    error UnknownGrant();
    error BadGrantType();
    error BadGrantState();
    error AmountExceedsGrant();
    error MustRevokeVesting();
    error VestingAdminMismatch();
    error VestingTreasuryMismatch();
    error VestingBeneficiaryMismatch();

    uint256 public ethPerCallCap;
    uint256 public ethDailyCap;
    uint256 public ethPerProposalCap;
    uint256 public erc20PerCallCap;
    uint256 public erc20DailyCap;
    uint256 public erc20PerProposalCap;
    uint256 public treasuryFloor;
    mapping(address => TokenPolicy) public tokenPolicies;
    mapping(address => bool) public isTokenAllowed;
    bool public enforceAllowlist = true;
    // day => token (address(0) = ETH) => spent
    mapping(uint256 => mapping(address => uint256)) public spentToday;

    address public pauser;
    uint64 public pauseExpiresAt;
    uint64 public maxPauseDuration = 7 days;

    constructor(address timelock, GrantRegistry registry_) Ownable(timelock) {
        // Ownable also rejects a zero owner; this makes the intent explicit.
        if (timelock == address(0)) revert ZeroAddress();
        if (address(registry_) == address(0)) revert ZeroAddress();
        registry = registry_;
        pauser = timelock;
    }

    receive() external payable {
        emit FundsReceived(msg.sender, msg.value);
    }

    function paused() public view returns (bool) {
        return block.timestamp < uint256(pauseExpiresAt);
    }

    modifier whenOutflowsAllowed() {
        if (paused()) revert PausedOutflows();
        _;
    }

    // ---- pause ----

    function pause(uint64 durationSeconds) external {
        if (msg.sender != pauser && msg.sender != owner()) revert NotPauser();
        // Only governance may extend an active pause. The guardian must wait
        // for expiry before starting another bounded pause; persistent
        // re-pausing is a documented liveness residual, not a fund-loss path.
        if (paused() && msg.sender != owner()) revert PauseAlreadyActive();
        require(durationSeconds > 0 && durationSeconds <= maxPauseDuration, "bad duration");
        pauseExpiresAt = uint64(block.timestamp) + durationSeconds;
        emit Paused(msg.sender, pauseExpiresAt);
    }

    function unpause() external onlyOwner {
        pauseExpiresAt = 0;
        emit Unpaused(msg.sender);
    }

    function setPauser(address next) external onlyOwner {
        if (next == address(0)) revert ZeroAddress();
        address old = pauser;
        pauser = next;
        emit PauserUpdated(old, next);
    }

    function setMaxPauseDuration(uint64 next) external onlyOwner {
        require(next > 0, "duration=0");
        maxPauseDuration = next;
        emit MaxPauseDurationUpdated(next);
    }

    // ---- policy setters (timelock only) ----

    function setCaps(
        uint256 _ethPerCall,
        uint256 _ethDaily,
        uint256 _erc20PerCall,
        uint256 _erc20Daily
    ) external onlyOwner {
        ethPerCallCap = _ethPerCall;
        ethDailyCap = _ethDaily;
        erc20PerCallCap = _erc20PerCall;
        erc20DailyCap = _erc20Daily;
        // Safe default: a single transaction cannot exceed the daily policy.
        // Governance can tighten these with setProposalCaps.
        ethPerProposalCap = _ethDaily;
        erc20PerProposalCap = _erc20Daily;
        emit CapsUpdated(_ethPerCall, _ethDaily, _erc20PerCall, _erc20Daily);
        emit ProposalCapsUpdated(ethPerProposalCap, erc20PerProposalCap);
    }

    function setProposalCaps(uint256 _ethPerProposal, uint256 _erc20PerProposal)
        external
        onlyOwner
    {
        ethPerProposalCap = _ethPerProposal;
        erc20PerProposalCap = _erc20PerProposal;
        emit ProposalCapsUpdated(_ethPerProposal, _erc20PerProposal);
    }

    function setTokenPolicy(address token, uint256 perCall, uint256 daily, uint256 perProposal)
        external
        onlyOwner
    {
        if (token == address(0)) revert ZeroAddress();
        tokenPolicies[token] =
            TokenPolicy({perCall: perCall, daily: daily, perProposal: perProposal, set: true});
        emit TokenPolicyUpdated(token, perCall, daily, perProposal);
    }

    function setTreasuryFloor(uint256 floorWei) external onlyOwner {
        treasuryFloor = floorWei;
        emit TreasuryFloorUpdated(floorWei);
    }

    function setTokenAllowed(address token, bool allowed) external onlyOwner {
        isTokenAllowed[token] = allowed;
        emit TokenAllowlistUpdated(token, allowed);
    }

    function setEnforceAllowlist(bool enforced) external onlyOwner {
        enforceAllowlist = enforced;
        emit EnforceAllowlistUpdated(enforced);
    }

    // ---- deposits (never paused) ----

    function depositERC20(address token, uint256 amount) external nonReentrant returns (uint256) {
        if (amount == 0) revert ZeroAmount();
        uint256 before = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        uint256 received = IERC20(token).balanceOf(address(this)) - before;
        if (received != amount) revert FeeOnTransfer();
        emit DepositedERC20(token, msg.sender, amount);
        return received;
    }

    // ---- policy internals ----

    function _policy(address token)
        internal
        view
        returns (uint256 perCall, uint256 daily, uint256 proposalCap)
    {
        if (token == address(0)) {
            return (ethPerCallCap, ethDailyCap, ethPerProposalCap);
        }
        TokenPolicy storage p = tokenPolicies[token];
        if (p.set) {
            return (p.perCall, p.daily, p.perProposal);
        }
        return (erc20PerCallCap, erc20DailyCap, erc20PerProposalCap);
    }

    function _chargeSpend(address token, uint256 amount, uint256 perCallCap, uint256 dailyCap)
        internal
    {
        if (amount == 0) revert ZeroAmount();
        if (amount > perCallCap) revert CapExceeded();
        uint256 day = block.timestamp / 1 days;
        uint256 spent = spentToday[day][token] + amount;
        if (spent > dailyCap) revert DailyCapExceeded();
        spentToday[day][token] = spent;
    }

    function _chargeAndCheckProposal(address token, uint256 amount) internal {
        (uint256 perCall, uint256 daily, uint256 proposalCap) = _policy(token);
        if (amount > proposalCap) revert CapExceeded();
        _chargeSpend(token, amount, perCall, daily);
    }

    function _grant(uint256 grantId) internal view returns (GrantRegistry.Grant memory g) {
        g = registry.grants(grantId);
        if (g.recipient == address(0)) revert UnknownGrant();
    }

    function _validateMilestone(uint256 grantId, uint256 milestoneId)
        internal
        view
        returns (GrantRegistry.Grant memory g, GrantRegistry.Milestone memory m)
    {
        g = _grant(grantId);
        if (g.grantType != GrantRegistry.GrantType.Milestone) revert BadGrantType();
        if (g.status != GrantRegistry.GrantStatus.Active) revert BadGrantState();
        m = registry.milestone(grantId, milestoneId);
        if (m.status != GrantRegistry.MilestoneStatus.Approved) revert BadGrantState();
    }

    function _validateVestingAdmin(address vesting) internal view {
        IVestingRevocable v = IVestingRevocable(vesting);
        if (v.admin() != address(this)) revert VestingAdminMismatch();
        if (v.treasury() != address(this)) revert VestingTreasuryMismatch();
    }

    function _validateVestingBeneficiary(address vesting, address recipient) internal view {
        if (IVestingRevocable(vesting).beneficiary() != recipient) {
            revert VestingBeneficiaryMismatch();
        }
    }

    // ---- grant payouts ----

    /// @notice Pay an Immediate grant. Amount is bounded by the grant remainder.
    function payGrant(uint256 grantId, uint256 amount)
        external
        nonReentrant
        onlyOwner
        whenOutflowsAllowed
    {
        GrantRegistry.Grant memory g = _grant(grantId);
        if (g.grantType != GrantRegistry.GrantType.Immediate) revert BadGrantType();
        if (g.status != GrantRegistry.GrantStatus.Active) revert BadGrantState();
        if (amount > g.total - g.paid - g.funded) revert AmountExceedsGrant();
        _pay(grantId, 0, g, amount);
    }

    /// @notice Pay one approved milestone. The amount comes from the registry.
    function payMilestone(uint256 grantId, uint256 milestoneId)
        external
        nonReentrant
        onlyOwner
        whenOutflowsAllowed
    {
        (GrantRegistry.Grant memory g, GrantRegistry.Milestone memory m) =
            _validateMilestone(grantId, milestoneId);
        _pay(grantId, milestoneId, g, m.amount);
    }

    /// @notice Pay multiple approved ETH milestones atomically.
    /// @dev All amounts are validated and charged before any external call.
    function payMilestoneBatch(uint256[] calldata grantIds, uint256[] calldata milestoneIds)
        external
        nonReentrant
        onlyOwner
        whenOutflowsAllowed
    {
        require(grantIds.length == milestoneIds.length, "length mismatch");
        require(grantIds.length > 0, "empty batch");

        uint256 total = 0;
        for (uint256 i = 0; i < grantIds.length; i++) {
            (GrantRegistry.Grant memory g, GrantRegistry.Milestone memory m) =
                _validateMilestone(grantIds[i], milestoneIds[i]);
            if (g.token != address(0)) revert BadGrantType();
            if (m.amount == 0) revert ZeroAmount();
            if (m.amount > ethPerCallCap) revert CapExceeded();
            total += m.amount;
        }
        if (total > ethPerProposalCap) revert CapExceeded();
        uint256 day = block.timestamp / 1 days;
        if (spentToday[day][address(0)] + total > ethDailyCap) revert DailyCapExceeded();
        spentToday[day][address(0)] += total;
        if (total > address(this).balance) revert FloorViolated();
        if (address(this).balance - total < treasuryFloor) revert FloorViolated();

        for (uint256 i = 0; i < grantIds.length; i++) {
            GrantRegistry.Grant memory g = registry.grants(grantIds[i]);
            GrantRegistry.Milestone memory m = registry.milestone(grantIds[i], milestoneIds[i]);
            registry.recordPayout(grantIds[i], milestoneIds[i], m.amount);
            (bool ok,) = payable(g.recipient).call{value: m.amount}("");
            require(ok, "Treasury: batch eth failed");
            emit GrantPaidETH(grantIds[i], milestoneIds[i], g.recipient, m.amount);
        }
    }

    function _pay(
        uint256 grantId,
        uint256 milestoneId,
        GrantRegistry.Grant memory g,
        uint256 amount
    ) internal {
        if (amount == 0) revert ZeroAmount();
        _chargeAndCheckProposal(g.token, amount);

        if (g.token == address(0)) {
            if (amount > address(this).balance) revert FloorViolated();
            if (address(this).balance - amount < treasuryFloor) revert FloorViolated();
            registry.recordPayout(grantId, milestoneId, amount);
            (bool ok,) = payable(g.recipient).call{value: amount}("");
            require(ok, "Treasury: eth send failed");
            emit GrantPaidETH(grantId, milestoneId, g.recipient, amount);
        } else {
            if (!isTokenAllowed[g.token] && enforceAllowlist) revert TokenNotAllowed();
            registry.recordPayout(grantId, milestoneId, amount);
            uint256 before = IERC20(g.token).balanceOf(address(this));
            uint256 recipientBefore = IERC20(g.token).balanceOf(g.recipient);
            IERC20(g.token).safeTransfer(g.recipient, amount);
            uint256 spent = before - IERC20(g.token).balanceOf(address(this));
            uint256 received = IERC20(g.token).balanceOf(g.recipient) - recipientBefore;
            if (spent != amount || received != amount) revert FeeOnTransfer();
            emit GrantPaidERC20(grantId, milestoneId, g.token, g.recipient, amount);
        }
    }

    // ---- vesting ----

    function fundVesting(uint256 grantId, uint256 amount)
        external
        nonReentrant
        onlyOwner
        whenOutflowsAllowed
    {
        GrantRegistry.Grant memory g = _grant(grantId);
        if (g.grantType != GrantRegistry.GrantType.Vesting) revert BadGrantType();
        if (g.status != GrantRegistry.GrantStatus.Active) revert BadGrantState();
        if (g.token != address(0)) revert BadGrantType();
        _validateVestingAdmin(g.vesting);
        _validateVestingBeneficiary(g.vesting, g.recipient);
        if (amount > g.total - g.paid - g.funded) revert AmountExceedsGrant();
        _chargeAndCheckProposal(address(0), amount);
        if (amount > address(this).balance) revert FloorViolated();
        if (address(this).balance - amount < treasuryFloor) revert FloorViolated();

        registry.recordVestingFunding(grantId, amount);
        IVestingFundable(g.vesting).fund{value: amount}();
        emit VestingFunded(grantId, g.vesting, amount);
    }

    function fundVestingERC20(uint256 grantId, uint256 amount)
        external
        nonReentrant
        onlyOwner
        whenOutflowsAllowed
    {
        GrantRegistry.Grant memory g = _grant(grantId);
        if (g.grantType != GrantRegistry.GrantType.Vesting) revert BadGrantType();
        if (g.status != GrantRegistry.GrantStatus.Active) revert BadGrantState();
        if (g.token == address(0)) revert BadGrantType();
        if (!isTokenAllowed[g.token] && enforceAllowlist) revert TokenNotAllowed();
        _validateVestingAdmin(g.vesting);
        _validateVestingBeneficiary(g.vesting, g.recipient);
        if (amount > g.total - g.paid - g.funded) revert AmountExceedsGrant();
        _chargeAndCheckProposal(g.token, amount);

        registry.recordVestingFunding(grantId, amount);
        IERC20(g.token).forceApprove(g.vesting, amount);
        IVestingFundable(g.vesting).fundERC20(g.token, amount);
        IERC20(g.token).forceApprove(g.vesting, 0);
        emit VestingFundedERC20(grantId, g.token, g.vesting, amount);
    }

    /// @notice Revoke a vesting grant. Unvested funds return to this Treasury.
    function revokeVesting(uint256 grantId, string calldata reason)
        external
        nonReentrant
        onlyOwner
    {
        GrantRegistry.Grant memory g = _grant(grantId);
        if (g.grantType != GrantRegistry.GrantType.Vesting) revert BadGrantType();
        if (g.status != GrantRegistry.GrantStatus.Active) revert BadGrantState();
        // The vesting admin must be this Treasury so governance can revoke
        // through the same value-moving path and registry accounting stays atomic.
        _validateVestingAdmin(g.vesting);
        if (g.token == address(0)) {
            IVestingRevocable(g.vesting).revoke();
        } else {
            IVestingRevocable(g.vesting).revokeERC20(g.token);
        }
        registry.revokeGrant(grantId, reason);
        emit VestingRevoked(grantId, g.vesting, reason);
    }

    /// @notice Cancel an unfunded Immediate or Milestone grant.
    function cancelGrant(uint256 grantId, string calldata reason) external onlyOwner {
        GrantRegistry.Grant memory g = _grant(grantId);
        if (g.grantType == GrantRegistry.GrantType.Vesting && g.funded > 0) {
            revert MustRevokeVesting();
        }
        registry.cancelGrant(grantId, reason);
        emit GrantCancelled(grantId, reason);
    }
}
