const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const Stage = struct {
    level: u32,
    stage_id: u32,
    monster_list: ArrayList(ArrayList(u32)),
};

pub const StageConfig = struct {
    stage_config: ArrayList(Stage),

    pub fn deinit(self: *StageConfig) void {
        for (self.stage_config.items) |*stage| {
            for (stage.monster_list.items) |*wave| {
                wave.deinit();
            }
            stage.monster_list.deinit();
        }
        self.stage_config.deinit();
    }
};

pub fn parseStageConfig(root: std.json.Value, allocator: Allocator) anyerror!StageConfig {
    var stage_config = ArrayList(Stage).init(allocator);
    for (root.object.get("stage_config").?.array.items) |stage_json| {
        var stage = Stage{
            .level = @intCast(stage_json.object.get("Level").?.integer),
            .stage_id = @intCast(stage_json.object.get("StageID").?.integer),
            .monster_list = ArrayList(ArrayList(u32)).init(allocator),
        };

        for (stage_json.object.get("MonsterList").?.array.items) |wave| {
            var wave_list = ArrayList(u32).init(allocator);
            for (wave.array.items) |monster| {
                try wave_list.append(@intCast(monster.integer));
            }
            try stage.monster_list.append(wave_list);
        }

        try stage_config.append(stage);
    }

    return StageConfig{
        .stage_config = stage_config,
    };
}
