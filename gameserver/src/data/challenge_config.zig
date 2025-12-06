const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const ChallengeConfig = struct {
    id: u32,
    group_id: u32,
    floor: ?u32,
    npc_monster_id_list1: ArrayList(u32),
    npc_monster_id_list2: ArrayList(u32),
    event_id_list1: ArrayList(u32),
    event_id_list2: ArrayList(u32),
    map_entrance_id: u32,
    map_entrance_id2: u32,
    maze_group_id1: u32,
    maze_group_id2: ?u32,
    maze_buff_id: u32,
};

pub const ChallengePeak = struct {
    id: u32,
    maze_group_id: u32,
    map_entrance_id: u32,
    npc_monster_id_list: ArrayList(u32),
    event_id_list: ArrayList(u32),
    tag_list: ArrayList(u32),
};

pub const ChallengePeakGroup = struct {
    id: u32,
    boss_level_id: u32,
};

pub const ChallengePeakBoss = struct {
    id: u32,
    hard_tag_list: ArrayList(u32),
    buff_list: ArrayList(u32),
};

pub const ChallengeMazeConfig = struct {
    challenge_config: ArrayList(ChallengeConfig),

    pub fn deinit(self: *ChallengeMazeConfig) void {
        for (self.challenge_config.items) |*challenge| {
            challenge.npc_monster_id_list1.deinit();
            challenge.npc_monster_id_list2.deinit();
            challenge.event_id_list1.deinit();
            challenge.event_id_list2.deinit();
        }
        self.challenge_config.deinit();
    }
};

pub const ChallengePeakConfig = struct {
    challenge_peak: ArrayList(ChallengePeak),

    pub fn deinit(self: *ChallengePeakConfig) void {
        for (self.challenge_peak.items) |*challenge| {
            challenge.npc_monster_id_list.deinit();
            challenge.event_id_list.deinit();
        }
        self.challenge_peak.deinit();
    }
};

pub const ChallengePeakGroupConfig = struct {
    challenge_peak_group: ArrayList(ChallengePeakGroup),

    pub fn deinit(self: *ChallengePeakGroupConfig) void {
        self.challenge_peak_group.deinit();
    }
};

pub const ChallengePeakBossConfig = struct {
    challenge_peak_boss_config: ArrayList(ChallengePeakBoss),

    pub fn deinit(self: *ChallengePeakBossConfig) void {
        for (self.challenge_peak_boss_config.items) |*challenge| {
            challenge.buff_list.deinit();
            challenge.hard_tag_list.deinit();
        }
        self.challenge_peak_boss_config.deinit();
    }
};

pub fn parseChallengeConfig(root: std.json.Value, allocator: Allocator) anyerror!ChallengeMazeConfig {
    var challenge_config = ArrayList(ChallengeConfig).init(allocator);
    for (root.object.get("challenge_config").?.array.items) |challenge_json| {
        var challenge = ChallengeConfig{
            .id = @intCast(challenge_json.object.get("ID").?.integer),
            .group_id = @intCast(challenge_json.object.get("GroupID").?.integer),
            .floor = if (challenge_json.object.get("Floor")) |val| @intCast(val.integer) else null,
            .maze_buff_id = @intCast(challenge_json.object.get("MazeBuffID").?.integer),
            .npc_monster_id_list1 = ArrayList(u32).init(allocator),
            .npc_monster_id_list2 = ArrayList(u32).init(allocator),
            .event_id_list1 = ArrayList(u32).init(allocator),
            .event_id_list2 = ArrayList(u32).init(allocator),
            .map_entrance_id = @intCast(challenge_json.object.get("MapEntranceID").?.integer),
            .map_entrance_id2 = @intCast(challenge_json.object.get("MapEntranceID2").?.integer),
            .maze_group_id1 = @intCast(challenge_json.object.get("MazeGroupID1").?.integer),
            .maze_group_id2 = if (challenge_json.object.get("MazeGroupID2")) |val| @intCast(val.integer) else null,
        };
        for (challenge_json.object.get("NpcMonsterIDList1").?.array.items) |npc1| {
            try challenge.npc_monster_id_list1.append(@intCast(npc1.integer));
        }
        for (challenge_json.object.get("NpcMonsterIDList2").?.array.items) |npc2| {
            try challenge.npc_monster_id_list2.append(@intCast(npc2.integer));
        }
        for (challenge_json.object.get("EventIDList1").?.array.items) |event1| {
            try challenge.event_id_list1.append(@intCast(event1.integer));
        }
        for (challenge_json.object.get("EventIDList2").?.array.items) |event2| {
            try challenge.event_id_list2.append(@intCast(event2.integer));
        }
        try challenge_config.append(challenge);
    }

    return ChallengeMazeConfig{
        .challenge_config = challenge_config,
    };
}

pub fn parseChallengePeakConfig(root: std.json.Value, allocator: Allocator) anyerror!ChallengePeakConfig {
    var challenge_config = ArrayList(ChallengePeak).init(allocator);
    for (root.object.get("challenge_peak_config").?.array.items) |challenge_json| {
        var challenge = ChallengePeak{
            .id = @intCast(challenge_json.object.get("ID").?.integer),
            .npc_monster_id_list = ArrayList(u32).init(allocator),
            .event_id_list = ArrayList(u32).init(allocator),
            .tag_list = ArrayList(u32).init(allocator),
            .map_entrance_id = @intCast(challenge_json.object.get("MapEntranceID").?.integer),
            .maze_group_id = @intCast(challenge_json.object.get("MazeGroupID").?.integer),
        };
        for (challenge_json.object.get("TagList").?.array.items) |tag| {
            try challenge.tag_list.append(@intCast(tag.integer));
        }
        for (challenge_json.object.get("NpcMonsterIDList").?.array.items) |npc| {
            try challenge.npc_monster_id_list.append(@intCast(npc.integer));
        }
        for (challenge_json.object.get("EventIDList").?.array.items) |event| {
            try challenge.event_id_list.append(@intCast(event.integer));
        }
        try challenge_config.append(challenge);
    }
    return ChallengePeakConfig{
        .challenge_peak = challenge_config,
    };
}

pub fn parseChallengePeakGroupConfig(root: std.json.Value, allocator: Allocator) anyerror!ChallengePeakGroupConfig {
    var group_config = ArrayList(ChallengePeakGroup).init(allocator);
    for (root.object.get("challenge_peak_group_config").?.array.items) |group_json| {
        const group = ChallengePeakGroup{
            .id = @intCast(group_json.object.get("ID").?.integer),
            .boss_level_id = @intCast(group_json.object.get("BossLevelID").?.integer),
        };
        try group_config.append(group);
    }
    return ChallengePeakGroupConfig{
        .challenge_peak_group = group_config,
    };
}

pub fn parseChallengePeakBossConfig(root: std.json.Value, allocator: Allocator) anyerror!ChallengePeakBossConfig {
    var boss_config = ArrayList(ChallengePeakBoss).init(allocator);
    for (root.object.get("challenge_peak_boss_config").?.array.items) |boss_json| {
        var boss = ChallengePeakBoss{
            .id = @intCast(boss_json.object.get("ID").?.integer),
            .hard_tag_list = ArrayList(u32).init(allocator),
            .buff_list = ArrayList(u32).init(allocator),
        };
        for (boss_json.object.get("HardTagList").?.array.items) |tag| {
            try boss.hard_tag_list.append(@intCast(tag.integer));
        }
        for (boss_json.object.get("BuffList").?.array.items) |buff| {
            try boss.buff_list.append(@intCast(buff.integer));
        }
        try boss_config.append(boss);
    }
    return ChallengePeakBossConfig{
        .challenge_peak_boss_config = boss_config,
    };
}
