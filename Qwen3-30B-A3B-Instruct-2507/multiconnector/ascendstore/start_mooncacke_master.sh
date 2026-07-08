mooncake_master --port 50088 --eviction_high_watermark_ratio 0.95 --eviction_ratio 0.05 --rpc_thread_num 64 

# 2>&1 | split -b 5M -d -a 5 - /data