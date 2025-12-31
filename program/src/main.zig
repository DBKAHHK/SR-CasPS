const std = @import("std");
const builtin = @import("builtin");

const color = struct {
    const blue = "\x1b[36m"; // cyan / sky blue
    const pink = "\x1b[95;1m"; // bright magenta / hot pink
    const reset = "\x1b[0m";
};

const prompt_prefix = color.pink ++ "<CastoricePS>" ++ color.reset ++ " ";

const dispatch_main = @import("dispatch_main");
const gameserver_main = @import("gameserver_main");

extern "kernel32" fn SetCurrentDirectoryW(lpPathName: [*:0]const std.os.windows.WCHAR) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;
extern "kernel32" fn SetConsoleOutputCP(wCodePageID: u32) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;
extern "kernel32" fn SetConsoleCP(wCodePageID: u32) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;
extern "shell32" fn ShellExecuteW(
    hwnd: ?*anyopaque,
    lpOperation: ?[*:0]const std.os.windows.WCHAR,
    lpFile: [*:0]const std.os.windows.WCHAR,
    lpParameters: ?[*:0]const std.os.windows.WCHAR,
    lpDirectory: ?[*:0]const std.os.windows.WCHAR,
    nShowCmd: i32,
) callconv(std.os.windows.WINAPI) ?*anyopaque;
extern "wininet" fn InternetSetOptionW(hInternet: ?*anyopaque, dwOption: u32, lpBuffer: ?*anyopaque, dwBufferLength: u32) callconv(std.os.windows.WINAPI) std.os.windows.BOOL;
extern "advapi32" fn RegCreateKeyExW(
    hKey: std.os.windows.HKEY,
    lpSubKey: [*:0]const std.os.windows.WCHAR,
    Reserved: u32,
    lpClass: ?[*:0]const std.os.windows.WCHAR,
    dwOptions: u32,
    samDesired: u32,
    lpSecurityAttributes: ?*anyopaque,
    phkResult: *std.os.windows.HKEY,
    lpdwDisposition: ?*u32,
) callconv(std.os.windows.WINAPI) u32;
extern "advapi32" fn RegSetValueExW(
    hKey: std.os.windows.HKEY,
    lpValueName: [*:0]const std.os.windows.WCHAR,
    Reserved: u32,
    dwType: u32,
    lpData: ?[*]const u8,
    cbData: u32,
) callconv(std.os.windows.WINAPI) u32;
extern "advapi32" fn RegCloseKey(hKey: std.os.windows.HKEY) callconv(std.os.windows.WINAPI) u32;

fn changeCwd(allocator: std.mem.Allocator, dir: []const u8) void {
    switch (builtin.os.tag) {
        .windows => {
            const wdir = std.unicode.utf8ToUtf16LeAllocZ(allocator, dir) catch return;
            defer allocator.free(wdir);
            _ = SetCurrentDirectoryW(wdir.ptr);
        },
        else => {
            std.posix.chdir(dir) catch return;
        },
    }
}

fn fileExists(allocator: std.mem.Allocator, dir: []const u8, name: []const u8) bool {
    _ = allocator;
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const sep = std.fs.path.sep;
    const needs_sep = dir.len > 0 and dir[dir.len - 1] != sep;
    const path = if (needs_sep)
        (std.fmt.bufPrint(&buf, "{s}{c}{s}", .{ dir, sep, name }) catch return false)
    else
        (std.fmt.bufPrint(&buf, "{s}{s}", .{ dir, name }) catch return false);
    if (std.fs.path.isAbsolute(path)) {
        std.fs.accessAbsolute(path, .{}) catch return false;
    } else {
        std.fs.cwd().access(path, .{}) catch return false;
    }
    return true;
}

fn pickWorkingDir(allocator: std.mem.Allocator, exe_dir: []const u8) struct { dir: []const u8, ok: bool } {
    const parent = std.fs.path.dirname(exe_dir) orelse exe_dir;
    const grand = std.fs.path.dirname(parent) orelse parent;
    const cwd_path = std.fs.cwd().realpathAlloc(allocator, ".") catch exe_dir;

    const candidates = [_][]const u8{ cwd_path, grand, parent, exe_dir };

    for (candidates) |c| {
        const has_freesr = fileExists(allocator, c, "freesr-data.json");
        const has_resources = fileExists(allocator, c, "resources");
        const has_protocol = fileExists(allocator, c, "protocol");
        if (has_freesr and has_resources and has_protocol) return .{ .dir = c, .ok = true };
    }
    return .{ .dir = exe_dir, .ok = false };
}

fn disableWindowsSystemProxy(allocator: std.mem.Allocator) void {
    _ = allocator;
    if (builtin.os.tag != .windows) return;

    const subkey_u8 = "Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings";
    const subkey = std.unicode.utf8ToUtf16LeAllocZ(std.heap.page_allocator, subkey_u8) catch return;
    defer std.heap.page_allocator.free(subkey);

    var key: std.os.windows.HKEY = undefined;
    const KEY_SET_VALUE: u32 = 0x0002;
    const REG_OPTION_NON_VOLATILE: u32 = 0x0000;
    const REG_DWORD: u32 = 4;
    const rc = RegCreateKeyExW(std.os.windows.HKEY_CURRENT_USER, subkey.ptr, 0, null, REG_OPTION_NON_VOLATILE, KEY_SET_VALUE, null, &key, null);
    if (rc != 0) return;
    defer _ = RegCloseKey(key);

    const value_name = std.unicode.utf8ToUtf16LeAllocZ(std.heap.page_allocator, "ProxyEnable") catch return;
    defer std.heap.page_allocator.free(value_name);

    var zero: u32 = 0;
    _ = RegSetValueExW(key, value_name.ptr, 0, REG_DWORD, std.mem.asBytes(&zero).ptr, 4);

    // INTERNET_OPTION_SETTINGS_CHANGED (39) + INTERNET_OPTION_REFRESH (37)
    _ = InternetSetOptionW(null, 39, null, 0);
    _ = InternetSetOptionW(null, 37, null, 0);
}

fn findProxyExePath(allocator: std.mem.Allocator, exe_dir: []const u8) ?[]u8 {
    const name = if (builtin.os.tag == .windows) "firefly-proxy.exe" else "firefly-proxy";
    const candidate = std.fs.path.join(allocator, &[_][]const u8{ exe_dir, name }) catch return null;
    if (std.fs.path.isAbsolute(candidate)) {
        std.fs.accessAbsolute(candidate, .{}) catch {
            allocator.free(candidate);
            return null;
        };
    } else {
        std.fs.cwd().access(candidate, .{}) catch {
            allocator.free(candidate);
            return null;
        };
    }
    return candidate;
}

fn enableUtf8ConsoleOnWindows() void {
    if (builtin.os.tag != .windows) return;
    _ = SetConsoleOutputCP(65001);
    _ = SetConsoleCP(65001);
}

const Settings = struct {
    last_selected: ?[]u8 = null,
    disable_proxy: bool = false,

    fn deinit(self: *Settings, allocator: std.mem.Allocator) void {
        if (self.last_selected) |p| allocator.free(p);
        self.* = .{};
    }
};

fn loadSettings(allocator: std.mem.Allocator) Settings {
    var settings: Settings = .{};
    const file = std.fs.cwd().openFile("CastoricePS-settings.json", .{}) catch return settings;
    defer file.close();
    const file_size = file.getEndPos() catch return settings;
    const buf = file.readToEndAlloc(allocator, file_size) catch return settings;
    defer allocator.free(buf);

    var tree = std.json.parseFromSlice(std.json.Value, allocator, buf, .{}) catch return settings;
    defer tree.deinit();
    if (tree.value != .object) return settings;
    if (tree.value.object.get("last_selected")) |v| {
        if (v == .string and v.string.len != 0) settings.last_selected = allocator.dupe(u8, v.string) catch null;
    }
    if (tree.value.object.get("disable_proxy")) |v| {
        if (v == .bool) settings.disable_proxy = v.bool;
    }
    return settings;
}

fn saveSettings(settings: Settings) void {
    var file = std.fs.cwd().createFile("CastoricePS-settings.json", .{ .truncate = true }) catch return;
    defer file.close();
    const root = .{
        .last_selected = settings.last_selected orelse "",
        .disable_proxy = settings.disable_proxy,
    };
    std.json.stringify(root, .{ .whitespace = .indent_2 }, file.writer()) catch {};
}

fn fileExistsAny(path: []const u8) bool {
    if (std.fs.path.isAbsolute(path)) {
        std.fs.accessAbsolute(path, .{}) catch return false;
    } else {
        std.fs.cwd().access(path, .{}) catch return false;
    }
    return true;
}

fn selectGameExeViaDialogWindows(allocator: std.mem.Allocator) ?[]u8 {
    if (builtin.os.tag != .windows) return null;

    const ps = [_][]const u8{
        "powershell",
        "-NoProfile",
        "-STA",
        "-Command",
        "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; "
        ++ "Add-Type -AssemblyName System.Windows.Forms; "
        ++ "$o = New-Object System.Windows.Forms.OpenFileDialog; "
        ++ "$o.Filter = 'StarRail.exe|StarRail.exe|Executable (*.exe)|*.exe|All files (*.*)|*.*'; "
        ++ "$o.Title = 'Select StarRail.exe'; "
        ++ "if ($o.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { Write-Output $o.FileName }",
    };

    var child = std.process.Child.init(&ps, allocator);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Ignore;
    child.spawn() catch return null;

    const stdout_bytes = child.stdout.?.reader().readAllAlloc(allocator, 16 * 1024) catch return null;
    _ = child.wait() catch {};
    defer allocator.free(stdout_bytes);
    const trimmed = std.mem.trim(u8, stdout_bytes, " \r\n\t");
    if (trimmed.len == 0) return null;

    const p = allocator.dupe(u8, trimmed) catch return null;
    if (!fileExistsAny(p)) {
        allocator.free(p);
        return null;
    }
    return p;
}

fn launchGameWindows(allocator: std.mem.Allocator, game_exe_path: []const u8) void {
    if (builtin.os.tag != .windows) return;

    const game_dir = std.fs.path.dirname(game_exe_path) orelse ".";

    const wexe = std.unicode.utf8ToUtf16LeAllocZ(allocator, game_exe_path) catch return;
    defer allocator.free(wexe);

    const wdir = std.unicode.utf8ToUtf16LeAllocZ(allocator, game_dir) catch return;
    defer allocator.free(wdir);

    const SW_SHOWNORMAL: i32 = 1;

    // First try normal launch. If the game requires elevation, Windows will show UAC.
    const h1 = ShellExecuteW(null, null, wexe.ptr, null, wdir.ptr, SW_SHOWNORMAL);
    const code1: usize = if (h1) |p| @intFromPtr(p) else 0;
    if (code1 > 32) return;

    // Fallback: explicitly request elevation (UAC prompt) without elevating this process.
    const wrunas = std.unicode.utf8ToUtf16LeAllocZ(allocator, "runas") catch return;
    defer allocator.free(wrunas);

    const h2 = ShellExecuteW(null, wrunas.ptr, wexe.ptr, null, wdir.ptr, SW_SHOWNORMAL);
    const code2: usize = if (h2) |p| @intFromPtr(p) else 0;
    if (code2 <= 32) {
        std.log.warn("[Program] failed to launch game (ShellExecuteW error code: {d})", .{code2});
    }
}

fn startFireflyProxy(
    allocator: std.mem.Allocator,
    exe_dir: []const u8,
    workdir: []const u8,
    game_exe_path: ?[]const u8,
    disable_proxy_setting: bool,
) ?std.process.Child {
    const disable = std.process.getEnvVarOwned(allocator, "CASTORICEPS_NO_PROXY") catch null;
    if (disable) |v| {
        if (v.len > 0 and !std.mem.eql(u8, v, "0")) return null;
    }
    if (disable_proxy_setting) return null;

    const proxy_path = findProxyExePath(allocator, exe_dir) orelse return null;

    const redirect_host = std.process.getEnvVarOwned(allocator, "CASTORICEPS_PROXY_REDIRECT") catch null;
    const r = redirect_host orelse "127.0.0.1:21000";

    _ = game_exe_path;

    const argv = allocator.alloc([]const u8, 3) catch return null;
    argv[0] = proxy_path;
    argv[1] = "-r";
    argv[2] = r;

    var child = std.process.Child.init(argv, allocator);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    child.cwd = workdir;
    child.spawn() catch return null;

    std.log.info("[Program] started firefly proxy: {s} -r {s}", .{ proxy_path, r });
    return child;
}

fn runDispatch() void {
    if (dispatch_main.main()) |_| {
        std.log.info("{s}[Dispatch]{s} stopped gracefully", .{ color.blue, color.reset });
    } else |err| {
        std.log.err("{s}[Dispatch]{s} exited with error: {s}", .{ color.blue, color.reset, @errorName(err) });
    }
}

fn runGameserver() void {
    if (gameserver_main.main()) |_| {
        std.log.info("{s}[GameServer]{s} stopped gracefully", .{ color.blue, color.reset });
    } else |err| {
        std.log.err("{s}[GameServer]{s} exited with error: {s}", .{ color.blue, color.reset, @errorName(err) });
    }
}

fn computeHwId(allocator: std.mem.Allocator) ![]u8 {
    var hasher = std.crypto.hash.Blake3.init(.{});

    const host_env = std.process.getEnvVarOwned(allocator, "COMPUTERNAME") catch null;
    if (host_env) |h| {
        defer allocator.free(h);
        hasher.update(h);
    }

    const self_path = std.fs.selfExePathAlloc(allocator) catch null;
    if (self_path) |p| {
        defer allocator.free(p);
        hasher.update(p);
    }

    var digest: [32]u8 = undefined;
    hasher.final(&digest);
    return try std.fmt.allocPrint(allocator, "{s}", .{std.fmt.fmtSliceHexLower(digest[0..16])});
}

fn collectIpStrings(allocator: std.mem.Allocator) ![]const []const u8 {
    _ = allocator;
    return &[_][]const u8{};
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var stdin = std.io.getStdIn().reader();
    var stdout = std.io.getStdOut().writer();

    enableUtf8ConsoleOnWindows();

    // Ensure working directory is the executable's directory so relative resources resolve.
    var workdir: []const u8 = ".";
    var exe_dir: []const u8 = ".";
    var has_full_paths = false;
    if (std.fs.selfExePathAlloc(allocator)) |self_path| {
        if (std.fs.path.dirname(self_path)) |exe_dir_path| {
            exe_dir = exe_dir_path;
            const pick = pickWorkingDir(allocator, exe_dir_path);
            workdir = pick.dir;
            has_full_paths = pick.ok;
            changeCwd(allocator, workdir);
        }
    } else |_| {}

    if (!has_full_paths) {
        std.log.warn("[Program] could not find complete freesr-data/resources/protocol; continuing with cwd '{s}'", .{workdir});
        std.log.warn("[Program] ensure freesr-data.json, resources/, protocol/ are present in cwd or parent directories", .{});
    }

    // Optional: choose game path and launch via firefly proxy.
    var selected_game_exe: ?[]u8 = null;
    defer if (selected_game_exe) |p| allocator.free(p);

    var settings = loadSettings(allocator);
    defer settings.deinit(allocator);

    const no_game_launch = std.process.getEnvVarOwned(allocator, "CASTORICEPS_NO_GAME_LAUNCH") catch null;
    if (!settings.disable_proxy and (no_game_launch == null or std.mem.eql(u8, no_game_launch.?, "0"))) {
        const force_pick = std.process.getEnvVarOwned(allocator, "CASTORICEPS_FORCE_GAME_PICK") catch null;
        const should_force_pick = force_pick != null and force_pick.?.len != 0 and !std.mem.eql(u8, force_pick.?, "0");

        if (std.process.getEnvVarOwned(allocator, "CASTORICEPS_GAME_PATH") catch null) |v| {
            if (fileExistsAny(v)) {
                selected_game_exe = v;
            } else {
                allocator.free(v);
            }
        } else if (!should_force_pick) {
            if (settings.last_selected) |saved| {
                if (fileExistsAny(saved)) {
                    selected_game_exe = saved;
                    settings.last_selected = null; // transfer ownership
                }
            }
        }

        if (selected_game_exe == null) {
            selected_game_exe = selectGameExeViaDialogWindows(allocator);
            if (selected_game_exe) |p| saveSettings(.{ .last_selected = p, .disable_proxy = settings.disable_proxy });
        }
    }

    // Start bundled proxy (best-effort).
    var proxy_child_opt: ?std.process.Child = startFireflyProxy(allocator, exe_dir, workdir, selected_game_exe, settings.disable_proxy);
    defer {
        if (proxy_child_opt) |*child| {
            blk: {
                _ = child.kill() catch |err| {
                    std.log.warn("[Program] failed to stop firefly proxy: {s}", .{@errorName(err)});
                    break :blk;
                };
            }
            disableWindowsSystemProxy(allocator);
        }
    }

    if (!settings.disable_proxy) {
        if (selected_game_exe) |p| {
            launchGameWindows(allocator, p);
        }
    }

    // Pink notices at the very start.
    std.debug.print("{s}CastoricePS by aero_pro. Completely free to use.{s}\n", .{ color.pink, color.reset });
    std.debug.print("{s}It's a free software, If you paid for it, you've been scammed.{s}\n", .{ color.pink, color.reset });

    // Device info: HWID and IP addresses.
    const hwid_opt: ?[]u8 = computeHwId(allocator) catch |err| blk: {
        std.log.err("Failed to compute HWID: {s}", .{@errorName(err)});
        break :blk null;
    };
    defer if (hwid_opt) |v| allocator.free(v);
    const hwid = hwid_opt orelse "unknown";

    const ip_list_opt: ?[]const []const u8 = collectIpStrings(allocator) catch |err| blk: {
        std.log.err("Failed to collect IP addresses: {s}", .{@errorName(err)});
        break :blk null;
    };
    defer if (ip_list_opt) |list| {
        for (list) |item| allocator.free(item);
        allocator.free(list);
    };
    const ip_list = ip_list_opt orelse &[_][]const u8{"unknown"};

    std.log.info("Device HWID: {s}", .{hwid});
    for (ip_list) |ip| {
        std.log.info("Detected IP: {s}", .{ip});
    }

    std.log.info("Starting embedded servers (dispatch + gameserver)...", .{});

    const dispatch_thread = try std.Thread.spawn(.{}, runDispatch, .{});
    const gameserver_thread = try std.Thread.spawn(.{}, runGameserver, .{});

    dispatch_thread.detach();
    gameserver_thread.detach();

    // REPL loop: allow user to type commands without being disrupted by logs.
    try stdout.print("{s}", .{prompt_prefix});
    while (true) {
        var buf: [256]u8 = undefined;
        const line = stdin.readUntilDelimiterOrEof(&buf, '\n') catch |err| {
            std.log.err("Input error: {s}", .{@errorName(err)});
            break;
        };
        if (line == null) break;
        const trimmed = std.mem.trim(u8, line.?, " \r\n");
        if (trimmed.len == 0) {
            try stdout.print("{s}", .{prompt_prefix});
            continue;
        }
        if (std.mem.eql(u8, trimmed, "exit") or std.mem.eql(u8, trimmed, "quit")) break;
        // Echo the command; hook here to forward to servers if desired.
        try stdout.print("{s} command received: {s}\n", .{ prompt_prefix, trimmed });
        try stdout.print("{s}", .{prompt_prefix});
    }
}
