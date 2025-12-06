var global_uid_gen = UidGenerator().init(0);
var initial_uid: u32 = 0;

pub fn UidGenerator() type {
    return struct {
        current_id: u32,
        const Self = @This();
        pub fn init(start_id: u32) Self {
            return Self{ .current_id = start_id };
        }
        pub fn nextId(self: *Self) u32 {
            self.current_id +%= 1;
            return self.current_id;
        }
        pub fn getCurrentId(self: *const Self) u32 {
            return self.current_id;
        }
        pub fn setCurrentId(self: *Self, new_id: u32) void {
            self.current_id = new_id;
        }
    };
}

pub fn BaseUidGen() type {
    return struct {
        current_id: u32,

        const Self = @This();

        pub fn init() Self {
            return Self{ .current_id = 0 };
        }
        pub fn nextId(self: *Self) u32 {
            self.current_id +%= 1;
            return self.current_id;
        }
    };
}

pub fn nextGlobalId() u32 {
    return global_uid_gen.nextId();
}
pub fn resetGlobalUidGen(start_id: u32) void {
    global_uid_gen = UidGenerator().init(start_id);
}
pub fn getCurrentGlobalId() u32 {
    return global_uid_gen.getCurrentId();
}
pub fn getCurrentUid() u32 {
    return global_uid_gen.getCurrentId();
}
pub fn setCurrentUid(new_id: u32) void {
    global_uid_gen.setCurrentId(new_id);
}
pub fn resetGlobalUidGens() void {
    global_uid_gen = UidGenerator().init(initial_uid);
}
pub fn updateInitialUid() void {
    initial_uid = getCurrentUid();
}
