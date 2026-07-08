set -eo pipefail

PYTHONHASHSEED=0 lmcache_controller \
  --host 0.0.0.0 \
  --port 9000 \
  --monitor-ports '{"pull": 9800, "reply": 9900}'
