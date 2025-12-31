// gameserver/src/player_state.zig
const std = @import("std");
const InventoryMod = @import("inventory.zig");
const Data = @import("data.zig");
const BattleManager = @import("./manager/battle_mgr.zig");
const Logic = @import("./utils/logic.zig");
const ConfigManager = @import("./manager/config_mgr.zig");

const Allocator = std.mem.Allocator;
const Inventory = InventoryMod.Inventory;
const MaterialStack = InventoryMod.MaterialStack;
const ArrayList = std.ArrayList;
const Position = struct { plane_id: u32, floor_id: u32, entry_id: u32, teleport_id: u32 = 0 };
const LineupManager = @import("./manager/lineup_mgr.zig");

pub const LineupSlots: usize = 4;
pub const MaxLineups: usize = 6;
pub const LineupPreset = [LineupSlots]u32;

/// 运行时玩家状态
pub const PlayerState = struct {
    uid: u32,
    level: u32,
    world_level: u32,
    stamina: u32,
    mcoin: u32,
    hcoin: u32,
    scoin: u32,
    position: Position,

    inventory: Inventory,
    opened_chests: std.ArrayList(u32),
    cur_lineup_index: u32,
    lineups: [MaxLineups]LineupPreset,

    pub fn init(allocator: Allocator, uid: u32) PlayerState {
        return .{
            .uid = uid,
            .level = 0,
            .world_level = 0,
            .stamina = 0,
            .mcoin = 0,
            .hcoin = 0,
            .scoin = 0,
            .position = .{ .plane_id = 0, .floor_id = 0, .entry_id = 0, .teleport_id = 0 },
            .inventory = Inventory.init(allocator),
            .opened_chests = std.ArrayList(u32).init(allocator),
            .cur_lineup_index = 0,
            .lineups = std.mem.zeroes([MaxLineups]LineupPreset),
        };
    }

    pub fn deinit(self: *PlayerState) void {
        self.inventory.deinit();
        self.opened_chests.deinit();
    }
};

/// JSON 持久化结构（无需 Allocator、ArrayList）
const PlayerStateFile = struct {
    uid: u32,
    level: u32,
    world_level: u32,
    stamina: u32,
    mcoin: u32,
    hcoin: u32,
    scoin: u32,
    materials: []MaterialStack,
    // saved selected lineup (length 4) - optional for backward compatibility
    selected_lineup: ?[]u32 = null,
    // saved funmode lineup - optional
    funmode_lineup: ?[]u32 = null,
    // multi-lineup presets (optional)
    cur_lineup_index: ?u32 = null,
    lineups: ?[][]u32 = null,
    // already opened prop entity ids (persistent)
    opened_chests: ?[]u32 = null,
    position: ?Position = null,
};

/// 保存到 misc.json（统一存档）
pub fn save(state: *PlayerState) !void {
    const cwd = std.fs.cwd();

    const gender_str = switch (ConfigManager.global_misc_defaults.mc_gender) {
        .male => "male",
        .female => "female",
    };
    const path_str = switch (ConfigManager.global_misc_defaults.mc_path) {
        .warrior => "warrior",
        .knight => "knight",
        .shaman => "shaman",
        .memory => "memory",
    };

    const root = .{
        .player = .{
            .uid = state.uid,
            .level = state.level,
            .world_level = state.world_level,
            .stamina = state.stamina,
            .mcoin = state.mcoin,
            .hcoin = state.hcoin,
            .scoin = state.scoin,
            // keep legacy `lineup` for backward compatibility
            .lineup = state.lineups[@intCast(state.cur_lineup_index)],
            .cur_lineup_index = state.cur_lineup_index,
            .lineups = state.lineups,
            .funmode_lineup = BattleManager.funmodeAvatarID.items,
            .opened_chests = state.opened_chests.items,
            .inventory = state.inventory.materials.items,
            .skins = ConfigManager.global_misc_defaults.player.skins,
            .player_outfits = ConfigManager.global_misc_defaults.player.player_outfits,
            .position = state.position,
        },
        .mc_gender = gender_str,
        .mc_path = path_str,
    };

    var file = try cwd.createFile("misc.json", .{ .truncate = true });
    defer file.close();
    try std.json.stringify(root, .{ .whitespace = .indent_2 }, file.writer());
}

/// 读取当前编队并保存：同样写回 misc.json
pub fn saveLineupToConfig(state: *PlayerState) !void {
    try save(state);
}

/// 加载存档（来自 misc.json；单账号）
pub fn loadOrCreate(allocator: Allocator, uid: u32) !PlayerState {
    _ = uid;
    const defaults = ConfigManager.global_misc_defaults.player;
    var s = PlayerState.init(allocator, defaults.uid);
    s.level = defaults.level;
    s.world_level = defaults.world_level;
    s.stamina = defaults.stamina;
    s.mcoin = defaults.mcoin;
    s.hcoin = defaults.hcoin;
    s.scoin = defaults.scoin;
    s.position = .{
        .plane_id = defaults.position.plane_id,
        .floor_id = defaults.position.floor_id,
        .entry_id = defaults.position.entry_id,
        .teleport_id = defaults.position.teleport_id,
    };

    for (defaults.inventory) |mat| {
        try s.inventory.addMaterial(mat.id, mat.count);
    }

    BattleManager.funmodeAvatarID.clearRetainingCapacity();
    try BattleManager.funmodeAvatarID.appendSlice(defaults.funmode_lineup);
    // Initialize lineup presets from defaults (lineup0) and attempt to override from misc.json.
    for (s.lineups[0][0..], 0..) |*slot, i| {
        slot.* = if (i < defaults.lineup.len) defaults.lineup[i] else 0;
    }
    for (s.lineups[1..]) |*preset| preset.* = std.mem.zeroes(LineupPreset);
    s.cur_lineup_index = 0;

    // Best-effort: load `player.lineups` + `player.cur_lineup_index` from misc.json if present.
    if (std.fs.cwd().openFile("misc.json", .{})) |file| {
        defer file.close();
        const file_size = file.getEndPos() catch 0;
        if (file_size > 0) {
            const buffer = file.readToEndAlloc(allocator, file_size) catch null;
            if (buffer) |buf| {
                defer allocator.free(buf);
                var json_tree = std.json.parseFromSlice(std.json.Value, allocator, buf, .{}) catch null;
                if (json_tree) |*tree| {
                    defer tree.deinit();
                    const root = tree.value;
                    if (root == .object) {
                        if (root.object.get("player")) |player_node| {
                            if (player_node == .object) {
                                if (player_node.object.get("cur_lineup_index")) |idx_node| {
                                    if (idx_node == .integer) {
                                        const idx: u32 = @intCast(idx_node.integer);
                                        if (idx < MaxLineups) s.cur_lineup_index = idx;
                                    }
                                }
                                if (player_node.object.get("lineups")) |lineups_node| {
                                    if (lineups_node == .array) {
                                        const count = @min(MaxLineups, lineups_node.array.items.len);
                                        var i: usize = 0;
                                        while (i < count) : (i += 1) {
                                            const preset_node = lineups_node.array.items[i];
                                            if (preset_node != .array) continue;
                                            const slots = @min(LineupSlots, preset_node.array.items.len);
                                            var j: usize = 0;
                                            while (j < slots) : (j += 1) {
                                                const v = preset_node.array.items[j];
                                                if (v == .integer) s.lineups[i][j] = @intCast(v.integer);
                                            }
                                            // Fill missing with 0
                                            while (j < LineupSlots) : (j += 1) s.lineups[i][j] = 0;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    } else |_| {}

    // Apply current preset to runtime selected lineup (skip zeros).
    var ids = std.ArrayList(u32).init(allocator);
    defer ids.deinit();
    for (s.lineups[@intCast(s.cur_lineup_index)]) |id| {
        if (id != 0) try ids.append(id);
    }
    try LineupManager.getSelectedAvatarID(allocator, ids.items);

    try s.opened_chests.appendSlice(defaults.opened_chests);

    return s;
}

pub fn applySavedLineup(state: *PlayerState) !void {
    _ = state;
    // 预留扩展：如需从其他存档恢复阵容，可在此实现。
}
