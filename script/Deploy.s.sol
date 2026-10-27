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
/// @dev TOKEN_HOLDER must be a separate account/contract that will self-delegate
/// after deployment. GUARDIAN_ADDRESS must be a multisig contract.
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
    uint256 public constant ETH_PER_PROPOSAL_CAP = 100 ether;
    uint256 public constant ERC20_PER_CALL_CAP = 500_000e18;
    uint256 public constant ERC20_DAILY_CAP = 2_000_000e18;
    uint256 public constant ERC20_PER_PROPOSAL_CAP = 1_000_000e18;
    uint256 public constant TREASURY_FLOOR = 1 ether;

    address[] proposers;
    address[] executors;

    function run() external {
        uint256 deployerPK = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPK);
        address tokenHolder = vm.envAddress("TOKEN_HOLDER");
        address guardian = vm.envAddress("GUARDIAN_ADDRESS");

        require(tokenHolder != address(0), "token holder=0");
        require(tokenHolder != deployer, "token holder must be separate");
        require(guardian != address(0), "guardian=0");
        require(guardian != deployer, "guardian must be separate");
        require(guardian.code.length > 0, "guardian must be a contract/multisig");

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
            QUORUM_PERCENT,
            guardian
        );

        // Registry starts owned by deployer only long enough to wire Treasury,
        // then ownership moves to the Timelock before deployment completes.
        GrantRegistry registry = new GrantRegistry(deployer);
        Treasury treasury = new Treasury(deployer, registry);

        bytes32 PROPOSER_ROLE = timelock.PROPOSER_ROLE();
        bytes32 EXECUTOR_ROLE = timelock.EXECUTOR_ROLE();
        bytes32 CANCELLER_ROLE = timelock.CANCELLER_ROLE();
        bytes32 ADMIN_ROLE = timelock.DEFAULT_ADMIN_ROLE();

        timelock.grantRole(PROPOSER_ROLE, address(governor));
        timelock.grantRole(EXECUTOR_ROLE, address(0));
        // The guardian cancels through Governor.cancel, so only the Governor
        // needs the Timelock CANCELLER_ROLE. Keeping it off the guardian avoids
        // a stale direct-cancel privilege after guardian rotation.
        timelock.grantRole(CANCELLER_ROLE, address(governor));

        registry.setTreasury(address(treasury));

        treasury.setCaps(ETH_PER_CALL_CAP, ETH_DAILY_CAP, ERC20_PER_CALL_CAP, ERC20_DAILY_CAP);
        treasury.setProposalCaps(ETH_PER_PROPOSAL_CAP, ERC20_PER_PROPOSAL_CAP);
        treasury.setTreasuryFloor(TREASURY_FLOOR);
        treasury.setPauser(guardian);
        treasury.setEnforceAllowlist(true);
        treasury.transferOwnership(address(timelock));
        registry.transferOwnership(address(timelock));

        // Self-administered timelock so governance can rotate roles later.
        timelock.grantRole(ADMIN_ROLE, address(timelock));
        timelock.renounceRole(ADMIN_ROLE, deployer);

        vm.stopBroadcast();

        // Post-deploy assertions: no retained privilege on deployer.
        require(treasury.owner() == address(timelock), "treasury owner");
        require(registry.owner() == address(timelock), "registry owner");
        require(address(treasury.registry()) == address(registry), "treasury registry");
        require(registry.treasury() == address(treasury), "registry treasury");
        require(treasury.enforceAllowlist(), "token allowlist not enforced");
        require(treasury.pauser() == guardian, "treasury pauser");
        require(governor.guardian() == guardian, "guardian");
        require(
            guardian != address(timelock) && guardian != address(governor)
                && guardian != address(treasury) && guardian != address(registry)
                && guardian != address(token),
            "guardian role conflict"
        );
        require(timelock.hasRole(PROPOSER_ROLE, address(governor)), "proposer role");
        require(timelock.hasRole(EXECUTOR_ROLE, address(0)), "executor role");
        require(!timelock.hasRole(CANCELLER_ROLE, guardian), "guardian direct canceller");
        require(timelock.hasRole(CANCELLER_ROLE, address(governor)), "governor canceller role");
        require(!timelock.hasRole(ADMIN_ROLE, deployer), "deployer admin retained");
        require(timelock.hasRole(ADMIN_ROLE, address(timelock)), "timelock self-admin");
        require(token.balanceOf(tokenHolder) == INITIAL_SUPPLY, "token holder balance");

        console2.log("GrantToken:", address(token));
        console2.log("Timelock  :", address(timelock));
        console2.log("Governor  :", address(governor));
        console2.log("Treasury  :", address(treasury));
        console2.log("Registry  :", address(registry));
        console2.log("Guardian  :", guardian);
        console2.log("TokenHolder:", tokenHolder);
        console2.log(
            "REQUIRED NEXT STEP: tokenHolder must call token.delegate(tokenHolder) before proposing"
        );
        console2.log("Timelock Delay:", TIMELOCK_DELAY);
        console2.log("Quorum %:", QUORUM_PERCENT);
        console2.log("Proposal Threshold:", PROPOSAL_THRESHOLD);
    }
}
