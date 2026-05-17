# tsycdn-guardd-release

这是 `tsycdn-guardd` 的公开下载仓库，只放安装脚本和公开下载资产，不存放源码。guardd-center Web 已内嵌 Vue、Naive UI、ECharts 本地静态文件，不依赖 unpkg/CDN 外链。

## 一键安装

```bash
curl -fsSL https://github.com/1227cwx/tsycdn-guardd-release/releases/latest/download/install.sh | bash
```

执行后选择：

- `1) guardd 节点 Agent`
- `2) guardd-center 中心管理平台`
- `3) guardd-test 节点测试工具`

## 后续更新/卸载

安装完成后直接执行 `guardd`、`guardd-center` 或 `guardd-test` 进入交互菜单。
菜单内已提供“检查更新并更新”和“完全卸载”。
卸载时会询问是否删除配置、数据库/数据目录和备份目录，不再默认静默保留。

## latest release 资产

- `install.sh`
- `guardd-linux-amd64.tar.gz`
- `guardd-center-linux-amd64.tar.gz`
- `guardd-test-linux-amd64.tar.gz`
- `SHA256SUMS`
- `usage.txt`

> 说明：GitHub Release 底层必须有一个 tag，本仓库内部使用 `latest` tag 自动更新，但安装脚本和下载地址不使用版本 tag，只使用 `/releases/latest/download/`。


> v1.0.2：guardd-center 切换防护模式时必须确认 TCP/UDP 防护端口，支持单独下发端口设置；首页只显示真实节点状态和真实指标，没有真实数据时显示空状态，不再使用演示 QPS、演示地域排行或固定峰值。

> v1.0.3：guardd-center 顶部菜单收敛为总览大屏、节点管理、节点操作；节点列表新增编辑按钮，操作区改为“编辑 / 切换模式 / 更多”，页面左右边距缩小，表格和图表改为更适配当前屏幕宽度。

> v1.0.4：guardd-center 每 3 秒并发实时拉取所有节点，首页读取内存实时快照；删除节点后立即移除旧数据。添加节点改为粘贴 guardd 节点导出的 Base64 信息，添加弹窗不再设置防护端口，所有请求按钮补充加载态。

> v1.0.5：新增 guardd-test 节点本机测试工具；统一安装脚本第 3 项可安装，支持 XDP 内核自测和 veth 隔离实流测试，验证 TCP SYN、UDP、ICMP、Bad TCP Flags、混合场景是否真实命中。

> v1.0.6：guardd-center 新增“防御规则”页面；节点策略下发改为“端口白名单优先放行 + 确定 XDP 规则选择”。默认 TCP 白名单为 22，规则参数可编辑并随模式切换下发节点。

> v1.0.7：防御规则页去掉分类/层级/XDP适合度/动作/类型等冗余列，改成“规则、说明、当前设置、启用、操作”；参数不再展示 JSON，改为中文表单配置，每个设置都有问号说明弹窗。同时扩展到 ACK/RST 限速、TTL、包大小、ICMP 类型、TCP 窗口、UDP 长度、源端口 0 等确定可在 XDP L3/L4 判断的规则。

> v1.0.1：未配置到 service_ports 的端口默认 PASS，避免切换防护模式后误拦截 SSH、后台端口或其他业务端口；guardd 正常停止时会尝试卸载 XDP。

