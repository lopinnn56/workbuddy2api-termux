#!/data/data/com.termux/files/usr/bin/bash
# 平时启动脚本: 放 ~/workbuddy2api-panel/start.sh 一份即可
cd "$(dirname "$0")"
termux-wake-lock 2>/dev/null || true
if tmux has-session -t wb2api 2>/dev/null; then
  echo "wb2api 已在运行 (tmux attach -t wb2api 查看, Ctrl-b d 退出)"
else
  tmux new-session -d -s wb2api -c "$PWD" './wb2api -config config.json >> data/wb2api.log 2>&1'
  echo "已启动, 3秒后检查..."
  sleep 3
fi
curl -s http://127.0.0.1:7863/healthz; echo
API_KEY=$(python3 -c "import json; print(json.load(open('config.json'))['api_key'])" 2>/dev/null || echo "")
echo "面板: http://127.0.0.1:7863/panel/"
echo "API Base: http://127.0.0.1:7863/v1"
echo "API Key: $API_KEY"
echo "日志: tail -f data/wb2api.log"
echo "停止: tmux kill-session -t wb2api"
