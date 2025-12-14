const commandhandler = @import("../command.zig");
const Session = @import("../Session.zig");
const Config = @import("../data/stage_config.zig");
const MiscDefaults = @import("../data/misc_defaults.zig");
const ConfigManager = @import("../manager/config_mgr.zig");
const LineupManager = @import("../manager/lineup_mgr.zig");
const AvatarManager = @import("../manager/avatar_mgr.zig");
const BattleManager = @import("../manager/battle_mgr.zig");
const Logic = @import("../utils/logic.zig");
const PlayerStateMod = @import("../player_state.zig");
const ItemDb = @import("../item_db.zig");
const Sync = @import("sync.zig");
const protocol = @import("protocol");
const CmdID = protocol.CmdID;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

var next_mail_id: u32 = 1000;

fn isMcId(id: u32) bool {
    return id >= 8001 and id <= 8008;
}

fn applyMcToLineups(new_id: u32) void {
    for (BattleManager.selectedAvatarID.items) |*id| {
        if (isMcId(id.*)) id.* = new_id;
    }
    for (BattleManager.funmodeAvatarID.items) |*id| {
        if (isMcId(id.*)) id.* = new_id;
    }
}

pub fn handle(session: *Session, _: []const u8, allocator: Allocator) !void {
    try commandhandler.sendMessage(session, "Test Command for Chat\n", allocator);
}
pub fn challengeNode(session: *Session, _: []const u8, allocator: Allocator) !void {
    try commandhandler.sendMessage(session, Logic.CustomMode().ChangeNode(), allocator);
}
pub fn FunMode(session: *Session, input: []const u8, allocator: Allocator) !void {
    var args = std.mem.tokenizeAny(u8, input, " ");
    if (args.next()) |subcmd| {
        if (std.mem.eql(u8, subcmd, "on")) {
            Logic.FunMode().SetFunMode(true);
            const config = &ConfigManager.global_game_config_cache.game_config;
            var ids = std.ArrayList(u32).init(allocator);
            defer ids.deinit();
            var picked_mc = false;
            var picked_m7th = false;
            for (config.avatar_config.items) |avatarConf| {
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
            try LineupManager.getFunModeAvatarID(ids.items);
            // 自动保存当前玩家存档以持久化 funmode 编队
            if (session.player_state) |*state| {
                try PlayerStateMod.save(state);
            }
            try commandhandler.sendMessage(session, "Fun mode ON\n", allocator);
        } else if (std.mem.eql(u8, subcmd, "off")) {
            Logic.FunMode().SetFunMode(false);
            if (session.player_state) |*state| {
                try PlayerStateMod.save(state);
            }
            try commandhandler.sendMessage(session, "Fun mode OFF\n", allocator);
        } else if (std.mem.eql(u8, subcmd, "hp")) {
            if (args.next()) |hp_arg| {
                if (std.mem.eql(u8, hp_arg, "max")) {
                    Logic.FunMode().SetHp(std.math.maxInt(i32));
                    try commandhandler.sendMessage(session, "Set HP = MAX (2,147,483,647)\n", allocator);
                    try commandhandler.sendMessage(session, "Remember to set it back to 0 to use actual HP value\n", allocator);
                } else {
                    const parsed = try std.fmt.parseInt(i64, hp_arg, 10);
                    if (parsed < 0 or parsed > std.math.maxInt(i32)) {
                        try commandhandler.sendMessage(session, "Error: HP out of range (0 - 2147483647)\n", allocator);
                    } else {
                        Logic.FunMode().SetHp(@intCast(parsed));
                        try commandhandler.sendMessage(
                            session,
                            try std.fmt.allocPrint(allocator, "Set HP = {d}\n", .{parsed}),
                            allocator,
                        );
                        try commandhandler.sendMessage(session, "Remember to set it back to 0 to use actual HP value\n", allocator);
                    }
                }
            } else {
                try commandhandler.sendMessage(session, "Usage: /funmode hp <max|number>\n", allocator);
            }
        } else {
            try commandhandler.sendMessage(session, "Unknown funmode subcommand\n", allocator);
        }
    } else {
        try commandhandler.sendMessage(session, "Usage: /funmode <on|off|hp>\n", allocator);
    }
}

pub fn setGachaCommand(session: *Session, args: []const u8, allocator: Allocator) !void {
    var arg_iter = std.mem.splitSequence(u8, args, " ");
    const command = arg_iter.next() orelse {
        try commandhandler.sendMessage(session, "Error: Missing sub-command. Usage: /set <sub-command> [arguments]", allocator);
        return;
    };
    if (std.mem.eql(u8, command, "standard")) {
        try standard(session, &arg_iter, allocator);
    } else if (std.mem.eql(u8, command, "rateup")) {
        const next = arg_iter.next();
        if (next) |rateup_number| {
            if (std.mem.eql(u8, rateup_number, "5")) {
                try gacha5Stars(session, &arg_iter, allocator);
            } else if (std.mem.eql(u8, rateup_number, "4")) {
                try gacha4Stars(session, &arg_iter, allocator);
            } else {
                try commandhandler.sendMessage(session, "Error: Invalid rateup number. Please use 4 (four stars) or 5 (5 stars).", allocator);
            }
        } else {
            try commandhandler.sendMessage(session, "Error: Missing number for rateup. Usage: /set rateup <number>", allocator);
        }
    } else {
        try commandhandler.sendMessage(session, "Error: Unknown sub-command. Available: standard, rateup 5, rateup 4", allocator);
    }
}

fn standard(session: *Session, arg_iter: *std.mem.SplitIterator(u8, .sequence), allocator: Allocator) !void {
    var avatar_ids: [6]u32 = undefined;
    var count: usize = 0;
    while (count < 6) {
        if (arg_iter.next()) |avatar_id_str| {
            const id = std.fmt.parseInt(u32, avatar_id_str, 10) catch {
                return sendErrorMessage(session, "Error: Invalid avatar ID. Please provide a valid unsigned 32-bit integer.", allocator);
            };
            if (!isValidAvatarId(id)) {
                return sendErrorMessage(session, "Error: Invalid Avatar ID format.", allocator);
            }
            avatar_ids[count] = id;
            count += 1;
        } else {
            break;
        }
    }
    if (arg_iter.next() != null or count != 6) {
        return sendErrorMessage(session, "Error: You must provide exactly 6 avatar IDs.", allocator);
    }
    @memcpy(Logic.Banner().SetStandardBanner(), &avatar_ids);
    const msg = try std.fmt.allocPrint(allocator, "Set standard banner ID to: {d}, {d}, {d}, {d}, {d}, {d}", .{ avatar_ids[0], avatar_ids[1], avatar_ids[2], avatar_ids[3], avatar_ids[4], avatar_ids[5] });
    try commandhandler.sendMessage(session, msg, allocator);
}
fn gacha4Stars(session: *Session, arg_iter: *std.mem.SplitIterator(u8, .sequence), allocator: Allocator) !void {
    var avatar_ids: [3]u32 = undefined;
    var count: usize = 0;
    while (count < 3) {
        if (arg_iter.next()) |avatar_id_str| {
            const id = std.fmt.parseInt(u32, avatar_id_str, 10) catch {
                return sendErrorMessage(session, "Error: Invalid avatar ID. Please provide a valid unsigned 32-bit integer.", allocator);
            };
            if (!isValidAvatarId(id)) {
                return sendErrorMessage(session, "Error: Invalid Avatar ID format.", allocator);
            }
            avatar_ids[count] = id;
            count += 1;
        } else {
            break;
        }
    }
    if (arg_iter.next() != null or count != 3) {
        return sendErrorMessage(session, "Error: You must provide exactly 3 avatar IDs.", allocator);
    }
    @memcpy(Logic.Banner().SetRateUpFourStar(), &avatar_ids);
    const msg = try std.fmt.allocPrint(allocator, "Set 4 star rate up ID to: {d}, {d}, {d}", .{ avatar_ids[0], avatar_ids[1], avatar_ids[2] });
    try commandhandler.sendMessage(session, msg, allocator);
}
fn gacha5Stars(session: *Session, arg_iter: *std.mem.SplitIterator(u8, .sequence), allocator: Allocator) !void {
    var avatar_ids: [1]u32 = undefined;
    if (arg_iter.next()) |avatar_id_str| {
        const id = std.fmt.parseInt(u32, avatar_id_str, 10) catch {
            return sendErrorMessage(session, "Error: Invalid avatar ID. Please provide a valid unsigned 32-bit integer.", allocator);
        };
        if (!isValidAvatarId(id)) {
            return sendErrorMessage(session, "Error: Invalid Avatar ID format.", allocator);
        }
        avatar_ids[0] = id;
    } else {
        return sendErrorMessage(session, "Error: You must provide a rate-up avatar ID.", allocator);
    }
    if (arg_iter.next() != null) {
        return sendErrorMessage(session, "Error: Only one rate-up avatar ID is allowed.", allocator);
    }
    @memcpy(Logic.Banner().SetRateUp(), &avatar_ids);
    const msg = try std.fmt.allocPrint(allocator, "Set rate up ID to: {d}", .{avatar_ids[0]});
    try commandhandler.sendMessage(session, msg, allocator);
}
fn sendErrorMessage(session: *Session, message: []const u8, allocator: Allocator) !void {
    try commandhandler.sendMessage(session, message, allocator);
}
fn isValidAvatarId(avatar_id: u32) bool {
    return avatar_id >= 1000 and avatar_id <= 9999;
}
pub fn onBuffId(session: *Session, input: []const u8, allocator: Allocator) !void {
    if (std.ascii.eqlIgnoreCase(std.mem.trim(u8, input, " "), "info")) {
        return try onBuffInfo(session, allocator);
    }
    var tokens = std.ArrayList([]const u8).init(allocator);
    defer tokens.deinit();
    var iter = std.mem.tokenizeScalar(u8, input, ' ');
    while (iter.next()) |tok| {
        try tokens.append(tok);
    }
    if (tokens.items.len == 0) {
        return sendErrorMessage(session, "Error: Missing command arguments.", allocator);
    }
    if (std.ascii.eqlIgnoreCase(tokens.items[0], "off")) {
        Logic.CustomMode().SetCustomMode(false);
        _ = try commandhandler.sendMessage(session, "Custom mode OFF.", allocator);
        return;
    }
    if (tokens.items.len < 6) {
        return sendErrorMessage(session, "Error: Usage: /id <group_id> floor <n> node <1|2>", allocator);
    }
    const group_id = std.fmt.parseInt(u32, tokens.items[0], 10) catch return sendErrorMessage(session, "Error: Invalid group ID.", allocator);
    if (!std.ascii.eqlIgnoreCase(tokens.items[1], "floor")) return sendErrorMessage(session, "Error: Expected 'floor' keyword.", allocator);
    const floor = std.fmt.parseInt(u32, tokens.items[2], 10) catch return sendErrorMessage(session, "Error: Invalid floor number.", allocator);
    if (!std.ascii.eqlIgnoreCase(tokens.items[3], "node")) return sendErrorMessage(session, "Error: Expected 'node' keyword.", allocator);
    const node = std.fmt.parseInt(u8, tokens.items[4], 10) catch return sendErrorMessage(session, "Error: Invalid node number.", allocator);
    if (node != 1 and node != 2) return sendErrorMessage(session, "Error: Node must be 1 or 2.", allocator);
    Logic.CustomMode().SelectCustomNode(node);
    const challenge_mode = switch (group_id / 1000) {
        1 => "MoC",
        2 => "PF",
        3 => "AS",
        else => "Unknown",
    };
    try commandhandler.sendMessage(session, try std.fmt.allocPrint(allocator, "Challenge mode: {s}", .{challenge_mode}), allocator);
    const challenge_config = &ConfigManager.global_game_config_cache.challenge_maze_config;
    const stage_config = &ConfigManager.global_game_config_cache.stage_config;
    const challenge_entry = for (challenge_config.challenge_config.items) |entry| {
        if (entry.group_id == group_id and entry.floor == floor)
            break entry;
    } else {
        return sendErrorMessage(session, "Error: Could not find matching challenge ID.", allocator);
    };
    if (tokens.items.len > 5) {
        const keyword = tokens.items[5];
        if (std.ascii.eqlIgnoreCase(keyword, "buff")) {
            if (tokens.items.len < 7) {
                return sendErrorMessage(session, "Error: Missing buff sub-command (info/set <index>).", allocator);
            }
            const sub = tokens.items[6];
            if (std.ascii.eqlIgnoreCase(sub, "info")) {
                return sendBuffInfo(session, allocator, group_id, node);
            } else if (std.ascii.eqlIgnoreCase(sub, "set")) {
                return sendErrorMessage(session, "Error: Missing buff index for 'set' command.", allocator);
            } else {
                const buff_index = std.fmt.parseInt(usize, sub, 10) catch {
                    return sendErrorMessage(session, "Error: Invalid buff index.", allocator);
                };
                if (tokens.items.len < 8 or !std.ascii.eqlIgnoreCase(tokens.items[7], "set")) {
                    return sendErrorMessage(session, "Error: Expected 'set' after buff index.", allocator);
                }
                return handleBuffSetCommand(session, allocator, group_id, node, buff_index, challenge_entry.id);
            }
        } else if (std.ascii.eqlIgnoreCase(keyword, "set")) {
            if ((group_id / 1000) != 1) {
                return sendErrorMessage(session, "Error: Unexpected 'set' command. Did you mean 'buff <index> set' ?", allocator);
            }
            try handleMoCSelectChallenge(session, allocator, challenge_entry.id);
            return;
        }
    }
    var event_id: ?u32 = null;
    if (node == 1 and challenge_entry.event_id_list1.items.len > 0) {
        event_id = challenge_entry.event_id_list1.items[0];
    } else if (node == 2 and challenge_entry.event_id_list2.items.len > 0) {
        event_id = challenge_entry.event_id_list2.items[0];
    }
    if (event_id == null) {
        return sendErrorMessage(session, "Error: Could not find matching EventID.", allocator);
    }
    if ((group_id / 1000) == 1) {
        try handleMoCSelectChallenge(session, allocator, challenge_entry.id);
        return;
    }
    for (stage_config.stage_config.items) |stage| {
        if (stage.stage_id == event_id.?) {
            try sendStageInfo(session, allocator, group_id, floor, node, stage);
            return;
        }
    }
    return sendErrorMessage(session, "Error: Stage not found for given EventID.", allocator);
}
fn handleMoCSelectChallenge(session: *Session, allocator: Allocator, challenge_id: u32) !void {
    const line = try std.fmt.allocPrint(allocator, "Selected MoC Challenge ID: {d}", .{challenge_id});
    try commandhandler.sendMessage(session, line, allocator);
    Logic.CustomMode().SetCustomChallengeID(challenge_id);
    Logic.CustomMode().SetCustomBuffID(0);
    Logic.CustomMode().SetCustomMode(true);
}
fn handleBuffSetCommand(session: *Session, allocator: Allocator, group_id: u32, node: u8, buff_index: usize, challenge_id: u32) !void {
    const buff_config = &ConfigManager.global_game_config_cache.buff_info_config;
    for (buff_config.text_map_config.items) |entry| {
        if (entry.group_id == group_id) {
            const list = if (node == 1) &entry.buff_list1 else &entry.buff_list2;
            if (buff_index == 0 or buff_index > list.items.len) {
                return sendErrorMessage(session, "Error: Buff index out of range.", allocator);
            }
            const buff = list.items[buff_index - 1];
            const line = try std.fmt.allocPrint(allocator, "Selected Challenge ID: {d}, Buff ID: {d} - {s}", .{ challenge_id, buff.id, buff.name });
            try commandhandler.sendMessage(session, line, allocator);
            Logic.CustomMode().SetCustomChallengeID(challenge_id);
            Logic.CustomMode().SetCustomBuffID(buff.id);
            Logic.CustomMode().SetCustomMode(true);
            return;
        }
    }
    return sendErrorMessage(session, "Error: Buff group ID not found.", allocator);
}
fn sendStageInfo(session: *Session, allocator: Allocator, group_id: u32, floor: u32, node: u8, stage: Config.Stage) !void {
    const header = try std.fmt.allocPrint(allocator, "GroupID: {d}, Floor: {d}, Node: {d}, StageID: {d}", .{ group_id, floor, node, stage.stage_id });
    try commandhandler.sendMessage(session, header, allocator);
    for (stage.monster_list.items, 0..) |wave, i| {
        var msg = try std.fmt.allocPrint(allocator, "wave {d}:", .{i + 1});
        for (wave.items) |monster_id| {
            msg = try std.fmt.allocPrint(allocator, "{s} {d},", .{ msg, monster_id });
        }
        try commandhandler.sendMessage(session, msg, allocator);
    }
}
fn sendBuffInfo(session: *Session, allocator: Allocator, group_id: u32, node: u8) !void {
    const buff_config = &ConfigManager.global_game_config_cache.buff_info_config;
    for (buff_config.text_map_config.items) |entry| {
        if (entry.group_id == group_id) {
            const list = if (node == 1) &entry.buff_list1 else &entry.buff_list2;
            for (list.items) |buff| {
                const line = try std.fmt.allocPrint(allocator, "id: {d} - {s}", .{ buff.id, buff.name });
                try commandhandler.sendMessage(session, line, allocator);
            }
            return;
        }
    }
    return sendErrorMessage(session, "Error: Buff group ID not found.", allocator);
}
pub fn onBuffInfo(session: *Session, allocator: Allocator) !void {
    const challenge_config = &ConfigManager.global_game_config_cache.challenge_maze_config;

    var max_moc: u32 = 0;
    var max_pf: u32 = 0;
    var max_as: u32 = 0;

    for (challenge_config.challenge_config.items) |entry| {
        const id = entry.group_id;
        if (id >= 1000 and id < 2000 and id > max_moc) {
            max_moc = id;
        } else if (id >= 2000 and id < 3000 and id > max_pf) {
            max_pf = id;
        } else if (id >= 3000 and id < 4000 and id > max_as) {
            max_as = id;
        }
    }
    const msg = try std.fmt.allocPrint(allocator, "Current Challenge IDs: MoC: {d}, PF: {d}, AS: {d}", .{ max_moc, max_pf, max_as });
    try commandhandler.sendMessage(session, msg, allocator);
}

const std = @import("std");
const mem = std.mem;
// Session and PlayerStateMod imports are defined above.

pub fn give(session: *Session, args: []const u8, allocator: mem.Allocator) !void {
    var it = mem.tokenizeAny(u8, args, " \\t");
    const tid_str = it.next() orelse {
        try commandhandler.sendMessage(session, "Usage: /give <itemId> <count>", allocator);
        return;
    };
    const cnt_str = it.next() orelse {
        try commandhandler.sendMessage(session, "Usage: /give <itemId> <count>", allocator);
        return;
    };

    const tid = try std.fmt.parseInt(u32, tid_str, 10);
    const count = try std.fmt.parseInt(u32, cnt_str, 10);

    // Validate item exists (avoid sending IDs the client lacks).
    const cfg_opt = ItemDb.findById(tid);
    if (cfg_opt == null) {
        var buf: [128]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buf, "Unknown item ID: {d} (check items.json)", .{tid});
        try commandhandler.sendMessage(session, msg, allocator);
        return;
    }
    const cfg = cfg_opt.?;

    // Grant via sync notify only (no save-file writes).
    var sync = protocol.PlayerSyncScNotify.init(allocator);
    try sync.material_list.append(.{ .tid = tid, .num = count });
    try session.send(CmdID.CmdPlayerSyncScNotify, sync);

    var buf: [128]u8 = undefined;
    const msg = try std.fmt.bufPrint(&buf, "Granted {s} x {d} (ID={d}) via sync", .{ cfg.name, count, tid });
    try commandhandler.sendMessage(session, msg, allocator);
}

pub fn level(session: *Session, args: []const u8, allocator: mem.Allocator) !void {
    var it = mem.tokenizeAny(u8, args, " \\t");
    const lv_str = it.next() orelse {
        try commandhandler.sendMessage(session, "Usage: /level <value>", allocator);
        return;
    };

    const lv = try std.fmt.parseInt(u32, lv_str, 10);

    if (lv < 1 or lv > 70) {
        try commandhandler.sendMessage(session, "Level must be in 1~70", allocator);
        return;
    }

    if (session.player_state) |*state| {
        state.level = lv;
        try PlayerStateMod.save(state);

        var buf: [128]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buf, "Set level to {d}", .{lv});
        try commandhandler.sendMessage(session, msg, allocator);
    } else {
        try commandhandler.sendMessage(session, "Player save not found", allocator);
    }
}

pub fn setHp(session: *Session, args: []const u8, allocator: std.mem.Allocator) !void {
    // Parse "/hp 123"
    var it = std.mem.tokenizeScalar(u8, args, ' ');
    const first = it.next() orelse {
        try commandhandler.sendMessage(session, "Usage: /hp <value>", allocator);
        return;
    };

    const value = std.fmt.parseInt(u32, first, 10) catch {
        try commandhandler.sendMessage(session, "Usage: /hp <value>", allocator);
        return;
    };

    const cfg = &ConfigManager.global_game_config_cache.game_config;

    // Update HP for all avatars (in-memory only).
    for (cfg.avatar_config.items) |*avatar| {
        avatar.hp = value;
    }

    try Sync.onSyncAvatar(session, "", allocator);

    try commandhandler.sendMessage(session, "Updated all avatars HP and synced", allocator);
}

pub fn sceneCommand(session: *Session, args: []const u8, allocator: std.mem.Allocator) !void {
    var it = std.mem.tokenizeAny(u8, args, " \t");
    const sub = it.next() orelse {
        try commandhandler.sendMessage(session, "Usage: /scene <pos|reload>", allocator);
        return;
    };

    if (std.ascii.eqlIgnoreCase(sub, "pos")) {
        if (session.player_state) |state| {
            const pos = state.position;
            const msg = try std.fmt.allocPrint(allocator, "Position: plane={d}, floor={d}, entry={d}", .{ pos.plane_id, pos.floor_id, pos.entry_id });
            defer allocator.free(msg);
            try commandhandler.sendMessage(session, msg, allocator);
        } else {
            try commandhandler.sendMessage(session, "No player state; position unavailable", allocator);
        }
        return;
    }

    if (std.ascii.eqlIgnoreCase(sub, "reload")) {
        // Reload configs to refresh scene data; requires reconnect to apply.
        ConfigManager.reloadGameConfig() catch {
            try commandhandler.sendMessage(session, "Scene reload failed (config reload error)", allocator);
            return;
        };
        try commandhandler.sendMessage(session, "Scene config reloaded; reconnect/reauth to apply", allocator);
        return;
    }

    try commandhandler.sendMessage(session, "Usage: /scene <pos|reload>", allocator);
}

pub fn syncSceneReload(session: *Session, _: []const u8, allocator: std.mem.Allocator) !void {
    // Alias of /scene reload for convenience
    try sceneCommand(session, "reload", allocator);
}

pub fn playerInfo(session: *Session, _: []const u8, allocator: std.mem.Allocator) !void {
    if (session.player_state) |state| {
        const msg = try std.fmt.allocPrint(allocator, "UID={d}, Level={d}, WorldLevel={d}, Stamina={d}, MCoin={d}, HCoin={d}, SCoin={d}", .{
            state.uid, state.level, state.world_level, state.stamina, state.mcoin, state.hcoin, state.scoin,
        });
        defer allocator.free(msg);
        try commandhandler.sendMessage(session, msg, allocator);
    } else {
        try commandhandler.sendMessage(session, "Player info unavailable (no active state)", allocator);
    }
}

pub fn stop(session: *Session, _: []const u8, allocator: std.mem.Allocator) !void {
    // Inform client then close connection to force logout.
    try commandhandler.sendMessage(session, "Server will stop your session", allocator);
    session.stream.close();
}

pub fn kick(session: *Session, _: []const u8, allocator: Allocator) !void {
    // Gracefully tell client it is kicked, then close only that connection.
    var notify = protocol.PlayerKickOutScNotify.init(allocator);
    notify.kick_type = .KICK_BY_GM;
    try session.send(CmdID.CmdPlayerKickOutScNotify, notify);
    try commandhandler.sendMessage(session, "You have been kicked by admin.", allocator);
    session.stream.close();
}

pub fn saveLineup(session: *Session, _: []const u8, allocator: std.mem.Allocator) !void {
    if (session.player_state) |*state| {
        try PlayerStateMod.saveLineupToConfig(state);
        try commandhandler.sendMessage(session, try std.fmt.allocPrint(allocator, "Saved lineup to saves/{d}_lineup.json\n", .{state.uid}), allocator);
    } else {
        try commandhandler.sendMessage(session, "未找到玩家存档\n", allocator);
    }
}
pub fn syncFreeseData(session: *Session, args: []const u8, allocator: std.mem.Allocator) !void {
    _ = args; // 目前不用参数

    // 1) 重载 GameConfig（freesr-data.json）
    ConfigManager.reloadGameConfig() catch {
        try commandhandler.sendMessage(session, "重新加载 freesr-data.json 失败", allocator);
        return;
    };

    // 2) 重新生成并同步阵容 / 属性（用新的 game_config）
    try Sync.onGenerateAndSync(session, "", allocator);

    // 3) 同步最新编队到客户端（使用 misc/存档数据，避免面板延迟刷新）
    var lineup_mgr = LineupManager.LineupManager.init(allocator);
    const lineup = try lineup_mgr.createLineup();
    var sync_lineup = protocol.SyncLineupNotify.init(allocator);
    sync_lineup.lineup = lineup;
    try session.send(CmdID.CmdSyncLineupNotify, sync_lineup);

    try commandhandler.sendMessage(session, "已重新加载 freesr-data.json，并同步至客户端", allocator);
}

fn genderToString(g: MiscDefaults.Gender) []const u8 {
    return switch (g) {
        .male => "male",
        .female => "female",
    };
}

fn pathToString(p: MiscDefaults.Path) []const u8 {
    return switch (p) {
        .warrior => "warrior",
        .knight => "knight",
        .shaman => "shaman",
        .memory => "memory",
    };
}

pub fn setGender(session: *Session, args: []const u8, allocator: std.mem.Allocator) !void {
    var it = std.mem.tokenizeAny(u8, args, " \t");
    const token = it.next() orelse {
        try commandhandler.sendMessage(session, "Usage: /gender <male|female>", allocator);
        return;
    };
    const gender: MiscDefaults.Gender = blk: {
        if (std.ascii.eqlIgnoreCase(token, "male")) break :blk .male;
        if (std.ascii.eqlIgnoreCase(token, "female")) break :blk .female;
        try commandhandler.sendMessage(session, "Usage: /gender <male|female>", allocator);
        return;
    };
    const path = ConfigManager.global_misc_defaults.mc_path;
    AvatarManager.setMc(gender, path);
    const mc_id = AvatarManager.getMcId();
    applyMcToLineups(mc_id);
    const msg = try std.fmt.allocPrint(allocator, "Set Trailblazer gender to {s} (path: {s}, id={d})", .{ genderToString(gender), pathToString(path), mc_id });
    defer allocator.free(msg);
    try commandhandler.sendMessage(session, msg, allocator);
}

pub fn setPath(session: *Session, args: []const u8, allocator: std.mem.Allocator) !void {
    var it = std.mem.tokenizeAny(u8, args, " \t");
    const token = it.next() orelse {
        try commandhandler.sendMessage(session, "Usage: /path <warrior|knight|shaman|memory>", allocator);
        return;
    };
    const path: MiscDefaults.Path = blk: {
        if (std.ascii.eqlIgnoreCase(token, "warrior")) break :blk .warrior;
        if (std.ascii.eqlIgnoreCase(token, "knight")) break :blk .knight;
        if (std.ascii.eqlIgnoreCase(token, "shaman")) break :blk .shaman;
        if (std.ascii.eqlIgnoreCase(token, "memory")) break :blk .memory;
        try commandhandler.sendMessage(session, "Usage: /path <warrior|knight|shaman|memory>", allocator);
        return;
    };
    const gender = ConfigManager.global_misc_defaults.mc_gender;
    AvatarManager.setMc(gender, path);
    const mc_id = AvatarManager.getMcId();
    applyMcToLineups(mc_id);
    const msg = try std.fmt.allocPrint(allocator, "Set Trailblazer path to {s} (gender: {s}, id={d})", .{ pathToString(path), genderToString(gender), mc_id });
    defer allocator.free(msg);
    try commandhandler.sendMessage(session, msg, allocator);
}

pub fn sendMail(session: *Session, _: []const u8, allocator: Allocator) !void {
    var attachments = std.ArrayList(protocol.Item).init(allocator);
    defer attachments.deinit();

    // Simple gift: some credits + jade. Edit here if you need different loot.
    try attachments.appendSlice(&[_]protocol.Item{
        .{ .item_id = 1, .num = 800 },   // Stellar Jade
        .{ .item_id = 2, .num = 50000 }, // Credits
    });

    var mail = protocol.ClientMail.init(allocator);
    mail.id = next_mail_id;
    mail.sender = .{ .Const = "CastoricePS" };
    mail.title = .{ .Const = "Console mail" };
    mail.content = .{ .Const = "Sent from /mail command." };
    mail.is_read = false;
    mail.time = std.time.timestamp();
    mail.expire_time = mail.time + 30 * 24 * 3600;
    mail.mail_type = protocol.MailType.MAIL_TYPE_STAR;
    mail.attachment = .{ .item_list = attachments };

    var rsp = protocol.GetMailScRsp.init(allocator);
    rsp.total_num = 1;
    rsp.is_end = true;
    rsp.start = 0;
    rsp.retcode = 0;
    try rsp.mail_list.append(mail);

    var notify = protocol.NewMailScNotify.init(allocator);
    try notify.mail_id_list.append(mail.id);

    try session.send(CmdID.CmdNewMailScNotify, notify);
    try session.send(CmdID.CmdGetMailScRsp, rsp);

    next_mail_id += 1;
    try commandhandler.sendMessage(session, "Mail sent.", allocator);
}
