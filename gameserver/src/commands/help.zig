const commandhandler = @import("../command.zig");
const std = @import("std");
const Session = @import("../Session.zig");

const Allocator = std.mem.Allocator;

pub fn handle(session: *Session, _: []const u8, allocator: Allocator) !void {
    try commandhandler.sendMessage(session, "/tp to teleport, /sync to sync data from config\n", allocator);
    try commandhandler.sendMessage(session, "/refill to refill technique point after battle\n", allocator);
    try commandhandler.sendMessage(session, "/set to set gacha banner\n", allocator);
    try commandhandler.sendMessage(session, "/node to chage node in PF, AS, MoC\n", allocator);
    try commandhandler.sendMessage(session, "/id to turn ON custom mode for challenge mode. /id info to check current challenge id. /id off to turn OFF\n", allocator);
    try commandhandler.sendMessage(session, "/funmode to Sillyism\n", allocator);
    try commandhandler.sendMessage(session, "You can enter MoC, PF, AS via F4 menu\n", allocator);
    try commandhandler.sendMessage(session, "Please strictly distinguish between /sync and /syncdata", allocator);
    try commandhandler.sendMessage(session, "/sync to sync your config.(Beta, only test)", allocator);
    try commandhandler.sendMessage(session, "/syncdata to sync your free-sr data(Beta, only test)", allocator);
    try commandhandler.sendMessage(session, "/give to give your a Material, such as credits(Beta, only test)", allocator);
    try commandhandler.sendMessage(session, "/level to set your Trailblaze Level(Beta, only test)", allocator);
    try commandhandler.sendMessage(session, "/tp to teleport(Beta, only test)", allocator);
    try commandhandler.sendMessage(session, "/scene pos to show current position; /scene reload to reload scene config(Beta, only test)", allocator);
    try commandhandler.sendMessage(session, "/info to show player basic info (uid/level/currency)", allocator);
    try commandhandler.sendMessage(session, "/gender <male|female> to pick Trailblazer gender; /path <warrior|knight|shaman|memory> to pick path", allocator);
    try commandhandler.sendMessage(session, "/kick to disconnect your session", allocator);
}
