#!/usr/bin/env bash
# workbuddy2api-termux 一键安装脚本 (Termux aarch64, 多开容器通用: files/files1/files2/files3)
# 原理: Release 二进制是在 Alpine 编译的 CGO_ENABLED=0, 硬读 /etc/resolv.conf,
# 在 Termux 里会回落到 [::1]:53 报 connection refused, 所以必须本地 go build。
# 注意: 每个 Termux 分身(files/files3 等)是独立 HOME/独立端口, 脚本在哪里运行就装在哪里;
# 同一手机同时只能起一个 :7863, 第二个容器要改 config.json 里 listen 端口(见 README)。
set -e
APP_DIR="$HOME/workbuddy2api-panel"
SRC_DIR="$HOME/workbuddy-src"
UPSTREAM="https://github.com/linguo2625469/workbuddy2api-panel.git"

echo "=== 1/5 环境 ==="
pkg update -y
pkg install -y golang git curl tmux python

echo "=== 2/5 目录 ==="
mkdir -p "$APP_DIR/auths" "$APP_DIR/data"

echo "=== 3/5 拉源码(取最新 tag) ==="
TAG=$(curl -sL https://api.github.com/repos/linguo2625469/workbuddy2api-panel/releases/latest | python3 -c "import json,sys; print(json.load(sys.stdin).get('tag_name','main'))")
echo "最新 tag: $TAG"
if [ -d "$SRC_DIR/.git" ]; then
  git -C "$SRC_DIR" fetch --tags --depth 1 origin "$TAG" || git -C "$SRC_DIR" fetch --tags
  git -C "$SRC_DIR" checkout "$TAG"
else
  rm -rf "$SRC_DIR"
  git clone --depth 1 --branch "$TAG" "$UPSTREAM" "$SRC_DIR"
fi

echo "=== 4/5 本地编译(Termux 补丁版 Go, 修 DNS, 约2-5分钟) ==="
cd "$SRC_DIR"
go build -trimpath -ldflags="-s -w" -o "$APP_DIR/wb2api" ./cmd/server
ls -lh "$APP_DIR/wb2api"
cp "$SRC_DIR/config.example.json" "$APP_DIR/config.example.json" 2>/dev/null || true

echo "=== 5/5 首次启动(自动生成 config.json + 随机 api_key) ==="
cd "$APP_DIR"
chmod +x "$APP_DIR/wb2api"
if [ ! -f config.json ]; then
  timeout 8 ./wb2api -config config.json || true
fi
API_KEY=$(python3 -c "import json; print(json.load(open('config.json'))['api_key'])" 2>/dev/null || echo "unknown")
echo "----------------------------------------"
echo "安装完成!"
echo "面板: http://127.0.0.1:7863/panel/"
echo "API Base: http://127.0.0.1:7863/v1"
echo "API Key: $API_KEY"
echo "----------------------------------------"
echo "启动: bash $APP_DIR/start.sh (本仓库已附带, 安装时自动复制)"
cp -f "$(dirname "$0")/start.sh" "$APP_DIR/start.sh"
chmod +x "$APP_DIR/start.sh"
[ -x "$APP_DIR/start.sh" ] || { echo "错误: start.sh 复制失败, 请检查上面报错"; exit 1; }
bash "$APP_DIR/start.sh"
