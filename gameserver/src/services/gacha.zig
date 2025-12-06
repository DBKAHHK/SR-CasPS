const std = @import("std");
const protocol = @import("protocol");
const Session = @import("../Session.zig");
const Packet = @import("../Packet.zig");
const Data = @import("../data.zig");
const Logic = @import("../utils/logic.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const CmdID = protocol.CmdID;

pub fn onGetGachaInfo(session: *Session, _: *const Packet, allocator: Allocator) !void {
    var info = ArrayList(protocol.GachaCeilingAvatar).init(allocator);
    for (Logic.Banner().GetStandardBanner()) |id| {
        try info.appendSlice(&[_]protocol.GachaCeilingAvatar{
            .{ .repeated_cnt = 300, .avatar_id = id },
        });
    }
    var gacha_info = protocol.GachaInfo.init(allocator);
    gacha_info.begin_time = 0;
    gacha_info.end_time = 2524608000;
    gacha_info.gacha_ceiling = .{
        .avatar_list = info,
        .is_claimed = false,
        .ceiling_num = 200,
    };
    gacha_info.EOHEEGMKMOE = 1;
    gacha_info.DKHDCPOOHKA = 3;
    gacha_info.gacha_id = 1001; // standard banner

    var rsp = protocol.GetGachaInfoScRsp.init(allocator);

    rsp.retcode = 0;
    rsp.FMCPOBKEMAG = 20;
    rsp.FMCPOBKEMAG = 20;
    rsp.APOCGAOJOJF = 900;
    rsp.gacha_random = 0;
    try rsp.gacha_info_list.append(gacha_info);

    try session.send(CmdID.CmdGetGachaInfoScRsp, rsp);
}
pub fn onBuyGoods(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.BuyGoodsCsReq, allocator);
    defer req.deinit();

    var rsp = protocol.BuyGoodsScRsp.init(allocator);
    var item = ArrayList(protocol.Item).init(allocator);

    try item.appendSlice(&[_]protocol.Item{.{
        .item_id = 101,
        .num = 100,
    }});

    rsp.retcode = 0;
    rsp.goods_id = req.goods_id;
    rsp.goods_buy_times = req.goods_num;
    rsp.shop_id = 0;
    rsp.return_item_list = .{ .item_list = item };

    try session.send(CmdID.CmdBuyGoodsScRsp, rsp);
}
pub fn onExchangeHcoin(session: *Session, packet: *const Packet, allocator: Allocator) !void {
    const req = try packet.getProto(protocol.ExchangeHcoinCsReq, allocator);
    defer req.deinit();

    var rsp = protocol.ExchangeHcoinScRsp.init(allocator);
    rsp.num = req.num;
    rsp.retcode = 0;

    try session.send(CmdID.CmdExchangeHcoinScRsp, rsp);
}

var five_star_pity: u32 = 0;
var four_star_pity: u32 = 0;
var guaranteed_five_star_rate_up: bool = false;
var guaranteed_four_star_rate_up: bool = false;
var avatar_list_cached: ?std.ArrayList(u32) = null;
var lightcone_list_3_cached: ?std.ArrayList(u32) = null;
var lightcone_list_4_cached: ?std.ArrayList(u32) = null;
fn pow(base: f64, exp: f64) f64 {
    return @exp(exp * @log(base));
}
fn getFiveStarRate(gacha_count: u32) f64 {
    if (gacha_count < 21) {
        return 0.02;
    }
    if (gacha_count < 72) {
        return 0.008;
    }
    const excess_pulls = @as(f64, @floatFromInt(gacha_count - 71));
    return 0.008 + (1.0 - 0.008) * pow(excess_pulls / 18.0, 2.8);
}
fn getFourStarRate(gacha_count: u32) f64 {
    if (gacha_count < 6) {
        return 0.055;
    }
    const excess_pulls = @as(f64, @floatFromInt(gacha_count - 5));
    return 0.055 + (1.0 - 0.055) * pow(excess_pulls / 3.5, 2.2);
}
fn pickRandomId(banner: []const u32) u32 {
    const idx = std.crypto.random.intRangeLessThan(usize, 0, banner.len);
    return banner[idx];
}

pub fn onDoGacha(session: *Session, packet: *const Packet, allocator: std.mem.Allocator) !void {
    const req = try packet.getProto(protocol.DoGachaCsReq, allocator);
    defer req.deinit();

    var rsp = protocol.DoGachaScRsp.init(allocator);
    const rnd = std.crypto.random;

    var selected_ids = std.ArrayList(u32).init(allocator);
    defer selected_ids.deinit();
    var got_four_star = false;
    for (0..req.gacha_num) |_| {
        const five_star_rate = getFiveStarRate(five_star_pity);
        const four_star_rate = getFourStarRate(four_star_pity);
        const random_value = rnd.float(f64);
        var selected_banner: []const u32 = &Data.LightconeList_3;
        var is_five_star = false;
        var is_four_star = false;
        if (random_value < five_star_rate or five_star_pity == 89) {
            is_five_star = true;
            five_star_pity = 0;
            if (guaranteed_five_star_rate_up) {
                selected_banner = Logic.Banner().GetRateUp();
                guaranteed_five_star_rate_up = false;
            } else {
                if (rnd.boolean()) {
                    selected_banner = Logic.Banner().GetRateUp();
                } else {
                    selected_banner = Logic.Banner().GetStandardBanner();
                    guaranteed_five_star_rate_up = true;
                }
            }
        } else if (four_star_pity == 9 or random_value < (five_star_rate + four_star_rate)) {
            is_four_star = true;
            four_star_pity = 0;
            got_four_star = true;

            if (guaranteed_four_star_rate_up or rnd.float(f64) < 0.70) {
                selected_banner = Logic.Banner().GetRateUpFourStar();
                guaranteed_four_star_rate_up = false;
            } else {
                if (rnd.boolean()) {
                    selected_banner = Data.AvatarList;
                } else {
                    selected_banner = &Data.LightconeList_4;
                }
                guaranteed_four_star_rate_up = true;
            }
        } else {
            four_star_pity += 1;
        }
        five_star_pity += 1;
        try selected_ids.append(pickRandomId(selected_banner));
    }
    if (req.gacha_num > 1 and !got_four_star) {
        selected_ids.items[
            std.crypto.random.intRangeLessThan(usize, 0, selected_ids.items.len)
        ] = pickRandomId(Logic.Banner().GetRateUpFourStar());
    }
    for (selected_ids.items) |id| {
        var gacha_item = protocol.GachaItem.init(allocator);
        gacha_item.gacha_item = .{ .item_id = id };
        gacha_item.is_new = false;
        var back_item = std.ArrayList(protocol.Item).init(allocator);
        var transfer_item = std.ArrayList(protocol.Item).init(allocator);
        if (id < 10000) {
            if (Logic.inlist(id, Logic.Banner().GetRateUp()) or Logic.inlist(id, Logic.Banner().GetStandardBanner())) {
                try transfer_item.appendSlice(&[_]protocol.Item{
                    .{ .item_id = id + 10000, .num = 1 },
                    .{ .item_id = 252, .num = 20 },
                });
            } else {
                try transfer_item.append(.{ .item_id = 252, .num = 20 });
            }
        }
        try back_item.append(.{ .item_id = 252, .num = 20 });
        gacha_item.transfer_item_list = .{ .item_list = transfer_item };
        gacha_item.token_item = .{ .item_list = back_item };
        try rsp.gacha_item_list.append(gacha_item);
    }
    rsp.gacha_num = req.gacha_num;
    rsp.gacha_id = req.gacha_id;
    rsp.ceiling_num = 200;
    rsp.EOHEEGMKMOE = 1;
    rsp.FMCPOBKEMAG = 20;
    rsp.DKHDCPOOHKA = 3;
    rsp.retcode = 0;

    std.debug.print("FIVE STAR PITY: {}, (RATE: {d:.4}%)\n", .{ five_star_pity, getFiveStarRate(five_star_pity) * 100.0 });
    std.debug.print("FOUR STAR PITY: {}, (RATE: {d:.4}%)\n", .{ four_star_pity, getFourStarRate(four_star_pity) * 100.0 });

    try session.send(protocol.CmdID.CmdDoGachaScRsp, rsp);
}
