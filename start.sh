#!/usr/bin/env bash
# 平时启动脚本: 从哪里跑都行, 会自动定位运行目录。
# - 首选: cd ~/workbuddy2api-panel && ./start.sh (install.sh 会自动拷一份过去)
# - 兜底: bash ~/workbuddy2api-termux/start.sh (没拷过去也能用, 脚本自己找 panel 目录)
# 必须在“装了服务的那个 Termux 分身”里运行, 跨分身不可见(tmux/进程隔离)。
# 多开同时跑: 先改其中一个 config.json 的 listen(如 ":7864"), 面板/ Base URL 端口同步换。
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -x "$SCRIPT_DIR/wb2api" ] && [ -f "$SCRIPT_DIR/config.json" ]; then
  APP_DIR="$SCRIPT_DIR"
else
  APP_DIR="$HOME/workbuddy2api-panel"
fi
if [ ! -x "$APP_DIR/wb2api" ]; then
  echo "错误: 在 $APP_DIR 下没找到 wb2api, 请先跑 install.sh (bash ~/workbuddy2api-termux/install.sh)"
  exit 1
fi
cd "$APP_DIR"
termux-wake-lock 2>/dev/null || true
if tmux has-session -t wb2api 2>/dev/null; then
  echo "wb2api 已在运行 (tmux attach -t wb2api 查看, Ctrl-b d 退出)"
else
  tmux new-session -d -s wb2api -c "$PWD" './wb2api -config config.json >> data/wb2api.log 2>&1'
  echo "已启动, 3秒后检查..."
  sleep 3
fi
PORT=$(python3 -c "import json; print(str(json.load(open('config.json')).get('listen',':7863')).split(':')[-1])" 2>/dev/null || echo "7863")
curl -s "http://127.0.0.1:$PORT/healthz"; echo
API_KEY=$(python3 -c "import json; print(json.load(open('config.json'))['api_key'])" 2>/dev/null || echo "")
echo "面板: http://127.0.0.1:$PORT/panel/"
echo "API Base: http://127.0.0.1:$PORT/v1"
echo "API Key: $API_KEY"
echo "日志: tail -f data/wb2api.log"
echo "停止: tmux kill-session -t wb2api"
