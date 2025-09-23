// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Treasury} from "../Treasury.sol";

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
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory desc)
    {
        targets = new address;
        values = new uint256;
        calldatas = new bytes;

        // call Treasury.execute(recipient, amountWei, "")
        targets[0] = address(treasury);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(
            Treasury.execute.selector,
            recipient,
            amountWei,
            bytes("")
        );
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
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory desc)
    {
        targets = new address;
        values = new uint256;
        calldatas = new bytes;

        // IERC20(erc20).transfer(to, amount) via Treasury.execute
        bytes memory data = abi.encodeWithSelector(bytes4(keccak256("transfer(address,uint256)")), to, amount);

        targets[0] = address(treasury);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(
            Treasury.execute.selector,
            erc20,
            0,
            data
        );
        desc = description;
    }
}
