# LMCache P2P Mooncake 启动脚本使用说明

本目录是一组基于 vLLM Ascend disaggregated prefill 的启动脚本。默认拓扑为 2 个 prefiller rank 和 2 个 decoder rank，prefiller 侧通过 `MultiConnector` 同时启用 `MooncakeConnectorV1` 和 `LMCacheAscendConnector`，decoder 侧当前使用 `MooncakeConnectorV1` 作为 KV consumer。

四个 vLLM 脚本默认使用 8 张 Ascend 卡、`tensor-parallel-size=8`、`data-parallel-size=2`。如果多个实例部署在同一台机器，需要先调整端口、设备列表和 DP 地址，避免资源和端口冲突。

## 文件说明

| 文件 | 作用 |
| --- | --- |
| `mooncake.json` | Mooncake 配置文件，默认 master 地址为 `localhost:50088`。 |
| `lmcache-p2p-prefiller-1.yaml` | prefiller rank 0 的 LMCache P2P 配置。 |
| `lmcache-p2p-prefiller-2.yaml` | prefiller rank 1 的 LMCache P2P 配置。 |
| `start_mooncake_master.sh` | 启动 `mooncake_master`，监听 `50088`。 |
| `start_lmcache_controller.sh` | 启动 `lmcache_controller`，监听 `9000`，monitor pull/reply 端口为 `9800/9900`。 |
| `start_lmcache_p2p_prefiller_1.sh` | 启动 prefiller rank 0，KV role 为 producer，使用 `lmcache-p2p-prefiller-1.yaml`。 |
| `start_lmcache_p2p_prefiller_2.sh` | 启动 prefiller rank 1，KV role 为 producer，使用 `lmcache-p2p-prefiller-2.yaml`。 |
| `start_lmcache_p2p_decoder_1.sh` | 启动 decoder rank 0，KV role 为 consumer。 |
| `start_lmcache_p2p_decoder_2.sh` | 启动 decoder rank 1，KV role 为 consumer。 |
| `start_mooncake_proxy.sh` | 启动 disaggregated prefill load balance proxy，默认监听 `8100`。 |

## 启动前检查

1. 确认运行环境已安装 Ascend Toolkit、vLLM、vLLM Ascend、LMCache，并且以下路径或命令可用：
   - `/usr/local/Ascend/ascend-toolkit/latest`
   - `/vllm-workspace/vllm`
   - `/vllm-workspace/vllm-ascend/examples/disaggregated_prefill_v1/load_balance_proxy_server_example.py`
   - `vllm`
   - `mooncake_master`
   - `lmcache_controller`

2. 修改模型和日志路径：
   - `MODEL_PATH` 默认为 `/workspace/models/MiniMax-M2.7-w8a8-QuaRot`。
   - `vllm serve` 后面的模型路径也硬编码为 `/workspace/models/MiniMax-M2.7-w8a8-QuaRot`，更换模型时两处都要检查。
   - `MODEL_NAME` 默认为 `MiniMax-M2.7`。
   - `LOG_ROOT` 默认为 `/mnt/sdb/csy/p2p/logs-pd-kv/minimax27/lmcache`。

3. 修改网络和 DP 地址：
   - 四个 vLLM 脚本中的 `local_ip="PLACEHOLDER_LOCAL_IP"` 必须替换为当前节点用于 HCCL/P2P 通信的 IP。
   - 四个 vLLM 脚本中的 `node0_ip="PLACEHOLDER_NODE0_IP"` 必须替换为对应 DP group 的 rank 0 节点 IP。
   - `nic_name` 默认为 `enp67s0f5`，需要改成实际 RoCE/HCCL 网卡名。
   - `ASCEND_RT_VISIBLE_DEVICES` 默认为 `0,1,2,3,4,5,6,7`。

4. 修改 `mooncake.json`：
   - `master_server_address` 当前为 `localhost:50088`。如果 Mooncake master 不在本机，需要替换为实际 `MASTER_IP:50088`。
   - `global_segment_size` 当前为 `140000000000`，按可用内存和部署规模调整。

5. 修改 LMCache YAML：
   - `p2p_host: "localhost"` 需要替换为对应 prefiller 节点 IP。
   - `controller_pull_url: "localhost:9800"` 和 `controller_reply_url: "localhost:9900"` 需要替换为 LMCache controller 所在节点地址。
   - 两份 YAML 的 `lmcache_instance_id` 不应重复，当前分别为 `minimax27_lmcache_2p2d_prefiller_1` 和 `minimax27_lmcache_2p2d_prefiller_2`。
   - `p2p_init_ports`、`p2p_lookup_ports`、`lmcache_worker_ports` 每个 TP rank 各一个端口，和 `tensor-parallel-size=8` 对齐。

6. 修改 proxy 后端：
   - `start_mooncake_proxy.sh` 中的 `PREFILLER_NODE0_IP`、`PREFILLER_NODE1_IP`、`DECODER_NODE0_IP`、`DECODER_NODE1_IP` 必须替换为实际服务节点 IP。
   - 默认 prefiller 和 decoder 后端端口都是 `7100 7100`，如果同机多实例部署，需要和各 vLLM 脚本保持一致。

## 默认端口

| 端口 | 使用方 |
| --- | --- |
| `50088` | `mooncake_master` |
| `8100` | load balance proxy |
| `9000` | `lmcache_controller` API |
| `9800` | `lmcache_controller` monitor pull |
| `9900` | `lmcache_controller` monitor reply |
| `7100` | vLLM OpenAI API 服务端口，当前四个 vLLM 脚本默认相同 |
| `12321` | prefiller data parallel RPC |
| `12323` | decoder data parallel RPC |
| `30000` | prefiller `MooncakeConnectorV1` KV 端口 |
| `30200` | decoder `MooncakeConnectorV1` KV 端口 |
| `5556` | KV cache events ZMQ publisher endpoint |
| `3999+` | prefiller 1 LMCache internal API |
| `4999+` | prefiller 2 LMCache internal API |
| `9950-9957` | prefiller 1 LMCache P2P init ports |
| `9970-9977` | prefiller 1 LMCache P2P lookup ports |
| `9940-9947` | prefiller 1 LMCache worker ports |
| `9850-9857` | prefiller 2 LMCache P2P init ports |
| `9870-9877` | prefiller 2 LMCache P2P lookup ports |
| `9840-9847` | prefiller 2 LMCache worker ports |

同一台机器上启动多个实例时，需要避免上述端口冲突。

## 推荐启动顺序

在 Linux 运行节点上进入目录：

```bash
cd /path/to/lmcache-p2p
chmod +x *.sh
```

1. 启动 Mooncake master：

```bash
bash start_mooncake_master.sh
```

该脚本会先执行 `pkill -9 mooncake_master`，会停止当前机器上已有的 `mooncake_master` 进程。

2. 启动 LMCache controller：

```bash
bash start_lmcache_controller.sh
```

3. 启动 prefiller rank：

```bash
bash start_lmcache_p2p_prefiller_1.sh
bash start_lmcache_p2p_prefiller_2.sh
```

4. 启动 decoder rank：

```bash
bash start_lmcache_p2p_decoder_1.sh
bash start_lmcache_p2p_decoder_2.sh
```

5. 启动 proxy：

```bash
bash start_mooncake_proxy.sh
```

请求入口为：

```text
http://<proxy_host>:8100
```

## 日志位置

默认日志根目录：

```text
/mnt/sdb/csy/p2p/logs-pd-kv/minimax27/lmcache
```

子目录：

| 子目录 | 内容 |
| --- | --- |
| `mooncake/` | Mooncake master 日志 |
| `controller/` | LMCache controller 日志 |
| `prefiller-node1/` | prefiller rank 0 日志 |
| `prefiller-node2/` | prefiller rank 1 日志 |
| `decoder-node1/` | decoder rank 0 日志 |
| `decoder-node2/` | decoder rank 1 日志 |
| `proxy/` | proxy 日志 |

查看示例：

```bash
tail -f /mnt/sdb/csy/p2p/logs-pd-kv/minimax27/lmcache/mooncake/mooncake_master_*.log
tail -f /mnt/sdb/csy/p2p/logs-pd-kv/minimax27/lmcache/controller/lmcache_controller_*.log
tail -f /mnt/sdb/csy/p2p/logs-pd-kv/minimax27/lmcache/prefiller-node1/lmcache_*.log
tail -f /mnt/sdb/csy/p2p/logs-pd-kv/minimax27/lmcache/decoder-node1/lmcache_*.log
```

## 检查和停止

检查监听端口：

```bash
ss -lntp | egrep ':50088|:8100|:9000|:9800|:9900|:7100|:12321|:12323|:30000|:30200|:5556'
```

检查 LMCache P2P 端口：

```bash
ss -lntp | egrep ':39[0-9][0-9]|:49[0-9][0-9]|:98[0-9][0-9]|:99[0-9][0-9]'
```

停止进程示例：

```bash
pkill -f 'load_balance_proxy_server_example.py'
pkill -f 'lmcache_controller'
pkill -f 'vllm serve /workspace/models/MiniMax-M2.7-w8a8-QuaRot'
pkill -9 mooncake_master
```

## 常见注意事项

- `PLACEHOLDER_LOCAL_IP` 和 `PLACEHOLDER_NODE0_IP` 不替换时，HCCL、DP RPC 和 KV event topic 都会使用错误地址。
- 两份 LMCache YAML 中的 `localhost` 只适合同机验证，跨节点部署必须替换为真实 IP。
- `start_lmcache_p2p_prefiller_2.sh` 当前显式导出 `MOONCAKE_CONFIG_PATH`，但 `start_lmcache_p2p_prefiller_1.sh` 和两个 decoder 脚本当前未导出；如果运行时 Mooncake connector 找不到配置，需要对齐补上 `MOONCAKE_CONFIG_PATH="${LMCACHE_SCRIPT_ROOT}/mooncake.json"`。
- 四个 vLLM 脚本默认都监听 `7100` 且使用 `ASCEND_RT_VISIBLE_DEVICES=0,1,2,3,4,5,6,7`，不适合直接在同一台 8 卡机器上同时启动。
- prefiller 的 `--max-num-batched-tokens` 为 `32768`，decoder 为 `256`，这是当前脚本面向 PD 分离的默认差异。
- YAML 中 `extra_config.use_host_staging: True` 依赖 `transfer_channel: "hccl"` 和 `p2p_delay_pull: True`，调整 P2P 模式时需要一起检查。
