const std = @import("std");
const protocol = @import("protocol");
const Session = @import("Session.zig");
const Packet = @import("Packet.zig");
const PlayerStateMod = @import("player_state.zig");

const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

const value_command = @import("./commands/value.zig");
const help_command = @import("./commands/help.zig");
const tp_command = @import("./commands/tp.zig");
const unstuck_command = @import("./commands/unstuck.zig");
const sync_command = @import("./commands/sync.zig");
const refill_command = @import("./commands/refill.zig");

const CommandFn = *const fn (session: *Session, args: []const u8, allocator: Allocator) anyerror!void;

const Command = struct {
    name: []const u8,
    action: []const u8,
    func: CommandFn,
};

const commandList = [_]Command{
    .{ .name = "help", .action = "", .func = help_command.handle },
    .{ .name = "test", .action = "", .func = value_command.handle },
    .{ .name = "node", .action = "", .func = value_command.challengeNode },
    .{ .name = "set", .action = "", .func = value_command.setGachaCommand },
    .{ .name = "tp", .action = "", .func = tp_command.handle },
    .{ .name = "unstuck", .action = "", .func = unstuck_command.handle },
    .{ .name = "sync", .action = "", .func = sync_command.onGenerateAndSync },
    .{ .name = "refill", .action = "", .func = refill_command.onRefill },
    .{ .name = "id", .action = "", .func = value_command.onBuffId },
    .{ .name = "funmode", .action = "", .func = value_command.FunMode },
    .{ .name = "give", .action = "", .func = value_command.give },
    .{ .name = "level", .action = "", .func = value_command.level },
    .{ .name = "info", .action = "", .func = value_command.playerInfo },
    .{ .name = "scene", .action = "", .func = value_command.sceneCommand },
    .{ .name = "savelineup", .action = "", .func = value_command.saveLineup },
    .{ .name = "gender", .action = "", .func = value_command.setGender },
    .{ .name = "path", .action = "", .func = value_command.setPath },
    .{ .name = "stop", .action = "", .func = value_command.stop },
    .{ .name = "kick", .action = "", .func = value_command.kick },
    .{ .name = "mail", .action = "", .func = value_command.sendMail },
};

pub fn handleCommand(session: *Session, msg: []const u8, allocator: Allocator) !void {
    if (msg.len < 1 or msg[0] != '/') {
        std.debug.print("Message Text 2: {any}\n", .{msg});
        return sendMessage(session, "Commands must start with a '/'", allocator);
    }

    const input = msg[1..]; // Remove leading '/'
    var tokenizer = std.mem.tokenizeAny(u8, input, " ");
    const command = tokenizer.next() orelse return sendMessage(session, "Invalid command", allocator);
    const args = tokenizer.rest();

    for (commandList) |cmd| {
        if (std.mem.eql(u8, cmd.name, command)) {
            return try cmd.func(session, args, allocator);
        }
    }

    return sendMessage(session, "Invalid command", allocator);
}

pub fn sendMessage(session: *Session, msg: []const u8, allocator: Allocator) !void {
    var chat = protocol.RevcMsgScNotify.init(allocator);
    chat.message_type = protocol.MsgType.MSG_TYPE_CUSTOM_TEXT;
    chat.chat_type = protocol.ChatType.CHAT_TYPE_PRIVATE;
    chat.source_uid = 2000;
    chat.message_text = .{ .Const = msg };
    chat.target_uid = 1;
    try session.send(CmdID.CmdRevcMsgScNotify, chat);
}
