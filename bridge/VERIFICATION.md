# 桥接器验证说明

`tests/test_coach.py` 覆盖协议握手、旧消息隔离、截断响应拒绝、超大帧拒绝、地图参数校验及 MCP 只读工具集合。

`tests/live_check.py` 是可选实局测试，需要开启 Tuner 并载入单人地图。它读取并保存观察数据，不会下达游戏指令。
已在 macOS Steam 版 Civilization VI 进行实局读取验证；不保证其他发行版本、DLC 或 Mod 组合的兼容性。
查询关闭后保留 0.5 秒连接冷却，以缓解 Mac 版 FireTuner 的连续重连拒绝问题。
协议参考：civ6-mcp，版本 `dd2019056371b92ea4854e879ddf05a8cad95e8a`。
