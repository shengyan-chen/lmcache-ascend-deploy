#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MODEL_PATH="${MODEL_PATH:-xxx}"
PROXY_SCRIPT="${LMCACHE_DISAGG_PROXY:-/xxx/LMCache-Ascend/examples/disagg_prefill/disagg_proxy_server.py}"
PREFILL_HOST="${PREFILL_IP:-xxx}"
DECODE_HOST="${DECODE_IP:-xxx}"
PROXY_NOTIFY_HOST="${PROXY_NOTIFY_HOST:-xxx}"
DECODER_INIT_PORTS="${DECODER_INIT_PORTS:-7300,7301,7302,7303,7304,7305,7306,7307}"
DECODER_ALLOC_PORTS="${DECODER_ALLOC_PORTS:-7400,7401,7402,7403,7404,7405,7406,7407}"
LOG_DIR="${LOG_ROOT:-${SCRIPT_DIR}/logs}/proxy"
TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"

if [[ ! -d "$MODEL_PATH" ]]; then
    echo "MODEL_PATH does not exist inside the container: $MODEL_PATH" >&2
    exit 2
fi
if [[ ! -f "$PROXY_SCRIPT" ]]; then
    echo "LMCache-Ascend proxy does not exist inside the container: $PROXY_SCRIPT" >&2
    echo "Mount LMCache-Ascend at /workspace/LMCache-Ascend or set LMCACHE_DISAGG_PROXY." >&2
    exit 2
fi

unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY
mkdir -p "$LOG_DIR"

echo "Starting LMCache 1P1D proxy at 0.0.0.0:8100"
echo "Prefill: ${PREFILL_HOST}:6700; Decode: ${DECODE_HOST}:6720"
echo "PD notification endpoint: ${PROXY_NOTIFY_HOST}:7500"
echo "Log: ${LOG_DIR}/lmcache_proxy_${TIMESTAMP}.log"

python3 "$PROXY_SCRIPT" \
    --host 0.0.0.0 \
    --port 8100 \
    --prefiller-host "$PREFILL_HOST" \
    --prefiller-port 6700 \
    --num-prefillers 1 \
    --decoder-host "$DECODE_HOST" \
    --decoder-port 6720 \
    --decoder-init-port "$DECODER_INIT_PORTS" \
    --decoder-alloc-port "$DECODER_ALLOC_PORTS" \
    --proxy-host "$PROXY_NOTIFY_HOST" \
    --proxy-port 7500 \
    --num-decoders 1 \
    --model "$MODEL_PATH" \
    --pd-transfer-mode delay_pull \
    --pd-buffer-size 2415919104 \
    --chunk-size 256 \
    2>&1 | tee "${LOG_DIR}/lmcache_proxy_${TIMESTAMP}.log"