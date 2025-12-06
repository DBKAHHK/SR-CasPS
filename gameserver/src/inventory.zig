// gameserver/src/inventory.zig
const std = @import("std");

pub const Allocator = std.mem.Allocator;

pub const MaterialStack = struct {
    tid: u32, // 物品 ID（和 config 里的 tid 一致）
    count: u32, // 数量
};

pub const Inventory = struct {
    allocator: Allocator,
    materials: std.ArrayList(MaterialStack),

    pub fn init(allocator: Allocator) Inventory {
        return .{
            .allocator = allocator,
            .materials = std.ArrayList(MaterialStack).init(allocator),
        };
    }

    pub fn deinit(self: *Inventory) void {
        self.materials.deinit();
    }

    /// 获取某个 tid 的数量（没有就 0）
    pub fn getMaterialCount(self: *const Inventory, tid: u32) u32 {
        for (self.materials.items) |m| {
            if (m.tid == tid) return m.count;
        }
        return 0;
    }

    /// 增加材料（不存在则插入）
    pub fn addMaterial(self: *Inventory, tid: u32, count: u32) !void {
        if (count == 0) return;
        for (self.materials.items) |*m| {
            if (m.tid == tid) {
                m.count += count;
                return;
            }
        }
        try self.materials.append(.{ .tid = tid, .count = count });
    }

    /// 扣除材料，返回是否成功（数量不足返回 false，不改数据）
    pub fn removeMaterial(self: *Inventory, tid: u32, count: u32) bool {
        if (count == 0) return true;
        var i: usize = 0;
        while (i < self.materials.items.len) : (i += 1) {
            const m = &self.materials.items[i];
            if (m.tid == tid) {
                if (m.count < count) return false;
                m.count -= count;
                if (m.count == 0) {
                    _ = self.materials.swapRemove(i);
                }
                return true;
            }
        }
        return false;
    }
};
