# guardd-suite v0.1.0 内测版

三个二进制：

- `guardd`：CDN 节点 eBPF/XDP 防护 Agent，直接输入 `guardd` 进入交互式维护菜单。
- `guardd-center`：中心 Web 管理平台，使用本地 Vue / Naive UI / ECharts 静态资源，生产存储为 MySQL + Redis。
- `guardd-test`：节点本机防护测试工具，支持 XDP 内核自测和 veth 隔离实流测试，不走公网流量。

v0.1.0 固定核心链路：

```txt
规则库 -> 防护模板 -> 节点下发 -> 节点观察/实时防护 -> center 展示真实数据
```

关键变化：

- 节点只保留“观察模式 / 实时防护”两种执行状态。
- 防护强度、端口、白名单和规则参数全部通过防护模板体现。
- 模板拥有自己的规则副本，规则库修改不会覆盖已经被模板使用的规则。
- 内置 Web、HTTPS、QUIC、游戏 UDP、SSH 白名单、数据库内网、默认严防、观察、CDN、严格、保命等模板。
- Web 增加模板规则编辑、端口与协议画像、TOP 攻击源、硬件防火墙漏量评估、系统管理。
- guardd-center 安装时必须配置并测试 MySQL 和 Redis。

构建：

```bash
make release
```

统一安装脚本：

```bash
curl -fsSL https://github.com/1227cwx/tsycdn-guardd-release/releases/latest/download/install.sh | bash
```

普通用户：

```bash
curl -fsSL https://github.com/1227cwx/tsycdn-guardd-release/releases/latest/download/install.sh | sudo -E bash
```

安装选项：

- `1) guardd 节点 Agent`
- `2) guardd-center 中心管理平台`
- `3) guardd-test 节点测试工具`

默认 release 下载地址：

- `https://github.com/1227cwx/tsycdn-guardd-release/releases/latest/download/guardd-linux-amd64.tar.gz`
- `https://github.com/1227cwx/tsycdn-guardd-release/releases/latest/download/guardd-center-linux-amd64.tar.gz`
- `https://github.com/1227cwx/tsycdn-guardd-release/releases/latest/download/guardd-test-linux-amd64.tar.gz`
