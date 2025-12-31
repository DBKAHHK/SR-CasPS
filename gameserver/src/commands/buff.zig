const commandhandler = @import("../command.zig");
const std = @import("std");
const Session = @import("../Session.zig");
const Logic = @import("../utils/logic.zig");

const Allocator = std.mem.Allocator;

pub fn handle(session: *Session, args: []const u8, allocator: Allocator) !void {
    var it = std.mem.tokenizeAny(u8, args, " \t");
    const token = it.next() orelse {
        return commandhandler.sendMessage(session, "Usage: /buff <id|off|info>", allocator);
    };

    if (std.ascii.eqlIgnoreCase(token, "info")) {
        const msg = try std.fmt.allocPrint(
            allocator,
            "CustomMode: {s}, challenge_id={d}, buff_id={d}",
            .{
                if (Logic.CustomMode().CustomMode()) "ON" else "OFF",
                Logic.CustomMode().GetCustomChallengeID(),
                Logic.CustomMode().GetCustomBuffID(),
            },
        );
        defer allocator.free(msg);
        return commandhandler.sendMessage(session, msg, allocator);
    }

    if (std.ascii.eqlIgnoreCase(token, "off")) {
        Logic.CustomMode().SetCustomBuffID(0);
        return commandhandler.sendMessage(session, "Cleared custom buff id.", allocator);
    }

    const buff_id = std.fmt.parseInt(u32, token, 10) catch {
        return commandhandler.sendMessage(session, "Usage: /buff <id|off|info>", allocator);
    };

    Logic.CustomMode().SetCustomBuffID(buff_id);
    if (Logic.CustomMode().GetCustomChallengeID() != 0) {
        Logic.CustomMode().SetCustomMode(true);
        return commandhandler.sendMessage(session, "Set custom buff id (custom mode ON).", allocator);
    }

    return commandhandler.sendMessage(session, "Set custom buff id. Note: custom mode is OFF until you select a challenge via /id.", allocator);
}

