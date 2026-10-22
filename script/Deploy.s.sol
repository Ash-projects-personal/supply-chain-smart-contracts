// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../contracts/SupplyChain.sol";

interface Vm2 {
    function startBroadcast(uint256) external;
    function stopBroadcast() external;
    function writeFile(string calldata, string calldata) external;
    function toString(address) external returns (string memory);
}

/// @notice Deploys SupplyChain on a local anvil chain, grants roles to
/// three anvil accounts, and moves three batches through the chain so
/// the analytics pipeline has real events to read. Batch 0 goes all the
/// way to the retailer, batch 1 stops at the distributor, batch 2 stays
/// with the manufacturer.
contract Deploy {
    Vm2 constant vm = Vm2(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    uint256 constant ADMIN_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 constant MFR_KEY = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    uint256 constant DIST_KEY = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;

    function run() external {
        address admin = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        address manufacturer = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        address distributor = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
        address retailer = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;

        vm.startBroadcast(ADMIN_KEY);
        SupplyChain sc = new SupplyChain();
        sc.grantRole(sc.MANUFACTURER_ROLE(), manufacturer);
        sc.grantRole(sc.DISTRIBUTOR_ROLE(), distributor);
        sc.grantRole(sc.RETAILER_ROLE(), retailer);
        vm.stopBroadcast();

        vm.startBroadcast(MFR_KEY);
        sc.createBatch("Coffee Beans Lot 1", keccak256("cert-1"));
        sc.createBatch("Coffee Beans Lot 2", keccak256("cert-2"));
        sc.createBatch("Coffee Beans Lot 3", keccak256("cert-3"));
        sc.transferBatch(0, distributor);
        sc.transferBatch(1, distributor);
        vm.stopBroadcast();

        vm.startBroadcast(DIST_KEY);
        sc.transferBatch(0, retailer);
        vm.stopBroadcast();

        vm.writeFile(
            "outputs/deployment.json",
            string(abi.encodePacked('{"address": "', vm.toString(address(sc)), '", "admin": "', vm.toString(admin), '"}'))
        );
    }
}
