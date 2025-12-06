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

/// 保存到 saves/<uid>.json
pub fn save(state: *PlayerState) !void {
    const cwd = std.fs.cwd();
    cwd.makeDir("saves") catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    var path_buf: [64]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "saves/{d}.json", .{state.uid});

    var file = try cwd.createFile(path, .{ .truncate = true });
    defer file.close();

    const writer = file.writer();

    const file_state = PlayerStateFile{
        .uid = state.uid,
        .level = state.level,
        .world_level = state.world_level,
        .stamina = state.stamina,
        .mcoin = state.mcoin,
        .hcoin = state.hcoin,
        .scoin = state.scoin,
        .materials = state.inventory.materials.items,
        .selected_lineup = BattleManager.selectedAvatarID[0..],
        .funmode_lineup = BattleManager.funmodeAvatarID.items,
        .opened_chests = state.opened_chests.items,
        .position = state.position,
    };

    try std.json.stringify(
        file_state,
        .{ .whitespace = .indent_2 },
        writer,
    );
}

/// 读取当前编队并保存到 `saves/<uid>_lineup.json`
pub fn saveLineupToConfig(state: *PlayerState) !void {
    const cwd = std.fs.cwd();
    cwd.makeDir("saves") catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    var path_buf: [80]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "saves/{d}_lineup.json", .{state.uid});

    var file = try cwd.createFile(path, .{ .truncate = true });
    defer file.close();

    const writer = file.writer();

    try writer.print("{{\"uid\": {d}, \"lineup\": [", .{state.uid});

    if (!Logic.FunMode().FunMode()) {
        var first: bool = true;
        for (BattleManager.selectedAvatarID) |id| {
            if (!first) try writer.print(", ", .{});
            first = false;
            try writer.print("{d}", .{id});
        }
    } else {
        var first: bool = true;
        for (BattleManager.funmodeAvatarID.items) |id| {
            if (!first) try writer.print(", ", .{});
            first = false;
            try writer.print("{d}", .{id});
        }
    }

    try writer.print("]}}\n", .{});
}

/// 如果不存在则创建默认存档（来自 misc.json）
pub fn loadOrCreate(allocator: Allocator, uid: u32) !PlayerState {
    const cwd = std.fs.cwd();

    var path_buf: [64]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "saves/{d}.json", .{uid});

    const file = cwd.openFile(path, .{}) catch |err| switch (err) {
        error.FileNotFound => {
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
            var i: usize = 0;
            while (i < BattleManager.selectedAvatarID.len) : (i += 1) {
                BattleManager.selectedAvatarID[i] = if (i < defaults.lineup.len) defaults.lineup[i] else 0;
            }

            try s.opened_chests.appendSlice(defaults.opened_chests);
            try save(&s);
            return s;
        },
        else => return err,
    };
    defer file.close();

    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();
    try file.reader().readAllArrayList(&buf, 1024 * 4);

    var parsed = try std.json.parseFromSlice(
        PlayerStateFile,
        allocator,
        buf.items,
        .{},
    );
    defer parsed.deinit();

    var s = PlayerState.init(allocator, parsed.value.uid);
    s.level = parsed.value.level;
    s.world_level = parsed.value.world_level;
    s.stamina = parsed.value.stamina;
    s.mcoin = parsed.value.mcoin;
    s.hcoin = parsed.value.hcoin;
    s.scoin = parsed.value.scoin;

    // 恢复编队（如果存档里有）
    if (parsed.value.selected_lineup) |arr| {
        var i: usize = 0;
        while (i < arr.len and i < BattleManager.selectedAvatarID.len) : (i += 1) {
            BattleManager.selectedAvatarID[i] = arr[i];
        }
        while (i < BattleManager.selectedAvatarID.len) : (i += 1) {
            BattleManager.selectedAvatarID[i] = 0;
        }
    }
    if (parsed.value.funmode_lineup) |arr| {
        BattleManager.funmodeAvatarID.clearRetainingCapacity();
        for (arr) |id| {
            try BattleManager.funmodeAvatarID.append(id);
        }
    }

    // 还原背包内容
    for (parsed.value.materials) |mat| {
        try s.inventory.addMaterial(mat.tid, mat.count);
    }

    // 已经打开的修理体id (如果存在)
    if (parsed.value.opened_chests) |arr| {
        try s.opened_chests.appendSlice(arr);
    }

    // 位置（不存在时使用默认值）
    if (parsed.value.position) |pos| {
        s.position = pos;
    } else {
        const pos = ConfigManager.global_misc_defaults.player.position;
        s.position = .{ .plane_id = pos.plane_id, .floor_id = pos.floor_id, .entry_id = pos.entry_id };
    }

    return s;
}

pub fn applySavedLineup(state: *PlayerState) !void {
    _ = state;
    // 预留扩展：如需从其他存档恢复阵容，可在此实现。
}
