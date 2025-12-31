const commandhandler = @import("../command.zig");
const std = @import("std");
const Session = @import("../Session.zig");
const protocol = @import("protocol");
const PlayerStateMod = @import("../player_state.zig");
const LineupManager = @import("../manager/lineup_mgr.zig");
const AvatarManager = @import("../manager/avatar_mgr.zig");

const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

const MaxLineups = PlayerStateMod.MaxLineups;
const LineupSlots = PlayerStateMod.LineupSlots;

const default_lineup_names = [_][]const u8{
    "Team 1",
    "Team 2",
    "Team 3",
    "Team 4",
    "Team 5",
    "Team 6",
};

fn buildPresetLineup(allocator: Allocator, preset: PlayerStateMod.LineupPreset, index: u32) !protocol.LineupInfo {
    var ids = std.ArrayList(u32).init(allocator);
    defer ids.deinit();
    for (preset) |id| if (id != 0) try ids.append(id);
    if (ids.items.len == 0) try ids.append(AvatarManager.getMcId());

    var lineup = try LineupManager.buildLineup(allocator, ids.items, null);
    lineup.index = index;
    if (index < default_lineup_names.len) {
        lineup.name = .{ .Const = default_lineup_names[@intCast(index)] };
    }
    return lineup;
}

fn printLineupList(session: *Session, state: *const PlayerStateMod.PlayerState, allocator: Allocator) !void {
    const header = try std.fmt.allocPrint(allocator, "Current lineup index: {d}", .{state.cur_lineup_index});
    defer allocator.free(header);
    try commandhandler.sendMessage(session, header, allocator);

    var i: u32 = 0;
    while (i < MaxLineups) : (i += 1) {
        const preset = state.lineups[@intCast(i)];
        const msg = try std.fmt.allocPrint(
            allocator,
            "{d}: [{d}, {d}, {d}, {d}]",
            .{ i, preset[0], preset[1], preset[2], preset[3] },
        );
        defer allocator.free(msg);
        try commandhandler.sendMessage(session, msg, allocator);
    }
}

pub fn handle(session: *Session, args: []const u8, allocator: Allocator) !void {
    var it = std.mem.tokenizeAny(u8, args, " \t");
    const sub = it.next() orelse "list";

    if (session.player_state) |*state| {
        if (std.ascii.eqlIgnoreCase(sub, "list")) {
            return printLineupList(session, state, allocator);
        }

        if (std.ascii.eqlIgnoreCase(sub, "switch")) {
            const idx_str = it.next() orelse return commandhandler.sendMessage(session, "Usage: /lineup switch <index>", allocator);
            const idx = std.fmt.parseInt(u32, idx_str, 10) catch return commandhandler.sendMessage(session, "Usage: /lineup switch <index>", allocator);
            if (idx >= MaxLineups) return commandhandler.sendMessage(session, "Error: index out of range.", allocator);

            state.cur_lineup_index = idx;

            var ids = std.ArrayList(u32).init(allocator);
            defer ids.deinit();
            for (state.lineups[@intCast(idx)]) |id| if (id != 0) try ids.append(id);
            try LineupManager.getSelectedAvatarID(allocator, ids.items);

            const lineup_info = try buildPresetLineup(allocator, state.lineups[@intCast(idx)], idx);
            var sync = protocol.SyncLineupNotify.init(allocator);
            sync.lineup = lineup_info;
            try session.send(CmdID.CmdSyncLineupNotify, sync);

            const msg = try std.fmt.allocPrint(allocator, "Switched to lineup {d}.", .{idx});
            defer allocator.free(msg);
            try commandhandler.sendMessage(session, msg, allocator);
            try PlayerStateMod.save(state);
            return;
        }

        if (std.ascii.eqlIgnoreCase(sub, "set")) {
            const idx_str = it.next() orelse return commandhandler.sendMessage(session, "Usage: /lineup set <index> <id1> <id2> <id3> <id4>", allocator);
            const idx = std.fmt.parseInt(u32, idx_str, 10) catch return commandhandler.sendMessage(session, "Usage: /lineup set <index> <id1> <id2> <id3> <id4>", allocator);
            if (idx >= MaxLineups) return commandhandler.sendMessage(session, "Error: index out of range.", allocator);

            var preset: PlayerStateMod.LineupPreset = std.mem.zeroes(PlayerStateMod.LineupPreset);
            var slot: usize = 0;
            while (slot < LineupSlots) : (slot += 1) {
                const id_str = it.next() orelse break;
                preset[slot] = std.fmt.parseInt(u32, id_str, 10) catch {
                    return commandhandler.sendMessage(session, "Usage: /lineup set <index> <id1> <id2> <id3> <id4>", allocator);
                };
            }
            if (it.next() != null) {
                return commandhandler.sendMessage(session, "Usage: /lineup set <index> <id1> <id2> <id3> <id4>", allocator);
            }

            state.lineups[@intCast(idx)] = preset;

            // If editing the current lineup, refresh runtime selected lineup.
            if (state.cur_lineup_index == idx) {
                var ids = std.ArrayList(u32).init(allocator);
                defer ids.deinit();
                for (preset) |id| if (id != 0) try ids.append(id);
                try LineupManager.getSelectedAvatarID(allocator, ids.items);
            }

            const lineup_info = try buildPresetLineup(allocator, preset, idx);
            var sync = protocol.SyncLineupNotify.init(allocator);
            sync.lineup = lineup_info;
            try session.send(CmdID.CmdSyncLineupNotify, sync);

            try PlayerStateMod.save(state);
            return commandhandler.sendMessage(session, "Lineup updated.", allocator);
        }

        return commandhandler.sendMessage(session, "Usage: /lineup <list|switch|set>", allocator);
    }

    return commandhandler.sendMessage(session, "No player state loaded; lineup command unavailable.", allocator);
}
