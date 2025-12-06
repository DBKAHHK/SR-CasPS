const std = @import("std");
const Session = @import("../Session.zig");

pub const Allocator = std.mem.Allocator;

/// 目前先不做任何角色添加逻辑：
/// - 所有角色你已经默认都有
/// - 不处理星魂、不处理补偿
/// 以后要做星魂/补偿的时候再来填这里
pub fn addAvatarFromVoucher(session: *Session, allocator: Allocator, item_id: u32) !void {
    _ = session;
    _ = allocator;
    _ = item_id;
    // TODO: 未来在这里根据 item_id 转角色 + 星魂 + 补偿
}
