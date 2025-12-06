const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const Vector = struct {
    x: i32,
    y: i32,
    z: i32,
};

pub const Teleports = struct {
    anchorId: u32,
    groupId: u32,
    instId: u32,
    pos: Vector,
    rot: Vector,
    teleportId: u32,
};

pub const Monsters = struct {
    groupId: u32,
    instId: u32,
    eventId: u32,
    pos: Vector,
    rot: Vector,
    monsterId: u32,
};

pub const Props = struct {
    groupId: u32,
    instId: u32,
    propState: u32,
    pos: Vector,
    rot: Vector,
    propId: u32,
};

pub const Anchor = struct {
    id: u32,
    pos: Vector,
    rot: Vector,
};

pub const Values = struct {
    name: ?[]const u8,
    max_value: ?i32,
};

pub const SavedValues = struct {
    floor_id: u32,
    saved_values: ArrayList(Values),

    pub fn deinit(self: *SavedValues) void {
        self.saved_values.deinit();
    }
};

pub const FloorSavedValuesConfig = struct {
    floor_saved_values: ArrayList(SavedValues),

    pub fn deinit(self: *FloorSavedValuesConfig) void {
        for (self.floor_saved_values.items) |*res| {
            res.deinit();
        }
        self.floor_saved_values.deinit();
    }
};

pub const ResConfig = struct {
    planeID: u32,
    entryID: u32,
    props: ArrayList(Props),
    monsters: ArrayList(Monsters),
    teleports: ArrayList(Teleports),

    pub fn deinit(self: *ResConfig) void {
        self.props.deinit();
        self.monsters.deinit();
        self.teleports.deinit();
    }
};

pub const AnchorConfig = struct {
    entryID: u32,
    anchor: ArrayList(Anchor),
    pub fn deinit(self: *AnchorConfig) void {
        self.anchor.deinit();
    }
};

pub const SceneConfig = struct {
    scene_config: ArrayList(ResConfig),

    pub fn deinit(self: *SceneConfig) void {
        for (self.scene_config.items) |*res| {
            res.deinit();
        }
        self.scene_config.deinit();
    }
};

pub const SceneAnchorConfig = struct {
    anchor_config: ArrayList(AnchorConfig),

    pub fn deinit(self: *SceneAnchorConfig) void {
        for (self.anchor_config.items) |*res| {
            res.deinit();
        }
        self.anchor_config.deinit();
    }
};

pub fn parseAnchor(root: std.json.Value, allocator: Allocator) anyerror!SceneConfig {
    var res_config = ArrayList(ResConfig).init(allocator);
    for (root.object.get("scene_config").?.array.items) |res_json| {
        var res = ResConfig{
            .planeID = @intCast(res_json.object.get("planeID").?.integer),
            .entryID = @intCast(res_json.object.get("entryID").?.integer),
            .props = ArrayList(Props).init(allocator),
            .monsters = ArrayList(Monsters).init(allocator),
            .teleports = ArrayList(Teleports).init(allocator),
        };
        for (res_json.object.get("props").?.array.items) |scene_prop| {
            var prop = Props{
                .groupId = @intCast(scene_prop.object.get("groupId").?.integer),
                .instId = @intCast(scene_prop.object.get("instId").?.integer),
                .propState = @intCast(scene_prop.object.get("propState").?.integer),
                .pos = undefined,
                .rot = undefined,
                .propId = @intCast(scene_prop.object.get("propId").?.integer),
            };
            const pos_json = scene_prop.object.get("pos").?;
            prop.pos = Vector{
                .x = @intCast(pos_json.object.get("x").?.integer),
                .y = @intCast(pos_json.object.get("y").?.integer),
                .z = @intCast(pos_json.object.get("z").?.integer),
            };
            const rot_json = scene_prop.object.get("rot").?;
            prop.rot = Vector{
                .x = @intCast(rot_json.object.get("x").?.integer),
                .y = @intCast(rot_json.object.get("y").?.integer),
                .z = @intCast(rot_json.object.get("z").?.integer),
            };
            try res.props.append(prop);
        }
        for (res_json.object.get("monsters").?.array.items) |monster_json| {
            var monster = Monsters{
                .groupId = @intCast(monster_json.object.get("groupId").?.integer),
                .instId = @intCast(monster_json.object.get("instId").?.integer),
                .eventId = @intCast(monster_json.object.get("eventId").?.integer),
                .monsterId = @intCast(monster_json.object.get("monsterId").?.integer),
                .pos = undefined,
                .rot = undefined,
            };
            const pos_json = monster_json.object.get("pos").?;
            monster.pos = Vector{
                .x = @intCast(pos_json.object.get("x").?.integer),
                .y = @intCast(pos_json.object.get("y").?.integer),
                .z = @intCast(pos_json.object.get("z").?.integer),
            };
            const rot_json = monster_json.object.get("rot").?;
            monster.rot = Vector{
                .x = @intCast(rot_json.object.get("x").?.integer),
                .y = @intCast(rot_json.object.get("y").?.integer),
                .z = @intCast(rot_json.object.get("z").?.integer),
            };
            try res.monsters.append(monster);
        }
        for (res_json.object.get("teleports").?.array.items) |teleport_json| {
            var teleport = Teleports{
                .anchorId = @intCast(teleport_json.object.get("anchorId").?.integer),
                .groupId = @intCast(teleport_json.object.get("groupId").?.integer),
                .instId = @intCast(teleport_json.object.get("instId").?.integer),
                .teleportId = @intCast(teleport_json.object.get("teleportId").?.integer),
                .pos = undefined,
                .rot = undefined,
            };
            const pos_json = teleport_json.object.get("pos").?;
            teleport.pos = Vector{
                .x = @intCast(pos_json.object.get("x").?.integer),
                .y = @intCast(pos_json.object.get("y").?.integer),
                .z = @intCast(pos_json.object.get("z").?.integer),
            };
            const rot_json = teleport_json.object.get("rot").?;
            teleport.rot = Vector{
                .x = @intCast(rot_json.object.get("x").?.integer),
                .y = @intCast(rot_json.object.get("y").?.integer),
                .z = @intCast(rot_json.object.get("z").?.integer),
            };
            try res.teleports.append(teleport);
        }
        try res_config.append(res);
    }

    return SceneConfig{
        .scene_config = res_config,
    };
}

pub fn parseAnchorConfig(root: std.json.Value, allocator: Allocator) anyerror!SceneAnchorConfig {
    var anchor_config = ArrayList(AnchorConfig).init(allocator);
    for (root.object.get("anchor_config").?.array.items) |anchor_json| {
        var anchor = AnchorConfig{
            .entryID = @intCast(anchor_json.object.get("entryID").?.integer),
            .anchor = ArrayList(Anchor).init(allocator),
        };
        for (anchor_json.object.get("anchor").?.array.items) |scene_anchor| {
            var anchor_list = Anchor{
                .id = @intCast(scene_anchor.object.get("ID").?.integer),
                .pos = undefined,
                .rot = undefined,
            };
            const pos_json = scene_anchor.object.get("pos").?;
            anchor_list.pos = Vector{
                .x = @intCast(pos_json.object.get("x").?.integer),
                .y = @intCast(pos_json.object.get("y").?.integer),
                .z = @intCast(pos_json.object.get("z").?.integer),
            };
            const rot_json = scene_anchor.object.get("rot").?;
            anchor_list.rot = Vector{
                .x = @intCast(rot_json.object.get("x").?.integer),
                .y = @intCast(rot_json.object.get("y").?.integer),
                .z = @intCast(rot_json.object.get("z").?.integer),
            };
            try anchor.anchor.append(anchor_list);
        }
        try anchor_config.append(anchor);
    }

    return SceneAnchorConfig{
        .anchor_config = anchor_config,
    };
}

pub fn parseFloorSavedValuesConfig(root: std.json.Value, allocator: Allocator) anyerror!FloorSavedValuesConfig {
    var saved_values_config = ArrayList(SavedValues).init(allocator);
    for (root.object.get("saved_values").?.array.items) |json| {
        var saved_values = SavedValues{
            .floor_id = @intCast(json.object.get("FloorID").?.integer),
            .saved_values = ArrayList(Values).init(allocator),
        };
        for (json.object.get("SavedValues").?.array.items) |saved| {
            const value = Values{
                .max_value = if (saved.object.get("MaxValue")) |val| @intCast(val.integer) else null,
                .name = if (saved.object.get("Name")) |val| try allocator.dupe(u8, val.string) else null,
            };
            try saved_values.saved_values.append(value);
        }
        try saved_values_config.append(saved_values);
    }

    return FloorSavedValuesConfig{
        .floor_saved_values = saved_values_config,
    };
}
