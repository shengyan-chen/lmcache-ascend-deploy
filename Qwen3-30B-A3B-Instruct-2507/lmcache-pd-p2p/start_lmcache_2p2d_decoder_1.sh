#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export LMCACHE_CONFIG_FILE="$SCRIPT_DIR/lmcache-2p2d-tp2-decoder-1.yaml"
export ASCEND_RT_VISIBLE_DEVICES=4,5
export VLLM_ENABLE_V1_MULTIPROCESSING=1
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export PYTHONHASHSEED=0

export LD_LIBRARY_PATH=/usr/local/Ascend/ascend-toolkit/latest/python/site-packages:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
export PYTHONPATH=$PYTHONPATH:/vllm-workspace/vllm
export ASCEND_BUFFER_POOL=4:8
export HCCL_INTRA_ROCE_ENABLE=1

MODEL_PATH="${MODEL_PATH:-/mnt/sdb/models/Qwen3-30B-A3B-Instruct-2507}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_DIR="${LOG_ROOT:-/mnt/sdb/csy/p2p/logs-lmcache-pd-p2p-test/2p2d/lmcache/decoder-node1}"
mkdir -p "$LOG_DIR"

python -m vllm.entrypoints.openai.api_server \
--host 0.0.0.0 \
--port 7600 \
--model "$MODEL_PATH" \
--gpu-memory-utilization 0.9 \
--no-enable-prefix-caching \
--tensor-parallel-size 2 \
--trust-remote-code \
--block-size 128 \
--max-model-len 32768 \
--kv-transfer-config \
'{
    "kv_connector": "LMCacheAscendConnector",
    "kv_role": "kv_consumer",
    "kv_connector_extra_config": {
        "discard_partial_chunks": false,
        "lmcache_rpc_port": "consumer1",
        "skip_last_n_tokens": 1
    }
}' \
> "$LOG_DIR/lmcache_$TIMESTAMP.log" 2>&1 &
