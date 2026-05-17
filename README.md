# tsycdn-guardd-release

这是 `tsycdn-guardd` 的公开下载仓库，只放安装脚本和公开下载资产，不存放源码。guardd-center Web 已内嵌 Vue、Naive UI、ECharts 本地静态文件，不依赖 unpkg/CDN 外链。

## 一键安装

```bash
curl -fsSL https://github.com/1227cwx/tsycdn-guardd-release/releases/latest/download/install.sh | bash
```

执行后选择：

- `1) guardd 节点 Agent`
- `2) guardd-center 中心管理平台`

## 后续更新/卸载

安装完成后直接执行 `guardd` 或 `guardd-center` 进入交互菜单。
菜单内已提供“检查更新并更新”和“完全卸载”。
卸载时会询问是否删除配置、数据库/数据目录和备份目录，不再默认静默保留。

## latest release 资产

- `install.sh`
- `guardd-linux-amd64.tar.gz`
- `guardd-center-linux-amd64.tar.gz`
- `SHA256SUMS`
- `usage.txt`

> 说明：GitHub Release 底层必须有一个 tag，本仓库内部使用 `latest` tag 自动更新，但安装脚本和下载地址不使用版本 tag，只使用 `/releases/latest/download/`。


> 最新包：guardd-center Web 已改为版本号 v1.0.0、北京时间更新日期、顶部导航、自适应布局、Naive UI 原生组件提示、中文防护模式，并增强统计大屏。




> v1.0.1：未配置到 service_ports 的端口默认 PASS，避免切换防护模式后误拦截 SSH、后台端口或其他业务端口；guardd 正常停止时会尝试卸载 XDP。

