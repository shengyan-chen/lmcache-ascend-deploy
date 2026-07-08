#!/bin/bash

export ASCEND_RT_VISIBLE_DEVICES=6,7
export VLLM_ENABLE_V1_MULTIPROCESSING=1
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export PYTHONHASHSEED=0

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

export LD_LIBRARY_PATH=/usr/local/Ascend/ascend-toolkit/latest/python/site-packages:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
export PYTHONHASHSEED=0
export PYTHONPATH=$PYTHONPATH:/vllm-workspace/vllm
export MOONCAKE_CONFIG_PATH="/mnt/sdb/csy/p2p/pd-kvpool-script-lmcache/2p2d/mooncake/mooncake.json"
export ASCEND_BUFFER_POOL=4:8
export HCCL_INTRA_ROCE_ENABLE=1

python -m vllm.entrypoints.openai.api_server \
--port 7400 \
--model /mnt/sdb/models/Qwen3-30B-A3B-Instruct-2507 \
--gpu-memory-utilization 0.9 \
--no-enable-prefix-caching \
--tensor-parallel-size 2 \
--trust-remote-code \
--block-size 128 \
--max-model-len 32768 \
--kv-transfer-config \
'{
    "kv_connector": "MultiConnector",
    "kv_role": "kv_consumer",
    "kv_connector_extra_config": {
        "connectors": [
            {
                "kv_connector": "MooncakeConnectorV1",
                "kv_role": "kv_consumer",
                "kv_port": "30300",
                "kv_connector_module_path": "vllm_ascend.distributed.mooncake_connector",
                "kv_connector_extra_config": {
                    "use_ascend_direct": true,
                    "prefill": {
                        "dp_size": 1,
                        "tp_size": 2
                    },
                    "decode": {
                        "dp_size": 1,
                        "tp_size": 2
                    }
                }
            },
            {
                "kv_connector": "AscendStoreConnector",
                "kv_role": "kv_consumer",
                "kv_connector_extra_config": {
                    "lookup_rpc_port":"0",
                    "backend": "mooncake"
                }
            }  
        ]
    }
}' \
  > /mnt/sdb/csy/p2p/logs-pd-kv/mooncake/decoder-node2/mooncake_$TIMESTAMP.log 2>&1 &
