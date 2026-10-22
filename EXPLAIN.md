# How this works, in plain words

A batch is a record with a product name, a current holder, a stage, a
quality certificate hash, and a list of transfers. The stage machine is
strict: Created, then WithDistributor, then WithRetailer, and each step
checks the receiver's role through OpenZeppelin AccessControl. Because
the transfer history lives on chain, anyone can replay exactly how a
batch moved.

The analytics half exists to answer one question honestly: do the
events a data pipeline would consume match the state the contract
stores? The run script spins up anvil (a local chain), deploys the
contract, moves three batches by different amounts, and the Python
pipeline then reads the events with Web3.py and cross checks the count
against the history arrays. Three transfers both ways, match true.

## What got re scoped from the original

- The old pipeline never imported Web3 at all; it generated fake events
  in a loop. The "1,200 plus batches" was the loop bound and the
  "91 percent fewer discrepancies" was arithmetic on two assumed rates.
  Both claims are gone, and the new pipeline only counts what a real
  contract emitted on a local chain.
- "Loads into PostgreSQL" was a JSON file with the SQL in a comment.
  The loader now writes a real SQLite database and says SQLite.
- The contract itself was mostly real before and stays: role checks,
  staged transfers, recall, and hash verification. The false numbers
  that lived in its header comment are removed there too.
