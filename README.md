# Supply Chain Smart Contracts

I built a batch traceability contract in Solidity, plus a Python
analytics pipeline that reads what the contract actually did.

## The contract

`SupplyChain.sol` tracks a product batch through three hands:
manufacturer, distributor, retailer. Each transfer is appended to the
batch's history and emitted as a `BatchTransferred` event. Roles are
enforced with real OpenZeppelin AccessControl (version 5.0.2, vendored
under `lib/`): only a manufacturer can create a batch, the current
holder must be the sender of a transfer, and the receiver must hold the
role for the next stage. A manufacturer can recall a batch, which blocks
further transfers. `verifyQualityCert` compares a supplied hash with
the certificate hash stored at creation; the contract itself never
touches IPFS, whatever the hash points at lives elsewhere.

## The analytics, on real events this time

The original analytics script was a mock wearing a Web3 costume: it
fabricated 1,200 events with the same fake transaction hash and
computed a "91 percent discrepancy reduction" from two assumed rates
typed into the function. Both headline numbers in the old README came
from that mock. They were invented, and they are deleted.

The new pipeline (`analytics/on_chain_pipeline.py`) does the real
thing, locally:

1. `scripts/run_analytics.sh` starts a local anvil chain and deploys
   the contract with three seeded batches (one reaches the retailer,
   one stops at the distributor, one stays with the manufacturer).
2. The pipeline connects with Web3.py, pulls the `BatchCreated` and
   `BatchTransferred` events, and loads the transfers into a SQLite
   database at `outputs/warehouse.db`.
3. It then reconciles two independent reads: the transfer count from
   the event log against the transfer count stored in the on chain
   history arrays.

Result of the run recorded in `outputs/metrics.json`: 3 batches
created, 3 transfer events read, 3 rows loaded, reconciliation match
true.

## What it is not

- Never deployed to any live network. Every number here is from a
  disposable local chain started for the run.
- No discrepancy reduction or batch volume claim. There is no manual
  tracking baseline to compare against, so no such figure is computed.
- The warehouse is a local SQLite file, named as such, not a hosted
  PostgreSQL warehouse.

## Run it

```
forge test
sh scripts/run_analytics.sh
```

## Contract test results

8 tests, 8 passed: creation, role gating on create and transfer,
skipping a stage, non holder transfer, quality certificate verify in
both directions, recall blocking transfer, and the end of the chain at
the retailer.
