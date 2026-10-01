#!/usr/bin/env bash
# 更新到上游最新 tag 并重编重启(在哪个分身运行就更新哪个分身)
set -e
APP_DIR="$HOME/workbuddy2api-panel"
SRC_DIR="$HOME/workbuddy-src"
TAG=$(curl -sL https://api.github.com/repos/linguo2625469/workbuddy2api-panel/releases/latest | python3 -c "import json,sys; print(json.load(sys.stdin).get('tag_name','main'))")
echo "更新到 $TAG ..."
git -C "$SRC_DIR" fetch --tags --depth 1 origin "$TAG"
git -C "$SRC_DIR" checkout "$TAG"
cd "$SRC_DIR"
go build -trimpath -ldflags="-s -w" -o "$APP_DIR/wb2api" ./cmd/server
tmux kill-session -t wb2api 2>/dev/null || true
sleep 1
bash "$APP_DIR/start.sh"
