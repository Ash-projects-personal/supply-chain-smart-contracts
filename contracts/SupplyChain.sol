// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title SupplyChain
/// @notice Batch traceability for a three step supply chain. A
/// manufacturer creates a batch, a distributor receives it, then a
/// retailer receives it. Every transfer is appended to the batch's
/// history and emitted as an event. Roles come from OpenZeppelin
/// AccessControl, vendored under lib/.
///
/// There are no usage statistics in this header, on purpose: an earlier
/// version claimed 1,200 tracked batches and a 91 percent discrepancy
/// reduction. Both numbers were invented in the mock analytics script,
/// not measured anywhere. The contract has never been deployed.
contract SupplyChain is AccessControl {
    bytes32 public constant MANUFACTURER_ROLE = keccak256("MANUFACTURER_ROLE");
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    bytes32 public constant RETAILER_ROLE = keccak256("RETAILER_ROLE");

    enum Stage {
        Created,
        WithDistributor,
        WithRetailer,
        Recalled
    }

    struct Transfer {
        address from;
        address to;
        uint256 timestamp;
        Stage stageAfter;
    }

    struct Batch {
        string productName;
        address currentHolder;
        Stage stage;
        bytes32 qualityCertHash;
        bool exists;
        Transfer[] history;
    }

    uint256 public nextBatchId;
    mapping(uint256 => Batch) public batches;

    event BatchCreated(uint256 indexed batchId, address indexed manufacturer, string productName);
    event BatchTransferred(uint256 indexed batchId, address indexed from, address indexed to, Stage stageAfter);
    event BatchRecalled(uint256 indexed batchId, address indexed by);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function createBatch(string calldata productName, bytes32 qualityCertHash)
        external
        onlyRole(MANUFACTURER_ROLE)
        returns (uint256 batchId)
    {
        batchId = nextBatchId++;
        Batch storage b = batches[batchId];
        b.productName = productName;
        b.currentHolder = msg.sender;
        b.stage = Stage.Created;
        b.qualityCertHash = qualityCertHash;
        b.exists = true;
        b.history.push(Transfer({from: address(0), to: msg.sender, timestamp: block.timestamp, stageAfter: Stage.Created}));
        emit BatchCreated(batchId, msg.sender, productName);
    }

    function transferBatch(uint256 batchId, address to) external {
        Batch storage b = batches[batchId];
        require(b.exists, "no such batch");
        require(b.currentHolder == msg.sender, "not the current holder");
        require(b.stage != Stage.Recalled, "batch recalled");

        Stage next;
        if (b.stage == Stage.Created) {
            require(hasRole(DISTRIBUTOR_ROLE, to), "next holder must be a distributor");
            next = Stage.WithDistributor;
        } else if (b.stage == Stage.WithDistributor) {
            require(hasRole(RETAILER_ROLE, to), "next holder must be a retailer");
            next = Stage.WithRetailer;
        } else {
            revert("batch already at retailer");
        }

        b.history.push(Transfer({from: msg.sender, to: to, timestamp: block.timestamp, stageAfter: next}));
        b.currentHolder = to;
        b.stage = next;
        emit BatchTransferred(batchId, msg.sender, to, next);
    }

    function recallBatch(uint256 batchId) external onlyRole(MANUFACTURER_ROLE) {
        Batch storage b = batches[batchId];
        require(b.exists, "no such batch");
        b.stage = Stage.Recalled;
        emit BatchRecalled(batchId, msg.sender);
    }

    /// @notice Compares a supplied hash with the quality certificate
    /// hash stored on the batch at creation. The contract never touches
    /// IPFS; the stored value is whatever hash the manufacturer supplied.
    function verifyQualityCert(uint256 batchId, bytes32 certHash) external view returns (bool) {
        require(batches[batchId].exists, "no such batch");
        return batches[batchId].qualityCertHash == certHash;
    }

    function historyLength(uint256 batchId) external view returns (uint256) {
        return batches[batchId].history.length;
    }

    function getTransfer(uint256 batchId, uint256 index)
        external
        view
        returns (address from, address to, uint256 timestamp, Stage stageAfter)
    {
        Transfer storage t = batches[batchId].history[index];
        return (t.from, t.to, t.timestamp, t.stageAfter);
    }
}
