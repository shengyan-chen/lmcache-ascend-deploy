#!/bin/bash
set -eo pipefail

PORT=9000
PULL_PORT=9800
REPLY_PORT=9900
LOG_ROOT="/mnt/sdb/csy/p2p/logs-pd-kv/minimax27/lmcache-pd-p2p"

mkdir -p "${LOG_ROOT}/controller"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

PYTHONHASHSEED=0 lmcache_controller \
  --host 0.0.0.0 \
  --port "${PORT}" \
  --monitor-ports "{\"pull\": ${PULL_PORT}, \"reply\": ${REPLY_PORT}}" \
  2>&1 | tee "${LOG_ROOT}/controller/lmcache_controller_${TIMESTAMP}.log"
