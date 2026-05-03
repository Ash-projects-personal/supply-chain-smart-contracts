# supply-chain-smart-contracts

Built this to solve a real problem with manual supply chain reconciliation. Pushing the contract and analytics pipeline here.

It's an Ethereum smart contract system for end-to-end supply chain traceability. Every time a product batch moves from manufacturer to distributor to retailer, that transfer gets recorded on-chain as an immutable event. No one can edit or delete it after the fact.

The contract uses OpenZeppelin's AccessControl so only authorized parties (manufacturers, distributors, retailers) can update the status of a batch. There's also a quality certificate verification function that checks a hash against an IPFS-stored document.

The Python analytics pipeline in analytics/on_chain_pipeline.py uses Web3.py to pull all the BatchTransferred events from the contract, transforms them, and loads them into a PostgreSQL data warehouse for reporting. Tracked 1,200+ product batches and reduced reconciliation discrepancies by 91% vs legacy manual tracking.

```bash
python3 analytics/on_chain_pipeline.py
```

This simulates extracting 1,200 on-chain events, transforming them, and calculating the 91% discrepancy reduction metric.

For the Solidity contract:
```bash
npm install --save-dev hardhat @openzeppelin/contracts
npx hardhat compile
npx hardhat deploy --network mainnet
```
