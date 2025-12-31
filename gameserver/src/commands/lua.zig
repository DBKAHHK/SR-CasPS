const std = @import("std");
const Session = @import("../Session.zig");
const commandhandler = @import("../command.zig");

const Allocator = std.mem.Allocator;

fn isUnsafePath(p: []const u8) bool {
    if (p.len == 0) return true;
    if (std.fs.path.isAbsolute(p)) return true;
    if (std.mem.indexOf(u8, p, ":")) |_| return true; // prevent drive letters on Windows

    var it = std.mem.tokenizeScalar(u8, p, std.fs.path.sep);
    while (it.next()) |seg| {
        if (std.mem.eql(u8, seg, "..")) return true;
    }
    return false;
}

fn readLuaFile(allocator: Allocator, rel_path: []const u8) ![]u8 {
    if (isUnsafePath(rel_path)) return error.InvalidPath;

    const path = if (std.mem.startsWith(u8, rel_path, "lua/") or std.mem.startsWith(u8, rel_path, "lua\\"))
        rel_path
    else
        try std.fs.path.join(allocator, &[_][]const u8{ "lua", rel_path });
    defer if (path.ptr != rel_path.ptr) allocator.free(path);

    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const size = try file.getEndPos();
    if (size > 512 * 1024) return error.FileTooBig;
    return try file.readToEndAlloc(allocator, size);
}

pub fn handle(session: *Session, args: []const u8, allocator: Allocator) !void {
    const trimmed = std.mem.trim(u8, args, " \r\n\t");
    if (trimmed.len == 0) {
        try commandhandler.sendMessage(session, "Usage: /lua <file.lua>  (reads from lua/ and executes on next heartbeat)", allocator);
        try commandhandler.sendMessage(session, "Example: /lua heartbeat.lua", allocator);
        return;
    }

    const content = readLuaFile(allocator, trimmed) catch |err| {
        const msg = switch (err) {
            error.InvalidPath => "Invalid path. Only files under lua/ are allowed.",
            error.FileTooBig => "Lua file too big (max 512KB).",
            error.FileNotFound => "Lua file not found.",
            else => "Failed to read lua file.",
        };
        return commandhandler.sendMessage(session, msg, allocator);
    };

    // Transfer ownership to session; it will be sent once on the next PlayerHeartBeat.
    session.setPendingLuaScript(content);
    try commandhandler.sendMessage(session, "Lua queued. It will be sent/executed on the next heartbeat.", allocator);
}

