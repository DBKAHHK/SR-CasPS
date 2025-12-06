const commandhandler = @import("../command.zig");
const std = @import("std");
const Session = @import("../Session.zig");
const protocol = @import("protocol");
const Packet = @import("../Packet.zig");
const Data = @import("../data.zig");
const Uid = @import("../utils/uid.zig");
const AvatarManager = @import("../manager/avatar_mgr.zig");
const ConfigManager = @import("../manager/config_mgr.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

pub fn syncItems(session: *Session, allocator: Allocator, equip_avatar: bool) !void {
    Uid.resetGlobalUidGens();
    var sync = protocol.PlayerSyncScNotify.init(allocator);
    const config = &ConfigManager.global_game_config_cache.game_config;
    for (config.avatar_config.items) |avatarConf| {
        const dress_avatar_id: u32 = if (equip_avatar) avatarConf.id else 0;
        const lc = try AvatarManager.createEquipment(avatarConf.lightcone, dress_avatar_id);
        try sync.equipment_list.append(lc);
        for (avatarConf.relics.items) |input| {
            const r = try AvatarManager.createRelic(allocator, input, dress_avatar_id);
            try sync.relic_list.append(r);
        }
    }
    if (!equip_avatar) {
        try ConfigManager.UpdateGameConfig();
        Uid.updateInitialUid();
    }
    try session.send(CmdID.CmdPlayerSyncScNotify, sync);
}
pub fn onSyncAvatar(session: *Session, _: []const u8, allocator: Allocator) !void {
    Uid.resetGlobalUidGens();
    var sync = protocol.PlayerSyncScNotify.init(allocator);
    const config = &ConfigManager.global_game_config_cache.game_config;
    var char = protocol.AvatarSync.init(allocator);
    for (Data.AllAvatars) |id| {
        const avatar = try AvatarManager.createAllAvatar(allocator, id);
        try char.avatar_list.append(avatar);
    }
    for (config.avatar_config.items) |avatarConf| {
        const avatar = try AvatarManager.createAvatar(allocator, avatarConf);
        try char.avatar_list.append(avatar);
    }
    sync.avatar_sync = char;
    try session.send(CmdID.CmdPlayerSyncScNotify, sync);
}

pub fn onSyncMultiPath(session: *Session, _: []const u8, allocator: Allocator) !void {
    var sync = protocol.PlayerSyncScNotify.init(allocator);
    const config = &ConfigManager.global_game_config_cache.game_config;
    const multis = try AvatarManager.createAllMultiPath(allocator, config);
    try sync.multi_path_avatar_info_list.appendSlice(multis.items);
    try session.send(CmdID.CmdPlayerSyncScNotify, sync);
}

pub fn onGenerateAndSync(session: *Session, placeholder: []const u8, allocator: Allocator) !void {
    try commandhandler.sendMessage(session, "Sync items with config\n", allocator);
    try syncItems(session, allocator, false);
    try syncItems(session, allocator, true);
    try onSyncAvatar(session, placeholder, allocator);
    try onSyncMultiPath(session, placeholder, allocator);
}
