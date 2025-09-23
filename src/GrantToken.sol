// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

/// @title Grant DAO Token (GDT)
/// @notice ERC20 + Permit + Votes (checkpointed voting power for governance)
contract GrantToken is ERC20, ERC20Permit, ERC20Votes {
    constructor(
        uint256 initialSupply,
        address initialHolder
    ) ERC20("Grant DAO Token", "GDT") ERC20Permit("Grant DAO Token") {
        _mint(initialHolder, initialSupply);
    }

    // ------- OZ v5 required overrides -------
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Votes)
    {
        super._update(from, to, value);
    }

    function _mint(address to, uint256 value)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, value);
    }

    function _burn(address from, uint256 value)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(from, value);
    }
}
