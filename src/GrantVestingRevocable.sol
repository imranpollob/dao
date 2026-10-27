// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title Grant Vesting Wallet (revocable)
/// @notice Cliff + linear vesting with split beneficiary/admin roles.
/// Beneficiary cannot move the schedule. Admin (timelock) can revoke per
/// asset; the vested-but-unreleased amount is frozen at revocation and stays
/// releasable, while unvested funds return to the Treasury.
contract GrantVestingRevocable is ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public immutable beneficiary;
    address public immutable treasury;
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

    bool public ethRevoked;
    mapping(address => bool) public erc20Revoked;
    uint64 public revokedAtETH;
    mapping(address => uint64) public revokedAtERC20;

    event Funded(address indexed from, uint256 amount);
    event FundedERC20(address indexed token, address indexed from, uint256 amount);
    event Released(uint256 amount);
    event ReleasedERC20(address indexed token, uint256 amount);
    event Revoked(uint256 ethReturned, uint256 timestamp);
    event RevokedERC20(address indexed token, uint256 amountReturned, uint256 timestamp);
    event AdminUpdated(address indexed oldAdmin, address indexed newAdmin);

    error OnlyAdmin();
    error AlreadyRevoked();
    error ZeroAmount();

    constructor(
        address _beneficiary,
        address _admin,
        address _treasury,
        uint64 _start,
        uint64 _duration,
        uint64 _cliff
    ) {
        require(
            _beneficiary != address(0) && _admin != address(0) && _treasury != address(0),
            "zero address"
        );
        require(_duration > 0, "duration=0");
        require(_cliff <= _duration, "cliff>duration");
        beneficiary = _beneficiary;
        admin = _admin;
        treasury = _treasury;
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
        address old = admin;
        admin = next;
        emit AdminUpdated(old, next);
    }

    /// @notice Compatibility view: true once ETH has been revoked.
    function revoked() external view returns (bool) {
        return ethRevoked;
    }

    /// @notice Fund ETH vesting allocation with exact accounting.
    function fund() external payable nonReentrant {
        if (ethRevoked) revert AlreadyRevoked();
        if (msg.value == 0) revert ZeroAmount();
        fundedETH += msg.value;
        emit Funded(msg.sender, msg.value);
    }

    function fundERC20(address token, uint256 amount) external nonReentrant {
        if (erc20Revoked[token]) revert AlreadyRevoked();
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

    function _releasableETH(uint64 timestamp) internal view returns (uint256) {
        uint256 vested = vestedETH(timestamp);
        return vested > releasedETH ? vested - releasedETH : 0;
    }

    function _releasableERC20(address token, uint64 timestamp) internal view returns (uint256) {
        uint256 vested = vestedERC20(token, timestamp);
        uint256 rel = releasedERC20[token];
        return vested > rel ? vested - rel : 0;
    }

    function releasableETH() public view returns (uint256) {
        uint64 timestamp = ethRevoked ? revokedAtETH : uint64(block.timestamp);
        return _releasableETH(timestamp);
    }

    function releasableERC20(address token) public view returns (uint256) {
        uint64 timestamp = erc20Revoked[token] ? revokedAtERC20[token] : uint64(block.timestamp);
        return _releasableERC20(token, timestamp);
    }

    function release() external nonReentrant {
        uint256 amount = releasableETH();
        require(amount > 0, "nothing vested");
        releasedETH += amount;
        emit Released(amount);
        (bool ok,) = payable(beneficiary).call{value: amount}("");
        require(ok, "eth send failed");
    }

    function releaseERC20(address token) external nonReentrant {
        uint256 amount = releasableERC20(token);
        require(amount > 0, "nothing vested");
        releasedERC20[token] += amount;
        emit ReleasedERC20(token, amount);
        IERC20(token).safeTransfer(beneficiary, amount);
    }

    /// @notice Revoke ETH: beneficiary keeps the amount vested at this moment.
    function revoke() external nonReentrant onlyAdmin {
        if (ethRevoked) revert AlreadyRevoked();
        ethRevoked = true;
        revokedAtETH = uint64(block.timestamp);
        uint256 owed = _releasableETH(revokedAtETH);
        uint256 ethBal = address(this).balance;
        uint256 back = ethBal > owed ? ethBal - owed : 0;
        revokedETH += back;
        emit Revoked(back, block.timestamp);
        if (back > 0) {
            (bool ok,) = payable(treasury).call{value: back}("");
            require(ok, "revoke send failed");
        }
    }

    /// @notice Revoke one ERC20 allocation; other assets remain independent.
    function revokeERC20(address token) external nonReentrant onlyAdmin {
        if (erc20Revoked[token]) revert AlreadyRevoked();
        erc20Revoked[token] = true;
        revokedAtERC20[token] = uint64(block.timestamp);
        uint256 owed = _releasableERC20(token, revokedAtERC20[token]);
        uint256 bal = IERC20(token).balanceOf(address(this));
        uint256 back = bal > owed ? bal - owed : 0;
        revokedERC20[token] += back;
        emit RevokedERC20(token, back, block.timestamp);
        if (back > 0) IERC20(token).safeTransfer(treasury, back);
    }
}
