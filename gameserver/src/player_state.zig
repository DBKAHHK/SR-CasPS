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
const Position = struct { plane_id: u32, floor_id: u32, entry_id: u32 };

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

    pub fn init(allocator: Allocator, uid: u32) PlayerState {
        return .{
            .uid = uid,
            .level = 0,
            .world_level = 0,
            .stamina = 0,
            .mcoin = 0,
            .hcoin = 0,
            .scoin = 0,
            .position = .{ .plane_id = 0, .floor_id = 0, .entry_id = 0 },
            .inventory = Inventory.init(allocator),
            .opened_chests = std.ArrayList(u32).init(allocator),
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
            .lineup = BattleManager.selectedAvatarID.items,
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
    s.position = .{ .plane_id = defaults.position.plane_id, .floor_id = defaults.position.floor_id, .entry_id = defaults.position.entry_id };

    for (defaults.inventory) |mat| {
        try s.inventory.addMaterial(mat.id, mat.count);
    }

    BattleManager.funmodeAvatarID.clearRetainingCapacity();
    try BattleManager.funmodeAvatarID.appendSlice(defaults.funmode_lineup);
    BattleManager.selectedAvatarID.clearRetainingCapacity();
    try BattleManager.selectedAvatarID.appendSlice(defaults.lineup);

    try s.opened_chests.appendSlice(defaults.opened_chests);

    return s;
}

pub fn applySavedLineup(state: *PlayerState) !void {
    _ = state;
    // 预留扩展：如需从其他存档恢复阵容，可在此实现。
}
