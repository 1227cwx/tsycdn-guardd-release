#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# guardd-suite 统一安装脚本
# 脚本版本：v0.1.0003
# 默认使用本项目 GitHub Releases 的三个发布包。
# 如需私有镜像，可通过环境变量覆盖：
#   GUARDD_PACKAGE_URL=https://your-url/guardd-linux-amd64.tar.gz
#   GUARDD_CENTER_PACKAGE_URL=https://your-url/guardd-center-linux-amd64.tar.gz
#   GUARDD_TEST_PACKAGE_URL=https://your-url/guardd-test-linux-amd64.tar.gz
#   GEOIP_ASSETS_URL=https://your-url/geoip-assets.tar.gz
# ============================================================
INSTALLER_VERSION="${INSTALLER_VERSION:-v0.1.0004}"
GUARDD_PACKAGE_URL="${GUARDD_PACKAGE_URL:-https://ghfast.top/https://github.com/1227cwx/tsycdn-guardd-release/releases/latest/download/guardd-linux-amd64.tar.gz}"
GUARDD_PACKAGE_FALLBACK_URL="${GUARDD_PACKAGE_FALLBACK_URL:-https://github.com/1227cwx/tsycdn-guardd-release/releases/latest/download/guardd-linux-amd64.tar.gz}"
GUARDD_CENTER_PACKAGE_URL="${GUARDD_CENTER_PACKAGE_URL:-https://ghfast.top/https://github.com/1227cwx/tsycdn-guardd-release/releases/latest/download/guardd-center-linux-amd64.tar.gz}"
GUARDD_CENTER_PACKAGE_FALLBACK_URL="${GUARDD_CENTER_PACKAGE_FALLBACK_URL:-https://github.com/1227cwx/tsycdn-guardd-release/releases/latest/download/guardd-center-linux-amd64.tar.gz}"
GUARDD_TEST_PACKAGE_URL="${GUARDD_TEST_PACKAGE_URL:-https://ghfast.top/https://github.com/1227cwx/tsycdn-guardd-release/releases/latest/download/guardd-test-linux-amd64.tar.gz}"
GUARDD_TEST_PACKAGE_FALLBACK_URL="${GUARDD_TEST_PACKAGE_FALLBACK_URL:-https://github.com/1227cwx/tsycdn-guardd-release/releases/latest/download/guardd-test-linux-amd64.tar.gz}"
GEOIP_ASSETS_URL="${GEOIP_ASSETS_URL:-https://ghfast.top/https://github.com/1227cwx/tsycdn-guardd-release/releases/latest/download/geoip-assets.tar.gz}"
GEOIP_ASSETS_FALLBACK_URL="${GEOIP_ASSETS_FALLBACK_URL:-https://github.com/1227cwx/tsycdn-guardd-release/releases/latest/download/geoip-assets.tar.gz}"

TTY=/dev/tty
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

ask(){ local p="$1" d="${2:-}" v; if [ -n "$d" ]; then read -r -p "$p [$d]: " v < "$TTY"; echo "${v:-$d}"; else read -r -p "$p: " v < "$TTY"; echo "$v"; fi; }
ask_secret(){ local p="$1" v; read -r -s -p "$p: " v < "$TTY"; echo >&2; echo "$v"; }
yesno(){ local p="$1" d="${2:-Y}" v; read -r -p "$p [$d]: " v < "$TTY"; v="${v:-$d}"; [[ "$v" =~ ^[Yy] ]]; }
need_root(){ [ "$(id -u)" = "0" ] || { echo "请使用 root 执行，普通用户请使用 sudo -E bash install.sh"; exit 1; }; }
need_common(){ command -v curl >/dev/null || { echo "缺少 curl"; exit 1; }; command -v tar >/dev/null || { echo "缺少 tar"; exit 1; }; command -v systemctl >/dev/null || { echo "缺少 systemd"; exit 1; }; }
ensure_cmd(){
  local cmd="$1" pkg="$2"
  if command -v "$cmd" >/dev/null 2>&1; then return 0; fi
  if command -v apt-get >/dev/null 2>&1; then
    echo "缺少 $cmd，正在尝试安装 $pkg ..."
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"
  fi
  command -v "$cmd" >/dev/null 2>&1 || { echo "缺少 $cmd，请先安装 $pkg"; exit 1; }
}
need_center_deps(){ ensure_cmd mysql default-mysql-client; ensure_cmd redis-cli redis-tools; }

download_file(){
  local out="$1" primary="$2" fallback="${3:-}"
  echo "Download URL: $primary"
  if curl -fL --retry 3 -o "$out" "$primary"; then
    return 0
  fi
  if [ -n "$fallback" ] && [ "$fallback" != "$primary" ]; then
    echo "Primary download failed, fallback URL: $fallback"
    curl -fL --retry 3 -o "$out" "$fallback"
    return $?
  fi
  return 1
}

test_mysql_conn(){
  local host="$1" port="$2" db="$3" user="$4" pass="$5" tls="$6"
  local ssl_args=()
  if [ "$tls" = "true" ]; then ssl_args=(--ssl-mode=REQUIRED); fi
  local sql="CREATE TABLE IF NOT EXISTS guardd_install_check(id INT PRIMARY KEY, v VARCHAR(32)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4; INSERT INTO guardd_install_check(id,v) VALUES(1,'ok') ON DUPLICATE KEY UPDATE v='ok'; SELECT v FROM guardd_install_check WHERE id=1; DELETE FROM guardd_install_check WHERE id=1;"
  MYSQL_PWD="$pass" mysql -h "$host" -P "$port" -u "$user" "${ssl_args[@]}" --default-character-set=utf8mb4 "$db" -N -B -e "$sql" | grep -q '^ok$'
}

test_redis_conn(){
  local addr="$1" pass="$2" db="$3" tls="$4"
  local host="${addr%:*}"
  local port="${addr##*:}"
  if [ "$host" = "$port" ]; then
    host="127.0.0.1"
    port="$addr"
  fi
  local args=(-h "$host" -p "$port" -n "$db")
  [ -n "$pass" ] && args+=(-a "$pass" --no-auth-warning)
  [ "$tls" = "true" ] && args+=(--tls)
  redis-cli "${args[@]}" PING | grep -qi PONG || return 1
  local key="guardd:install:test:$$"
  redis-cli "${args[@]}" SET "$key" ok EX 30 >/dev/null || return 1
  [ "$(redis-cli "${args[@]}" GET "$key")" = "ok" ] || return 1
  redis-cli "${args[@]}" DEL "$key" >/dev/null || return 1
}

install_geoip_assets(){
  local target="/var/lib/guardd-center/geoip"
  if ! yesno "是否安装 GeoIP 离线资源（中文地区、ASN、国旗、世界地图）" "Y"; then
    return 0
  fi
  echo "GeoIP 资源 URL: $GEOIP_ASSETS_URL"
  install -d -m 0755 "$target"
  download_file "$TMP/geoip-assets.tar.gz" "$GEOIP_ASSETS_URL" "$GEOIP_ASSETS_FALLBACK_URL"
  tar -C "$target" -xzf "$TMP/geoip-assets.tar.gz"
  chown -R root:root "$target"
  chmod -R a+rX "$target"
  echo "GeoIP 离线资源已安装到 $target"
}

install_guardd(){
  echo "========================================"
  echo " guardd 节点安装向导"
  echo "========================================"
  echo "安装包 URL: $GUARDD_PACKAGE_URL"
  mount | grep -q ' /sys/fs/bpf ' || mount -t bpf bpf /sys/fs/bpf || true
  ip -br addr || true
  IFACE=$(ask "请选择防护网卡" "eth0")
  NODE_NAME=$(ask "设置节点名称" "cdn-node-$(hostname)")
  NODE_GROUP=$(ask "设置节点分组" "default")
  API_IP=$(ask "设置 API 监听 IP" "0.0.0.0")
  API_PORT=$(ask "设置 API 监听端口" "9443")
  CENTER_CIDR=$(ask "允许访问 API 的 center IP/CIDR" "0.0.0.0/0")
  KEY_CHOICE=$(ask "API Key：1 自动生成，2 手动输入" "1")
  if [ "$KEY_CHOICE" = "2" ]; then API_KEY=$(ask_secret "请输入 API Key"); else API_KEY=$(openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'); fi
  MODE_CHOICE=$(ask "XDP 初始模式：1 observe-only，2 enforce" "1")
  OBSERVE=true; [ "$MODE_CHOICE" = "2" ] && OBSERVE=false
  DEFAULT_IP=$(curl -fsS --max-time 2 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
  PUB_URL=$(ask "节点 API 公网/内网访问地址" "https://${DEFAULT_IP}:${API_PORT}")
  yesno "确认开始安装 guardd" "Y" || exit 0

  download_file "$TMP/guardd.tar.gz" "$GUARDD_PACKAGE_URL" "$GUARDD_PACKAGE_FALLBACK_URL"
  tar -C "$TMP" -xzf "$TMP/guardd.tar.gz"
  install -m 0755 "$TMP"/guardd-linux-amd64/guardd /usr/local/bin/guardd
  install -d -m 0700 /etc/guardd/tls /var/lib/guardd
  printf '%s\n' "$API_KEY" > /etc/guardd/api.key; chmod 600 /etc/guardd/api.key
  if command -v openssl >/dev/null; then openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -subj "/CN=$NODE_NAME" -keyout /etc/guardd/tls/server.key -out /etc/guardd/tls/server.crt >/dev/null 2>&1; fi
  cat >/etc/guardd/guardd.yaml <<EOF
node:
  id: $NODE_NAME
  name: $NODE_NAME
  group: $NODE_GROUP
network:
  interface: $IFACE
xdp:
  attach_mode: native
  observe_only: $OBSERVE
  mode: normal
  enable_ipv6: false
  enable_quic: true
api:
  enabled: true
  listen_ip: $API_IP
  listen_port: $API_PORT
  public_url: $PUB_URL
  allow_cidrs: [$CENTER_CIDR]
  auth: {key_id: $NODE_NAME, secret_file: /etc/guardd/api.key}
  tls: {enabled: true, cert_file: /etc/guardd/tls/server.crt, key_file: /etc/guardd/tls/server.key}
service_ports:
  tcp: [80, 443]
  udp: [443]
port_whitelist:
  tcp: [22]
  udp: []
rules:
  enabled: [xdp_tcp_syn_rate, xdp_udp_rate, xdp_icmp_rate, xdp_bad_tcp_flags, xdp_fragment_drop, xdp_malformed_drop, xdp_src_port_zero_drop]
rule_params:
  xdp_tcp_syn_rate: {normal_pps_per_ip: 200, elevated_pps_per_ip: 80, critical_pps_per_ip: 30}
  xdp_tcp_ack_rate: {normal_pps_per_ip: 800, elevated_pps_per_ip: 300, critical_pps_per_ip: 120}
  xdp_tcp_rst_rate: {normal_pps_per_ip: 200, elevated_pps_per_ip: 80, critical_pps_per_ip: 30}
  xdp_udp_rate: {normal_pps_per_ip: 300, elevated_pps_per_ip: 120, critical_pps_per_ip: 60}
  xdp_icmp_rate: {normal_pps_per_ip: 10, elevated_pps_per_ip: 5, critical_pps_per_ip: 2}
  xdp_bad_tcp_flags: {drop_null: true, drop_xmas: true, drop_syn_fin: true, drop_syn_rst: true, drop_fin_rst: true}
  xdp_fragment_drop: {drop_all_fragments: true}
  xdp_malformed_drop: {drop_short_headers: true}
  xdp_ttl_filter: {min_ttl: 1, max_ttl: 255}
  xdp_packet_size_filter: {min_packet_len: 0, max_packet_len: 0}
  xdp_icmp_type_filter: {drop_echo_request: false, drop_timestamp: true, drop_address_mask: true}
  xdp_tcp_window_filter: {drop_zero_window: false}
  xdp_udp_length_filter: {min_udp_len: 8, max_udp_len: 0}
  xdp_src_port_zero_drop: {drop_tcp_src_zero: true, drop_udp_src_zero: true}
thresholds:
  normal: {syn_pps_per_ip: 200, udp_pps_per_ip: 300, icmp_pps_per_ip: 10}
  elevated: {syn_pps_per_ip: 80, udp_pps_per_ip: 120, icmp_pps_per_ip: 5}
  critical: {syn_pps_per_ip: 30, udp_pps_per_ip: 60, icmp_pps_per_ip: 2}
cache: {rule_cache_file: /var/lib/guardd/rules-cache.json, last_center_snapshot: /var/lib/guardd/last-center.json}
EOF
  cat >/etc/systemd/system/guardd.service <<'EOF'
[Unit]
Description=guardd XDP Node Agent
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
Environment=GUARDD_MODE=service
ExecStart=/usr/local/bin/guardd
Restart=always
RestartSec=2
LimitMEMLOCK=infinity
CapabilityBoundingSet=CAP_NET_ADMIN CAP_BPF CAP_PERFMON CAP_SYS_RESOURCE
AmbientCapabilities=CAP_NET_ADMIN CAP_BPF CAP_PERFMON CAP_SYS_RESOURCE
NoNewPrivileges=true
[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable --now guardd
  cat <<EOF
========================================
 guardd 安装完成
========================================
节点名称: $NODE_NAME
API 地址: $PUB_URL
Key ID: $NODE_NAME
API Key: $API_KEY
维护菜单: root 直接执行 guardd，普通用户执行 sudo guardd
EOF
}

install_center(){
  echo "========================================"
  echo " guardd-center 中心安装向导"
  echo "========================================"
  need_center_deps
  echo "安装包 URL: $GUARDD_CENTER_PACKAGE_URL"
  WEB_IP=$(ask "设置 Web 监听 IP" "0.0.0.0")
  WEB_PORT=$(ask "设置 Web 监听端口" "8080")
  TLS_CHOICE=$(ask "访问协议：1 HTTP，2 HTTPS 自签" "2")
  ADMIN_USER=$(ask "管理员用户名" "admin")
  while true; do P1=$(ask_secret "管理员密码"); P2=$(ask_secret "再次输入管理员密码"); [ "$P1" = "$P2" ] && [ -n "$P1" ] && break; echo "两次密码不一致或为空"; done
  echo
  echo "----- MySQL 配置（必须测试通过才能继续）-----"
  while true; do
    MYSQL_HOST=$(ask "MySQL 主机地址" "127.0.0.1")
    MYSQL_PORT=$(ask "MySQL 端口" "3306")
    MYSQL_DB=$(ask "MySQL 数据库名" "guardd")
    MYSQL_USER=$(ask "MySQL 用户名" "guardd")
    MYSQL_PASS=$(ask_secret "MySQL 密码（可空直接回车）")
    MYSQL_TLS=false; yesno "MySQL 是否启用 TLS/SSL" "N" && MYSQL_TLS=true
    echo "正在测试 MySQL 连接、读写和建表权限..."
    if test_mysql_conn "$MYSQL_HOST" "$MYSQL_PORT" "$MYSQL_DB" "$MYSQL_USER" "$MYSQL_PASS" "$MYSQL_TLS"; then
      echo "MySQL 测试成功。"
      break
    fi
    echo "MySQL 测试失败：请确认数据库已创建、账号密码正确、具备建表/读写权限，并使用 utf8mb4 字符集。"
  done
  echo
  echo "----- Redis 配置（必须测试通过才能继续）-----"
  while true; do
    REDIS_ADDR=$(ask "Redis 地址 host:port" "127.0.0.1:6379")
    REDIS_PASS=$(ask_secret "Redis 密码（可空直接回车）")
    REDIS_DB=$(ask "Redis DB 编号" "0")
    REDIS_TLS=false; yesno "Redis 是否启用 TLS" "N" && REDIS_TLS=true
    echo "正在测试 Redis PING / 写入 / 读取 / 删除..."
    if test_redis_conn "$REDIS_ADDR" "$REDIS_PASS" "$REDIS_DB" "$REDIS_TLS"; then
      echo "Redis 测试成功。"
      break
    fi
    echo "Redis 测试失败：请确认地址、密码、DB 编号、TLS 配置正确。"
  done
  RAW_DAYS=$(ask "原始指标保留天数" "7")
  MIN_DAYS=$(ask "分钟聚合指标保留天数" "30")
  HOUR_DAYS=$(ask "小时聚合指标保留天数" "365")
  yesno "确认开始安装 guardd-center" "Y" || exit 0

  download_file "$TMP/guardd-center.tar.gz" "$GUARDD_CENTER_PACKAGE_URL" "$GUARDD_CENTER_PACKAGE_FALLBACK_URL"
  tar -C "$TMP" -xzf "$TMP/guardd-center.tar.gz"
  install -m 0755 "$TMP"/guardd-center-linux-amd64/guardd-center /usr/local/bin/guardd-center
  install -d -m 0700 /etc/guardd-center/tls /var/lib/guardd-center /var/backups/guardd-center
  install_geoip_assets
  printf '%s' "$P1" > /etc/guardd-center/bootstrap-admin.pass; chmod 600 /etc/guardd-center/bootstrap-admin.pass
  head -c 32 /dev/urandom > /etc/guardd-center/master.key; chmod 600 /etc/guardd-center/master.key
  head -c 32 /dev/urandom > /etc/guardd-center/session.key; chmod 600 /etc/guardd-center/session.key
  TLS_ENABLED=false
  if [ "$TLS_CHOICE" = "2" ]; then TLS_ENABLED=true; if command -v openssl >/dev/null; then openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -subj "/CN=guardd-center" -keyout /etc/guardd-center/tls/server.key -out /etc/guardd-center/tls/server.crt >/dev/null 2>&1; fi; fi
  MYSQL_PASS_YAML=$(printf '%s' "$MYSQL_PASS" | sed 's/\\/\\\\/g; s/"/\\"/g')
  REDIS_PASS_YAML=$(printf '%s' "$REDIS_PASS" | sed 's/\\/\\\\/g; s/"/\\"/g')
  cat >/etc/guardd-center/center.yaml <<EOF
web:
  listen_ip: $WEB_IP
  listen_port: $WEB_PORT
  public_url: https://center.example.com:$WEB_PORT
  tls: {enabled: $TLS_ENABLED, cert_file: /etc/guardd-center/tls/server.crt, key_file: /etc/guardd-center/tls/server.key}
security: {session_secret_file: /etc/guardd-center/session.key, master_key_file: /etc/guardd-center/master.key, login_rate_limit_per_minute: 10}
storage:
  driver: mysql
  sqlite_path: /var/lib/guardd-center/guardd-center.db
  mysql:
    host: $MYSQL_HOST
    port: $MYSQL_PORT
    database: $MYSQL_DB
    username: $MYSQL_USER
    password: "$MYSQL_PASS_YAML"
    tls: $MYSQL_TLS
    max_open_conns: 50
    max_idle_conns: 10
  redis:
    addr: $REDIS_ADDR
    password: "$REDIS_PASS_YAML"
    db: $REDIS_DB
    tls: $REDIS_TLS
  backup_dir: /var/backups/guardd-center
  retention: {raw_metrics_days: $RAW_DAYS, minute_metrics_days: $MIN_DAYS, hour_metrics_days: $HOUR_DAYS}
collector: {scrape_interval_seconds: 3, node_timeout_seconds: 5, max_concurrency: 64}
audit: {enabled: true, keep_days: 365}
bootstrap: {admin_username: $ADMIN_USER, admin_password_file: /etc/guardd-center/bootstrap-admin.pass}
EOF
  cat >/etc/systemd/system/guardd-center.service <<'EOF'
[Unit]
Description=guardd-center Management Server
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
Environment=GUARDD_CENTER_MODE=service
Environment=GUARDD_CENTER_GEOIP_DIR=/var/lib/guardd-center/geoip
ExecStart=/usr/local/bin/guardd-center
Restart=always
RestartSec=2
NoNewPrivileges=true
[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable --now guardd-center
  SCHEME=http; [ "$TLS_ENABLED" = true ] && SCHEME=https
  cat <<EOF
========================================
 guardd-center 安装完成
========================================
Web 地址: $SCHEME://服务器IP:$WEB_PORT
管理员账号: $ADMIN_USER
维护菜单: root 直接执行 guardd-center，普通用户执行 sudo guardd-center
EOF
}

install_guardd_test(){
  echo "========================================"
  echo " guardd-test 节点测试工具安装向导"
  echo "========================================"
  echo "安装包 URL: $GUARDD_TEST_PACKAGE_URL"
  echo "说明：guardd-test 需要安装在 guardd 节点服务器本机，并使用 root 运行。"
  echo "它不会向公网发起攻击流量；默认使用 XDP 内核自测，也支持 veth 隔离实流测试。"
  yesno "确认开始安装 guardd-test" "Y" || exit 0

  download_file "$TMP/guardd-test.tar.gz" "$GUARDD_TEST_PACKAGE_URL" "$GUARDD_TEST_PACKAGE_FALLBACK_URL"
  tar -C "$TMP" -xzf "$TMP/guardd-test.tar.gz"
  install -m 0755 "$TMP"/guardd-test-linux-amd64/guardd-test /usr/local/bin/guardd-test
  install -d -m 0700 /etc/guardd-test
  cat <<EOF
========================================
 guardd-test 安装完成
========================================
维护菜单: root 直接执行 guardd-test，普通用户执行 sudo guardd-test
建议流程:
1. 先在 guardd 节点执行 guardd，选择“导出 center 接入信息”，复制 Base64。
2. 执行 guardd-test，选择“导入节点 Base64 信息”。
3. 选择 TCP SYN / UDP / ICMP / Bad TCP Flags / 混合测试。
EOF
  if yesno "是否立即进入 guardd-test 菜单" "Y"; then
    /usr/local/bin/guardd-test
  fi
}

main(){
  need_root
  need_common
  echo "========================================"
  echo " guardd-suite 统一安装脚本"
  echo "========================================"
  echo "脚本版本: $INSTALLER_VERSION"
  echo "guardd 包 URL: $GUARDD_PACKAGE_URL"
  echo "guardd-center 包 URL: $GUARDD_CENTER_PACKAGE_URL"
  echo "guardd-test 包 URL: $GUARDD_TEST_PACKAGE_URL"
  echo
  echo "请选择安装组件："
  echo "1) guardd 节点 Agent"
  echo "2) guardd-center 中心管理平台"
  echo "3) guardd-test 节点测试工具"
  echo "0) 退出"
  choice=$(ask "请输入序号" "1")
  case "$choice" in
    1) install_guardd ;;
    2) install_center ;;
    3) install_guardd_test ;;
    0) exit 0 ;;
    *) echo "无效选择"; exit 1 ;;
  esac
}

main "$@"

