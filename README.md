# CastoricePS（Zig 0.14.1）
基于 Zig 的《崩坏：星穹铁道》私人服实现，`Dispatch + GameServer` 已打包为单一可执行文件 `CastoricePS.exe`（同目录运行）。

本项目完全免费。如果你为它付费，你被骗了。

- Discord：`Discord.gg/dyn9NjBwzZ`
- srtools：`https://srtools.neonteam.dev/`（用于修改角色/光锥/遗器/战斗配置；保存后会写入本项目根目录 `freesr-data.json`）

## 主要特性
- 单进程启动：一个 `CastoricePS.exe` 同时拉起 Dispatch 与 GameServer
- 配置分离：
  - `freesr-data.json`：角色/光锥/遗器/战斗等（srtools 写入）
  - `misc.json`：默认背包/主角性别与命途/阵容等偏好
- 装备显示：背包（GetBag）返回的装备/遗器 `unique_id` 与角色穿戴引用保持一致
- srtools 接入：`/srtools` 支持浏览器 CORS（可直接从网页保存）
- 指令同步：仅保留 `/sync`，用于重载 `freesr-data.json` 并同步数据（完成后会强制客户端重连以避免界面黑屏）
- 登录公告：进入游戏后推送一次紧急提示公告

## 目录结构（运行时）
建议把以下文件放在同一目录：
```
CastoricePS.exe
freesr-data.json
misc.json
hotfix.json              # 可选
resources/               # 资源配置
saves/                   # 可选：玩家存档
```

## 编译与运行（Windows）
1) 安装 Zig 0.14.1，并把 `zig.exe` 加入 PATH

2) 构建并运行：
- 开发运行：`zig build run-program`
- 仅构建：`zig build`
- 发布构建：`zig build -Doptimize=ReleaseSafe`（产物在 `zig-out/bin/CastoricePS.exe`）

## 常用指令
- `/help` 查看全部指令
- `/sync` 重载 `freesr-data.json` 并同步（会强制客户端重连）
- `/scene pos` 查看坐标；`/scene reload` 重载场景配置
- `/info` 查看玩家基本信息
- `/give <itemId> <count>` 发放材料（测试用途）

## 开发提示
- srtools 网页保存的数据会写入根目录 `freesr-data.json`，服务器侧会在 `/sync` 时重新加载
- 如果你频繁 `zig build` 提示 `AccessDenied`，通常是 `CastoricePS.exe` 正在运行占用文件，先退出进程再构建
