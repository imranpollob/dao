// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {GrantToken} from "../src/GrantToken.sol";
import {Treasury} from "../src/Treasury.sol";
import {GrantGovernor} from "../src/GrantGovernor.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

contract TreasurySmoke is Test {
    GrantToken token;
    TimelockController timelock;
    GrantGovernor governor;
    Treasury treasury;

    address deployer = makeAddr("deployer");
    address voter1 = makeAddr("voter1");
    address payee = makeAddr("payee");

    function setUp() public {
        vm.startPrank(deployer);

        token = new GrantToken(1_000_000e18, deployer);
        timelock = new TimelockController(2 days, new address[](0), new address[](0), deployer);
        governor = new GrantGovernor(
            IVotes(address(token)),
            timelock,
            10_000e18, // threshold
            1, // votingDelay
            5, // votingPeriod
            4 // quorum %
        );
        treasury = new Treasury(address(timelock));

        // Roles and admin renounce
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        timelock.renounceRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);

        // delegate votes
        token.transfer(voter1, 100_000e18);
        vm.stopPrank();
        vm.prank(voter1);
        token.delegate(voter1);

        // fund treasury
        vm.deal(address(treasury), 10 ether);
    }

    function test_snapshot_compile() public {
        // does nothing; setUp ensures contracts deploy
        assertTrue(address(governor) != address(0));
        assertTrue(address(treasury) != address(0));
    }
}
