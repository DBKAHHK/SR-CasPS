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
            var has_selected = false;
            for (BattleManager.selectedAvatarID) |id| {
                if (id != 0) {
                    has_selected = true;
                    break;
                }
            }
            if (has_selected) {
                for (BattleManager.selectedAvatarID) |id| {
                    if (id != 0) try ids.append(id);
                }
            } else {
                // 3) Fallback to misc.json defaults if present.
                const misc_lineup = ConfigManager.global_misc_defaults.player.lineup;
                if (misc_lineup.len > 0) {
                    try ids.appendSlice(misc_lineup);
                }
            }
        }

        // 4) If still empty, fall back to first 4 avatars from config.
        if (ids.items.len == 0) {
            var picked_mc = false;
            var picked_m7th = false;
            for (config.avatar_config.items) |avatarConf| {
                if (ids.items.len >= 4) break;
                const id = switch (avatarConf.id) {
                    8001...8008 => if (!picked_mc) blk: {
                        picked_mc = true;
                        break :blk AvatarManager.getMcId();
                    } else continue,
                    1224, 1001 => if (!picked_m7th) blk: {
                        picked_m7th = true;
                        break :blk AvatarManager.m7th;
                    } else continue,
                    else => avatarConf.id,
                };
                try ids.append(id);
            }
        }

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

pub fn getSelectedAvatarID(allocator: Allocator, input: []const u32) !void {
    var tempList = ArrayList(u32).init(allocator);
    defer tempList.deinit();
    try tempList.appendSlice(input);
    for (tempList.items) |*item| {
        if (item.* == 8001) item.* = AvatarManager.getMcId();
        if (item.* == 1001) item.* = AvatarManager.m7th;
    }
    var i: usize = 0;
    while (i < BattleManager.selectedAvatarID.len and i < tempList.items.len) : (i += 1) {
        BattleManager.selectedAvatarID[i] = tempList.items[i];
    }
    while (i < BattleManager.selectedAvatarID.len) : (i += 1) {
        BattleManager.selectedAvatarID[i] = 0;
    }
}
pub fn getFunModeAvatarID(input: []const u32) !void {
    BattleManager.funmodeAvatarID.clearRetainingCapacity();
    try BattleManager.funmodeAvatarID.appendSlice(input);
}
