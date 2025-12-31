const commandhandler = @import("../command.zig");
const std = @import("std");
const Session = @import("../Session.zig");
const Logic = @import("../utils/logic.zig");

const Allocator = std.mem.Allocator;

pub fn handle(session: *Session, args: []const u8, allocator: Allocator) !void {
    var it = std.mem.tokenizeAny(u8, args, " \t");
    const token = it.next() orelse {
        return commandhandler.sendMessage(session, "Usage: /mhp <max|number|0|off>  (sets enemy max HP override for battles)", allocator);
    };

    const hp: u32 = blk: {
        if (std.ascii.eqlIgnoreCase(token, "off")) break :blk 0;
        if (std.ascii.eqlIgnoreCase(token, "max")) break :blk std.math.maxInt(i32);
        const parsed = std.fmt.parseInt(u32, token, 10) catch {
            return commandhandler.sendMessage(session, "Usage: /mhp <max|number|0|off>", allocator);
        };
        break :blk parsed;
    };

    // BattleManager uses this value (when non-zero) to override monster max HP for newly created battles.
    Logic.FunMode().SetHp(hp);

    const msg = if (hp == 0)
        "Enemy max HP override cleared (use real config values)."
    else
        try std.fmt.allocPrint(allocator, "Enemy max HP override set to {d} (applies to newly created battles).", .{hp});
    defer if (hp != 0) allocator.free(msg);
    try commandhandler.sendMessage(session, msg, allocator);
}
