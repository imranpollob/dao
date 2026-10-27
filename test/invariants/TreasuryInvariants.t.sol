// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {Treasury} from "../../src/Treasury.sol";
import {GrantRegistry} from "../../src/GrantRegistry.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/// @notice Handler-driven invariants: floor, spend accounting, registry totals.
contract TreasuryHandler is Test {
    Treasury public treasury;
    GrantRegistry public registry;
    TimelockController public timelock;
    address payable public payee = payable(makeAddr("payee"));
    uint256 public grantId;
    uint256 public totalPaid;

    constructor() {
        timelock = new TimelockController(1 days, new address[](0), new address[](0), address(this));
        registry = new GrantRegistry(address(timelock));
        // Handler is the Treasury owner so it can drive payouts directly.
        treasury = new Treasury(address(this), registry);
        vm.prank(address(timelock));
        registry.setTreasury(address(treasury));

        GrantRegistry.CreateGrantParams memory p = GrantRegistry.CreateGrantParams({
            recipient: payee,
            token: address(0),
            total: 1_000 ether,
            grantType: GrantRegistry.GrantType.Immediate,
            proposalId: 1,
            vesting: address(0),
            reviewer: address(0)
        });
        vm.prank(address(timelock));
        grantId = registry.createGrant(p, "ipfs://invariant", new uint256[](0), new uint64[](0));

        vm.deal(address(treasury), 100 ether);
        treasury.setCaps(50 ether, 200 ether, 500_000e18, 2_000_000e18);
        treasury.setTreasuryFloor(10 ether);
    }

    function payout(uint256 amount) external {
        amount = bound(amount, 0, 60 ether);
        uint256 bal = address(treasury).balance;
        if (bal <= treasury.treasuryFloor()) return;
        uint256 maxOk = bal - treasury.treasuryFloor();
        if (amount > maxOk) return;
        try treasury.payGrant(grantId, amount) {
            totalPaid += amount;
        } catch {}
    }

    function pauseUnpause(uint256 seed) external {
        if (seed % 2 == 0) {
            try treasury.pause(1 hours) {} catch {}
        } else {
            try treasury.unpause() {} catch {}
        }
    }
}

contract TreasuryInvariants is Test {
    TreasuryHandler handler;

    function setUp() public {
        handler = new TreasuryHandler();
        targetContract(address(handler));
    }

    /// @notice Treasury never drops below its floor via the typed path.
    function invariant_floorHolds() public view {
        assertGe(address(handler.treasury()).balance, handler.treasury().treasuryFloor());
    }

    /// @notice Paid totals never exceed initial funding minus current balance.
    function invariant_accountingHolds() public view {
        uint256 initial = 100 ether;
        uint256 bal = address(handler.treasury()).balance;
        assertLe(handler.totalPaid(), initial - bal);
    }

    /// @notice Registry commitment always equals the unpaid remainder.
    function invariant_commitmentMatchesRemainder() public view {
        GrantRegistry.Grant memory g = handler.registry().grants(handler.grantId());
        assertEq(handler.registry().committed(address(0)), g.total - g.paid - g.funded);
    }
}
