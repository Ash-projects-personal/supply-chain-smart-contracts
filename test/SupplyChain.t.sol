// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../contracts/SupplyChain.sol";

interface Vm {
    function prank(address) external;
    function expectRevert() external;
}

contract SupplyChainTest {
    Vm constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    SupplyChain sc;
    address manufacturer = address(0x1001);
    address distributor = address(0x1002);
    address retailer = address(0x1003);
    address outsider = address(0xBAD);
    bytes32 cert = keccak256("cert-doc");

    function check(bool c, string memory m) internal pure {
        require(c, m);
    }

    function setUp() public {
        sc = new SupplyChain();
        sc.grantRole(sc.MANUFACTURER_ROLE(), manufacturer);
        sc.grantRole(sc.DISTRIBUTOR_ROLE(), distributor);
        sc.grantRole(sc.RETAILER_ROLE(), retailer);
        vm.prank(manufacturer);
        sc.createBatch("Coffee Beans Lot 1", cert);
    }

    function testCreateBatch() public {
        (, address holder, SupplyChain.Stage stage, , bool exists) = sc.batches(0);
        check(exists, "batch missing");
        check(holder == manufacturer, "holder wrong");
        check(stage == SupplyChain.Stage.Created, "stage wrong");
        check(sc.historyLength(0) == 1, "history should hold creation");
    }

    function testNonManufacturerCannotCreate() public {
        vm.prank(outsider);
        vm.expectRevert();
        sc.createBatch("Fake", cert);
    }

    function testFullChainTransfer() public {
        vm.prank(manufacturer);
        sc.transferBatch(0, distributor);
        vm.prank(distributor);
        sc.transferBatch(0, retailer);
        (, address holder, SupplyChain.Stage stage, , ) = sc.batches(0);
        check(holder == retailer, "final holder wrong");
        check(stage == SupplyChain.Stage.WithRetailer, "final stage wrong");
        check(sc.historyLength(0) == 3, "history should hold 3 entries");
        (address from2, address to2, , ) = sc.getTransfer(0, 2);
        check(from2 == distributor && to2 == retailer, "last transfer wrong");
    }

    function testWrongRoleReceiverReverts() public {
        // Manufacturer cannot skip the distributor step.
        vm.prank(manufacturer);
        vm.expectRevert();
        sc.transferBatch(0, retailer);
    }

    function testNonHolderCannotTransfer() public {
        vm.prank(outsider);
        vm.expectRevert();
        sc.transferBatch(0, distributor);
    }

    function testVerifyQualityCert() public {
        check(sc.verifyQualityCert(0, cert), "correct hash rejected");
        check(!sc.verifyQualityCert(0, keccak256("other")), "wrong hash accepted");
    }

    function testRecallBlocksTransfer() public {
        vm.prank(manufacturer);
        sc.recallBatch(0);
        vm.prank(manufacturer);
        vm.expectRevert();
        sc.transferBatch(0, distributor);
    }

    function testRetailerCannotTransferFurther() public {
        vm.prank(manufacturer);
        sc.transferBatch(0, distributor);
        vm.prank(distributor);
        sc.transferBatch(0, retailer);
        vm.prank(retailer);
        vm.expectRevert();
        sc.transferBatch(0, manufacturer);
    }
}
