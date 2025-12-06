const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../session.zig");
const Packet = @import("../Packet.zig");
const FreeSrAdapter = @import("../data/freesr_adapter.zig");
const MiscDefaults = @import("../data/misc_defaults.zig");

pub const GameConfig = @import("../data/game_config.zig");
pub const StageConfig = @import("../data/stage_config.zig");
pub const ChallengeConfig = @import("../data/challenge_config.zig");
pub const MiscConfig = @import("../data/misc_config.zig");
pub const ResConfig = @import("../data/res_config.zig");
pub const AvatarConfig = @import("../data/avatar_config.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const Data = @import("../data.zig");

pub fn loadGameConfigAuto(allocator: Allocator) !GameConfig.GameConfig {
    const fsr = FreeSrAdapter.loadFromFreesr(allocator) catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };

    if (fsr) |cfg| {
        std.log.info("Loaded freesr-data.json", .{});
        return cfg;
    }

    std.log.info("Loaded config.json", .{});
    return try loadConfig(GameConfig.GameConfig, GameConfig.parseConfig, allocator, "config.json");
}
pub const GameConfigCache = struct {
    allocator: Allocator,
    game_config: GameConfig.GameConfig,
    res_config: ResConfig.SceneConfig,
    saved_values_config: ResConfig.FloorSavedValuesConfig,
    avatar_skill_config: AvatarConfig.AvatarSkillTreeConfig,
    avatar_config: AvatarConfig.AvatarConfig,
    map_entrance_config: MiscConfig.MapEntranceConfig,
    maze_config: MiscConfig.MazePlaneConfig,
    stage_config: StageConfig.StageConfig,
    anchor_config: ResConfig.SceneAnchorConfig,
    quest_config: MiscConfig.QuestConfig,
    challenge_maze_config: ChallengeConfig.ChallengeMazeConfig,
    challenge_peak_config: ChallengeConfig.ChallengePeakConfig,
    challenge_peak_group_config: ChallengeConfig.ChallengePeakGroupConfig,
    challenge_peak_boss_config: ChallengeConfig.ChallengePeakBossConfig,
    activity_config: MiscConfig.ActivityConfig,
    main_mission_config: MiscConfig.MainMissionConfig,
    tutorial_guide_config: MiscConfig.TutorialGuideConfig,
    tutorial_config: MiscConfig.TutorialConfig,
    player_icon_config: MiscConfig.PlayerIconConfig,
    interact_config: MiscConfig.InteractConfig,
    buff_info_config: MiscConfig.TextMapConfig,

    pub fn init(allocator: Allocator) !GameConfigCache {
        var game_cfg = try loadGameConfigAuto(allocator);

        errdefer game_cfg.deinit();

        var res_cfg = try loadConfig(ResConfig.SceneConfig, ResConfig.parseAnchor, allocator, "resources/res.json");
        errdefer res_cfg.deinit();

        var saved_values_cfg = try loadConfig(ResConfig.FloorSavedValuesConfig, ResConfig.parseFloorSavedValuesConfig, allocator, "resources/FloorSavedValuesConfig.json");
        errdefer saved_values_cfg.deinit();

        var avatar_skill_cfg = try loadConfig(AvatarConfig.AvatarSkillTreeConfig, AvatarConfig.parseAvatarSkillTreeConfig, allocator, "resources/AvatarSkillTreeConfig.json");
        errdefer avatar_skill_cfg.deinit();

        var avatar_cfg = try loadConfig(AvatarConfig.AvatarConfig, AvatarConfig.parseAvatarConfig, allocator, "resources/AvatarConfig.json");
        errdefer avatar_cfg.deinit();

        var map_entr_cfg = try loadConfig(MiscConfig.MapEntranceConfig, MiscConfig.parseMapEntranceConfig, allocator, "resources/MapEntrance.json");
        errdefer map_entr_cfg.deinit();

        var maze_cfg = try loadConfig(MiscConfig.MazePlaneConfig, MiscConfig.parseMazePlaneConfig, allocator, "resources/MazePlane.json");
        errdefer maze_cfg.deinit();

        var stage_cfg = try loadConfig(StageConfig.StageConfig, StageConfig.parseStageConfig, allocator, "resources/StageConfig.json");
        errdefer stage_cfg.deinit();

        var anchor_cfg = try loadConfig(ResConfig.SceneAnchorConfig, ResConfig.parseAnchorConfig, allocator, "resources/Anchor.json");
        errdefer anchor_cfg.deinit();

        var quest_cfg = try loadConfig(MiscConfig.QuestConfig, MiscConfig.parseQuestConfig, allocator, "resources/QuestData.json");
        errdefer quest_cfg.deinit();

        var challenge_maze_cfg = try loadConfig(ChallengeConfig.ChallengeMazeConfig, ChallengeConfig.parseChallengeConfig, allocator, "resources/ChallengeMazeConfig.json");
        errdefer challenge_maze_cfg.deinit();

        var challenge_peak_cfg = try loadConfig(ChallengeConfig.ChallengePeakConfig, ChallengeConfig.parseChallengePeakConfig, allocator, "resources/ChallengePeakConfig.json");
        errdefer challenge_peak_cfg.deinit();

        var challenge_peak_group_cfg = try loadConfig(ChallengeConfig.ChallengePeakGroupConfig, ChallengeConfig.parseChallengePeakGroupConfig, allocator, "resources/ChallengePeakGroupConfig.json");
        errdefer challenge_peak_group_cfg.deinit();

        var challenge_peak_boss_cfg = try loadConfig(ChallengeConfig.ChallengePeakBossConfig, ChallengeConfig.parseChallengePeakBossConfig, allocator, "resources/ChallengePeakBossConfig.json");
        errdefer challenge_peak_boss_cfg.deinit();

        var activity_cfg = try loadConfig(MiscConfig.ActivityConfig, MiscConfig.parseActivityConfig, allocator, "resources/ActivityConfig.json");
        errdefer activity_cfg.deinit();

        var main_mission_cfg = try loadConfig(MiscConfig.MainMissionConfig, MiscConfig.parseMainMissionConfig, allocator, "resources/MainMission.json");
        errdefer main_mission_cfg.deinit();

        var tutorial_guide_cfg = try loadConfig(MiscConfig.TutorialGuideConfig, MiscConfig.parseTutorialGuideConfig, allocator, "resources/TutorialGuideGroup.json");
        errdefer tutorial_guide_cfg.deinit();

        var tutorial_cfg = try loadConfig(MiscConfig.TutorialConfig, MiscConfig.parseTutorialConfig, allocator, "resources/TutorialData.json");
        errdefer tutorial_cfg.deinit();

        var player_icon_cfg = try loadConfig(MiscConfig.PlayerIconConfig, MiscConfig.parsePlayerIconConfig, allocator, "resources/AvatarPlayerIcon.json");
        errdefer player_icon_cfg.deinit();

        var interact_cfg = try loadConfig(MiscConfig.InteractConfig, MiscConfig.parseInteractConfig, allocator, "resources/InteractConfig.json");
        errdefer interact_cfg.deinit(allocator);

        var buff_info_cfg = try loadConfig(MiscConfig.TextMapConfig, MiscConfig.parseTextMapConfig, allocator, "resources/BuffInfoConfig.json");
        errdefer buff_info_cfg.deinit(allocator);
        return .{
            .allocator = allocator,
            .game_config = game_cfg,
            .res_config = res_cfg,
            .saved_values_config = saved_values_cfg,
            .avatar_skill_config = avatar_skill_cfg,
            .avatar_config = avatar_cfg,
            .map_entrance_config = map_entr_cfg,
            .maze_config = maze_cfg,
            .stage_config = stage_cfg,
            .anchor_config = anchor_cfg,
            .quest_config = quest_cfg,
            .challenge_maze_config = challenge_maze_cfg,
            .challenge_peak_config = challenge_peak_cfg,
            .challenge_peak_group_config = challenge_peak_group_cfg,
            .challenge_peak_boss_config = challenge_peak_boss_cfg,
            .activity_config = activity_cfg,
            .main_mission_config = main_mission_cfg,
            .tutorial_guide_config = tutorial_guide_cfg,
            .tutorial_config = tutorial_cfg,
            .player_icon_config = player_icon_cfg,
            .interact_config = interact_cfg,
            .buff_info_config = buff_info_cfg,
        };
    }
    pub fn deinit(self: *GameConfigCache) void {
        self.game_config.deinit();
        self.res_config.deinit();
        self.saved_values_config.deinit();
        self.avatar_skill_config.deinit();
        self.avatar_config.deinit();
        self.map_entrance_config.deinit();
        self.maze_config.deinit();
        self.stage_config.deinit();
        self.anchor_config.deinit();
        self.quest_config.deinit();
        self.challenge_maze_config.deinit();
        self.challenge_peak_config.deinit();
        self.challenge_peak_group_config.deinit();
        self.challenge_peak_boss_config.deinit();
        self.activity_config.deinit();
        self.main_mission_config.deinit();
        self.tutorial_guide_config.deinit();
        self.tutorial_config.deinit();
        self.player_icon_config.deinit();
        self.interact_config.deinit(global_main_allocator);
        self.buff_info_config.deinit(global_main_allocator);
    }
};
pub var global_game_config_cache: GameConfigCache = undefined;
pub var global_main_allocator: Allocator = undefined;
pub var global_misc_defaults: MiscDefaults.MiscDefaults = undefined;
pub fn initGameGlobals(main_allocator: Allocator) !void {
    global_main_allocator = main_allocator;
    global_misc_defaults = try MiscDefaults.loadFromFile(main_allocator, "misc.json");
    // propagate misc data to shared globals
    Data.SkinList = global_misc_defaults.player.skins;
    Data.PlayerOutfitList = global_misc_defaults.player.player_outfits;
    // ItemList tracks ids only; inventory entries carry counts
    {
        const ids = try main_allocator.alloc(u32, global_misc_defaults.player.inventory.len);
        for (global_misc_defaults.player.inventory, 0..) |mat, idx| ids[idx] = mat.id;
        Data.ItemList = ids;
    }

    global_game_config_cache = try GameConfigCache.init(main_allocator);

    const avatars = &global_game_config_cache.avatar_config.avatar_config.items;
    var all = ArrayList(u32).init(main_allocator);
    var four_star = ArrayList(u32).init(main_allocator);

    for (avatars.*) |avatar| {
        if (avatar.avatar_id == avatar.adventure_player_id and avatar.avatar_id <= 8001 and avatar.avatar_id != 1224 and (avatar.avatar_id == 1001 or avatar.avatar_id != 1001)) {
            try all.append(avatar.avatar_id);
            if (avatar.rarity == 4) try four_star.append(avatar.avatar_id);
        }
    }
    Data.AllAvatars = try all.toOwnedSlice();
    Data.AvatarList = try four_star.toOwnedSlice();
}
pub fn deinitGameGlobals() void {
    global_misc_defaults.deinit(global_main_allocator);
    global_game_config_cache.deinit();
}
var game_config_mtime: i128 = 0;
pub fn UpdateGameConfig() !void {
    const stat = try std.fs.cwd().statFile("config.json");
    if (stat.mtime > game_config_mtime) {
        global_game_config_cache.game_config.deinit();
        global_game_config_cache.game_config = try loadConfig(GameConfig.GameConfig, GameConfig.parseConfig, global_main_allocator, "config.json");
        game_config_mtime = stat.mtime;
    }
}
pub fn loadConfig(
    comptime ConfigType: type,
    comptime parseFn: fn (std.json.Value, Allocator) anyerror!ConfigType,
    allocator: Allocator,
    filename: []const u8,
) anyerror!ConfigType {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try file.readToEndAlloc(allocator, file_size);
    defer allocator.free(buffer);

    var json_tree = try std.json.parseFromSlice(std.json.Value, allocator, buffer, .{});
    defer json_tree.deinit();

    const root = json_tree.value;
    return try parseFn(root, allocator);
}
pub fn reloadGameConfig() !void {
    // 先释放旧的 game_config
    global_game_config_cache.game_config.deinit();

    // 再重新加载（这里用你之前写好的 loadGameConfigAuto，优先 freesr-data）
    global_game_config_cache.game_config =
        try loadGameConfigAuto(global_main_allocator);
}
