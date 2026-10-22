#!/bin/sh
# Starts a local anvil chain, deploys the contract with seed activity,
# runs the Python analytics pipeline against the real events, and stops
# the chain again.
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
BIN="$HOME/workspace/projects/rebuilds/.foundry"
"$BIN/anvil" --port 8547 --silent &
ANVIL_PID=$!
trap 'kill $ANVIL_PID 2>/dev/null || true' EXIT
sleep 2
cd "$ROOT"
"$BIN/forge" script script/Deploy.s.sol --rpc-url http://127.0.0.1:8547 --broadcast > outputs/deploy_log.txt 2>&1
"$HOME/workspace/projects/rebuilds/.venv-batch4/bin/python" analytics/on_chain_pipeline.py
