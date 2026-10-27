// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Treasury} from "../Treasury.sol";
import {GrantRegistry} from "../GrantRegistry.sol";

interface IVestingTarget {
    function fund() external payable;
}

library ProposalBuilder {
    /// @notice Build a proposal that sends ETH from Treasury to `recipient`
    function buildEthGrant(
        Treasury treasury,
        address payable recipient,
        uint256 amountWei,
        string memory description
    )
        internal
        pure
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        )
    {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);

        // call Treasury.execute(recipient, amountWei, "")
        targets[0] = address(treasury);
        values[0] = 0;
        calldatas[0] =
            abi.encodeWithSelector(Treasury.execute.selector, recipient, amountWei, bytes(""));
        desc = description;
    }

    /// @notice Build a proposal that transfers ERC20 tokens from Treasury to `to`
    /// @param erc20 token address that Treasury already holds
    /// @param amount amount in token's decimals
    function buildErc20Grant(
        Treasury treasury,
        address erc20,
        address to,
        uint256 amount,
        string memory description
    )
        internal
        pure
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        )
    {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);

        // IERC20(erc20).transfer(to, amount) via Treasury.execute
        bytes memory data =
            abi.encodeWithSelector(bytes4(keccak256("transfer(address,uint256)")), to, amount);

        targets[0] = address(treasury);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(Treasury.execute.selector, erc20, 0, data);
        desc = description;
    }

    /// @notice Build a batch ETH payout in ONE treasury call (atomic total-cap check).
    function buildBatchEthGrants(
        Treasury treasury,
        address payable[] memory recipients,
        uint256[] memory amounts,
        uint256[] memory grantIds,
        uint256[] memory milestoneIds,
        uint256 perProposalCap,
        string memory description
    )
        internal
        pure
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        )
    {
        require(
            recipients.length == amounts.length && recipients.length == grantIds.length
                && recipients.length == milestoneIds.length,
            "length mismatch"
        );
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        targets[0] = address(treasury);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(
            Treasury.batchSendETH.selector,
            recipients,
            amounts,
            grantIds,
            milestoneIds,
            perProposalCap
        );
        desc = description;
    }

    /// @notice Build a vesting-funding proposal: Treasury funds the vesting wallet.
    function buildVestingGrant(
        Treasury treasury,
        address payable vesting,
        uint256 amountWei,
        uint256 grantId,
        string memory description
    )
        internal
        pure
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        )
    {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        targets[0] = address(treasury);
        values[0] = 0;
        calldatas[0] =
            abi.encodeWithSelector(Treasury.fundVesting.selector, vesting, amountWei, grantId);
        desc = description;
    }

    /// @notice Build a milestone payout: Treasury pays AND registry records, atomically.
    function buildMilestonePayout(
        Treasury treasury,
        GrantRegistry registry,
        address payable recipient,
        uint256 amountWei,
        uint256 grantId,
        uint256 milestoneIdx,
        string memory description
    )
        internal
        pure
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas,
            string memory desc
        )
    {
        targets = new address[](2);
        values = new uint256[](2);
        calldatas = new bytes[](2);
        targets[0] = address(treasury);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(
            Treasury.sendETH.selector, recipient, amountWei, grantId, milestoneIdx
        );
        targets[1] = address(registry);
        values[1] = 0;
        calldatas[1] = abi.encodeWithSelector(
            GrantRegistry.recordPayout.selector, grantId, milestoneIdx, amountWei
        );
        desc = description;
    }
}
