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
        const has_config = fileExists(allocator, c, "config.json");
        const has_resources = fileExists(allocator, c, "resources");
        const has_protocol = fileExists(allocator, c, "protocol");
        if (has_config and has_resources and has_protocol) return .{ .dir = c, .ok = true };
    }
    return .{ .dir = exe_dir, .ok = false };
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

    // Ensure working directory is the executable's directory so relative resources resolve.
    var workdir: []const u8 = ".";
    var has_full_paths = false;
    if (std.fs.selfExePathAlloc(allocator)) |self_path| {
        defer allocator.free(self_path);
        if (std.fs.path.dirname(self_path)) |exe_dir| {
            const pick = pickWorkingDir(allocator, exe_dir);
            workdir = pick.dir;
            has_full_paths = pick.ok;
            changeCwd(allocator, workdir);
        }
    } else |_| {}

    if (!has_full_paths) {
        std.log.warn("[Program] could not find complete config/resources/protocol; continuing with cwd '{s}'", .{workdir});
        std.log.warn("[Program] ensure config.json, resources/, protocol/ are present in cwd or parent directories", .{});
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
    var stdin = std.io.getStdIn().reader();
    var stdout = std.io.getStdOut().writer();
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
