# CastoricePS（Zig 0.14.1）
基于 Zig 的某回合制游戏Server实现。

本项目完全免费。仅供学习使用。

- Discord：`Discord.gg/dyn9NjBwzZ`
- srtools：`https://srtools.neonteam.dev/`

## 主要特性
- 配置分离：
  - `freesr-data.json`：角色/光锥/遗器/战斗等（srtools 写入）
  - `misc.json`：默认背包/阵容/出生位置等偏好
- srtools 接入：`/srtools` 支持浏览器 CORS（可直接从网页保存）
- 更多的指令支持

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

## Android 应用
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

## 开发提示
- srtools 网页保存的数据会写入根目录 `freesr-data.json`，服务器侧会在 `/sync` 时重新加载（但其实你不重载也没事）
- 如果你频繁 `zig build` 提示 `AccessDenied`，通常是 `CastoricePS.exe` 正在运行占用文件，先退出进程再构建
## 贡献
欢迎提交PR和Issue.感谢Reversed Rooms (discord.gg/reversedrooms)，以及他们的开源服务器:  
https://git.xeondev.com/HonkaiSlopRail/dahlia-sr-0.14.1
