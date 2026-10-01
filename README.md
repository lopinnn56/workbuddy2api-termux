# workbuddy2api-termux

`workbuddy2api-panel` 的 Termux(aarch64) 一键安装/启动脚本。
上游: https://github.com/linguo2625469/workbuddy2api-panel (Go, OpenAI兼容网关 + Web面板)。

> 为什么不能直接下 Release 跑? Release 是 Alpine 编译的 `CGO_ENABLED=0`,
> 硬读 `/etc/resolv.conf`。Termux 里 `/etc -> /system/etc`(空文件不存在),
> 真实 DNS 在 `$PREFIX/etc/resolv.conf`, 所以 Go 会回落到 `[::1]:53`
> 报 `dial tcp: lookup www.workbuddy.ai on [::1]:53: read: connection refused`。
> 本仓库的 `install.sh` 用 Termux 补丁版 Go **本地编译**, 一劳永逸修 DNS。
> 本机已验证: `curl/ping` 通(200), 只有旧二进制不通; 本地编译后 `200 OK`。

## 0. 环境要求

- Termux (Google Play / F-Droid 版均可), Android 7+, arm64(`uname -m` 显示 `aarch64`)
- 磁盘 1G+ (Go 工具链约 230M, 源码+二进制约 100M), 流量约 100M
- 已有 1 个以上 CodeBuddy/WorkBuddy 账号(面板扫码/OAuth 登录用)

## 1. 一键安装(新手机/新 Termux 照抄)

```bash
pkg install -y git
git clone https://github.com/lopinnn56/workbuddy2api-termux.git
bash workbuddy2api-termux/install.sh
```

脚本会自动做(约 2-5 分钟):
1. `pkg update; pkg install golang git curl tmux python`
2. 建 `~/workbuddy2api-panel/auths` + `data`
3. 取上游最新 tag 克隆到 `~/workbuddy-src`
4. `go build -o ~/workbuddy2api-panel/wb2api ./cmd/server`
5. 首次 `timeout 8 ./wb2api` 自动生成 `config.json`(含随机 `api_key`)
6. 复制 `start.sh` 并 `tmux` 后台启动, 输出 Base/Key/面板地址

看到以下即成功:
```
面板: http://127.0.0.1:7863/panel/
API Base: http://127.0.0.1:7863/v1
API Key: sk-xxxx
{"healthy":0,"total":0,...}   # 0 是因为还没加号, 正常
```

## 2. API Base URL 和 Key 是什么

| 项 | 值 | 说明 |
|---|---|---|
| Base URL | `http://127.0.0.1:7863/v1` | OpenAI 兼容前缀, 第三方客户端照填 |
| Key | `config.json` 里 `api_key`, 如 `sk-xxxx` | 每次看: `python3 -c "import json;print(json.load(open('$HOME/workbuddy2api-panel/config.json'))['api_key'])"` |
| 面板 | `http://127.0.0.1:7863/panel/` | 手机浏览器打开, 加号/看积分/改配置 |
| 模型列表 | `GET /v1/models -H "Authorization: Bearer <key>"` | 加号前是空数组, 正常 |
| 聊天 | `POST /v1/chat/completions` | `model` 如 `deepseek-v4-flash`, 支持 `stream:true/false` |
| 状态 | `GET /status -H "Authorization: Bearer <key>"` | 每账号健康/冷却/积分 |
| 探活 | `GET /healthz` | 无号时 503/`healthy:0`, 有号后 `healthy>0` |

客户端示例(Claude Code / Codex / 任意 OpenAI SDK):
```
Base: http://127.0.0.1:7863/v1
Key: sk-xxxx (你的)
```
局域网别的设备要用: 把 `127.0.0.1` 换成手机 WiFi IP(如 `192.168.1.5`), 端口不变, 注意公网必须设强 `api_key`。

## 3. 添加账号(面板流, 推荐)

1. 手机浏览器开 `http://127.0.0.1:7863/panel/`
2. 右上「添加账号」-> 按提示在新页完成 OAuth 登录 -> 回面板确认
3. 自动落盘 `~/workbuddy2api-panel/auths/*.json` + 热加载免重启
4. 验证:
```bash
curl -s http://127.0.0.1:7863/healthz
# healthy:2/total:2 即 2 个号在线
curl -s http://127.0.0.1:7863/v1/models -H "Authorization: Bearer <你的key>"
```

## 4. 平时启动/停止/看日志

```bash
cd ~/workbuddy2api-panel
./start.sh            # 启动(已含 termux-wake-lock), 并打印 Base/Key/healthz
tmux attach -t wb2api # 进后台窗口看实时输出, Ctrl-b 再按 d 退出(不杀进程)
tail -f data/wb2api.log  # 看日志
tmux kill-session -t wb2api  # 停止
```

每次重开 Termux / 重启手机后跑一遍 `./start.sh` 即可。
保活三件套(缺一就可能被杀):
1. `termux-wake-lock` (start.sh 已自动执行)
2. 系统设置搜 Termux -> 省电/电池 -> 设为无限制 + 允许后台 + 锁屏不清理
3. 尽量保持 Termux 在最近任务里, 不要一键清理

可选开机自启: 装 `Termux:Boot` App, 把 `./start.sh` 路径加进 `~/.termux/boot/`。

## 5. 更新上游

```bash
bash ~/workbuddy2api-termux/update.sh
# 等价手动: git -C ~/workbuddy-src fetch --tags; checkout 最新tag; go build; 重启
```

## 6. 备份/迁移

只备 2 样(其余可重下重编):
```bash
cp ~/workbuddy2api-panel/config.json ~/config.bak.json
cp -r ~/workbuddy2api-panel/auths ~/auths.bak
# 恢复时拷回同名位置再 ./start.sh
```
**绝不**把 `config.json`(含 api_key)和 `auths/*.json`(含明文 accessToken/refreshToken)发人或传公开网盘。

## 7. 常见问题

- `[::1]:53 connection refused` -> 你用了旧 Release 二进制, 重跑 `install.sh` 本地编译即可。
- `healthz healthy:0` -> 还没加号或全在冷却, 先去面板加号/等签到(09/21点)解冻。
- `401` -> `Authorization: Bearer` 写错, 去 `config.json` 复制 `api_key`。
- 面板打不开 -> `curl 127.0.0.1:7863/healthz` 看进程在不在, 不在就 `./start.sh`; 换 Chrome/Via 试试。
- 编译慢/流量不够 -> 找 WiFi, `go build` 只需一次, 以后 `update.sh` 增量很快。
- `pkg install golang` 404 -> 先 `pkg update` 再装(脚本已含)。
- 多开 Termux 分身(files/files1/files2/files3, 如双开/平行空间):
  每个分身是独立 HOME/独立 `tmux`, 脚本在哪个分身运行就装在哪个分身,
  `~/workbuddy2api-panel` 不互通。`ERR_CONNECTION_REFUSED` 先看是不是找错了分身:
  `ls ~/workbuddy2api-panel/` 没目录 = 这个分身没装, 跑 `install.sh`;
  有目录没进程(`tmux ls` 无服务/`curl` exit 7)= 被杀了, 跑 `./start.sh`。
  同一手机两个分身**不能同用 `:7863`** (后起的 bind 失败): 留一个跑,
  或把另一个 `config.json` 里 `listen` 改成 `":7864"`, 面板/Base URL 端口同步换成 `7864`。
  搬家(旧分身 -> 新分身): 拷 `config.json` + `auths/*.json` 到新分身同名位置再 `./start.sh`,
  无需重新扫码登录。

## 8. 目录结构

```
~/workbuddy2api-panel/  # 运行目录(本仓库不上传, 只在你手机上)
  wb2api                # 本地编译的二进制
  config.json           # 自动生成, 含 api_key (保密!)
  auths/                # 账号凭证 (保密!)
  data/                 # 状态/日志/用量
  start.sh              # 平时启动
~/workbuddy-src/        # 上游源码(用于编译)
./install.sh ./start.sh ./update.sh  # 本仓库内容
```
