const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const Data = @import("../data.zig");
const ConfigManager = @import("../manager/config_mgr.zig");
const Logic = @import("../utils/logic.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

const challenge_config = &ConfigManager.global_game_config_cache.challenge_maze_config;
const entrance_config = &ConfigManager.global_game_config_cache.map_entrance_config;
const maze_config = &ConfigManager.global_game_config_cache.maze_config;
const peak_config = &ConfigManager.global_game_config_cache.challenge_peak_config;
const peak_boss_config = &ConfigManager.global_game_config_cache.challenge_peak_boss_config;

pub const ChallengeManager = struct {
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) ChallengeManager {
        return ChallengeManager{ .allocator = allocator };
    }
    pub fn createChallenge(
        self: *ChallengeManager,
        challenge_id: u32,
        buff_id: u32,
    ) !protocol.CurChallenge {
        var cur_challenge_info = protocol.CurChallenge.init(self.allocator);
        cur_challenge_info.challenge_id = challenge_id;
        cur_challenge_info.score_id = if (challenge_id > 20000 and challenge_id < 30000) 40000 else 0;
        cur_challenge_info.score_two = 0;
        cur_challenge_info.status = protocol.ChallengeStatus.CHALLENGE_DOING;
        cur_challenge_info.extra_lineup_type = if (Logic.CustomMode().FirstNode()) protocol.ExtraLineupType.LINEUP_CHALLENGE else protocol.ExtraLineupType.LINEUP_CHALLENGE_2;
        if (Logic.CustomMode().FirstNode()) {
            for (challenge_config.challenge_config.items) |challengeConf| {
                if (challengeConf.id == challenge_id) {
                    std.debug.print("TRACING CONFIG ID {} WITH CHALLENGE ID {}\n", .{ challengeConf.id, challenge_id });
                    for (entrance_config.map_entrance_config.items) |entrance| {
                        if (entrance.id == challengeConf.map_entrance_id) {
                            for (maze_config.maze_plane_config.items) |maze| {
                                if (Logic.contains(&maze.floor_id_list, entrance.floor_id)) {
                                    if (challenge_id > 20000 and challenge_id < 30000) {
                                        var story_buff = protocol.ChallengeStoryBuffList{
                                            .buff_list = ArrayList(u32).init(self.allocator),
                                        };
                                        try story_buff.buff_list.append(challengeConf.maze_buff_id);
                                        try story_buff.buff_list.append(buff_id);
                                        try Logic.Challenge().AddBlessing(story_buff.buff_list.items);
                                        cur_challenge_info.stage_info = .{
                                            .MLNEDDHOJGC = .{
                                                .cur_story_buffs = story_buff,
                                            },
                                        };
                                        Logic.Challenge().SetChallengeMode(1);
                                    } else if (challenge_id > 30000) {
                                        var boss_buff = protocol.ChallengeBossBuffList{
                                            .buff_list = ArrayList(u32).init(self.allocator),
                                            .challenge_boss_const = 1,
                                        };
                                        try boss_buff.buff_list.append(challengeConf.maze_buff_id);
                                        try boss_buff.buff_list.append(buff_id);
                                        try Logic.Challenge().AddBlessing(boss_buff.buff_list.items);
                                        cur_challenge_info.stage_info = .{
                                            .MLNEDDHOJGC = .{
                                                .cur_boss_buffs = boss_buff,
                                            },
                                        };
                                        Logic.Challenge().SetChallengeMode(2);
                                    }
                                    Logic.Challenge().SetChallengeInfo(
                                        entrance.floor_id,
                                        maze.world_id,
                                        challengeConf.npc_monster_id_list1.items[challengeConf.npc_monster_id_list1.items.len - 1],
                                        challengeConf.event_id_list1.items[challengeConf.event_id_list1.items.len - 1],
                                        challengeConf.maze_group_id1,
                                        challengeConf.maze_group_id1,
                                        maze.challenge_plane_id,
                                        challengeConf.map_entrance_id,
                                    );
                                }
                            }
                        }
                    }
                }
            }
        } else {
            for (challenge_config.challenge_config.items) |challengeConf| {
                if (challengeConf.id == challenge_id) {
                    std.debug.print("TRACING CONFIG ID {} WITH CHALLENGE ID {}\n", .{ challengeConf.id, challenge_id });
                    for (entrance_config.map_entrance_config.items) |entrance| {
                        if (entrance.id == challengeConf.map_entrance_id2) {
                            for (maze_config.maze_plane_config.items) |maze| {
                                if (Logic.contains(&maze.floor_id_list, entrance.floor_id)) {
                                    if (challengeConf.maze_group_id2) |id| {
                                        if (challenge_id > 20000 and challenge_id < 30000) {
                                            var story_buff = protocol.ChallengeStoryBuffList{
                                                .buff_list = ArrayList(u32).init(self.allocator),
                                            };
                                            try story_buff.buff_list.append(challengeConf.maze_buff_id);
                                            try story_buff.buff_list.append(buff_id);
                                            try Logic.Challenge().AddBlessing(story_buff.buff_list.items);
                                            cur_challenge_info.stage_info = .{
                                                .MLNEDDHOJGC = .{
                                                    .cur_story_buffs = story_buff,
                                                },
                                            };
                                            Logic.Challenge().SetChallengeMode(1);
                                        } else if (challenge_id > 30000) {
                                            var boss_buff = protocol.ChallengeBossBuffList{
                                                .buff_list = ArrayList(u32).init(self.allocator),
                                                .challenge_boss_const = 1,
                                            };
                                            try boss_buff.buff_list.append(challengeConf.maze_buff_id);
                                            try boss_buff.buff_list.append(buff_id);
                                            try Logic.Challenge().AddBlessing(boss_buff.buff_list.items);
                                            cur_challenge_info.stage_info = .{
                                                .MLNEDDHOJGC = .{
                                                    .cur_boss_buffs = boss_buff,
                                                },
                                            };
                                            Logic.Challenge().SetChallengeMode(2);
                                        }
                                        Logic.Challenge().SetChallengeInfo(
                                            entrance.floor_id,
                                            maze.world_id,
                                            challengeConf.npc_monster_id_list2.items[challengeConf.npc_monster_id_list2.items.len - 1],
                                            challengeConf.event_id_list2.items[challengeConf.event_id_list2.items.len - 1],
                                            id,
                                            id,
                                            maze.challenge_plane_id,
                                            challengeConf.map_entrance_id2,
                                        );
                                    } else {
                                        std.debug.print("THIS CHALLENGE ID: {} DOES NOT SUPPORT 2ND NODE. PLEASE DO COMMAND /node TO SWITCH BACK TO FIRST NODE\n", .{challenge_id});
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        return cur_challenge_info;
    }
    pub fn createChallengePeak(
        _: *ChallengeManager,
        challenge_peak_id: u32,
        buff_id: u32,
    ) !void {
        for (peak_config.challenge_peak.items) |peak| {
            if (peak.id == challenge_peak_id) {
                for (entrance_config.map_entrance_config.items) |entrance| {
                    if (entrance.id == peak.map_entrance_id) {
                        if (buff_id != 0) try Logic.Challenge().AddBlessing(&[_]u32{buff_id});
                        if (Logic.Challenge().ChallengePeakHard()) {
                            for (peak_boss_config.challenge_peak_boss_config.items) |boss| {
                                if (boss.id == challenge_peak_id) try Logic.Challenge().AddBlessing(boss.hard_tag_list.items);
                            }
                        } else {
                            try Logic.Challenge().AddBlessing(peak.tag_list.items);
                        }
                        Logic.Challenge().SetChallengePeakInfo(
                            entrance.floor_id,
                            peak.npc_monster_id_list.items[peak.npc_monster_id_list.items.len - 1],
                            Logic.Challenge().CalChallengePeakEventID(peak.event_id_list.items[peak.event_id_list.items.len - 1]),
                            peak.maze_group_id,
                            peak.maze_group_id,
                            entrance.plane_id,
                            peak.map_entrance_id,
                        );
                    }
                }
            }
        }
    }
};

pub fn deinitCurChallenge(challenge: *protocol.CurChallenge) void {
    if (challenge.stage_info) |*stage_info| {
        if (stage_info.MLNEDDHOJGC) |*union_val| {
            switch (union_val.*) {
                .cur_story_buffs => |*story_buffs| {
                    story_buffs.buff_list.deinit();
                },
                .cur_boss_buffs => |*boss_buffs| {
                    boss_buffs.buff_list.deinit();
                },
            }
        }
    }
}
