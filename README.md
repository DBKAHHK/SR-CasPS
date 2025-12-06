# CastoricePS（Zig 0.14.1）
本仓库是基于 Zig 服务器，已将 Dispatch 和 GameServer 打包为单个可执行文件 `CastoricePS.exe`，自带图标并可直接运行。

## 已实现功能
- 单进程启动：运行 `CastoricePS` 同时拉起 Dispatch 与 GameServer，无需额外 exe。
- 配置拆分：`config.json` 负责角色/怪物/关卡等配置；`misc.json` 管理默认背包、位置、皮肤、阵容，占位阵容默认为 1407/1409/1413/1415。
- 主角定制：`misc.json` 新增 `mc_gender`（male/female）与 `mc_path`（warrior/knight/shaman/memory），可用指令动态切换。
- 基础玩法：登录与出生、战斗模拟（MOC/PF/AS 与挑战巅峰）、卡池模拟、背包/皮肤/装备发放，支持 fun mode。
- 场景与信息：`/scene pos` 查看位置、`/scene reload` 重载场景配置、`/info` 查看玩家基本信息。
- 调试/便利指令：`/give` 发物品（仅同步给客户端）、`/hp` `/sp`、`/level`、`/savelineup`、`/funmode`、`/gender`、`/path` 等，`/help` 查看列表。
- freesr-data：存在 `freesr-data.json` 时会优先加载，否则回落 `config.json`。
- 终端交互：程序内置输入行带粉色 `<CastoricePS>` 前缀，长日志不会遮挡输入；scene services 的超长日志默认关闭。

## 编译与运行（Windows）
1) 安装 Zig 0.14.1  
   下载 [Zig 0.14.1 x64](https://ziglang.org/download/0.14.1/zig-x86_64-windows-0.14.1.zip)，将 `zig.exe` 放入 PATH。Windows 下 `zig rc` 依赖内置 llvm-rc，可直接使用。

2) 准备资源  
   确保仓库根目录存在：
   - `config.json`、`misc.json`、`hotfix.json`（如需）
   - `resources/` 目录及其中的各类配置 JSON
   - `protocol/StarRail.proto`（若需重新生成协议，可用 `zig build gen-proto`）
   - 可选：`saves/`（存档）、`icon_output.ico` 已用于嵌入，不必随发行版携带

3) 构建  
   - 调试运行：`zig build run-program`（会编译并直接运行）
   - 生成可执行文件：`zig build -Doptimize=ReleaseSafe`（或 `ReleaseFast`），产物位于 `zig-out/bin/CastoricePS.exe`（同时生成 `CastoricePS.pdb` 供调试）

4) 运行  
   将 `CastoricePS.exe` 与 `config.json`、`misc.json`、`resources/` 等放在同一目录，直接启动或使用 `zig build run-program`。终端中输入 `/help` 可查看可用指令。

## 发行版目录示例
```
CastoricePS.exe
CastoricePS.pdb          # 可选，调试符号
config.json
misc.json
hotfix.json              # 可选
resources/               # 所有资源配置文件
saves/                   # 可选，玩家存档
```

## 常用指令速览
- `/help` 查看帮助
- `/info` 玩家基础信息
- `/scene pos` 当前坐标；`/scene reload` 重载场景配置
- `/gender <male|female>`、`/path <warrior|knight|shaman|memory>` 切换主角
- `/give <itemId> <count>` 发物品（客户端侧同步）
- `/hp <n>` `/sp <n>` `/level <n>`、`/savelineup`、`/funmode on|off`
- `/syncdata` 重新加载 freesr-data/config

## 贡献与反馈
欢迎提交 PR 或 Issue，描述清晰的复现步骤与期望行为有助于快速定位问题。***
感谢Reversed Rooms，此项目基于仓库：
https://git.xeondev.com/HonkaiSlopRail/dahlia-sr-0.14.1

