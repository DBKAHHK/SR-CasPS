const std = @import("std");
const builtin = @import("builtin");
const httpz = @import("httpz");
const protocol = @import("protocol");

const authentication = @import("authentication.zig");
const dispatch = @import("dispatch.zig");
const PORT = 21000;

pub const std_options = std.Options{
    .log_level = switch (builtin.mode) {
        .Debug => .debug,
        else => .info,
    },
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var server = try httpz.Server(void).init(allocator, .{ .port = PORT }, {});
    defer server.stop();
    defer server.deinit();
    var router = try server.router(.{});

    router.get("/query_dispatch", dispatch.onQueryDispatch, .{});
    router.get("/query_gateway", dispatch.onQueryGateway, .{});
    router.post("/account/risky/api/check", authentication.onRiskyApiCheck, .{});
    router.post("/:product_name/mdk/shield/api/login", authentication.onShieldLogin, .{});
    router.post("/:product_name/mdk/shield/api/verify", authentication.onVerifyLogin, .{});
    router.post("/:product_name/combo/granter/login/v2/login", authentication.onComboTokenReq, .{});

    std.log.info("Dispatch is listening at localhost:{?}", .{server.config.port});
    try server.listen();
}
