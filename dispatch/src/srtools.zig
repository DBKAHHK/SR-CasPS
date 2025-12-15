const std = @import("std");
const httpz = @import("httpz");

const freesrFile = "freesr-data.json";
const okMessage = "OK";
const invalidJsonMessage = "invalid JSON payload";
const invalidDataMessage = "srtools data must be an object";

fn addCorsHeaders(res: *httpz.Response) void {
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.header("Access-Control-Allow-Headers", "content-type");
    res.header("Access-Control-Max-Age", "86400");
}

pub fn onSrtoolsOptions(_: *httpz.Request, res: *httpz.Response) !void {
    addCorsHeaders(res);
    res.status = 204;
    res.body = "";
}

pub fn onSrtoolsSave(req: *httpz.Request, res: *httpz.Response) !void {
    const allocator = res.arena;
    var status: u16 = 200;
    var message: []const u8 = okMessage;

    addCorsHeaders(res);

    if (req.body()) |payload| {
        if (payload.len != 0) {
            parseBody: {
                var parsed = std.json.parseFromSlice(std.json.Value, allocator, payload, .{
                    .ignore_unknown_fields = true,
                }) catch |err| {
                    status = 400;
                    message = invalidJsonMessage;
                    std.log.err("srtools payload parsing failed: {any}", .{err});
                    break :parseBody;
                };
                defer parsed.deinit();

                const data_value = switch (parsed.value) {
                    .object => |obj| obj.get("data"),
                    else => null,
                };

                if (data_value) |value| {
                    switch (value) {
                        .object => |_| {
                            const written = try saveFreesrData(allocator, value);
                            std.log.info("srtools saved freesr-data ({d} bytes)", .{written});
                            break :parseBody;
                        },
                        else => {
                            status = 400;
                            message = invalidDataMessage;
                            std.log.warn("srtools payload has invalid data type", .{});
                            break :parseBody;
                        },
                    }
                }
            }
        }
    }

    res.status = status;
    try res.json(.{
        .status = status,
        .message = message,
    }, .{});
}

fn saveFreesrData(allocator: std.mem.Allocator, value: std.json.Value) !usize {
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    try std.json.stringify(value, .{}, buffer.writer());

    const file = try std.fs.cwd().createFile(freesrFile, .{ .truncate = true });
    defer file.close();
    try file.writeAll(buffer.items);

    return buffer.items.len;
}
