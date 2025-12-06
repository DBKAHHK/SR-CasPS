const std = @import("std");
const httpz = @import("httpz");
const protocol = @import("protocol");
const tls = @import("tls");
const hotfixInfo = @import("hotfix.zig");
const Base64Encoder = @import("std").base64.standard.Encoder;
const Base64Decoder = @import("std").base64.standard.Decoder;

const HotfixInfo = struct {
    asset_bundle_url: []const u8,
    ex_resource_url: []const u8,
    lua_url: []const u8,
    ifix_url: []const u8,

    pub fn init() HotfixInfo {
        return HotfixInfo{
            .asset_bundle_url = "",
            .ex_resource_url = "",
            .lua_url = "",
            .ifix_url = "",
        };
    }
};

pub fn onQueryDispatch(_: *httpz.Request, res: *httpz.Response) !void {
    var proto = protocol.Dispatch.init(res.arena);
    proto.retcode = 0;

    try proto.region_list.append(.{
        .name = .{ .Const = "CastoricePS" },
        .display_name = .{ .Const = "CastoricePS" },
        .env_type = .{ .Const = "9" },
        .title = .{ .Const = "CastoricePS" },
        .dispatch_url = .{ .Const = "http://127.0.0.1:21000/query_gateway" },
    });

    const data = try proto.encode(res.arena);
    const size = Base64Encoder.calcSize(data.len);
    const output = try res.arena.alloc(u8, size);
    _ = Base64Encoder.encode(output, data);
    res.body = output;
}

pub fn onQueryGateway(req: *httpz.Request, res: *httpz.Response) !void {
    var proto = protocol.GateServer.init(res.arena);
    proto.port = 23301;
    proto.retcode = 0;
    proto.ip = .{ .Const = "127.0.0.1" };

    const query = try req.query();
    const version = query.get("version") orelse "";
    const dispatch_seed = query.get("dispatch_seed") orelse "";

    var asset_bundle_url: []const u8 = "";
    var ex_resource_url: []const u8 = "";
    var lua_url: []const u8 = "";
    var ifix_url: []const u8 = "";

    // Step 1: Try to fetch from hotfix.json first
    const hotfix_from_file = hotfixInfo.Parser(res.arena, "hotfix.json", version) catch null;

    if (hotfix_from_file) |hotfix| {
        if (hotfix.assetBundleUrl.len > 0) {
            asset_bundle_url = hotfix.assetBundleUrl;
            ex_resource_url = hotfix.exResourceUrl;
            lua_url = hotfix.luaUrl;
            ifix_url = hotfix.iFixUrl;
        }
    }

    // Step 2: If hotfix.json doesn't have URLs, try to fetch from server
    if (asset_bundle_url.len == 0 and version.len > 0) {
        std.log.info("Found new hotfix version: {s}, fetching from server...", .{version});

        // Try multiple times for reliability
        const max_retries = 3;
        var retry_count: u32 = 0;
        var server_hotfix: ?HotfixInfo = null;

        while (retry_count < max_retries and server_hotfix == null) {
            retry_count += 1;

            server_hotfix = fetchHotfixInfo(res.arena, version, dispatch_seed) catch blk: {
                if (retry_count < max_retries) {
                    std.time.sleep(100 * std.time.ns_per_ms); // 100ms delay
                }
                break :blk null;
            };
        }

        if (server_hotfix) |hotfix| {
            if (hotfix.asset_bundle_url.len > 0) {
                // Save to hotfix.json
                hotfixInfo.putValue(version, hotfix.asset_bundle_url, hotfix.ex_resource_url, hotfix.lua_url, hotfix.ifix_url) catch {};

                asset_bundle_url = hotfix.asset_bundle_url;
                ex_resource_url = hotfix.ex_resource_url;
                lua_url = hotfix.lua_url;
                ifix_url = hotfix.ifix_url;
            }
        }
    }

    // Step 3: If still no URLs, show error message
    if (asset_bundle_url.len == 0) {
        std.log.err("No suitable hotfix found for version: {s}. Please check your client version", .{version});
        // Use placeholder URLs to avoid crashes
        asset_bundle_url = "UNSUPPORTED_VERSION";
        ex_resource_url = "UNSUPPORTED_VERSION";
        lua_url = "UNSUPPORTED_VERSION";
    } else {
        // Success - log the final URLs
        std.log.info("Hotfix for {s}:", .{version});
        std.log.info("  Asset Bundle: {s}", .{asset_bundle_url});
        std.log.info("  Ex Resource: {s}", .{ex_resource_url});
        std.log.info("  Lua: {s}", .{lua_url});
    }

    proto.asset_bundle_url = .{ .Const = asset_bundle_url };
    proto.ex_resource_url = .{ .Const = ex_resource_url };
    proto.lua_url = .{ .Const = lua_url };

    proto.data_use_asset_boundle = true;
    proto.res_use_asset_boundle = true;
    proto.use_tcp = true;

    const data = try proto.encode(res.arena);
    const size = Base64Encoder.calcSize(data.len);
    const output = try res.arena.alloc(u8, size);
    _ = Base64Encoder.encode(output, data);
    res.body = output;
}

pub fn selectHost(version: []const u8) []const u8 {
    if (std.mem.startsWith(u8, version, "CNPROD")) {
        return "prod-gf-cn-dp01.bhsr.com";
    } else if (std.mem.startsWith(u8, version, "CNBETA")) {
        return "beta-release01-cn.bhsr.com";
    } else if (std.mem.startsWith(u8, version, "OSPROD")) {
        return "prod-official-asia-dp01.starrails.com";
    } else if (std.mem.startsWith(u8, version, "OSBETA")) {
        return "beta-release01-asia.starrails.com";
    } else {
        return "";
    }
}

pub fn constructUrl(allocator: std.mem.Allocator, host: []const u8, version: []const u8, dispatch_seed: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "https://{s}/query_gateway?version={s}&dispatch_seed={s}&language_type=1&platform_type=2&channel_id=1&sub_channel_id=1&is_need_url=1&account_type=1", .{ host, version, dispatch_seed });
}

pub fn fetchHotfixInfo(allocator: std.mem.Allocator, version: []const u8, dispatch_seed: []const u8) !HotfixInfo {
    const host = selectHost(version);
    if (host.len == 0) return error.UnknownVersion;

    const gateway_url = try constructUrl(allocator, host, version, dispatch_seed);
    defer allocator.free(gateway_url);

    const uri = std.Uri.parse(gateway_url) catch return error.InvalidUrl;
    const hostname = if (uri.host) |h| h.percent_encoded else return error.NoHost;
    const port: u16 = uri.port orelse 443;
    const path = if (uri.path.percent_encoded.len > 0) uri.path.percent_encoded else "/";
    const query_string = if (uri.query) |q| q.percent_encoded else "";

    const address_list = try std.net.getAddressList(allocator, hostname, port);
    defer address_list.deinit();
    if (address_list.addrs.len == 0) return error.NoAddressFound;

    const socket = try std.net.tcpConnectToAddress(address_list.addrs[0]);
    defer socket.close();

    var tls_conn = tls.client(socket, .{
        .host = hostname,
        .root_ca = .{},
        .insecure_skip_verify = true,
    }) catch return error.TlsHandshakeFailed;

    const full_path = if (query_string.len > 0)
        try std.fmt.allocPrint(allocator, "{s}?{s}", .{ path, query_string })
    else
        try allocator.dupe(u8, path);
    defer allocator.free(full_path);

    const request = try std.fmt.allocPrint(allocator, "GET {s} HTTP/1.1\r\n" ++
        "Host: {s}\r\n" ++
        "User-Agent: UnityPlayer/2021.3.21f1\r\n" ++
        "Accept: */*\r\n" ++
        "Connection: close\r\n" ++
        "\r\n", .{ full_path, hostname });
    defer allocator.free(request);

    try tls_conn.writeAll(request);

    const response_data = try readAllTlsData(&tls_conn, allocator);
    defer allocator.free(response_data);

    const body_start = std.mem.indexOf(u8, response_data, "\r\n\r\n") orelse return error.InvalidResponse;
    const raw_body = response_data[body_start + 4 ..];

    const body = if (std.mem.indexOf(u8, response_data, "Transfer-Encoding: chunked") != null)
        try dechunkHttpBody(allocator, raw_body)
    else
        try allocator.dupe(u8, raw_body);
    defer allocator.free(body);

    if (body.len == 0) return error.EmptyResponse;

    const decoded_len = Base64Decoder.calcSizeForSlice(body) catch return error.InvalidBase64;
    const decoded_data = try allocator.alloc(u8, decoded_len);
    defer allocator.free(decoded_data);
    Base64Decoder.decode(decoded_data, body) catch return error.Base64DecodeError;

    const gateserver_proto = protocol.GateServer.decode(decoded_data, allocator) catch return error.ProtobufDecodeError;

    var hotfix = HotfixInfo.init();
    try setUrl(allocator, &hotfix.asset_bundle_url, gateserver_proto.asset_bundle_url);
    try setUrl(allocator, &hotfix.ex_resource_url, gateserver_proto.ex_resource_url);
    try setUrl(allocator, &hotfix.lua_url, gateserver_proto.lua_url);
    try setUrl(allocator, &hotfix.ifix_url, gateserver_proto.ifix_url);

    if (hotfix.asset_bundle_url.len == 0 or hotfix.ex_resource_url.len == 0 or hotfix.lua_url.len == 0) {
        return error.EmptyUrls;
    }

    return hotfix;
}

fn readAllTlsData(tls_conn: anytype, allocator: std.mem.Allocator) ![]u8 {
    var response_buffer = std.ArrayList(u8).init(allocator);
    errdefer response_buffer.deinit();

    var buffer: [4096]u8 = undefined;
    var total_attempts: u32 = 0;
    const max_attempts = 1000;
    var consecutive_empty_reads: u32 = 0;
    const max_empty_reads = 10;

    while (total_attempts < max_attempts) {
        total_attempts += 1;

        const bytes_read = tls_conn.read(buffer[0..]) catch |err| {
            if (response_buffer.items.len > 0) break;
            return err;
        };

        if (bytes_read == 0) {
            consecutive_empty_reads += 1;
            if (consecutive_empty_reads >= max_empty_reads) break;
            std.time.sleep(1 * std.time.ns_per_ms);
            continue;
        }

        consecutive_empty_reads = 0;
        try response_buffer.appendSlice(buffer[0..bytes_read]);

        if (std.mem.indexOf(u8, response_buffer.items, "\r\n\r\n")) |headers_end_idx| {
            const headers = response_buffer.items[0..headers_end_idx];
            if (std.mem.indexOf(u8, headers, "Content-Length:")) |cl_pos| {
                const after = headers[cl_pos + "Content-Length:".len ..];
                var it = std.mem.tokenizeScalar(u8, after, '\r');
                if (it.next()) |len_str| {
                    const content_len = try std.fmt.parseInt(usize, std.mem.trim(u8, len_str, " \t"), 10);
                    const body_len = response_buffer.items.len - (headers_end_idx + 4);
                    if (body_len < content_len) {
                        continue;
                    }
                }
            }
        }
    }

    if (response_buffer.items.len == 0) return error.NoDataReceived;
    return response_buffer.toOwnedSlice();
}

fn isChunkedDataComplete(chunked_body: []const u8) bool {
    var pos: usize = 0;

    while (pos < chunked_body.len) {
        const chunk_size_end = std.mem.indexOfScalarPos(u8, chunked_body, pos, '\n') orelse return false;

        var chunk_size_str = chunked_body[pos..chunk_size_end];
        if (chunk_size_str.len > 0 and chunk_size_str[chunk_size_str.len - 1] == '\r') {
            chunk_size_str = chunk_size_str[0 .. chunk_size_str.len - 1];
        }

        const chunk_size = std.fmt.parseInt(usize, chunk_size_str, 16) catch return false;

        if (chunk_size == 0) return true;

        pos = chunk_size_end + 1;

        if (pos + chunk_size > chunked_body.len) return false;

        pos += chunk_size;
        if (pos < chunked_body.len and chunked_body[pos] == '\r') pos += 1;
        if (pos < chunked_body.len and chunked_body[pos] == '\n') pos += 1;
    }

    return false;
}

fn dechunkHttpBody(allocator: std.mem.Allocator, chunked_body: []const u8) ![]u8 {
    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();

    var pos: usize = 0;

    while (pos < chunked_body.len) {
        const chunk_size_end = std.mem.indexOfScalarPos(u8, chunked_body, pos, '\n') orelse break;

        var chunk_size_str = chunked_body[pos..chunk_size_end];
        if (chunk_size_str.len > 0 and chunk_size_str[chunk_size_str.len - 1] == '\r') {
            chunk_size_str = chunk_size_str[0 .. chunk_size_str.len - 1];
        }

        const chunk_size = std.fmt.parseInt(usize, chunk_size_str, 16) catch break;

        if (chunk_size == 0) break;

        pos = chunk_size_end + 1;

        if (pos + chunk_size <= chunked_body.len) {
            try result.appendSlice(chunked_body[pos .. pos + chunk_size]);
            pos += chunk_size;

            if (pos < chunked_body.len and chunked_body[pos] == '\r') pos += 1;
            if (pos < chunked_body.len and chunked_body[pos] == '\n') pos += 1;
        } else {
            break;
        }
    }

    return result.toOwnedSlice();
}
inline fn setUrl(allocator: std.mem.Allocator, field: *[]const u8, proto_url: anytype) !void {
    switch (proto_url) {
        .Const => |url| field.* = try allocator.dupe(u8, url),
        .Owned => |owned| field.* = try allocator.dupe(u8, owned.str),
        .Empty => {},
    }
}
