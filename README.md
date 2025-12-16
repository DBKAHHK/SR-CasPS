# CastoricePS（Zig 0.14.1）
基于 Zig 的《崩坏：星穹铁道》私人服实现，`Dispatch + GameServer` 已打包为单一可执行文件 `CastoricePS.exe`（同目录运行）。

本项目完全免费。

- Discord：`Discord.gg/dyn9NjBwzZ`
- srtools：`https://srtools.neonteam.dev/`（用于修改角色/光锥/遗器/战斗配置；保存后会写入本项目根目录 `freesr-data.json`）

## 主要特性
- 单进程启动：一个 `CastoricePS.exe` 同时拉起 Dispatch 与 GameServer
- 配置分离：
  - `freesr-data.json`：角色/光锥/遗器/战斗等（srtools 写入）
  - `misc.json`：默认背包/阵容/出生位置等偏好
- 装备显示：背包（GetBag）返回的装备/遗器 `unique_id` 与角色穿戴引用保持一致。
- srtools 接入：`/srtools` 支持浏览器 CORS（可直接从网页保存）
- 指令同步：`/sync` 重载 `freesr-data.json` 并同步数据（完成后会强制客户端重连以避免界面黑屏）//退出重进效果一样

## 目录结构（运行时）
建议把以下文件放在同一目录：
```
CastoricePS.exe          # 主程序
freesr-data.json         # 角色配置文件
misc.json                # 杂项配置文件
hotfix.json              # 热修复文件
resources/               # 资源配置
protocol/                # 协议文件
```

## 编译与运行（Windows）
1) 安装 Zig 0.14.1，并把 `zig.exe` 加入 PATH

2) 构建并运行：
- 开发运行：`zig build run-program`
- 仅构建：`zig build`
- 发布构建：`zig build -Doptimize=ReleaseSafe`（产物在 `zig-out/bin/CastoricePS.exe`）

## 编译（Android）
说明：这会生成 **Android ELF 可执行文件**（不是 APK）。

- ARM64（推荐，大多数手机）：`zig build -Dtarget=aarch64-linux-android -Doptimize=ReleaseSafe`
- ARMv7：`zig build -Dtarget=arm-linux-androideabi -Doptimize=ReleaseSafe`

产物路径：
- `zig-out/bin/CastoricePS`（在 Android 上运行的 ELF）

在设备上运行（示例）：
- `adb push zig-out/bin/CastoricePS /data/local/tmp/`
- `adb shell chmod +x /data/local/tmp/CastoricePS`
- `adb shell /data/local/tmp/CastoricePS`

## Android 壳应用（点按钮运行服务器）
仓库内提供了一个简单的 Android 壳工程：`android-app/`。它会把 `CastoricePS`（Android ELF）和默认配置打包进 APK，启动后可一键运行/停止服务器、查看日志、传入调试参数，并提供“一键恢复服务端数据”和启动提示弹窗。

集成步骤：
1) 先编译 Android ELF（ARM64）：
   - `zig build -Dtarget=aarch64-linux-android -Doptimize=ReleaseSafe`
2) 拷贝产物与默认配置到壳工程 assets：
   - `cp zig-out/bin/CastoricePS android-app/app/src/main/assets/CastoricePS`
   - `cp freesr-data.json android-app/app/src/main/assets/freesr-data.json`
   - `cp misc.json android-app/app/src/main/assets/misc.json`
   - `cp hotfix.json android-app/app/src/main/assets/hotfix.json`
3) 用 Android Studio 打开 `android-app/`，构建并安装到手机。

说明：
- 默认运行目录在应用内部（`data/data/.../files/castoriceps/`），更稳定；你也可以在壳应用里选择一个“公共文件夹”作为调试配置目录，并一键导入/导出配置。
- 这是“在 App 目录解压并执行 ELF”的方案，不是 APK 内直接运行。
- srtools 网页要访问手机上运行的服务器时，保存目标地址需要用手机本机/局域网 IP（如果网页在手机浏览器里打开，`127.0.0.1` 指向手机自己，通常可用）。

## 用 GitHub Actions 构建 APK（无需本地 Android SDK）
本仓库已提供 workflow：`.github/workflows/android-apk.yml`。

使用方式：
1) 推送代码到 GitHub 仓库
2) 打开 GitHub 仓库页面 → Actions → `Build Android APK` → `Run workflow`
3) 构建完成后，在该 workflow 的 Artifacts 下载 `CastoricePS-android-debug-apk`（内含 `app-debug.apk`）

## 常用指令
- `/help` 查看全部指令
- `/sync` 重载 `freesr-data.json` 并同步（会强制客户端重连）
- `/scene pos` 查看坐标；`/scene reload` 重载场景配置
- `/info` 查看玩家基本信息
- `/give <itemId> <count>` 发放材料（测试用途）

## 开发提示
- srtools 网页保存的数据会写入根目录 `freesr-data.json`，服务器侧会在 `/sync` 时重新加载（但其实你不重载也没事）
- 如果你频繁 `zig build` 提示 `AccessDenied`，通常是 `CastoricePS.exe` 正在运行占用文件，先退出进程再构建
