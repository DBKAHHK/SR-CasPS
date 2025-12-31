const std = @import("std");
const commandhandler = @import("../command.zig");
const Session = @import("../Session.zig");
const protocol = @import("protocol");

const ConfigManager = @import("../manager/config_mgr.zig");
const LineupManager = @import("../manager/lineup_mgr.zig");
const AvatarManager = @import("../manager/avatar_mgr.zig");
const BattleManager = @import("../manager/battle_mgr.zig");
const SceneManager = @import("../manager/scene_mgr.zig");
const PlayerStateMod = @import("../player_state.zig");
const ItemDb = @import("../item_db.zig");
const Logic = @import("../utils/logic.zig");
const MailService = @import("../services/mail.zig");
const MiscDefaults = @import("../data/misc_defaults.zig");

const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

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
    var args = std.mem.tokenizeAny(u8, input, " \t");
    const subcmd = args.next() orelse {
        return commandhandler.sendMessage(session, "Usage: /funmode <on|off|hp|lineup>", allocator);
    };

    if (std.ascii.eqlIgnoreCase(subcmd, "on")) {
        Logic.FunMode().SetFunMode(true);
        try commandhandler.sendMessage(session, "Fun mode ON", allocator);
        if (session.player_state) |*state| try PlayerStateMod.save(state);
        return;
    }
    if (std.ascii.eqlIgnoreCase(subcmd, "off")) {
        Logic.FunMode().SetFunMode(false);
        try commandhandler.sendMessage(session, "Fun mode OFF", allocator);
        if (session.player_state) |*state| try PlayerStateMod.save(state);
        return;
    }
    if (std.ascii.eqlIgnoreCase(subcmd, "hp")) {
        const hp_arg = args.next() orelse return commandhandler.sendMessage(session, "Usage: /funmode hp <max|number>", allocator);
        if (std.ascii.eqlIgnoreCase(hp_arg, "max")) {
            Logic.FunMode().SetHp(std.math.maxInt(i32));
            return commandhandler.sendMessage(session, "Set HP = MAX (2,147,483,647). Set it back to 0 to use real HP.", allocator);
        }
        const parsed = std.fmt.parseInt(i64, hp_arg, 10) catch return commandhandler.sendMessage(session, "Usage: /funmode hp <max|number>", allocator);
        if (parsed < 0 or parsed > std.math.maxInt(i32)) {
            return commandhandler.sendMessage(session, "Error: HP out of range (0 - 2147483647)", allocator);
        }
        Logic.FunMode().SetHp(@intCast(parsed));
        const msg = try std.fmt.allocPrint(allocator, "Set HP = {d}. Set it back to 0 to use real HP.", .{parsed});
        defer allocator.free(msg);
        return commandhandler.sendMessage(session, msg, allocator);
    }

    if (std.ascii.eqlIgnoreCase(subcmd, "lineup")) {
        const action = args.next() orelse "show";

        if (std.ascii.eqlIgnoreCase(action, "show")) {
            const list = BattleManager.funmodeAvatarID.items;
            if (list.len == 0) return commandhandler.sendMessage(session, "Funmode lineup is empty.", allocator);

            var buf = std.ArrayList(u8).init(allocator);
            defer buf.deinit();
            try buf.appendSlice("Funmode lineup: ");
            for (list, 0..) |id, i| {
                if (i != 0) try buf.appendSlice(", ");
                try buf.writer().print("{d}", .{id});
            }
            try commandhandler.sendMessage(session, buf.items, allocator);
            return;
        }

        if (std.ascii.eqlIgnoreCase(action, "clear")) {
            BattleManager.funmodeAvatarID.clearRetainingCapacity();
            if (session.player_state) |*state| try PlayerStateMod.save(state);
            try commandhandler.sendMessage(session, "Funmode lineup cleared.", allocator);
            return;
        }

        if (std.ascii.eqlIgnoreCase(action, "set")) {
            var ids = std.ArrayList(u32).init(allocator);
            defer ids.deinit();

            while (args.next()) |tok| {
                const raw_id = std.fmt.parseInt(u32, tok, 10) catch {
                    return commandhandler.sendMessage(session, "Usage: /funmode lineup set <id1> <id2> <id3> <id4>", allocator);
                };
                const id = switch (raw_id) {
                    8001 => AvatarManager.getMcId(),
                    1001 => AvatarManager.m7th,
                    else => raw_id,
                };
                try ids.append(id);
                if (ids.items.len >= 4) break;
            }
            if (ids.items.len == 0) {
                return commandhandler.sendMessage(session, "Usage: /funmode lineup set <id1> <id2> <id3> <id4>", allocator);
            }

            try LineupManager.getFunModeAvatarID(ids.items);
            if (session.player_state) |*state| try PlayerStateMod.save(state);

            // If funmode is enabled, refresh client lineup display too.
            if (Logic.FunMode().FunMode()) {
                var lineup_mgr = LineupManager.LineupManager.init(allocator);
                const lineup = try lineup_mgr.createLineup();
                var sync = protocol.SyncLineupNotify.init(allocator);
                sync.lineup = lineup;
                try session.send(CmdID.CmdSyncLineupNotify, sync);
            }

            try commandhandler.sendMessage(session, "Funmode lineup updated.", allocator);
            return;
        }

        return commandhandler.sendMessage(session, "Usage: /funmode lineup <show|set|clear>", allocator);
    }

    try commandhandler.sendMessage(session, "Usage: /funmode <on|off|hp|lineup>", allocator);
}

pub fn setGachaCommand(session: *Session, _: []const u8, allocator: Allocator) !void {
    // Kept as a stub (older servers used this), implement later if needed.
    try commandhandler.sendMessage(session, "Gacha command not implemented in this build.", allocator);
}

pub fn onBuffId(session: *Session, input: []const u8, allocator: Allocator) !void {
    const trimmed = std.mem.trim(u8, input, " \t");
    if (trimmed.len == 0) {
        return commandhandler.sendMessage(session, "Usage: /id <group_id> floor <n> node <1|2> | /id info | /id off", allocator);
    }

    if (std.ascii.eqlIgnoreCase(trimmed, "info")) {
        const msg = try std.fmt.allocPrint(
            allocator,
            "CustomMode: {s}, node={d}, challenge_id={d}, buff_id={d}",
            .{
                if (Logic.CustomMode().CustomMode()) "ON" else "OFF",
                if (Logic.CustomMode().FirstNode()) @as(u32, 1) else 2,
                Logic.CustomMode().GetCustomChallengeID(),
                Logic.CustomMode().GetCustomBuffID(),
            },
        );
        defer allocator.free(msg);
        return commandhandler.sendMessage(session, msg, allocator);
    }

    if (std.ascii.eqlIgnoreCase(trimmed, "off")) {
        Logic.CustomMode().SetCustomMode(false);
        Logic.CustomMode().SetCustomChallengeID(0);
        Logic.CustomMode().SetCustomBuffID(0);
        return commandhandler.sendMessage(session, "Custom mode OFF.", allocator);
    }

    var tok = std.mem.tokenizeAny(u8, trimmed, " \t");
    const group_id_str = tok.next() orelse return commandhandler.sendMessage(session, "Usage: /id <group_id> floor <n> node <1|2>", allocator);
    const kw_floor = tok.next() orelse return commandhandler.sendMessage(session, "Usage: /id <group_id> floor <n> node <1|2>", allocator);
    const floor_str = tok.next() orelse return commandhandler.sendMessage(session, "Usage: /id <group_id> floor <n> node <1|2>", allocator);
    const kw_node = tok.next() orelse return commandhandler.sendMessage(session, "Usage: /id <group_id> floor <n> node <1|2>", allocator);
    const node_str = tok.next() orelse return commandhandler.sendMessage(session, "Usage: /id <group_id> floor <n> node <1|2>", allocator);

    if (!std.ascii.eqlIgnoreCase(kw_floor, "floor") or !std.ascii.eqlIgnoreCase(kw_node, "node")) {
        return commandhandler.sendMessage(session, "Usage: /id <group_id> floor <n> node <1|2>", allocator);
    }

    const group_id = std.fmt.parseInt(u32, group_id_str, 10) catch return commandhandler.sendMessage(session, "Error: invalid group_id", allocator);
    const floor = std.fmt.parseInt(u32, floor_str, 10) catch return commandhandler.sendMessage(session, "Error: invalid floor", allocator);
    const node = std.fmt.parseInt(u32, node_str, 10) catch return commandhandler.sendMessage(session, "Error: invalid node", allocator);
    if (node != 1 and node != 2) return commandhandler.sendMessage(session, "Error: node must be 1 or 2", allocator);

    Logic.CustomMode().SelectCustomNode(node);

    const challenge_cfg = &ConfigManager.global_game_config_cache.challenge_maze_config;
    const challenge_entry = for (challenge_cfg.challenge_config.items) |entry| {
        if (entry.group_id == group_id and (entry.floor orelse 0) == floor) break entry;
    } else {
        return commandhandler.sendMessage(session, "Error: challenge not found for group/floor", allocator);
    };

    Logic.CustomMode().SetCustomChallengeID(challenge_entry.id);
    Logic.CustomMode().SetCustomBuffID(0);
    Logic.CustomMode().SetCustomMode(true);

    const msg = try std.fmt.allocPrint(allocator, "Selected challenge_id={d} (group={d} floor={d} node={d})", .{ challenge_entry.id, group_id, floor, node });
    defer allocator.free(msg);
    try commandhandler.sendMessage(session, msg, allocator);
}

pub fn give(session: *Session, args: []const u8, allocator: Allocator) !void {
    var it = std.mem.tokenizeAny(u8, args, " \t");
    const tid_str = it.next() orelse return commandhandler.sendMessage(session, "Usage: /give <itemId> <count>", allocator);
    const cnt_str = it.next() orelse return commandhandler.sendMessage(session, "Usage: /give <itemId> <count>", allocator);
    if (it.next() != null) return commandhandler.sendMessage(session, "Usage: /give <itemId> <count>", allocator);

    const tid = std.fmt.parseInt(u32, tid_str, 10) catch return commandhandler.sendMessage(session, "Usage: /give <itemId> <count>", allocator);
    const count = std.fmt.parseInt(u32, cnt_str, 10) catch return commandhandler.sendMessage(session, "Usage: /give <itemId> <count>", allocator);
    if (count == 0) return commandhandler.sendMessage(session, "Count must be > 0", allocator);

    const cfg_opt = ItemDb.findById(tid);
    if (cfg_opt == null) {
        var buf: [128]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buf, "Unknown item ID: {d} (check items.json)", .{tid});
        return commandhandler.sendMessage(session, msg, allocator);
    }

    if (session.player_state) |*state| {
        try state.inventory.addMaterial(tid, count);
        try PlayerStateMod.save(state);
    }

    var sync = protocol.PlayerSyncScNotify.init(allocator);
    try sync.material_list.append(.{ .tid = tid, .num = count });
    try session.send(CmdID.CmdPlayerSyncScNotify, sync);
    try commandhandler.sendMessage(session, "Granted item via sync.", allocator);
}

pub fn level(session: *Session, args: []const u8, allocator: Allocator) !void {
    var it = std.mem.tokenizeAny(u8, args, " \t");
    const lv_str = it.next() orelse return commandhandler.sendMessage(session, "Usage: /level <value>", allocator);
    const lv = std.fmt.parseInt(u32, lv_str, 10) catch return commandhandler.sendMessage(session, "Usage: /level <value>", allocator);
    if (lv < 1 or lv > 70) return commandhandler.sendMessage(session, "Level must be in 1~70", allocator);

    if (session.player_state) |*state| {
        state.level = lv;
        try PlayerStateMod.save(state);
        const msg = try std.fmt.allocPrint(allocator, "Set level to {d}", .{lv});
        defer allocator.free(msg);
        try commandhandler.sendMessage(session, msg, allocator);
    } else {
        try commandhandler.sendMessage(session, "Player save not found", allocator);
    }
}

pub fn playerInfo(session: *Session, _: []const u8, allocator: Allocator) !void {
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

pub fn stop(session: *Session, _: []const u8, allocator: Allocator) !void {
    try commandhandler.sendMessage(session, "Server will stop your session", allocator);
    session.close();
}

pub fn kick(session: *Session, _: []const u8, allocator: Allocator) !void {
    var notify = protocol.PlayerKickOutScNotify.init(allocator);
    notify.kick_type = .KICK_BY_GM;
    try session.send(CmdID.CmdPlayerKickOutScNotify, notify);
    try commandhandler.sendMessage(session, "You have been kicked by admin.", allocator);
    session.close();
}

pub fn saveLineup(session: *Session, _: []const u8, allocator: Allocator) !void {
    if (session.player_state) |*state| {
        try PlayerStateMod.saveLineupToConfig(state);
        try commandhandler.sendMessage(session, "Saved lineup to misc.json", allocator);
    } else {
        try commandhandler.sendMessage(session, "未找到玩家存档", allocator);
    }
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

pub fn setGender(session: *Session, args: []const u8, allocator: Allocator) !void {
    var it = std.mem.tokenizeAny(u8, args, " \t");
    const token = it.next() orelse return commandhandler.sendMessage(session, "Usage: /gender <male|female>", allocator);
    const gender: MiscDefaults.Gender = blk: {
        if (std.ascii.eqlIgnoreCase(token, "m") or std.ascii.eqlIgnoreCase(token, "male") or std.ascii.eqlIgnoreCase(token, "boy") or std.ascii.eqlIgnoreCase(token, "man") or std.mem.eql(u8, token, "1")) break :blk .male;
        if (std.ascii.eqlIgnoreCase(token, "f") or std.ascii.eqlIgnoreCase(token, "female") or std.ascii.eqlIgnoreCase(token, "girl") or std.ascii.eqlIgnoreCase(token, "woman") or std.mem.eql(u8, token, "2")) break :blk .female;
        return commandhandler.sendMessage(session, "Usage: /gender <male|female>", allocator);
    };

    const prev_gender = ConfigManager.global_misc_defaults.mc_gender;
    const path = ConfigManager.global_misc_defaults.mc_path;
    AvatarManager.setMc(gender, path);
    const mc_id = AvatarManager.getMcId();
    applyMcToLineups(mc_id);

    try session.send(CmdID.CmdGetBasicInfoScRsp, protocol.GetBasicInfoScRsp{
        .gender = if (gender == .male) 1 else 2,
        .is_gender_set = true,
        .player_setting_info = .{},
    });
    try AvatarManager.syncAvatarData(session, allocator);
    var lineup_mgr = LineupManager.LineupManager.init(allocator);
    var sync_lineup = protocol.SyncLineupNotify.init(allocator);
    sync_lineup.lineup = try lineup_mgr.createLineup();
    try session.send(CmdID.CmdSyncLineupNotify, sync_lineup);

    if (session.player_state) |*state| try PlayerStateMod.save(state);

    if (prev_gender != gender) {
        const msg = try std.fmt.allocPrint(allocator, "Set Trailblazer gender to {s} (path: {s}, id={d})", .{ genderToString(gender), pathToString(path), mc_id });
        defer allocator.free(msg);
        try commandhandler.sendMessage(session, msg, allocator);
    } else {
        try commandhandler.sendMessage(session, "Gender unchanged.", allocator);
    }
}

pub fn setPath(session: *Session, args: []const u8, allocator: Allocator) !void {
    var it = std.mem.tokenizeAny(u8, args, " \t");
    const token = it.next() orelse return commandhandler.sendMessage(session, "Usage: /path <warrior|knight|shaman|memory>", allocator);
    const path: MiscDefaults.Path = blk: {
        if (std.ascii.eqlIgnoreCase(token, "warrior")) break :blk .warrior;
        if (std.ascii.eqlIgnoreCase(token, "knight")) break :blk .knight;
        if (std.ascii.eqlIgnoreCase(token, "shaman")) break :blk .shaman;
        if (std.ascii.eqlIgnoreCase(token, "memory")) break :blk .memory;
        return commandhandler.sendMessage(session, "Usage: /path <warrior|knight|shaman|memory>", allocator);
    };

    const gender = ConfigManager.global_misc_defaults.mc_gender;
    AvatarManager.setMc(gender, path);
    const mc_id = AvatarManager.getMcId();
    applyMcToLineups(mc_id);

    try AvatarManager.syncAvatarData(session, allocator);
    var lineup_mgr = LineupManager.LineupManager.init(allocator);
    var sync_lineup = protocol.SyncLineupNotify.init(allocator);
    sync_lineup.lineup = try lineup_mgr.createLineup();
    try session.send(CmdID.CmdSyncLineupNotify, sync_lineup);
    if (session.player_state) |*state| try PlayerStateMod.save(state);

    const msg = try std.fmt.allocPrint(allocator, "Set Trailblazer path to {s} (gender: {s}, id={d})", .{ pathToString(path), genderToString(gender), mc_id });
    defer allocator.free(msg);
    try commandhandler.sendMessage(session, msg, allocator);
}

pub fn sceneCommand(session: *Session, args: []const u8, allocator: Allocator) !void {
    var it = std.mem.tokenizeAny(u8, args, " \t");
    const sub = it.next() orelse return commandhandler.sendMessage(session, "Usage: /scene <get|pos|reload|planeId floorId>", allocator);

    if (std.ascii.eqlIgnoreCase(sub, "get") or std.ascii.eqlIgnoreCase(sub, "pos")) {
        if (session.player_state) |state| {
            const pos = state.position;
            const msg = try std.fmt.allocPrint(allocator, "Scene: entryId={d}, planeId={d}, floorId={d}, teleportId={d}", .{ pos.entry_id, pos.plane_id, pos.floor_id, pos.teleport_id });
            defer allocator.free(msg);
            return commandhandler.sendMessage(session, msg, allocator);
        }
        return commandhandler.sendMessage(session, "No player state; position unavailable", allocator);
    }

    if (std.ascii.eqlIgnoreCase(sub, "reload")) {
        ConfigManager.reloadGameConfig() catch return commandhandler.sendMessage(session, "Config reload failed", allocator);
        return commandhandler.sendMessage(session, "Configs reloaded; reconnect/reauth to fully apply", allocator);
    }

    // Teleport: /scene <planeId> <floorId?>
    const plane_id = std.fmt.parseInt(u32, sub, 10) catch return commandhandler.sendMessage(session, "Usage: /scene <get|pos|reload|planeId floorId>", allocator);

    const maze_cfg = &ConfigManager.global_game_config_cache.maze_config;
    const maze_plane = for (maze_cfg.maze_plane_config.items) |m| {
        if (m.challenge_plane_id == plane_id) break m;
    } else {
        return commandhandler.sendMessage(session, "Error: maze plane not found", allocator);
    };

    const floor_arg = it.next();
    var floor_id: u32 = if (floor_arg) |s| (std.fmt.parseInt(u32, s, 10) catch 0) else 0;
    if (floor_id == 0) floor_id = maze_plane.start_floor_id;

    var floor_suffix: u32 = floor_id % 100;
    if (floor_suffix == 0) floor_suffix = 1;
    const entry_id: u32 = plane_id * 100 + floor_suffix;

    var teleport_id: u32 = 0;
    const anchors_cfg = &ConfigManager.global_game_config_cache.anchor_config;
    const res_cfg = &ConfigManager.global_game_config_cache.res_config;

    const anchor_id_opt: ?u32 = blk: {
        for (anchors_cfg.anchor_config.items) |a| {
            if (a.entryID != entry_id) continue;
            if (a.anchor.items.len == 0) break;
            break :blk a.anchor.items[0].id;
        }
        break :blk null;
    };
    if (anchor_id_opt) |anchor_id| {
        outer: for (res_cfg.scene_config.items) |sceneConf| {
            for (sceneConf.teleports.items) |tele| {
                if (tele.anchorId == anchor_id) {
                    teleport_id = tele.teleportId;
                    break :outer;
                }
            }
        }
    }

    if (teleport_id == 0) {
        // Some entries are missing Anchor.json mappings; fall back to the first teleportId for this
        // (planeId, entryId) scene, or (most commonly) teleportId == entryId.
        for (res_cfg.scene_config.items) |sceneConf| {
            if (sceneConf.planeID != plane_id or sceneConf.entryID != entry_id) continue;
            if (sceneConf.teleports.items.len > 0) teleport_id = sceneConf.teleports.items[0].teleportId;
            break;
        }
        if (teleport_id == 0) teleport_id = entry_id;
    }

    var scene_manager = SceneManager.SceneManager.init(allocator);
    const scene_info = try scene_manager.createScene(plane_id, floor_id, entry_id, teleport_id);
    var lineup_mgr = LineupManager.LineupManager.init(allocator);
    const lineup = try lineup_mgr.createLineup();
    try session.send(CmdID.CmdEnterSceneByServerScNotify, protocol.EnterSceneByServerScNotify{
        .reason = protocol.EnterSceneReason.ENTER_SCENE_REASON_NONE,
        .lineup = lineup,
        .scene = scene_info,
    });

    if (session.player_state) |*state| {
        state.position = .{ .plane_id = plane_id, .floor_id = floor_id, .entry_id = entry_id, .teleport_id = teleport_id };
        try PlayerStateMod.save(state);
    }

    const msg = try std.fmt.allocPrint(allocator, "Teleported: entryId={d}, planeId={d}, floorId={d}", .{ entry_id, plane_id, floor_id });
    defer allocator.free(msg);
    try commandhandler.sendMessage(session, msg, allocator);
}

pub fn mailCommand(session: *Session, args: []const u8, allocator: Allocator) !void {
    var attachments = std.ArrayList(protocol.Item).init(allocator);
    defer attachments.deinit();

    var content_buf = std.ArrayList(u8).init(allocator);
    defer content_buf.deinit();

    var it = std.mem.tokenizeAny(u8, args, " \t");
    var first_content = true;
    while (it.next()) |tok| {
        const sep_index = std.mem.indexOfAny(u8, tok, ":,");
        if (sep_index) |idx| {
            const key_s = tok[0..idx];
            const val_s = tok[idx + 1 ..];
            const item_id = std.fmt.parseInt(u32, key_s, 10) catch continue;
            const num = std.fmt.parseInt(u32, val_s, 10) catch continue;
            if (num == 0) continue;
            if (ItemDb.findById(item_id) == null) continue;
            try attachments.append(.{ .item_id = item_id, .num = num });
            continue;
        }

        if (!first_content) try content_buf.append(' ');
        first_content = false;
        try content_buf.appendSlice(tok);
    }

    const uid: u32 = if (session.player_state) |st| st.uid else 1;
    const content = if (content_buf.items.len == 0) "System Mail" else content_buf.items;

    const mail_id = try MailService.pushMail(uid, .{
        .sender = "System Mail",
        .title = "Test",
        .content = content,
        .attachments = attachments.items,
    });

    var notify = protocol.NewMailScNotify.init(allocator);
    try notify.mail_id_list.append(mail_id);
    try session.send(CmdID.CmdNewMailScNotify, notify);

    try commandhandler.sendMessage(session, "Mail sent.", allocator);
}
