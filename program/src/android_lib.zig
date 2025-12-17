const std = @import("std");
const dispatch_main = @import("dispatch_main");
const gameserver_main = @import("gameserver_main");

const log = std.log.scoped(.android_lib);

var started = std.atomic.Value(bool).init(false);
var dispatch_thread: ?std.Thread = null;
var gameserver_thread: ?std.Thread = null;

fn runDispatch() void {
    if (dispatch_main.main()) |_| {
        log.info("[Dispatch] stopped", .{});
    } else |err| {
        log.err("[Dispatch] exited with error: {s}", .{@errorName(err)});
    }
}

fn runGameserver() void {
    if (gameserver_main.main()) |_| {
        log.info("[GameServer] stopped", .{});
    } else |err| {
        log.err("[GameServer] exited with error: {s}", .{@errorName(err)});
    }
}

// JNI bridge (no args). Kotlin side can set `CASTORICEPS_WORKDIR` before start().
export fn Java_dev_neonteam_castoriceps_NativeBridge_start(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.C) i32 {
    // Configure workdir via env var set by Kotlin: CASTORICEPS_WORKDIR
    if (std.process.getEnvVarOwned(std.heap.page_allocator, "CASTORICEPS_WORKDIR")) |dir| {
        defer std.heap.page_allocator.free(dir);
        std.posix.chdir(dir) catch {};
    } else |_| {}

    if (started.swap(true, .seq_cst)) return 1; // already running
    dispatch_thread = std.Thread.spawn(.{}, runDispatch, .{}) catch {
        _ = started.swap(false, .seq_cst);
        return -1;
    };
    gameserver_thread = std.Thread.spawn(.{}, runGameserver, .{}) catch {
        if (dispatch_thread) |t| t.detach();
        dispatch_thread = null;
        _ = started.swap(false, .seq_cst);
        return -2;
    };
    if (dispatch_thread) |t| t.detach();
    if (gameserver_thread) |t| t.detach();
    dispatch_thread = null;
    gameserver_thread = null;
    return 0;
}

// Signature: public external fun stop(): Int
// NOTE: Current server code does not provide a clean in-process shutdown API.
export fn Java_dev_neonteam_castoriceps_NativeBridge_stop(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.C) i32 {
    // best-effort: mark as not started so UI can re-run; actual threads keep running
    _ = started.swap(false, .seq_cst);
    return 0;
}
