# AscendStore Mooncake 启动脚本使用说明

本目录是一组基于 vLLM Ascend disaggregated prefill 的启动脚本，KV 传输使用 `MultiConnector`，同时启用 `MooncakeConnectorV1` 和 `AscendStoreConnector`，其中 AscendStore 后端配置为 `mooncake`。

默认拓扑为 2 个 prefiller rank 和 2 个 decoder rank。各 vLLM 脚本默认使用 8 张 Ascend 卡、`tensor-parallel-size=8`、`data-parallel-size=2`，因此通常按不同节点或不同资源组启动；如果放在同一台机器，需要先调整端口、设备列表和 DP 地址。

## 文件说明

| 文件 | 作用 |
| --- | --- |
| `mooncake.json` | Mooncake/AscendStore 配置文件，由 `MOONCAKE_CONFIG_PATH` 指向。 |
| `start_mooncacke_master.sh` | 启动 `mooncake_master`，监听 `50088`。文件名当前拼写为 `mooncacke`。 |
| `start_mooncake_p2p_prefiller_1.sh` | 启动 prefiller rank 0，作为 KV producer。 |
| `start_mooncake_p2p_prefiller_2.sh` | 启动 prefiller rank 1，作为 KV producer。 |
| `start_mooncake_p2p_decoder_1.sh` | 启动 decoder rank 0，作为 KV consumer。 |
| `start_mooncake_p2p_decoder_2.sh` | 启动 decoder rank 1，作为 KV consumer。 |
| `start_mooncake_proxy.sh` | 启动 disaggregated prefill load balance proxy，默认监听 `8100`。 |

## 启动前检查

1. 确认运行环境已安装 Ascend Toolkit、vLLM、vLLM Ascend，并且以下路径或命令可用：
   - `/usr/local/Ascend/ascend-toolkit/latest`
   - `/vllm-workspace/vllm`
   - `/vllm-workspace/vllm-ascend/examples/disaggregated_prefill_v1/load_balance_proxy_server_example.py`
   - `vllm`
   - `mooncake_master`

2. 修改 `mooncake.json`：
   - 将 `master_server_address` 中的 `MOONCAKE_MASTER_IP:50088` 替换为实际 Mooncake master 节点 IP 和端口。
   - `global_segment_size` 当前为 `140000000000`，按可用内存和部署规模调整。

3. 修改各启动脚本中的本地环境：
   - `MODEL_PATH` 和 `vllm serve` 后面的模型路径默认为 `/workspace/models/MiniMax-M2.7-w8a8-QuaRot`。
   - `MODEL_NAME` 默认为 `MiniMax-M2.7`。
   - `LOG_ROOT` 默认为 `/mnt/sdb/csy/p2p/logs-pd-kv/minimax27/base-mooncake`。
   - `nic_name` 默认为 `enp67s0f5`，需要改成实际 RoCE/HCCL 网卡名。
   - `ASCEND_RT_VISIBLE_DEVICES` 默认为 `0,1,2,3,4,5,6,7`。

4. 修改 DP rank 0 地址：
   - prefiller 两个脚本都设置了 `--data-parallel-size 2`，rank 1 脚本里的 `node0_ip` 应指向 prefiller rank 0 节点 IP。
   - decoder 两个脚本都设置了 `--data-parallel-size 2`，`start_mooncake_p2p_decoder_2.sh` 中的 `node0_ip="DECODER_NODE0_IP"` 必须替换为 decoder rank 0 节点 IP。

5. 修改 proxy 后端地址：
   - `start_mooncake_proxy.sh` 当前生效配置为本机 `localhost` 后端，prefiller 端口 `7100/7200`，decoder 端口 `7300/7400`。
   - 如果使用本目录 vLLM 脚本的默认配置，各服务脚本默认都监听 `7100`，需要把 proxy 的 `--prefiller-hosts`、`--prefiller-ports`、`--decoder-hosts`、`--decoder-ports` 改成实际节点 IP 和端口。
   - 脚本下半部分注释里有变量化写法，可按部署拓扑恢复使用。

## 默认端口

| 端口 | 使用方 |
| --- | --- |
| `50088` | `mooncake_master` |
| `8100` | load balance proxy |
| `7100` | vLLM OpenAI API 服务端口，当前四个 vLLM 脚本默认相同 |
| `12321` | prefiller data parallel RPC |
| `12323` | decoder data parallel RPC |
| `30000` | prefiller `MooncakeConnectorV1` KV 端口 |
| `30200` | decoder `MooncakeConnectorV1` KV 端口 |
| `5556` | KV cache events ZMQ publisher endpoint |

同一台机器上启动多个实例时，需要避免上述端口冲突。

## 推荐启动顺序

在 Linux 运行节点上进入目录：

```bash
cd /path/to/ascendstore
chmod +x *.sh
```

1. 启动 Mooncake master：

```bash
bash start_mooncacke_master.sh
```

该脚本会先执行 `pkill -9 mooncake_master`，会停止当前机器上已有的 `mooncake_master` 进程。

2. 启动 prefiller rank：

```bash
bash start_mooncake_p2p_prefiller_1.sh
bash start_mooncake_p2p_prefiller_2.sh
```

3. 启动 decoder rank：

```bash
bash start_mooncake_p2p_decoder_1.sh
bash start_mooncake_p2p_decoder_2.sh
```

4. 启动 proxy：

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
/mnt/sdb/csy/p2p/logs-pd-kv/minimax27/base-mooncake
```

子目录：

| 子目录 | 内容 |
| --- | --- |
| `mooncake/` | Mooncake master 日志 |
| `prefiller-node1/` | prefiller rank 0 日志 |
| `prefiller-node2/` | prefiller rank 1 日志 |
| `decoder-node1/` | decoder rank 0 日志 |
| `decoder-node2/` | decoder rank 1 日志 |
| `proxy/` | proxy 日志，当前生效 proxy 脚本未写入日志文件，恢复注释中的变量化版本后会写入该目录 |

查看示例：

```bash
tail -f /mnt/sdb/csy/p2p/logs-pd-kv/minimax27/base-mooncake/mooncake/mooncake_master_*.log
tail -f /mnt/sdb/csy/p2p/logs-pd-kv/minimax27/base-mooncake/prefiller-node1/mooncake_*.log
tail -f /mnt/sdb/csy/p2p/logs-pd-kv/minimax27/base-mooncake/decoder-node1/mooncake_*.log
```

## 检查和停止

检查监听端口：

```bash
ss -lntp | egrep ':50088|:8100|:7100|:12321|:12323|:30000|:30200|:5556'
```

停止进程示例：

```bash
pkill -f 'load_balance_proxy_server_example.py'
pkill -f 'vllm serve /workspace/models/MiniMax-M2.7-w8a8-QuaRot'
pkill -9 mooncake_master
```

## 常见注意事项

- `mooncake.json` 的 `master_server_address` 不替换时，Mooncake/AscendStore 无法连接 master。
- `start_mooncake_p2p_decoder_2.sh` 的 `DECODER_NODE0_IP` 不替换时，decoder DP rank 1 无法加入正确的 rank 0。
- 脚本中的 `MODEL_PATH` 变量没有被所有 `vllm serve` 命令引用；更换模型路径时需要同时检查变量和命令行参数。
- `start_mooncake_proxy.sh` 当前生效的 localhost 后端配置与四个 vLLM 脚本的默认端口不完全一致，部署前必须按实际 topology 修改。
- 四个 vLLM 脚本默认都使用 `ASCEND_RT_VISIBLE_DEVICES=0,1,2,3,4,5,6,7`，不适合直接在同一台 8 卡机器上同时启动。
