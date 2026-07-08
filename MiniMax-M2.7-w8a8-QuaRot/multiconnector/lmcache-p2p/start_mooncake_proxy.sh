#!/bin/bash
set -eo pipefail

PORT=8100
PREFILLER_HOSTS="PREFILLER_NODE0_IP PREFILLER_NODE1_IP"
PREFILLER_PORTS="7100 7100"
DECODER_HOSTS="DECODER_NODE0_IP DECODER_NODE1_IP"
DECODER_PORTS="7100 7100"
LOG_ROOT="/mnt/sdb/csy/p2p/logs-pd-kv/minimax27/lmcache"
PROXY_SCRIPT="/vllm-workspace/vllm-ascend/examples/disaggregated_prefill_v1/load_balance_proxy_server_example.py"

read -r -a PREFILLER_HOST_ARRAY <<< "${PREFILLER_HOSTS}"
read -r -a PREFILLER_PORT_ARRAY <<< "${PREFILLER_PORTS}"
read -r -a DECODER_HOST_ARRAY <<< "${DECODER_HOSTS}"
read -r -a DECODER_PORT_ARRAY <<< "${DECODER_PORTS}"

mkdir -p "${LOG_ROOT}/proxy"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

python "${PROXY_SCRIPT}" \
  --host 0.0.0.0 \
  --port "${PORT}" \
  --prefiller-hosts "${PREFILLER_HOST_ARRAY[@]}" \
  --prefiller-ports "${PREFILLER_PORT_ARRAY[@]}" \
  --decoder-hosts "${DECODER_HOST_ARRAY[@]}" \
  --decoder-ports "${DECODER_PORT_ARRAY[@]}" \
  2>&1 | tee "${LOG_ROOT}/proxy/proxy_${TIMESTAMP}.log"
