# 可选 MCP 桥接器

桌面应用不依赖 Python。此目录供需要在 MCP 客户端中直接查询游戏的开发者使用。

```sh
cd bridge
uv sync --python 3.12
uv run python coach.py snapshot
uv run python -m unittest discover -s tests -v
```

在 MCP 客户端配置 stdio 命令为本目录 `.venv/bin/python` 的绝对路径，参数为本目录 `coach.py` 的绝对路径及 `serve`。
提供 `get_game_snapshot`、`get_visible_map`、`get_recent_observations` 三个只读工具，不提供任意 Lua 或游戏操作。

数据保存在 `~/Library/Application Support/Civ6Coach/observations/`，与桌面应用共用 FireTuner 连接锁。
不同存档的历史不会自动分组，复盘前应确认是否属于同一局。
游戏连接配置、安全边界与成就影响见项目根目录 README。
