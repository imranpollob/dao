// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title Grant Vesting Wallet (revocable)
/// @notice Cliff + linear vesting with split beneficiary/admin roles.
/// Beneficiary cannot move the schedule. Admin (timelock) can revoke;
/// vested-but-unreleased funds stay releasable by the beneficiary and
/// unvested funds return to the admin. Funds must arrive via `fund()`
/// or `fundERC20()` so allocation accounting is exact.
contract GrantVestingRevocable is ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public immutable beneficiary;
    address public admin;
    uint64 public immutable start;
    uint64 public immutable duration;
    uint64 public immutable cliff;

    uint256 public fundedETH;
    uint256 public releasedETH;
    uint256 public revokedETH;
    mapping(address => uint256) public fundedERC20;
    mapping(address => uint256) public releasedERC20;
    mapping(address => uint256) public revokedERC20;
    bool public revoked;

    event Funded(address indexed from, uint256 amount);
    event FundedERC20(address indexed token, address indexed from, uint256 amount);
    event Released(uint256 amount);
    event ReleasedERC20(address indexed token, uint256 amount);
    event Revoked(uint256 ethReturned, uint256 timestamp);
    event AdminUpdated(address indexed oldAdmin, address indexed newAdmin);

    error OnlyAdmin();
    error AlreadyRevoked();
    error ZeroAmount();

    constructor(
        address _beneficiary,
        address _admin,
        uint64 _start,
        uint64 _duration,
        uint64 _cliff
    ) {
        require(_beneficiary != address(0) && _admin != address(0), "zero address");
        require(_duration > 0, "duration=0");
        require(_cliff <= _duration, "cliff>duration");
        beneficiary = _beneficiary;
        admin = _admin;
        start = _start;
        duration = _duration;
        cliff = _cliff;
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) revert OnlyAdmin();
        _;
    }

    receive() external payable {
        revert("use fund()");
    }

    function setAdmin(address next) external onlyAdmin {
        require(next != address(0), "zero address");
        emit AdminUpdated(admin, next);
        admin = next;
    }

    /// @notice Fund ETH vesting allocation with exact accounting.
    function fund() external payable nonReentrant {
        if (msg.value == 0) revert ZeroAmount();
        fundedETH += msg.value;
        emit Funded(msg.sender, msg.value);
    }

    function fundERC20(address token, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        uint256 before = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        uint256 received = IERC20(token).balanceOf(address(this)) - before;
        require(received == amount, "fee-on-transfer rejected");
        fundedERC20[token] += amount;
        emit FundedERC20(token, msg.sender, amount);
    }

    function end() public view returns (uint256) {
        return uint256(start) + uint256(duration);
    }

    function cliffEnd() public view returns (uint256) {
        return uint256(start) + uint256(cliff);
    }

    function vestedETH(uint64 timestamp) public view returns (uint256) {
        return _schedule(fundedETH, timestamp);
    }

    function vestedERC20(address token, uint64 timestamp) public view returns (uint256) {
        return _schedule(fundedERC20[token], timestamp);
    }

    function _schedule(uint256 total, uint64 timestamp) internal view returns (uint256) {
        if (total == 0 || timestamp < cliffEnd()) return 0;
        if (timestamp >= end()) return total;
        return (total * (uint256(timestamp) - uint256(start))) / uint256(duration);
    }

    function releasableETH() public view returns (uint256) {
        uint256 vested = vestedETH(uint64(block.timestamp));
        return vested > releasedETH ? vested - releasedETH : 0;
    }

    function releasableERC20(address token) public view returns (uint256) {
        uint256 vested = vestedERC20(token, uint64(block.timestamp));
        uint256 rel = releasedERC20[token];
        return vested > rel ? vested - rel : 0;
    }

    function release() external nonReentrant {
        uint256 amount = releasableETH();
        require(amount > 0, "nothing vested");
        releasedETH += amount;
        (bool ok,) = payable(beneficiary).call{value: amount}("");
        require(ok, "eth send failed");
        emit Released(amount);
    }

    function releaseERC20(address token) external nonReentrant {
        uint256 amount = releasableERC20(token);
        require(amount > 0, "nothing vested");
        releasedERC20[token] += amount;
        IERC20(token).safeTransfer(beneficiary, amount);
        emit ReleasedERC20(token, amount);
    }

    /// @notice Revoke: beneficiary keeps vested, admin recovers the rest.
    function revoke() external onlyAdmin nonReentrant {
        if (revoked) revert AlreadyRevoked();
        revoked = true;
        uint256 ethBal = address(this).balance;
        // Leave vested-but-unreleased ETH in place; return the remainder.
        uint256 owed = releasableETH();
        uint256 back = ethBal > owed ? ethBal - owed : 0;
        revokedETH += back;
        emit Revoked(back, block.timestamp);
        if (back > 0) {
            (bool ok,) = payable(admin).call{value: back}("");
            require(ok, "revoke send failed");
        }
    }

    function revokeERC20(address token) external onlyAdmin nonReentrant {
        if (revoked) revert AlreadyRevoked();
        uint256 owed = releasableERC20(token);
        uint256 bal = IERC20(token).balanceOf(address(this));
        uint256 back = bal > owed ? bal - owed : 0;
        revokedERC20[token] += back;
        if (back > 0) IERC20(token).safeTransfer(admin, back);
    }
}
