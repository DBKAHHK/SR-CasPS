const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const PlayerIcon = struct {
    id: u32,
};

pub const MainMission = struct {
    main_mission_id: u32,
};

pub const Quest = struct {
    quest_id: u32,
};

pub const TutorialGuide = struct {
    guide_group_id: u32,
};

pub const Tutorial = struct {
    tutorial_id: u32,
};

pub const Activity = struct {
    activity_module_list: ArrayList(u32),
    activity_id: u32,
    panel_id: ?u32,
};

pub const MapEntrance = struct {
    floor_id: u32,
    id: u32,
    plane_id: u32,
    begin_main_mission_idlist: ArrayList(u32),
    finish_main_mission_idlist: ArrayList(u32),
    finish_sub_mission_idlist: ArrayList(u32),
};

pub const MazePlane = struct {
    floor_id_list: ArrayList(u32),
    start_floor_id: u32,
    challenge_plane_id: u32,
    world_id: u32,
};

pub const BuffList = struct {
    id: u32,
    name: []u8,
};

pub const TextMap = struct {
    group_id: u32,
    buff_list1: std.ArrayList(BuffList),
    buff_list2: std.ArrayList(BuffList),
};

pub const PlayerIconConfig = struct {
    player_icon_config: ArrayList(PlayerIcon),
    pub fn deinit(self: *PlayerIconConfig) void {
        self.player_icon_config.deinit();
    }
};

pub const InteractEntry = struct {
    interact_id: u32,
    src_state: ?[]u8 = null,
    target_state: ?[]u8 = null,
    pub fn deinit(self: *InteractEntry, allocator: Allocator) void {
        if (self.src_state) |s| allocator.free(s);
        if (self.target_state) |t| allocator.free(t);
    }
};

pub const InteractConfig = struct {
    interact_config: ArrayList(InteractEntry),
    pub fn deinit(self: *InteractConfig, allocator: Allocator) void {
        // free each inner string then deinit list
        for (self.interact_config.items) |*e| {
            e.deinit(allocator);
        }
        self.interact_config.deinit();
    }
};

pub const MainMissionConfig = struct {
    main_mission_config: ArrayList(MainMission),
    pub fn deinit(self: *MainMissionConfig) void {
        self.main_mission_config.deinit();
    }
};

pub const QuestConfig = struct {
    quest_config: ArrayList(Quest),
    pub fn deinit(self: *QuestConfig) void {
        self.quest_config.deinit();
    }
};

pub const TutorialGuideConfig = struct {
    tutorial_guide_config: ArrayList(TutorialGuide),
    pub fn deinit(self: *TutorialGuideConfig) void {
        self.tutorial_guide_config.deinit();
    }
};

pub const TutorialConfig = struct {
    tutorial_config: ArrayList(Tutorial),
    pub fn deinit(self: *TutorialConfig) void {
        self.tutorial_config.deinit();
    }
};

pub const ActivityConfig = struct {
    activity_config: ArrayList(Activity),
    pub fn deinit(self: *ActivityConfig) void {
        for (self.activity_config.items) |*activity| {
            activity.activity_module_list.deinit();
        }
        self.activity_config.deinit();
    }
};

pub const MapEntranceConfig = struct {
    map_entrance_config: ArrayList(MapEntrance),
    pub fn deinit(self: *MapEntranceConfig) void {
        for (self.map_entrance_config.items) |*entrance| {
            entrance.begin_main_mission_idlist.deinit();
            entrance.finish_main_mission_idlist.deinit();
            entrance.finish_sub_mission_idlist.deinit();
        }
        self.map_entrance_config.deinit();
    }
};

pub const MazePlaneConfig = struct {
    maze_plane_config: ArrayList(MazePlane),
    pub fn deinit(self: *MazePlaneConfig) void {
        for (self.maze_plane_config.items) |*maze| {
            maze.floor_id_list.deinit();
        }
        self.maze_plane_config.deinit();
    }
};

pub const TextMapConfig = struct {
    text_map_config: ArrayList(TextMap),

    pub fn deinit(self: *TextMapConfig, allocator: Allocator) void {
        for (self.text_map_config.items) |*text| {
            for (text.buff_list1.items) |b| {
                allocator.free(b.name);
            }
            for (text.buff_list2.items) |b| {
                allocator.free(b.name);
            }
            text.buff_list1.deinit();
            text.buff_list2.deinit();
        }
        self.text_map_config.deinit();
    }
};

pub fn parsePlayerIconConfig(root: std.json.Value, allocator: Allocator) anyerror!PlayerIconConfig {
    var player_icon_config = ArrayList(PlayerIcon).init(allocator);
    for (root.object.get("player_icon_config").?.array.items) |icon_json| {
        const icon = PlayerIcon{
            .id = @intCast(icon_json.object.get("ID").?.integer),
        };
        try player_icon_config.append(icon);
    }
    return PlayerIconConfig{
        .player_icon_config = player_icon_config,
    };
}

pub fn parseInteractConfig(root: std.json.Value, allocator: Allocator) anyerror!InteractConfig {
    var interact_config = ArrayList(InteractEntry).init(allocator);
    // InteractConfig.json is an array at root
    for (root.array.items) |entry| {
        const id_val = entry.object.get("InteractID") orelse continue;
        const interact_id: u32 = @intCast(id_val.integer);

        var src: ?[]u8 = null;
        if (entry.object.get("SrcState")) |v| {
            if (v != .null) {
                const s = v.string;
                src = try allocator.dupe(u8, s);
            }
        }

        var tgt: ?[]u8 = null;
        if (entry.object.get("TargetState")) |v| {
            if (v != .null) {
                const s = v.string;
                tgt = try allocator.dupe(u8, s);
            }
        }

        try interact_config.append(InteractEntry{ .interact_id = interact_id, .src_state = src, .target_state = tgt });
    }
    return InteractConfig{ .interact_config = interact_config };
}

pub fn parseMainMissionConfig(root: std.json.Value, allocator: Allocator) anyerror!MainMissionConfig {
    var main_mission_config = ArrayList(MainMission).init(allocator);
    for (root.object.get("main_mission_config").?.array.items) |main_json| {
        const main_mission = MainMission{
            .main_mission_id = @intCast(main_json.object.get("MainMissionID").?.integer),
        };
        try main_mission_config.append(main_mission);
    }
    return MainMissionConfig{
        .main_mission_config = main_mission_config,
    };
}

pub fn parseQuestConfig(root: std.json.Value, allocator: Allocator) anyerror!QuestConfig {
    var quest_config = ArrayList(Quest).init(allocator);
    for (root.object.get("quest_config").?.array.items) |quest_json| {
        const quest = Quest{
            .quest_id = @intCast(quest_json.object.get("QuestID").?.integer),
        };
        try quest_config.append(quest);
    }
    return QuestConfig{
        .quest_config = quest_config,
    };
}

pub fn parseTutorialGuideConfig(root: std.json.Value, allocator: Allocator) anyerror!TutorialGuideConfig {
    var tutorial_guide_config = ArrayList(TutorialGuide).init(allocator);
    for (root.object.get("tutorial_guide_config").?.array.items) |guide_json| {
        const tutorial_guide = TutorialGuide{
            .guide_group_id = @intCast(guide_json.object.get("GroupID").?.integer),
        };
        try tutorial_guide_config.append(tutorial_guide);
    }
    return TutorialGuideConfig{
        .tutorial_guide_config = tutorial_guide_config,
    };
}

pub fn parseTutorialConfig(root: std.json.Value, allocator: Allocator) anyerror!TutorialConfig {
    var tutorial_config = ArrayList(Tutorial).init(allocator);
    for (root.object.get("tutorial_config").?.array.items) |tutorial_json| {
        const tutorial = Tutorial{
            .tutorial_id = @intCast(tutorial_json.object.get("TutorialID").?.integer),
        };
        try tutorial_config.append(tutorial);
    }
    return TutorialConfig{
        .tutorial_config = tutorial_config,
    };
}

pub fn parseActivityConfig(root: std.json.Value, allocator: Allocator) anyerror!ActivityConfig {
    var activity_config = ArrayList(Activity).init(allocator);
    for (root.object.get("activity_config").?.array.items) |activity_json| {
        var activity = Activity{
            //.panel_id = @intCast(activity_json.object.get("ActivityPanelID").?.integer),
            .panel_id = if (activity_json.object.get("ActivityPanelID")) |val| @intCast(val.integer) else null,
            .activity_module_list = ArrayList(u32).init(allocator),
            .activity_id = @intCast(activity_json.object.get("ActivityID").?.integer),
        };
        for (activity_json.object.get("ActivityModuleIDList").?.array.items) |id| {
            try activity.activity_module_list.append(@intCast(id.integer));
        }
        try activity_config.append(activity);
    }
    return ActivityConfig{
        .activity_config = activity_config,
    };
}

pub fn parseMapEntranceConfig(root: std.json.Value, allocator: Allocator) anyerror!MapEntranceConfig {
    var map_entrance_config = ArrayList(MapEntrance).init(allocator);
    for (root.object.get("map_entrance_config").?.array.items) |mapEntrance| {
        var entrance = MapEntrance{
            .id = @intCast(mapEntrance.object.get("ID").?.integer),
            .floor_id = @intCast(mapEntrance.object.get("FloorID").?.integer),
            .plane_id = @intCast(mapEntrance.object.get("PlaneID").?.integer),
            .begin_main_mission_idlist = ArrayList(u32).init(allocator),
            .finish_main_mission_idlist = ArrayList(u32).init(allocator),
            .finish_sub_mission_idlist = ArrayList(u32).init(allocator),
        };
        for (mapEntrance.object.get("BeginMainMissionList").?.array.items) |id| {
            try entrance.begin_main_mission_idlist.append(@intCast(id.integer));
        }
        for (mapEntrance.object.get("FinishMainMissionList").?.array.items) |id| {
            try entrance.finish_main_mission_idlist.append(@intCast(id.integer));
        }
        for (mapEntrance.object.get("FinishSubMissionList").?.array.items) |id| {
            try entrance.finish_sub_mission_idlist.append(@intCast(id.integer));
        }
        try map_entrance_config.append(entrance);
    }

    return MapEntranceConfig{
        .map_entrance_config = map_entrance_config,
    };
}

pub fn parseMazePlaneConfig(root: std.json.Value, allocator: Allocator) anyerror!MazePlaneConfig {
    var maze_plane_config = ArrayList(MazePlane).init(allocator);
    for (root.object.get("maze_plane_config").?.array.items) |id| {
        var maze = MazePlane{
            .start_floor_id = @intCast(id.object.get("StartFloorID").?.integer),
            .challenge_plane_id = @intCast(id.object.get("PlaneID").?.integer),
            .world_id = @intCast(id.object.get("WorldID").?.integer),
            .floor_id_list = ArrayList(u32).init(allocator),
        };
        for (id.object.get("FloorIDList").?.array.items) |list| {
            try maze.floor_id_list.append(@intCast(list.integer));
        }
        try maze_plane_config.append(maze);
    }

    return MazePlaneConfig{
        .maze_plane_config = maze_plane_config,
    };
}

pub fn parseTextMapConfig(root: std.json.Value, allocator: Allocator) !TextMapConfig {
    var text_map_config = ArrayList(TextMap).init(allocator);

    const arr = root.object.get("text_map_config");
    if (arr == null or arr.? == .null) {
        return TextMapConfig{ .text_map_config = text_map_config };
    }

    for (arr.?.array.items) |entry| {
        var buff_list1 = ArrayList(BuffList).init(allocator);
        var buff_list2 = ArrayList(BuffList).init(allocator);
        if (entry.object.get("BuffList1")) |buffs1| {
            if (buffs1 != .null) {
                for (buffs1.array.items) |buff| {
                    const parsed_name = buff.object.get("name").?.string;
                    const name_dup = try allocator.dupe(u8, parsed_name);
                    try buff_list1.append(BuffList{
                        .id = @intCast(buff.object.get("id").?.integer),
                        .name = name_dup,
                    });
                }
            }
        }
        if (entry.object.get("BuffList2")) |buffs2| {
            if (buffs2 != .null) {
                for (buffs2.array.items) |buff| {
                    const parsed_name = buff.object.get("name").?.string;
                    const name_dup = try allocator.dupe(u8, parsed_name);
                    try buff_list2.append(BuffList{
                        .id = @intCast(buff.object.get("id").?.integer),
                        .name = name_dup,
                    });
                }
            }
        }
        try text_map_config.append(TextMap{
            .group_id = @intCast(entry.object.get("GroupID").?.integer),
            .buff_list1 = buff_list1,
            .buff_list2 = buff_list2,
        });
    }

    return TextMapConfig{
        .text_map_config = text_map_config,
    };
}
