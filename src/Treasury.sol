// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IVestingFundable {
    function fund() external payable;
    function fundERC20(address token, uint256 amount) external;
}

/// @title Treasury vault controlled exclusively by Timelock
/// @notice Typed grant payouts with caps, allowlist, and time-bounded pause.
/// Legacy `execute` is preserved for the allowlisted admin path; the grant
/// path must use `sendETH` / `sendERC20` / `fundVesting` so every payout
/// carries grant and milestone ids and enforces policy.
contract Treasury is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    event FundsReceived(address indexed from, uint256 amount);
    event Executed(address indexed target, uint256 value, bytes4 selector, bytes result);
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
    event DepositedERC20(address indexed token, address indexed from, uint256 amount);
    event RecoveredERC20(address indexed token, address indexed to, uint256 amount);
    event CapsUpdated(
        uint256 ethPerCall, uint256 ethDaily, uint256 erc20PerCall, uint256 erc20Daily
    );
    event TreasuryFloorUpdated(uint256 floorWei);
    event TokenAllowlistUpdated(address indexed token, bool allowed);
    event TargetAllowlistUpdated(address indexed target, bool allowed);
    event EnforceAllowlistUpdated(bool enforced);
    event PauserUpdated(address indexed oldPauser, address indexed newPauser);
    event Paused(address indexed by, uint64 expiresAt);
    event Unpaused(address indexed by);

    error PausedOutflows();
    error ZeroAddress();
    error ZeroAmount();
    error CapExceeded();
    error DailyCapExceeded();
    error FloorViolated();
    error TokenNotAllowed();
    error TargetNotAllowed();
    error FeeOnTransfer();

    uint256 public ethPerCallCap;
    uint256 public ethDailyCap;
    uint256 public erc20PerCallCap;
    uint256 public erc20DailyCap;
    uint256 public treasuryFloor;
    mapping(address => bool) public isTokenAllowed;
    mapping(address => bool) public isTargetAllowed;
    bool public enforceAllowlist;
    // day => token (address(0) = ETH) => spent
    mapping(uint256 => mapping(address => uint256)) public spentToday;

    address public pauser;
    uint64 public pauseExpiresAt;
    uint64 public maxPauseDuration = 7 days;

    constructor(address timelock) Ownable(timelock) {
        // Permissive defaults so existing flows keep working; production
        // deploy scripts tighten these to real values.
        ethPerCallCap = type(uint256).max;
        ethDailyCap = type(uint256).max;
        erc20PerCallCap = type(uint256).max;
        erc20DailyCap = type(uint256).max;
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
        require(msg.sender == pauser || msg.sender == owner(), "not pauser");
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
        emit PauserUpdated(pauser, next);
        pauser = next;
    }

    function setMaxPauseDuration(uint64 next) external onlyOwner {
        maxPauseDuration = next;
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
        emit CapsUpdated(_ethPerCall, _ethDaily, _erc20PerCall, _erc20Daily);
    }

    function setTreasuryFloor(uint256 floorWei) external onlyOwner {
        treasuryFloor = floorWei;
        emit TreasuryFloorUpdated(floorWei);
    }

    function setTokenAllowed(address token, bool allowed) external onlyOwner {
        isTokenAllowed[token] = allowed;
        emit TokenAllowlistUpdated(token, allowed);
    }

    function setTargetAllowed(address target, bool allowed) external onlyOwner {
        isTargetAllowed[target] = allowed;
        emit TargetAllowlistUpdated(target, allowed);
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

    // ---- typed payouts (grant path) ----

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

    function sendETH(address payable to, uint256 amount, uint256 grantId, uint256 milestoneId)
        external
        onlyOwner
        nonReentrant
        whenOutflowsAllowed
        returns (bytes memory)
    {
        if (to == address(0)) revert ZeroAddress();
        _chargeSpend(address(0), amount, ethPerCallCap, ethDailyCap);
        if (address(this).balance - amount < treasuryFloor) revert FloorViolated();
        (bool ok,) = to.call{value: amount}("");
        require(ok, "Treasury: eth send failed");
        emit GrantPaidETH(grantId, milestoneId, to, amount);
        return "";
    }

    function sendERC20(
        address token,
        address to,
        uint256 amount,
        uint256 grantId,
        uint256 milestoneId
    ) external onlyOwner nonReentrant whenOutflowsAllowed {
        if (to == address(0)) revert ZeroAddress();
        if (!isTokenAllowed[token] && enforceAllowlist) revert TokenNotAllowed();
        _chargeSpend(token, amount, erc20PerCallCap, erc20DailyCap);
        uint256 before = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(to, amount);
        // Treasury-side delta must be exact; recipient-side forwarding is out of scope.
        if (before - IERC20(token).balanceOf(address(this)) != amount) revert FeeOnTransfer();
        emit GrantPaidERC20(grantId, milestoneId, token, to, amount);
    }

    function batchSendETH(
        address payable[] calldata tos,
        uint256[] calldata amounts,
        uint256[] calldata grantIds,
        uint256[] calldata milestoneIds,
        uint256 perProposalCap
    ) external onlyOwner nonReentrant whenOutflowsAllowed {
        require(
            tos.length == amounts.length && tos.length == grantIds.length
                && tos.length == milestoneIds.length,
            "length mismatch"
        );
        uint256 total = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            if (tos[i] == address(0)) revert ZeroAddress();
            _chargeSpend(address(0), amounts[i], ethPerCallCap, ethDailyCap);
            total += amounts[i];
        }
        if (total > perProposalCap) revert CapExceeded();
        if (address(this).balance - total < treasuryFloor) revert FloorViolated();
        for (uint256 i = 0; i < tos.length; i++) {
            (bool ok,) = tos[i].call{value: amounts[i]}("");
            require(ok, "Treasury: batch eth failed");
            emit GrantPaidETH(grantIds[i], milestoneIds[i], tos[i], amounts[i]);
        }
    }

    function fundVesting(address payable vesting, uint256 amount, uint256 grantId)
        external
        onlyOwner
        nonReentrant
        whenOutflowsAllowed
    {
        if (vesting == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        _chargeSpend(address(0), amount, ethPerCallCap, ethDailyCap);
        if (address(this).balance - amount < treasuryFloor) revert FloorViolated();
        IVestingFundable(vesting).fund{value: amount}();
        emit VestingFunded(grantId, vesting, amount);
    }

    function fundVestingERC20(address token, address vesting, uint256 amount, uint256 grantId)
        external
        onlyOwner
        nonReentrant
        whenOutflowsAllowed
    {
        if (!isTokenAllowed[token] && enforceAllowlist) revert TokenNotAllowed();
        _chargeSpend(token, amount, erc20PerCallCap, erc20DailyCap);
        IERC20(token).forceApprove(vesting, amount);
        IVestingFundable(vesting).fundERC20(token, amount);
        emit VestingFundedERC20(grantId, token, vesting, amount);
    }

    function recoverERC20(address token, address to, uint256 amount)
        external
        onlyOwner
        nonReentrant
    {
        if (to == address(0)) revert ZeroAddress();
        IERC20(token).safeTransfer(to, amount);
        emit RecoveredERC20(token, to, amount);
    }

    /// @notice Execute an arbitrary call (only owner = Timelock)
    function execute(address target, uint256 value, bytes calldata data)
        external
        onlyOwner
        nonReentrant
        whenOutflowsAllowed
        returns (bytes memory)
    {
        if (enforceAllowlist && !isTargetAllowed[target]) revert TargetNotAllowed();
        (bool ok, bytes memory ret) = target.call{value: value}(data);
        require(ok, "Treasury: exec failed");
        bytes4 selector = data.length >= 4 ? bytes4(data[0:4]) : bytes4(0);
        emit Executed(target, value, selector, ret);
        return ret;
    }
}
