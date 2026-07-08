python /vllm-workspace/vllm-ascend/examples/disaggregated_prefill_v1/load_balance_proxy_server_example.py \
    --host 0.0.0.0 \
    --port 8100 \
    --prefiller-hosts \
         localhost \
         localhost \
    --prefiller-ports \
         7100 7200 \
    --decoder-hosts \
         localhost \
         localhost \
    --decoder-ports \
         7300 7400

# 2>&1 | split -b 5M -d -a 5 - /data/logs/proxy_log_ &