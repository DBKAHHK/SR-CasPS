const commandhandler = @import("../command.zig");
const std = @import("std");
const Session = @import("../Session.zig");

const Allocator = std.mem.Allocator;

pub fn handle(session: *Session, _: []const u8, allocator: Allocator) !void {
    try commandhandler.sendMessage(session, "/buff <id|off|info> (challenge custom buff)\n", allocator);
    try commandhandler.sendMessage(session, "/heal to heal your cur lineup\n", allocator);
    try commandhandler.sendMessage(session, "/refill to refill technique point\n", allocator);
    try commandhandler.sendMessage(session, "/mhp <max|number> to set max HP and sync\n", allocator);
    try commandhandler.sendMessage(session, "/lineup <list|switch|set> for multi-team presets\n", allocator);
    try commandhandler.sendMessage(session, "/set to set gacha banner\n", allocator);
    try commandhandler.sendMessage(session, "/node to chage node in PF, AS, MoC\n", allocator);
    try commandhandler.sendMessage(session, "/id to turn ON custom mode for challenge mode. /id info to check current challenge id. /id off to turn OFF\n", allocator);
    try commandhandler.sendMessage(session, "/funmode to Sillyism\n", allocator);
    try commandhandler.sendMessage(session, "You can enter MoC, PF, AS via F4 menu\n", allocator);
    try commandhandler.sendMessage(session, "/sync reloads freesr-data.json and syncs items/avatars", allocator);
    try commandhandler.sendMessage(session, "/reload alias of /sync", allocator);
    try commandhandler.sendMessage(session, "/give to give your a Material, such as credits", allocator);
    try commandhandler.sendMessage(session, "/level to set your Trailblaze Level", allocator);
    try commandhandler.sendMessage(session, "/tp to teleport", allocator);
    try commandhandler.sendMessage(session, "/move alias of /tp; /pos alias of /scene pos", allocator);
    try commandhandler.sendMessage(session, "/scene get to show current scene; /scene <plane> <floor> to teleport; /scene pos to show current position; /scene reload to reload configs", allocator);
    try commandhandler.sendMessage(session, "/info to show player basic info (uid/level/currency)", allocator);
    try commandhandler.sendMessage(session, "/gender <male|female> (also m/f/1/2) to pick Trailblazer gender; /path <warrior|knight|shaman|memory> to pick path", allocator);
    try commandhandler.sendMessage(session, "/kick to force a client-side logout", allocator);
    try commandhandler.sendMessage(session, "/mail [content...] [itemId:count ...] to send a system mail", allocator);
    try commandhandler.sendMessage(session, "/lua <file.lua> to send/execute a lua script from lua/ folder", allocator);
}
