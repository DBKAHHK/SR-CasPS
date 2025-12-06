const std = @import("std");
const Allocator = std.mem.Allocator;

const hotfixInfo = struct {
    clientVersion: []const u8,
    assetBundleUrl: []const u8,
    exResourceUrl: []const u8,
    luaUrl: []const u8,
    iFixUrl: []const u8,
};

pub fn Parser(allocator: Allocator, filename: []const u8, version: []const u8) !hotfixInfo {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try file.readToEndAlloc(allocator, file_size);
    defer allocator.free(buffer);

    var json_tree = try std.json.parseFromSlice(std.json.Value, allocator, buffer, .{ .ignore_unknown_fields = true });
    defer json_tree.deinit();

    const version_node = json_tree.value.object.get(version) orelse {
        return hotfixInfo{
            .clientVersion = version,
            .assetBundleUrl = "",
            .exResourceUrl = "",
            .luaUrl = "",
            .iFixUrl = "",
        };
    };

    return getValue(version_node, version);
}

fn getValue(node: std.json.Value, client_version: []const u8) !hotfixInfo {
    if (node != .object) return error.InvalidJsonStructure;

    const obj = node.object;

    const assetBundleUrl = obj.get("asset_bundle_url") orelse return error.MissingAssetBundleUrl;
    const exResourceUrl = obj.get("ex_resource_url") orelse return error.MissingExResourceUrl;
    const luaUrl = obj.get("lua_url") orelse return error.MissingLuaUrl;
    const iFixUrl = obj.get("ifix_url") orelse return error.MissingIFixUrl;

    if (assetBundleUrl != .string or
        exResourceUrl != .string or
        luaUrl != .string or
        iFixUrl != .string) return error.InvalidUrlFormat;

    return hotfixInfo{
        .clientVersion = client_version,
        .assetBundleUrl = assetBundleUrl.string,
        .exResourceUrl = exResourceUrl.string,
        .luaUrl = luaUrl.string,
        .iFixUrl = iFixUrl.string,
    };
}

pub fn putValue(version: []const u8, assetBundleUrl: []const u8, exResourceUrl: []const u8, luaUrl: []const u8, iFixUrl: []const u8) !void {
    const file = try std.fs.cwd().openFile("hotfix.json", .{ .mode = .read_write });
    defer file.close();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const file_size = try file.getEndPos();
    const buffer0 = try file.readToEndAlloc(allocator, file_size);
    defer allocator.free(buffer0);

    var json_tree = try std.json.parseFromSlice(std.json.Value, allocator, buffer0, .{ .ignore_unknown_fields = true });
    defer json_tree.deinit();

    var root = json_tree.value.object;

    var new_version = std.json.ObjectMap.init(allocator);
    try new_version.put("asset_bundle_url", .{ .string = assetBundleUrl });
    try new_version.put("ex_resource_url", .{ .string = exResourceUrl });
    try new_version.put("ifix_url", .{ .string = iFixUrl });
    try new_version.put("ifix_version", .{ .string = "0" });
    try new_version.put("lua_url", .{ .string = luaUrl });
    try new_version.put("lua_version", .{ .string = "" });
    try root.put(version, .{ .object = new_version });

    const json_value = std.json.Value{ .object = root };

    var buffer = std.ArrayList(u8).init(allocator);
    try std.json.stringify(json_value, .{ .whitespace = .indent_4 }, buffer.writer());

    const new_file = try std.fs.cwd().createFile("hotfix.json", .{ .truncate = true });
    defer new_file.close();

    try new_file.writeAll(buffer.items);
}
