// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title Treasury vault controlled exclusively by Timelock
contract Treasury is Ownable, ReentrancyGuard {
    event FundsReceived(address indexed from, uint256 amount);
    event Executed(address indexed target, uint256 value, bytes4 selector, bytes result);

    constructor(address timelock) Ownable(timelock) {}

    receive() external payable {
        emit FundsReceived(msg.sender, msg.value);
    }

    /// @notice Execute an arbitrary call (only owner = Timelock)
    function execute(address target, uint256 value, bytes calldata data)
        external
        onlyOwner
        nonReentrant
        returns (bytes memory)
    {
        (bool ok, bytes memory ret) = target.call{value: value}(data);
        require(ok, "Treasury: exec failed");
        bytes4 selector = data.length >= 4 ? bytes4(data[0:4]) : bytes4(0);
        emit Executed(target, value, selector, ret);
        return ret;
    }
}
