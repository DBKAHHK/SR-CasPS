// gameserver/src/item_db.zig
const std = @import("std");

pub const ItemType = enum {
    Material,
    Currency,
    Other,
};

pub const ItemConfig = struct {
    id: u32,
    name: []const u8,
    item_type: ItemType,
};

const ItemCache = struct {
    loaded: bool = false,
    failed: bool = false,
    items: std.ArrayList(ItemConfig) = undefined,
};

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var cache: ItemCache = .{};

fn parseId(val: std.json.Value) !u32 {
    return switch (val) {
        .string => try std.fmt.parseInt(u32, val.string, 10),
        .integer => @intCast(val.integer),
        else => error.InvalidId,
    };
}

fn asString(val: std.json.Value) ![]const u8 {
    return switch (val) {
        .string => val.string,
        else => error.InvalidString,
    };
}

fn mapItemType(type_str: []const u8, sub_type: ?[]const u8) ItemType {
    if (std.mem.eql(u8, type_str, "Virtual")) return .Currency;
    if (std.mem.eql(u8, type_str, "Material")) return .Material;
    if (sub_type) |st| {
        if (std.mem.eql(u8, st, "Virtual")) return .Currency;
        if (std.mem.eql(u8, st, "Material")) return .Material;
    }
    return .Other;
}

fn ensureLoaded() void {
    if (cache.loaded or cache.failed) return;

    const allocator = gpa.allocator();
    const file = std.fs.cwd().openFile("resources/items.json", .{}) catch {
        cache.failed = true;
        return;
    };
    defer file.close();

    const file_size = file.getEndPos() catch {
        cache.failed = true;
        return;
    };
    const buffer = file.readToEndAlloc(allocator, file_size) catch {
        cache.failed = true;
        return;
    };
    defer allocator.free(buffer);

    var parsed = std.json.parseFromSlice(std.json.Value, allocator, buffer, .{}) catch {
        cache.failed = true;
        return;
    };
    defer parsed.deinit();

    if (parsed.value != .object) {
        cache.failed = true;
        return;
    }

    cache.items = std.ArrayList(ItemConfig).init(allocator);

    var it = parsed.value.object.iterator();
    while (it.next()) |entry| {
        const obj = entry.value_ptr.*;
        if (obj != .object) continue;
        const id_node = obj.object.get("id") orelse continue;
        const name_node = obj.object.get("name") orelse continue;
        const type_node = obj.object.get("type") orelse continue;
        const sub_type_node = obj.object.get("sub_type");

        const id = parseId(id_node) catch continue;
        const name_raw = asString(name_node) catch continue;
        const name = allocator.dupe(u8, name_raw) catch continue;
        const type_str = asString(type_node) catch {
            allocator.free(name);
            continue;
        };
        const sub_type = if (sub_type_node) |st| asString(st) catch null else null;

        const item_type = mapItemType(type_str, sub_type);

        cache.items.append(.{
            .id = id,
            .name = name,
            .item_type = item_type,
        }) catch {
            allocator.free(name);
            continue;
        };
    }

    cache.loaded = true;
}

pub fn findById(id: u32) ?ItemConfig {
    ensureLoaded();
    if (!cache.loaded) return null;
    for (cache.items.items) |cfg| {
        if (cfg.id == id) return cfg;
    }
    return null;
}
