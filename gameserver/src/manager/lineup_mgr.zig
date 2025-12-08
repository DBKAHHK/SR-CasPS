const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const BattleManager = @import("../manager/battle_mgr.zig");
const AvatarManager = @import("../manager/avatar_mgr.zig");
const ConfigManager = @import("../manager/config_mgr.zig");
const Logic = @import("../utils/logic.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

const config = &ConfigManager.global_game_config_cache.game_config;

pub const LineupManager = struct {
    allocator: Allocator,
    pub fn init(allocator: Allocator) LineupManager {
        return LineupManager{ .allocator = allocator };
    }
    pub fn createLineup(self: *LineupManager) !protocol.LineupInfo {
        var ids = ArrayList(u32).init(self.allocator);
        defer ids.deinit();

        // 1) Fun mode uses its own lineup.
        if (Logic.FunMode().FunMode()) {
            try ids.appendSlice(BattleManager.funmodeAvatarID.items);
        } else {
            // 2) Use current selected lineup if it has any non-zero entries.
            if (BattleManager.selectedAvatarID.items.len > 0) {
                for (BattleManager.selectedAvatarID.items) |id| {
                    if (id != 0) try ids.append(id);
                }
            } else {
                // 3) Fallback to misc.json defaults (global single source of truth).
                const misc_lineup = ConfigManager.global_misc_defaults.player.lineup;
                if (misc_lineup.len > 0) {
                    try ids.appendSlice(misc_lineup);
                }
            }
        }

        // 4) If still empty, at least ensure MC exists to avoid empty lineup crashes.
        if (ids.items.len == 0) try ids.append(AvatarManager.getMcId());

        return try buildLineup(self.allocator, ids.items, null);
    }
};

pub const ChallengeLineupManager = struct {
    allocator: Allocator,
    pub fn init(allocator: Allocator) ChallengeLineupManager {
        return ChallengeLineupManager{ .allocator = allocator };
    }
    pub fn createPeakLineup(self: *ChallengeLineupManager, avatar_list: ArrayList(u32)) !protocol.LineupInfo {
        return try buildLineup(self.allocator, avatar_list.items, .LINEUP_CHALLENGE);
    }
    pub fn createLineup(self: *ChallengeLineupManager, avatar_list: ArrayList(u32)) !protocol.LineupInfo {
        const t = if (Logic.CustomMode().FirstNode())
            protocol.ExtraLineupType.LINEUP_CHALLENGE
        else
            protocol.ExtraLineupType.LINEUP_CHALLENGE_2;
        return try buildLineup(self.allocator, avatar_list.items, t);
    }
};

pub fn buildLineup(
    allocator: Allocator,
    ids: []const u32,
    extra_type: ?protocol.ExtraLineupType,
) !protocol.LineupInfo {
    var lineup = protocol.LineupInfo.init(allocator);
    lineup.mp = 5;
    lineup.max_mp = 5;
    if (extra_type) |t| {
        lineup.extra_lineup_type = t;
    } else {
        lineup.name = .{ .Const = "HyacineLover" };
    }

    for (ids, 0..) |id, idx| {
        var avatar = protocol.LineupAvatar.init(allocator);
        avatar.id = id;
        if (id == 1408) {
            lineup.mp = 7;
            lineup.max_mp = 7;
        }
        avatar.slot = @intCast(idx);
        avatar.satiety = 0;
        avatar.hp = 10000;
        avatar.sp_bar = .{ .cur_sp = 10000, .max_sp = 10000 };
        avatar.avatar_type = protocol.AvatarType.AVATAR_FORMAL_TYPE;
        try lineup.avatar_list.append(avatar);
    }
    var id_list = try allocator.alloc(u32, lineup.avatar_list.items.len);
    defer allocator.free(id_list);
    for (lineup.avatar_list.items, 0..) |ava, idx| {
        id_list[idx] = ava.id;
    }
    try getSelectedAvatarID(allocator, id_list);
    return lineup;
}

pub fn deinitLineupInfo(lineup: *protocol.LineupInfo) void {
    lineup.avatar_list.deinit();
}

pub fn deinitChallengeLineupInfo(lineup: *protocol.LineupInfo) void {
    lineup.avatar_list.deinit();
}

pub fn getSelectedAvatarID(_: Allocator, input: []const u32) !void {
    BattleManager.selectedAvatarID.clearRetainingCapacity();
    try BattleManager.selectedAvatarID.appendSlice(input);
    for (BattleManager.selectedAvatarID.items) |*item| {
        if (item.* == 8001) item.* = AvatarManager.getMcId();
        if (item.* == 1001) item.* = AvatarManager.m7th;
    }
}
pub fn getFunModeAvatarID(input: []const u32) !void {
    BattleManager.funmodeAvatarID.clearRetainingCapacity();
    try BattleManager.funmodeAvatarID.appendSlice(input);
}
