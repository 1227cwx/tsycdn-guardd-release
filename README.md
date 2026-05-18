# guardd-suite

三个二进制：

- `guardd`：CDN 节点 eBPF/XDP 防护 Agent。直接输入 `guardd` 进入交互式维护菜单；systemd 通过 `GUARDD_MODE=service` 启动服务模式。
- `guardd-center`：中心 Web 管理平台。内嵌 Naive UI 页面、Vue/ECharts 本地静态依赖和 SQLite 存储，不依赖 unpkg/CDN 外链。直接输入 `guardd-center` 进入交互式维护菜单；systemd 通过 `GUARDD_CENTER_MODE=service` 启动服务模式。
- `guardd-test`：节点本机防护测试工具。直接输入 `guardd-test` 进入交互式菜单，支持 XDP 内核自测和 veth 隔离实流测试，不走公网流量。

v1.0.7 起，`guardd-center` 防御规则页改为中文表单配置，不再展示 JSON 参数；每个设置项带问号说明弹窗。节点下发策略按“端口白名单优先放行 -> 业务防护端口 -> 已确定适合 XDP 的防御规则”执行；默认 TCP 白名单为 `22`，当前可下发规则包括 SYN/ACK/RST/UDP/ICMP 限速、异常 TCP Flags、IP 分片、畸形包、TTL、包大小、ICMP 类型、TCP 窗口、UDP 长度、源端口 0 等 L3/L4 规则。

v1.0.8 起，`guardd-center` 增加节点策略版本闭环：每次策略下发都会生成 `policy_version` 和 `policy_digest`，节点成功应用后上报 applied policy；中心可显示期望版本、已生效版本、策略漂移状态，并支持回滚到上一个成功策略快照。

构建：

```bash
make release
```

生产统一安装脚本：

```bash
curl -fsSL https://github.com/1227cwx/tsycdn-guardd-release/releases/latest/download/install.sh | bash
```

执行后选择安装：

- `1) guardd 节点 Agent`
- `2) guardd-center 中心管理平台`
- `3) guardd-test 节点测试工具`

默认二进制包下载地址：

- `https://github.com/1227cwx/tsycdn-guardd-release/releases/latest/download/guardd-linux-amd64.tar.gz`
- `https://github.com/1227cwx/tsycdn-guardd-release/releases/latest/download/guardd-center-linux-amd64.tar.gz`
- `https://github.com/1227cwx/tsycdn-guardd-release/releases/latest/download/guardd-test-linux-amd64.tar.gz`


> v1.0.9：继续落地最终升级方案：新增 IPv4 CIDR ignore/drop LPM 集合、防锁死优先放行、auto-ban dry-run/临时封禁配置、per-cpu 包/字节统计、XDP ringbuf 采样事件、Prometheus 指标、节点 Web 远程更新、center Web 系统管理/自更新、管理员密码修改、CI 生成 BPF/测试/打包流程。

> v1.0.10：完善防御规则管理体验：自定义规则支持删除、内置规则禁止删除；规则 Key、规则名称、执行模型、执行动作增加详细问号说明；切换执行模型时自动刷新模型说明和参数表单；每个规则参数的帮助说明补充用途、填写范围、影响和推荐灰度流程。

> v1.0.11：补齐 guardd-center 顶部导航入口：IP 集合、系统管理重新显示；系统管理页展示版本、Web 配置、管理员密码维护和 center 检查/执行更新按钮；节点列表“更多”菜单增加检查节点更新和执行节点更新。

> v1.0.13：巡检修复系统管理保存路径和 center 更新目标路径：guardd-center 使用自定义配置文件启动时，Web 保存配置会写回当前配置文件；center 自更新会优先更新实际安装的 `/usr/local/bin/guardd-center`，不存在时回退到当前运行二进制。
