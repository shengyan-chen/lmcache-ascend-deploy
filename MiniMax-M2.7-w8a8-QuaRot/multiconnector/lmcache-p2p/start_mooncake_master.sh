#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT=50088
LOG_ROOT="/mnt/sdb/csy/p2p/logs-pd-kv/minimax27/lmcache"

export LD_LIBRARY_PATH=/usr/local/Ascend/ascend-toolkit/latest/python/site-packages:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/usr/local/lib:${LD_LIBRARY_PATH}
export PYTHONHASHSEED=0
export PYTHONPATH=$PYTHONPATH:/vllm-workspace/vllm
export MOONCAKE_CONFIG_PATH="${SCRIPT_DIR}/mooncake.json"
export ASCEND_BUFFER_POOL=4:8
export HCCL_INTRA_ROCE_ENABLE=1

mkdir -p "${LOG_ROOT}/mooncake"

pkill -9 mooncake_master 2>/dev/null || true

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
mooncake_master \
  --port "${PORT}" \
  --eviction_high_watermark_ratio 0.95 \
  --eviction_ratio 0.05 \
  --rpc_thread_num 64 \
  2>&1 | tee "${LOG_ROOT}/mooncake/mooncake_master_${TIMESTAMP}.log"
