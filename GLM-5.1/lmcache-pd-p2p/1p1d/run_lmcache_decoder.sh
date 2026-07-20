#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

NIC_NAME="${NIC_NAME:-xxx}"
LOCAL_IP="${DECODE_IP:-xxx}"
MODEL_PATH="${MODEL_PATH:-xxx}"
LMCACHE_CONFIG_FILE="${LMCACHE_CONFIG_FILE:-${SCRIPT_DIR}/lmcache-glm51-1p1d-decode.yaml}"
LOG_DIR="${LOG_ROOT:-${SCRIPT_DIR}/logs}/decode"
TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"

if [[ ! -d "$MODEL_PATH" ]]; then
    echo "MODEL_PATH does not exist inside the container: $MODEL_PATH" >&2
    exit 2
fi
if [[ ! -f "$LMCACHE_CONFIG_FILE" ]]; then
    echo "LMCACHE_CONFIG_FILE does not exist: $LMCACHE_CONFIG_FILE" >&2
    exit 2
fi
if command -v ip >/dev/null 2>&1 && ! ip -o -4 addr show dev "$NIC_NAME" 2>/dev/null | grep -Fq "$LOCAL_IP"; then
    echo "NIC_NAME=$NIC_NAME does not own DECODE_IP=$LOCAL_IP" >&2
    ip -o -4 addr show >&2 || true
    exit 2
fi

mkdir -p "$LOG_DIR"

export LMCACHE_CONFIG_FILE

export HCCL_OP_EXPANSION_MODE="AIV"

export HCCL_IF_IP="$LOCAL_IP"
export GLOO_SOCKET_IFNAME="$NIC_NAME"
export TP_SOCKET_IFNAME="$NIC_NAME"
export HCCL_SOCKET_IFNAME="$NIC_NAME"

#Mooncake
export OMP_PROC_BIND=false
export OMP_NUM_THREADS="${OMP_NUM_THREADS:-1}"

export PYTORCH_NPU_ALLOC_CONF="${PYTORCH_NPU_ALLOC_CONF:-expandable_segments:True}"
export HCCL_BUFFSIZE="${HCCL_BUFFSIZE:-256}"

export ASCEND_AGGREGATE_ENABLE=1
export ASCEND_TRANSPORT_PRINT=1
export ACL_OP_INIT_MODE=1
export ASCEND_A3_ENABLE=1

# Timeout (in seconds) for automatically releasing the prefiller’s KV cache for a particular request.
export ASCEND_BUFFER_POOL="${ASCEND_BUFFER_POOL:-4:8}"
export TASK_QUEUE_ENABLE=1
export ASCEND_RT_VISIBLE_DEVICES="${DECODE_DEVICES:-8,9,10,11,12,13,14,15}"
# export VLLM_ASCEND_ENABLE_FUSED_MC2=1
# export VLLM_ASCEND_ENABLE_MLAPO=1
# 8,9,10,11,12,13,14,15
# 0,1,2,3,4,5,6,7

export VLLM_USE_V1=1
export VLLM_ENABLE_V1_MULTIPROCESSING=1
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export PYTHONHASHSEED=0

export PYTHONPATH="/vllm-workspace/vllm${PYTHONPATH:+:${PYTHONPATH}}"
export LD_LIBRARY_PATH="/usr/local/Ascend/ascend-toolkit/latest/python/site-packages:/usr/local/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

echo "Starting GLM-5.1-W4A8 LMCache Decode at ${LOCAL_IP}:6720"
echo "LMCache config: $LMCACHE_CONFIG_FILE"
echo "Log: ${LOG_DIR}/lmcache_decode_${TIMESTAMP}.log"

vllm serve "$MODEL_PATH" \
    --host 0.0.0.0 \
    --port 6720 \
    --data-parallel-size 1 \
    --tensor-parallel-size 16 \
    --enable-expert-parallel \
    --profiler-config '{"profiler": "torch", "torch_profiler_dir": "./vllm_profile", "torch_profiler_with_stack": false}' \
    --seed 1024 \
    --served-model-name glm-5 \
    --max-model-len 32768 \
    --max-num-batched-tokens 32 \
    --compilation-config '{"cudagraph_mode":"FULL_DECODE_ONLY"}' \
    --additional-config '{"recompute_scheduler_enable": true}' \
    --trust-remote-code \
    --max-num-seqs 16 \
    --no-enable-prefix-caching \
    --gpu-memory-utilization 0.92 \
    --quantization ascend \
    --block-size 128 \
    --enable-auto-tool-choice \
    --tool-call-parser glm47 \
    --reasoning-parser glm45 \
    --kv-transfer-config '{
        "kv_connector": "LMCacheAscendConnector",
        "kv_role": "kv_consumer",
        "kv_connector_extra_config": {
            "discard_partial_chunks": false,
            "lmcache_rpc_port": "consumer1",
            "skip_last_n_tokens": 1
        }
    }' \
    2>&1 | tee "${LOG_DIR}/lmcache_decode_${TIMESTAMP}.log"

# --speculative-config '{"num_speculative_tokens": 3, "method": "deepseek_mtp"}' \
    # --no-enable-prefix-caching \