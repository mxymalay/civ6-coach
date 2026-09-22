# 文明 VI 陪练 · macOS

原生 SwiftUI 中文陪练：读取《文明 VI》局势，解释本回合该优先做什么，支持继续追问。无需反复截图，不替玩家操作游戏。

## 功能

- 只读获取自身经济、城市、生产、研究、单位和首都附近可见地图。
- 即时基础提醒（无需 AI）、一键 AI 建议、多轮中文聊天。
- 自定义 OpenAI 兼容 API：Chat Completions / Responses，支持本机 HTTP；远程要求 HTTPS。
- 菜单栏「文」图标：开关陪练、小窗查看建议、快速生成、进入聊天。
- 快捷小窗可拖动、缩放；右上角图钉固定后持续置顶，取消固定后点击外部自动收起。尺寸与图钉状态自动保存。
- 设置分为「API」「外观」「陪练与隐私」三页，共用保存按钮。
- 森林绿、海军蓝、暮光紫、石墨黑、纯白五套主题；设置预览，保存后同步主窗口和菜单栏。
- 可停止生成；API Key 保存在 macOS 钥匙串；对话可本机保存、归档、导出。

## 构建

需要 macOS 13+、Xcode / Swift 5.9+。已在 Apple Silicon Mac 实测，Intel 未实测。

```sh
git clone https://github.com/mxymalay/civ6-coach.git
cd civ6-coach
./build.sh
open "dist/文明 VI 陪练.app"
```

产物为本机 ad-hoc 签名，不是经过 Apple 公证的发行版。桌面应用不需要 Python。

## 连接游戏

1. 退出《文明 VI》，备份 `AppOptions.txt`。
2. 仅将 `EnableTuner 0` 改为 `EnableTuner 1`。
3. 重启游戏，载入单人存档进入地图，再开启应用里的陪练开关。

Steam macOS 常见配置位置：

```text
~/Library/Application Support/Sid Meier's Civilization VI/Firaxis Games/Sid Meier's Civilization VI/AppOptions.txt
```

**启用 Tuner 会影响游戏成就。** 应用不自动修改配置。恢复时退出游戏，仅改回 `EnableTuner 0`，不要用旧备份覆盖后来更改的其他选项。
连接失败时确认游戏已重启、地图已载入、没有其他 FireTuner 客户端占用连接。仅连接 `127.0.0.1:4318`，不对外开放端口。

## 配置 AI

在设置的「API」页配置服务。应用已移除 Codex 登录和 CLI 调用功能；升级保留原有 API、主题及其他偏好，不修改本机 Codex 账号。

填写服务地址、模型 ID 和 API Key，测试并保存。本机无鉴权服务可留空密钥。密钥不写入项目或设置 JSON；更换地址时输入框清空旧密钥。测试和生成会消耗所选服务的用量或费用。

## 隐私与限制

- 查询在本机执行；点建议/发送聊天时，局势和必要对话会发送到选中的 AI 服务。刷新局势不调用 AI。
- 暂停停止轮询并取消生成；已发送的请求不保证退回用量。
- 只读取自身及当前可见信息，不窥探迷雾。自动地图仅含首都附近，不能据此判断整个帝国安全。
- 固定 Lua 没有移动、建造、结束回合或任意脚本入口。FireTuner 本身是调试接口，勿暴露到外网。
- 缺失字段是未知，不当作零。快照不是引擎原子事务，查询时尽量不要结束回合。
- 回合倒退或文明变化会开启新对话；无法识别所有同文明/同回合换档，换局后请手动「新对话」。
- 重启应用后仍显示保存的旧对话，但不会把上次会话自动发给 AI，避免误用另一存档的历史。
- AI 可能有误，不是精确规则引擎或最优策略求解器。主要验证单人 Steam Mac 版，不同 DLC/Mod 可能有缺失字段。
- 对话保存在 `~/Library/Application Support/Civ6Coach/`。关闭保存会移除当前对话副本，历史归档仍保留。`--qa` 使用独立偏好及对话目录。

## 测试

```sh
swift test
# 可选：需游戏已载入，会读取真实游戏数据
CIVCOACH_LIVE_TEST=1 swift test
```

默认测试用本地 HTTP 服务检查流解析、中文片段、错误、取消及 JSON 回退，不需真实 API Key。可选 Python MCP 桥接器见 [bridge](bridge/README.md)。

## 致谢

FireTuner 协议参考 [lmwilki/civ6-mcp](https://github.com/lmwilki/civ6-mcp)，其 MIT 声明保留于 `THIRD_PARTY_LICENSE.txt`。非官方工具，与 Firaxis、2K 或 OpenAI 无隶属关系。
