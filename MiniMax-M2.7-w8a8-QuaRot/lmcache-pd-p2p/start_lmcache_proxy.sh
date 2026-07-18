#!/bin/bash
set -eo pipefail

PORT=8100
MODEL_PATH="/workspace/models/MiniMax-M2.7-w8a8-QuaRot"
PROXY_SCRIPT="/workspace/LMCache-Ascend/examples/disagg_prefill/disagg_proxy_server.py"
PREFILLER_HOSTS="PREFILLER_NODE0_IP,PREFILLER_NODE1_IP"
PREFILLER_PORTS="7100,7100"
DECODER_HOSTS="DECODER_NODE0_IP,DECODER_NODE1_IP"
DECODER_PORTS="7100,7100"
DECODER_INIT_PORTS="7300,7301,7302,7303,7304,7305,7306,7307"
DECODER_ALLOC_PORTS="7400,7401,7402,7403,7404,7405,7406,7407"
PROXY_HOST="PROXY_NODE_IP"
PROXY_PORT=7500
PD_BUFFER_SIZE=2415919104
CHUNK_SIZE=256
LOG_ROOT="/mnt/sdb/csy/p2p/logs-pd-kv/minimax27/lmcache-pd-p2p"

mkdir -p "${LOG_ROOT}/proxy"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

python3 "${PROXY_SCRIPT}" \
  --host 0.0.0.0 \
  --port "${PORT}" \
  --prefiller-host "${PREFILLER_HOSTS}" \
  --prefiller-port "${PREFILLER_PORTS}" \
  --num-prefillers 2 \
  --decoder-host "${DECODER_HOSTS}" \
  --decoder-port "${DECODER_PORTS}" \
  --decoder-init-port "${DECODER_INIT_PORTS}" \
  --decoder-alloc-port "${DECODER_ALLOC_PORTS}" \
  --proxy-host "${PROXY_HOST}" \
  --proxy-port "${PROXY_PORT}" \
  --num-decoders 2 \
  --model "${MODEL_PATH}" \
  --pd-buffer-size "${PD_BUFFER_SIZE}" \
  --chunk-size "${CHUNK_SIZE}" \
  2>&1 | tee "${LOG_ROOT}/proxy/proxy_${TIMESTAMP}.log"
