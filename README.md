# tsycdn-guardd-release

这是 `tsycdn-guardd` 的公开下载仓库，只放安装脚本和公开下载资产，不存放源码。

## 一键安装

```bash
curl -fsSL https://github.com/1227cwx/tsycdn-guardd-release/releases/latest/download/install.sh | bash
```

执行后选择：

- `1) guardd 节点 Agent`
- `2) guardd-center 中心管理平台`

## latest release 资产

- `install.sh`
- `guardd-linux-amd64.tar.gz`
- `guardd-center-linux-amd64.tar.gz`
- `SHA256SUMS`
- `使用说明.txt`

> 说明：GitHub Release 底层必须有一个 tag，本仓库内部使用 `latest` tag 自动更新，但安装脚本和下载地址不使用版本 tag，只使用 `/releases/latest/download/`。
