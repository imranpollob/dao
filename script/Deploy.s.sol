// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {GrantToken} from "../src/GrantToken.sol";
import {Treasury} from "../src/Treasury.sol";
import {GrantRegistry} from "../src/GrantRegistry.sol";
import {GrantGovernor} from "../src/GrantGovernor.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

/// @notice Production deploy profile: realistic delays, registry, caps, self-admin timelock.
contract Deploy is Script {
    uint256 public constant INITIAL_SUPPLY = 10_000_000e18;
    uint256 public constant TIMELOCK_DELAY = 2 days;

    uint256 public constant PROPOSAL_THRESHOLD = 100_000e18;
    uint256 public constant VOTING_DELAY = 7200;
    uint256 public constant VOTING_PERIOD = 50400;
    uint256 public constant QUORUM_PERCENT = 4;

    // Production spend policy defaults (tightenable via governance).
    uint256 public constant ETH_PER_CALL_CAP = 50 ether;
    uint256 public constant ETH_DAILY_CAP = 200 ether;
    uint256 public constant ERC20_PER_CALL_CAP = 500_000e18;
    uint256 public constant ERC20_DAILY_CAP = 2_000_000e18;
    uint256 public constant TREASURY_FLOOR = 1 ether;

    address[] proposers;
    address[] executors;

    function run() external {
        uint256 deployerPK = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPK);
        address tokenHolder = vm.envOr("TOKEN_HOLDER", deployer);
        address guardian = vm.envOr("GUARDIAN_ADDRESS", deployer);

        vm.startBroadcast(deployerPK);

        GrantToken token = new GrantToken(INITIAL_SUPPLY, tokenHolder);

        TimelockController timelock =
            new TimelockController(TIMELOCK_DELAY, proposers, executors, deployer);

        GrantGovernor governor = new GrantGovernor(
            IVotes(address(token)),
            timelock,
            PROPOSAL_THRESHOLD,
            VOTING_DELAY,
            VOTING_PERIOD,
            QUORUM_PERCENT
        );

        // Treasury starts owned by the deployer so caps/floor/pauser can be
        // set, then ownership is handed to the timelock before renouncing.
        Treasury treasury = new Treasury(deployer);
        GrantRegistry registry = new GrantRegistry(address(timelock));

        bytes32 PROPOSER_ROLE = timelock.PROPOSER_ROLE();
        bytes32 EXECUTOR_ROLE = timelock.EXECUTOR_ROLE();
        bytes32 CANCELLER_ROLE = timelock.CANCELLER_ROLE();
        bytes32 ADMIN_ROLE = timelock.DEFAULT_ADMIN_ROLE();

        timelock.grantRole(PROPOSER_ROLE, address(governor));
        timelock.grantRole(EXECUTOR_ROLE, address(0));
        timelock.grantRole(CANCELLER_ROLE, guardian);

        treasury.setCaps(ETH_PER_CALL_CAP, ETH_DAILY_CAP, ERC20_PER_CALL_CAP, ERC20_DAILY_CAP);
        treasury.setTreasuryFloor(TREASURY_FLOOR);
        treasury.setPauser(guardian);
        treasury.transferOwnership(address(timelock));

        // Self-administered timelock so governance can rotate roles later.
        timelock.grantRole(ADMIN_ROLE, address(timelock));
        timelock.renounceRole(ADMIN_ROLE, deployer);

        token.delegate(tokenHolder);

        vm.stopBroadcast();

        // Post-deploy assertions: no retained privilege on deployer.
        require(treasury.owner() == address(timelock), "treasury owner");
        require(registry.owner() == address(timelock), "registry owner");
        require(timelock.hasRole(PROPOSER_ROLE, address(governor)), "proposer role");
        require(timelock.hasRole(EXECUTOR_ROLE, address(0)), "executor role");
        require(timelock.hasRole(CANCELLER_ROLE, guardian), "canceller role");
        require(!timelock.hasRole(ADMIN_ROLE, deployer), "deployer admin retained");
        require(timelock.hasRole(ADMIN_ROLE, address(timelock)), "timelock self-admin");

        console2.log("GrantToken:", address(token));
        console2.log("Timelock  :", address(timelock));
        console2.log("Governor  :", address(governor));
        console2.log("Treasury  :", address(treasury));
        console2.log("Registry  :", address(registry));
        console2.log("Guardian  :", guardian);
        console2.log("TokenHolder:", tokenHolder);
        if (guardian == deployer) {
            console2.log("WARNING: guardian=deployer; production must use a multisig");
        }
        if (tokenHolder == deployer) {
            console2.log("WARNING: tokens held by deployer; move to multisig/distributor");
        }
        console2.log("Timelock Delay:", TIMELOCK_DELAY);
        console2.log("Quorum %:", QUORUM_PERCENT);
        console2.log("Proposal Threshold:", PROPOSAL_THRESHOLD);
    }
}
