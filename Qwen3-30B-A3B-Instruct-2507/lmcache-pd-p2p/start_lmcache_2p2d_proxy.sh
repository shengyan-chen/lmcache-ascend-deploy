#!/bin/bash
set -eo pipefail

MODEL_PATH="${MODEL_PATH:-/mnt/sdb/models/Qwen3-30B-A3B-Instruct-2507}"
PROXY_SCRIPT="${LMCACHE_DISAGG_PROXY:-/mnt/sdb/csy/p2p/LMCache-Ascend/examples/disagg_prefill/disagg_proxy_server.py}"

LOG_DIR="${LOG_ROOT:-/mnt/sdb/csy/p2p/logs-lmcache-pd-p2p-test/2p2d/lmcache/lmcache-ascend-proxy}"
mkdir -p "$LOG_DIR"

python3 "$PROXY_SCRIPT" \
  --host 0.0.0.0 \
  --port 8100 \
  --prefiller-host localhost,localhost \
  --prefiller-port 7100,7200 \
  --num-prefillers 2 \
  --decoder-host localhost \
  --decoder-port 7600 \
  --decoder-init-port 7300,7302 \
  --decoder-alloc-port 7400,7402 \
  --proxy-host localhost \
  --proxy-port 7500 \
  --num-decoders 2 \
  --model "$MODEL_PATH" \
  --pd-transfer-mode delay_pull \
  --pd-buffer-size 524288000 \
  --chunk-size 512 \
  > "$LOG_DIR/lmcache_proxy_$TIMESTAMP.log" 2>&1 &