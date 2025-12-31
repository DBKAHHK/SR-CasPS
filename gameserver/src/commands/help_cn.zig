const commandhandler = @import("../command.zig");
const std = @import("std");
const Session = @import("../Session.zig");

const Allocator = std.mem.Allocator;

pub fn handle(session: *Session, _: []const u8, allocator: Allocator) !void {
    try commandhandler.sendMessage(session, "===== CastoricePS 指令帮助 =====\n", allocator);
    try commandhandler.sendMessage(session, "/help  英文帮助\n", allocator);

    try commandhandler.sendMessage(session, "\n【基础】\n", allocator);
    try commandhandler.sendMessage(session, "/info  查看玩家信息（UID/等级/货币）\n", allocator);
    try commandhandler.sendMessage(session, "/sync  重新加载 freesr-data.json 并同步物品/角色\n", allocator);
    try commandhandler.sendMessage(session, "/reload  等同于 /sync\n", allocator);

    try commandhandler.sendMessage(session, "\n【编队】\n", allocator);
    try commandhandler.sendMessage(session, "/lineup list  查看所有队伍预设\n", allocator);
    try commandhandler.sendMessage(session, "/lineup switch <index>  切换到第 index 队（0 开始）\n", allocator);
    try commandhandler.sendMessage(session, "/lineup set <index> <id1> <id2> <id3> <id4>  设置队伍预设\n", allocator);

    try commandhandler.sendMessage(session, "\n【治疗/秘技点】\n", allocator);
    try commandhandler.sendMessage(session, "/heal  回复当前队伍血量\n", allocator);
    try commandhandler.sendMessage(session, "/refill  回复当前队伍秘技点\n", allocator);

    try commandhandler.sendMessage(session, "\n【战斗/怪物】\n", allocator);
    try commandhandler.sendMessage(session, "/mhp <max|number|0|off>  覆盖“敌方最大血量”（0/off 关闭；新战斗生效）\n", allocator);

    try commandhandler.sendMessage(session, "\n【传送】\n", allocator);
    try commandhandler.sendMessage(session, "/tp <entryId>\n", allocator);
    try commandhandler.sendMessage(session, "/tp <planeId> <floorId> [entryId] [teleportId]\n", allocator);
    try commandhandler.sendMessage(session, "/move  等同 /tp\n", allocator);
    try commandhandler.sendMessage(session, "/scene get  查看当前场景\n", allocator);
    try commandhandler.sendMessage(session, "/scene pos  查看当前坐标\n", allocator);
    try commandhandler.sendMessage(session, "/scene <planeId> <floorId>  跨图传送\n", allocator);

    try commandhandler.sendMessage(session, "\n【挑战/自定义】\n", allocator);
    try commandhandler.sendMessage(session, "/buff <id|off|info>  挑战自定义 BUFF\n", allocator);
    try commandhandler.sendMessage(session, "/id  开启挑战自定义模式；/id info 查看；/id off 关闭\n", allocator);
    try commandhandler.sendMessage(session, "/node  在 PF/AS/MoC 切换节点，可以用于跳过上半\n", allocator);
    try commandhandler.sendMessage(session, "提示：MoC/PF/AS 可通过 F4 菜单进入\n", allocator);

    try commandhandler.sendMessage(session, "\n【趣味模式】\n", allocator);
    try commandhandler.sendMessage(session, "/funmode on|off  开/关 funmode\n", allocator);
    try commandhandler.sendMessage(session, "/funmode hp <max|number>  设置敌方血量覆盖（同 /mhp 的底层值）\n", allocator);
    try commandhandler.sendMessage(session, "/funmode lineup show|clear\n", allocator);
    try commandhandler.sendMessage(session, "/funmode lineup set <id1> <id2> <id3> <id4>\n", allocator);

    try commandhandler.sendMessage(session, "\n【其他】\n", allocator);
    try commandhandler.sendMessage(session, "/gender <male|female>（也支持 m/f/1/2）  设置主角性别\n", allocator);
    try commandhandler.sendMessage(session, "/path <warrior|knight|shaman|memory>  设置主角命途\n", allocator);
    try commandhandler.sendMessage(session, "/give  发放材料（例如信用点等；具体用法看英文 help）\n", allocator);
    try commandhandler.sendMessage(session, "/level  设置开拓等级\n", allocator);
    try commandhandler.sendMessage(session, "/kick  强制客户端退出登录\n", allocator);
    try commandhandler.sendMessage(session, "/mail [内容...] [itemId:count ...]  发送系统邮件\n", allocator);
    try commandhandler.sendMessage(session, "/lua <file.lua>  发送/执行 lua/ 目录下脚本\n", allocator);
}
