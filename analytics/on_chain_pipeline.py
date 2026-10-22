"""
On chain analytics pipeline.

Reads BatchCreated and BatchTransferred events from a SupplyChain
contract running on a local anvil chain, transforms them into flat
rows, and loads them into a SQLite database (a real local file, not a
mock). A reconciliation check compares the number of transfers in the
event log against the per batch history lengths stored on chain; both
come from the chain, so the comparison is a real consistency check of
two independent reads.

The previous version of this file used a MockWeb3 class that fabricated
1,200 events with the same fake transaction hash and computed a 91
percent discrepancy reduction from two assumed rates typed into the
function. All of that is gone. This version only processes events that
were actually emitted on the local chain.
"""

import json
import sqlite3
import sys
from pathlib import Path

from web3 import Web3

ROOT = Path(__file__).resolve().parent.parent
RPC = "http://127.0.0.1:8547"

ABI = [
    {
        "anonymous": False,
        "inputs": [
            {"indexed": True, "name": "batchId", "type": "uint256"},
            {"indexed": True, "name": "manufacturer", "type": "address"},
            {"indexed": False, "name": "productName", "type": "string"},
        ],
        "name": "BatchCreated",
        "type": "event",
    },
    {
        "anonymous": False,
        "inputs": [
            {"indexed": True, "name": "batchId", "type": "uint256"},
            {"indexed": True, "name": "from", "type": "address"},
            {"indexed": True, "name": "to", "type": "address"},
            {"indexed": False, "name": "stageAfter", "type": "uint8"},
        ],
        "name": "BatchTransferred",
        "type": "event",
    },
    {
        "inputs": [{"name": "batchId", "type": "uint256"}],
        "name": "historyLength",
        "outputs": [{"name": "", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function",
    },
    {
        "inputs": [],
        "name": "nextBatchId",
        "outputs": [{"name": "", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function",
    },
]

STAGES = {0: "Created", 1: "WithDistributor", 2: "WithRetailer", 3: "Recalled"}


def main() -> int:
    deployment = json.loads((ROOT / "outputs" / "deployment.json").read_text())
    w3 = Web3(Web3.HTTPProvider(RPC))
    if not w3.is_connected():
        print("cannot reach local anvil at", RPC)
        return 1
    contract = w3.eth.contract(address=deployment["address"], abi=ABI)

    created = contract.events.BatchCreated().get_logs(from_block=0)
    transferred = contract.events.BatchTransferred().get_logs(from_block=0)

    rows = []
    for ev in transferred:
        rows.append(
            {
                "batch_id": ev["args"]["batchId"],
                "from_addr": ev["args"]["from"],
                "to_addr": ev["args"]["to"],
                "stage_after": STAGES[ev["args"]["stageAfter"]],
                "block_number": ev["blockNumber"],
                "tx_hash": ev["transactionHash"].hex(),
            }
        )

    db_path = ROOT / "outputs" / "warehouse.db"
    if db_path.exists():
        db_path.unlink()
    conn = sqlite3.connect(db_path)
    conn.execute(
        "CREATE TABLE transfers (batch_id INTEGER, from_addr TEXT, to_addr TEXT,"
        " stage_after TEXT, block_number INTEGER, tx_hash TEXT)"
    )
    conn.executemany(
        "INSERT INTO transfers VALUES (:batch_id, :from_addr, :to_addr,"
        " :stage_after, :block_number, :tx_hash)",
        rows,
    )
    conn.commit()
    loaded = conn.execute("SELECT COUNT(*) FROM transfers").fetchone()[0]
    conn.close()

    # Reconciliation: the events are one read path, the stored per batch
    # history arrays are another. Transfers in history = historyLength
    # minus the creation entry. They must agree.
    batch_count = contract.functions.nextBatchId().call()
    history_transfers = 0
    for b in range(batch_count):
        history_transfers += contract.functions.historyLength(b).call() - 1

    sample_path = ROOT / "outputs" / "warehouse_sample.json"
    sample_path.write_text(json.dumps(rows, indent=2) + "\n")

    metrics = {
        "repo": "supply-chain-smart-contracts",
        "toolchain": "forge 1.0.0, solc 0.8.24, anvil local chain, OpenZeppelin AccessControl 5.0.2 (vendored), web3.py pipeline",
        "contract_address_local": deployment["address"],
        "batches_created_on_local_chain": len(created),
        "transfer_events_read": len(transferred),
        "rows_loaded_to_sqlite": loaded,
        "transfers_counted_from_onchain_history": history_transfers,
        "reconciliation_match": len(transferred) == history_transfers == loaded,
        "note": "All activity is on a disposable local anvil chain created for this run. The contract has never been deployed to any live network. No discrepancy reduction figure is computed, because there is no manual baseline to compare against.",
    }
    (ROOT / "outputs" / "metrics.json").write_text(json.dumps(metrics, indent=2) + "\n")
    print(json.dumps(metrics, indent=2))
    return 0 if metrics["reconciliation_match"] else 1


if __name__ == "__main__":
    sys.exit(main())
