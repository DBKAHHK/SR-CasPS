const std = @import("std");

const Allocator = std.mem.Allocator;

pub const Position = struct { plane_id: u32, floor_id: u32, entry_id: u32, teleport_id: u32 = 0 };
pub const Material = struct { id: u32, count: u32 };
pub const Gender = enum { male, female };
pub const Path = enum { warrior, knight, shaman, memory };

pub const Player = struct {
    uid: u32,
    level: u32,
    world_level: u32,
    stamina: u32,
    mcoin: u32,
    hcoin: u32,
    scoin: u32,
    lineup: []u32,
    funmode_lineup: []u32,
    opened_chests: []u32,
    inventory: []Material,
    skins: []u32,
    player_outfits: []u32,
    position: Position,
};

pub const MiscDefaults = struct {
    player: Player,
    mc_gender: Gender,
    mc_path: Path,

    pub fn deinit(self: *MiscDefaults, allocator: Allocator) void {
        allocator.free(self.player.lineup);
        allocator.free(self.player.funmode_lineup);
        allocator.free(self.player.opened_chests);
        allocator.free(self.player.inventory);
        allocator.free(self.player.skins);
        allocator.free(self.player.player_outfits);
    }
};

fn parseArrayU32(allocator: Allocator, node: std.json.Value) ![]u32 {
    var list = try allocator.alloc(u32, node.array.items.len);
    for (node.array.items, 0..) |val, i| {
        list[i] = @intCast(val.integer);
    }
    return list;
}

fn parseMaterials(allocator: Allocator, node: std.json.Value) ![]Material {
    var list = try allocator.alloc(Material, node.array.items.len);
    for (node.array.items, 0..) |val, i| {
        const obj = val.object;
        const id_node = obj.get("id") orelse obj.get("tid") orelse return error.MissingMaterialId;
        const count_node = obj.get("count") orelse return error.MissingMaterialCount;
        list[i] = Material{
            .id = @intCast(id_node.integer),
            .count = @intCast(count_node.integer),
        };
    }
    return list;
}

fn parsePosition(node: std.json.Value) Position {
    const pos_obj = node.object;
    return .{
        .plane_id = @intCast(pos_obj.get("plane_id").?.integer),
        .floor_id = @intCast(pos_obj.get("floor_id").?.integer),
        .entry_id = @intCast(pos_obj.get("entry_id").?.integer),
        .teleport_id = if (pos_obj.get("teleport_id")) |v| @intCast(v.integer) else 0,
    };
}
fn parseGender(node: ?std.json.Value) Gender {
    if (node) |n| switch (n) {
        .string => |s| {
            if (std.ascii.eqlIgnoreCase(s, "male")) return .male;
            if (std.ascii.eqlIgnoreCase(s, "female")) return .female;
        },
        else => {},
    };
    return .female;
}
fn parsePath(node: ?std.json.Value) Path {
    if (node) |n| switch (n) {
        .string => |s| {
            if (std.ascii.eqlIgnoreCase(s, "warrior")) return .warrior;
            if (std.ascii.eqlIgnoreCase(s, "knight")) return .knight;
            if (std.ascii.eqlIgnoreCase(s, "shaman")) return .shaman;
            if (std.ascii.eqlIgnoreCase(s, "memory")) return .memory;
        },
        else => {},
    };
    return .memory;
}

pub fn loadFromFile(allocator: Allocator, path: []const u8) !MiscDefaults {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try file.readToEndAlloc(allocator, file_size);
    defer allocator.free(buffer);

    var json_tree = try std.json.parseFromSlice(std.json.Value, allocator, buffer, .{});
    defer json_tree.deinit();

    const root = json_tree.value;
    const player_root = root.object.get("player") orelse return error.MissingPlayerSection;

    const lineup = try parseArrayU32(allocator, player_root.object.get("lineup").?);
    errdefer allocator.free(lineup);
    const funmode_lineup = try parseArrayU32(allocator, player_root.object.get("funmode_lineup").?);
    errdefer allocator.free(funmode_lineup);
    const opened_chests = if (player_root.object.get("opened_chests")) |v| blk: {
        const arr = try parseArrayU32(allocator, v);
        break :blk arr;
    } else try allocator.alloc(u32, 0);
    errdefer allocator.free(opened_chests);
    const inventory = try parseMaterials(allocator, player_root.object.get("inventory").?);
    errdefer allocator.free(inventory);
    const skins = try parseArrayU32(allocator, player_root.object.get("skins").?);
    errdefer allocator.free(skins);
    const player_outfits = try parseArrayU32(allocator, player_root.object.get("player_outfits").?);
    errdefer allocator.free(player_outfits);
    const mc_gender = parseGender(root.object.get("mc_gender"));
    const mc_path = parsePath(root.object.get("mc_path"));

    const misc = MiscDefaults{
        .player = .{
            .uid = @intCast(player_root.object.get("uid").?.integer),
            .level = @intCast(player_root.object.get("level").?.integer),
            .world_level = @intCast(player_root.object.get("world_level").?.integer),
            .stamina = @intCast(player_root.object.get("stamina").?.integer),
            .mcoin = @intCast(player_root.object.get("mcoin").?.integer),
            .hcoin = @intCast(player_root.object.get("hcoin").?.integer),
            .scoin = @intCast(player_root.object.get("scoin").?.integer),
            .lineup = lineup,
            .funmode_lineup = funmode_lineup,
            .opened_chests = opened_chests,
            .inventory = inventory,
            .skins = skins,
            .player_outfits = player_outfits,
            .position = parsePosition(player_root.object.get("position").?),
        },
        .mc_gender = mc_gender,
        .mc_path = mc_path,
    };

    return misc;
}
