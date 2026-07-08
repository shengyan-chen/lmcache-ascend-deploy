#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODEL_PATH="/workspace/models/MiniMax-M2.7-w8a8-QuaRot"
MODEL_NAME="MiniMax-M2.7"
LMCACHE_SCRIPT_ROOT="$SCRIPT_DIR"
LOG_ROOT="/mnt/sdb/csy/p2p/logs-pd-kv/minimax27/lmcache"

nic_name="enp67s0f5"
local_ip="PLACEHOLDER_LOCAL_IP"
node0_ip="PLACEHOLDER_NODE0_IP"

export HCCL_OP_EXPANSION_MODE="AIV"
export HCCL_IF_IP=$local_ip
export GLOO_SOCKET_IFNAME=$nic_name
export TP_SOCKET_IFNAME=$nic_name
export HCCL_SOCKET_IFNAME=$nic_name
export HCCL_BUFFSIZE=1024
export HCCL_INTRA_ROCE_ENABLE=1
export HCCL_CONNECT_TIMEOUT=120

export OMP_PROC_BIND=false
export OMP_NUM_THREADS=16
export VLLM_USE_V1=1
export VLLM_ASCEND_ENABLE_FLASHCOMM1=1

export PYTORCH_NPU_ALLOC_CONF=expandable_segments:True
export TASK_QUEUE_ENABLE=1
export CPU_AFFINITY_CONF=1
export ASCEND_AGGREGATE_ENABLE=1
export ASCEND_TRANSPORT_PRINT=1
export ACL_OP_INIT_MODE=1
export VLLM_NIXL_ABORT_REQUEST_TIMEOUT=300

export LD_LIBRARY_PATH=/usr/local/Ascend/ascend-toolkit/latest/python/site-packages:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/usr/local/lib:${LD_LIBRARY_PATH}
export PYTHONHASHSEED=0
export PYTHONPATH=$PYTHONPATH:/vllm-workspace/vllm

timestamp=$(date "+%Y%m%d%H%M%S")

export ASCEND_RT_VISIBLE_DEVICES=0,1,2,3,4,5,6,7

mkdir -p "${LOG_ROOT}/decoder-node1"

vllm serve /workspace/models/MiniMax-M2.7-w8a8-QuaRot \
  --served-model-name MiniMax-M2.7 \
  --gpu-memory-utilization 0.9 \
  --trust-remote-code \
  --dtype bfloat16 \
  --port 7100 \
  --data-parallel-size 2 \
  --data-parallel-rank 0 \
  --data-parallel-address $node0_ip \
  --data-parallel-rpc-port 12323 \
  --tensor-parallel-size 8 \
  --enable-expert-parallel \
  --max-num-seqs 32 \
  --max-num-batched-tokens 256 \
  --compilation-config '{"cudagraph_mode":"FULL_DECODE_ONLY"}' \
  --enable-auto-tool-choice \
  --tool-call-parser minimax_m2 \
  --reasoning-parser minimax_m2_append_think \
  --host 0.0.0.0 \
  --model-loader-extra-config '{"enable_multithread_load":true,"num_threads":16}' \
  --kv-transfer-config \
  '{
    "kv_connector": "MooncakeConnectorV1",
    "kv_role": "kv_consumer",
    "kv_port": "30200",
    "kv_connector_module_path": "vllm_ascend.distributed.mooncake_connector",
    "kv_connector_extra_config": {
        "use_ascend_direct": true,
        "prefill": {
            "dp_size": 2,
            "tp_size": 8
        },
        "decode": {
            "dp_size": 2,
            "tp_size": 8
        }
    }
  }' \
  --kv-events-config "{\"enable_kv_cache_events\": true,\"publisher\": \"zmq\",\"endpoint\": \"tcp://*:5556\",\"topic\": \"kv@${local_ip}@${MODEL_NAME}\"}" \
  --enable-prompt-tokens-details \
  > "${LOG_ROOT}/decoder-node1/lmcache_${timestamp}.log" 2>&1 &
