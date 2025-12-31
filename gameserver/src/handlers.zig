const std = @import("std");
const protocol = @import("protocol");
const Session = @import("Session.zig");
const Packet = @import("Packet.zig");
const avatar = @import("services/avatar.zig");
const chat = @import("services/chat.zig");
const gacha = @import("services/gacha.zig");
const item = @import("services/item.zig");
const battle = @import("services/battle.zig");
const login = @import("services/login.zig");
const lineup = @import("services/lineup.zig");
const mail = @import("services/mail.zig");
const misc = @import("services/misc.zig");
const mission = @import("services/mission.zig");
const pet = @import("services/pet.zig");
const profile = @import("services/profile.zig");
const scene = @import("services/scene.zig");
const events = @import("services/events.zig");
const challenge = @import("services/challenge.zig");

const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const CmdID = protocol.CmdID;

const log = std.log.scoped(.handlers);

const Action = *const fn (*Session, *const Packet, Allocator) anyerror!void;
pub const HandlerList = [_]struct { CmdID, Action }{
    .{ CmdID.CmdPlayerGetTokenCsReq, login.onPlayerGetToken },
    .{ CmdID.CmdPlayerLoginCsReq, login.onPlayerLogin },
    .{ CmdID.CmdPlayerHeartBeatCsReq, misc.onPlayerHeartBeat },
    .{ CmdID.CmdPlayerLoginFinishCsReq, login.onPlayerLoginFinish },
    .{ CmdID.CmdContentPackageGetDataCsReq, login.onContentPackageGetData },
    .{ CmdID.CmdSetClientPausedCsReq, login.onSetClientPaused },
    .{ CmdID.CmdGetArchiveDataCsReq, login.onGetArchiveData },
    .{ CmdID.CmdGetUpdatedArchiveDataCsReq, login.onGetUpdatedArchiveData },
    //avatar
    .{ CmdID.CmdGetAvatarDataCsReq, avatar.onGetAvatarData },
    .{ CmdID.CmdSetAvatarPathCsReq, avatar.onSetAvatarPath },
    .{ CmdID.CmdGetBasicInfoCsReq, avatar.onGetBasicInfo },
    .{ CmdID.CmdTakeOffAvatarSkinCsReq, avatar.onTakeOffAvatarSkin },
    .{ CmdID.CmdDressAvatarSkinCsReq, avatar.onDressAvatarSkin },
    .{ CmdID.CmdGetBigDataAllRecommendCsReq, avatar.onGetBigDataAll },
    .{ CmdID.CmdGetBigDataRecommendCsReq, avatar.onGetBigData },
    .{ CmdID.CmdGetPreAvatarGrowthInfoCsReq, avatar.onGetPreAvatarGrowthInfo },
    .{ CmdID.CmdSetPlayerOutfitCsReq, avatar.onSetPlayerOutfit },
    .{ CmdID.CmdSetAvatarEnhancedIdCsReq, avatar.onSetAvatarEnhancedId },
    //bag
    .{ CmdID.CmdGetBagCsReq, item.onGetBag },
    .{ CmdID.CmdUseItemCsReq, item.onUseItem },
    //lineup
    .{ CmdID.CmdChangeLineupLeaderCsReq, lineup.onChangeLineupLeader },
    .{ CmdID.CmdReplaceLineupCsReq, lineup.onReplaceLineup },
    .{ CmdID.CmdGetCurLineupDataCsReq, lineup.onGetCurLineupData },
    .{ CmdID.CmdGetAllLineupDataCsReq, lineup.onGetAllLineupData },
    .{ CmdID.CmdSwitchLineupIndexCsReq, lineup.onSwitchLineupIndex },
    .{ CmdID.CmdSetLineupNameCsReq, lineup.onSetLineupName },
    //battle
    .{ CmdID.CmdStartCocoonStageCsReq, battle.onStartCocoonStage },
    .{ CmdID.CmdPVEBattleResultCsReq, battle.onPVEBattleResult },
    .{ CmdID.CmdSceneCastSkillCsReq, battle.onSceneCastSkill },
    .{ CmdID.CmdSceneCastSkillCostMpCsReq, battle.onSceneCastSkillCostMp },
    .{ CmdID.CmdQuickStartCocoonStageCsReq, battle.onQuickStartCocoonStage },
    .{ CmdID.CmdQuickStartFarmElementCsReq, battle.onQuickStartFarmElement },
    .{ CmdID.CmdStartBattleCollegeCsReq, battle.onStartBattleCollege },
    .{ CmdID.CmdGetCurBattleInfoCsReq, battle.onGetCurBattleInfo },
    .{ CmdID.CmdSyncClientResVersionCsReq, battle.onSyncClientResVersion },
    //gacha
    .{ CmdID.CmdGetGachaInfoCsReq, gacha.onGetGachaInfo },
    .{ CmdID.CmdBuyGoodsCsReq, gacha.onBuyGoods },
    .{ CmdID.CmdExchangeHcoinCsReq, gacha.onExchangeHcoin },
    .{ CmdID.CmdDoGachaCsReq, gacha.onDoGacha },
    //mail
    .{ CmdID.CmdGetMailCsReq, mail.onGetMail },
    .{ CmdID.CmdTakeMailAttachmentCsReq, mail.onTakeMailAttachment },
    //pet
    .{ CmdID.CmdGetPetDataCsReq, pet.onGetPetData },
    .{ CmdID.CmdRecallPetCsReq, pet.onRecallPet },
    .{ CmdID.CmdSummonPetCsReq, pet.onSummonPet },
    //profile
    .{ CmdID.CmdGetPhoneDataCsReq, profile.onGetPhoneData },
    .{ CmdID.CmdSelectPhoneThemeCsReq, profile.onSelectPhoneTheme },
    .{ CmdID.CmdSelectChatBubbleCsReq, profile.onSelectChatBubble },
    .{ CmdID.CmdGetPlayerBoardDataCsReq, profile.onGetPlayerBoardData },
    .{ CmdID.CmdSetDisplayAvatarCsReq, profile.onSetDisplayAvatar },
    .{ CmdID.CmdSetAssistAvatarCsReq, profile.onSetAssistAvatar },
    .{ CmdID.CmdSetSignatureCsReq, profile.onSetSignature },
    .{ CmdID.CmdSetGameplayBirthdayCsReq, profile.onSetGameplayBirthday },
    .{ CmdID.CmdSetHeadIconCsReq, profile.onSetHeadIcon },
    .{ CmdID.CmdSelectPhoneCaseCsReq, profile.onSelectPhoneCase },
    .{ CmdID.CmdUpdatePlayerSettingCsReq, profile.onUpdatePlayerSetting },
    .{ CmdID.CmdGetPlayerDetailInfoCsReq, profile.onGetPlayerDetailInfo },
    .{ CmdID.CmdSetPersonalCardCsReq, profile.onSetPersonalCard },
    //mission
    .{ CmdID.CmdGetTutorialGuideCsReq, mission.onGetTutorialGuideStatus },
    .{ CmdID.CmdGetMissionStatusCsReq, mission.onGetMissionStatus },
    .{ CmdID.CmdGetTutorialCsReq, mission.onGetTutorialStatus },
    .{ CmdID.CmdUnlockTutorialGuideCsReq, mission.onUnlockTutorialGuide },
    .{ CmdID.CmdUnlockTutorialCsReq, mission.onUnlockTutorial },
    .{ CmdID.CmdFinishTalkMissionCsReq, mission.onFinishTalkMission },
    .{ CmdID.CmdGetQuestDataCsReq, mission.onGetQuestData },
    //chat
    .{ CmdID.CmdGetFriendListInfoCsReq, chat.onGetFriendListInfo },
    .{ CmdID.CmdGetPrivateChatHistoryCsReq, chat.onPrivateChatHistory },
    .{ CmdID.CmdGetChatEmojiListCsReq, chat.onChatEmojiList },
    .{ CmdID.CmdSendMsgCsReq, chat.onSendMsg },
    //scene
    .{ CmdID.CmdGetCurSceneInfoCsReq, scene.onGetCurSceneInfo },
    .{ CmdID.CmdSceneEntityMoveCsReq, scene.onSceneEntityMove },
    .{ CmdID.CmdEnterSceneCsReq, scene.onEnterScene },
    .{ CmdID.CmdGetSceneMapInfoCsReq, scene.onGetSceneMapInfo },
    .{ CmdID.CmdGetUnlockTeleportCsReq, scene.onGetUnlockTeleport },
    .{ CmdID.CmdEnterSectionCsReq, scene.onEnterSection },
    .{ CmdID.CmdSceneEntityTeleportCsReq, scene.onSceneEntityTeleport },
    .{ CmdID.CmdGetFirstTalkNpcCsReq, scene.onGetFirstTalkNpc },
    .{ CmdID.CmdGetFirstTalkByPerformanceNpcCsReq, scene.onGetFirstTalkByPerformanceNp },
    .{ CmdID.CmdGetNpcTakenRewardCsReq, scene.onGetNpcTakenReward },
    .{ CmdID.CmdUpdateGroupPropertyCsReq, scene.onUpdateGroupProperty },
    .{ CmdID.CmdChangePropTimelineInfoCsReq, scene.onChangePropTimeline },
    .{ CmdID.CmdDeactivateFarmElementCsReq, scene.onDeactivateFarmElement },
    .{ CmdID.CmdGetEnteredSceneCsReq, scene.onGetEnteredScene },
    .{ CmdID.CmdInteractPropCsReq, scene.onInteractProp },
    .{ CmdID.CmdChangeEraFlipperDataCsReq, scene.onChangeEraFlipperData },
    .{ CmdID.CmdSetTrainWorldIdCsReq, scene.onSetTrainWorldId },
    //events
    .{ CmdID.CmdGetActivityScheduleConfigCsReq, events.onGetActivity },
    .{ CmdID.CmdUpdateServerPrefsDataCsReq, events.onUpdateServerPrefsData },
    //challenge
    .{ CmdID.CmdGetChallengeCsReq, challenge.onGetChallenge },
    .{ CmdID.CmdGetChallengeGroupStatisticsCsReq, challenge.onGetChallengeGroupStatistics },
    .{ CmdID.CmdStartChallengeCsReq, challenge.onStartChallenge },
    .{ CmdID.CmdEnterChallengeNextPhaseCsReq, challenge.onEnterChallengeNextPhase },
    .{ CmdID.CmdLeaveChallengeCsReq, challenge.onLeaveChallenge },
    .{ CmdID.CmdLeaveChallengePeakCsReq, challenge.onLeaveChallengePeak },
    .{ CmdID.CmdGetCurChallengeCsReq, challenge.onGetCurChallengeScRsp },
    .{ CmdID.CmdGetChallengePeakDataCsReq, challenge.onGetChallengePeakData },
    .{ CmdID.CmdGetCurChallengePeakCsReq, challenge.onGetCurChallengePeak },
    .{ CmdID.CmdTakeChallengeRewardCsReq, challenge.onTakeChallengeReward },
    .{ CmdID.CmdStartChallengePeakCsReq, challenge.onStartChallengePeak },
    .{ CmdID.CmdReStartChallengePeakCsReq, challenge.onReStartChallengePeak },
    .{ CmdID.CmdSetChallengePeakMobLineupAvatarCsReq, challenge.onSetChallengePeakMobLineupAvatar },
    .{ CmdID.CmdSetChallengePeakBossHardModeCsReq, challenge.onSetChallengePeakBossHardMode },
    .{ CmdID.CmdConfirmChallengePeakSettleCsReq, challenge.onConfirmChallengePeakSettle },
    .{ CmdID.CmdGetFriendBattleRecordDetailCsReq, challenge.onGetFriendBattleRecordDetail },
};
// Dummy handlers for packets that can fix random loading issues.
const DummyCmdList = [_]struct { CmdID, CmdID }{
    .{ CmdID.CmdGetBagCsReq, CmdID.CmdGetBagScRsp },
    .{ CmdID.CmdGetMarkItemListCsReq, CmdID.CmdGetMarkItemListScRsp },
    .{ CmdID.CmdGetPlayerBoardDataCsReq, CmdID.CmdGetPlayerBoardDataScRsp },
    .{ CmdID.CmdGetCurAssistCsReq, CmdID.CmdGetCurAssistScRsp },
    .{ CmdID.CmdGetAllLineupDataCsReq, CmdID.CmdGetAllLineupDataScRsp },
    .{ CmdID.CmdGetAllServerPrefsDataCsReq, CmdID.CmdGetAllServerPrefsDataScRsp },
    .{ CmdID.CmdGetMissionDataCsReq, CmdID.CmdGetMissionDataScRsp },
    .{ CmdID.CmdDailyFirstMeetPamCsReq, CmdID.CmdDailyFirstMeetPamScRsp },
    .{ CmdID.CmdGetBattleCollegeDataCsReq, CmdID.CmdGetBattleCollegeDataScRsp },
    .{ CmdID.CmdGetNpcStatusCsReq, CmdID.CmdGetNpcStatusScRsp },
    .{ CmdID.CmdGetSecretKeyInfoCsReq, CmdID.CmdGetSecretKeyInfoScRsp },
    .{ CmdID.CmdGetHeartDialInfoCsReq, CmdID.CmdGetHeartDialInfoScRsp },
    .{ CmdID.CmdGetVideoVersionKeyCsReq, CmdID.CmdGetVideoVersionKeyScRsp },
    .{ CmdID.CmdHeliobusActivityDataCsReq, CmdID.CmdHeliobusActivityDataScRsp },
    .{ CmdID.CmdGetAetherDivideInfoCsReq, CmdID.CmdGetAetherDivideInfoScRsp },
    .{ CmdID.CmdGetMapRotationDataCsReq, CmdID.CmdGetMapRotationDataScRsp },
    .{ CmdID.CmdGetLevelRewardTakenListCsReq, CmdID.CmdGetLevelRewardTakenListScRsp },
    .{ CmdID.CmdGetMainMissionCustomValueCsReq, CmdID.CmdGetMainMissionCustomValueScRsp },
    .{ CmdID.CmdGetMaterialSubmitActivityDataCsReq, CmdID.CmdGetMaterialSubmitActivityDataScRsp },
    .{ CmdID.CmdRogueTournGetCurRogueCocoonInfoCsReq, CmdID.CmdRogueTournGetCurRogueCocoonInfoScRsp },
    .{ CmdID.CmdMusicRhythmDataCsReq, CmdID.CmdMusicRhythmDataScRsp },
    //friendlist
    .{ CmdID.CmdGetFriendApplyListInfoCsReq, CmdID.CmdGetFriendApplyListInfoScRsp },
    .{ CmdID.CmdGetChatFriendHistoryCsReq, CmdID.CmdGetChatFriendHistoryScRsp },
    .{ CmdID.CmdGetFriendLoginInfoCsReq, CmdID.CmdGetFriendLoginInfoScRsp },
    .{ CmdID.CmdGetFriendDevelopmentInfoCsReq, CmdID.CmdGetFriendDevelopmentInfoScRsp },
    .{ CmdID.CmdGetFriendRecommendListInfoCsReq, CmdID.CmdGetFriendRecommendListInfoScRsp },
    //add
    .{ CmdID.CmdSwitchHandDataCsReq, CmdID.CmdSwitchHandDataScRsp },
    .{ CmdID.CmdGetMissionMessageInfoCsReq, CmdID.CmdGetMissionMessageInfoScRsp },
    .{ CmdID.CmdTrainPartyGetDataCsReq, CmdID.CmdTrainPartyGetDataScRsp },
    .{ CmdID.CmdQueryProductInfoCsReq, CmdID.CmdQueryProductInfoScRsp },
    .{ CmdID.CmdGetPamSkinDataCsReq, CmdID.CmdGetPamSkinDataScRsp },
    .{ CmdID.CmdGetQuestRecordCsReq, CmdID.CmdGetQuestRecordScRsp },
    .{ CmdID.CmdGetDailyActiveInfoCsReq, CmdID.CmdGetDailyActiveInfoScRsp },
    .{ CmdID.CmdGetFightActivityDataCsReq, CmdID.CmdGetFightActivityDataScRsp },
    .{ CmdID.CmdGetShareDataCsReq, CmdID.CmdGetShareDataScRsp },
    .{ CmdID.CmdGetTreasureDungeonActivityDataCsReq, CmdID.CmdGetTreasureDungeonActivityDataScRsp },
    .{ CmdID.CmdGetOfferingInfoCsReq, CmdID.CmdGetOfferingInfoScRsp },
    .{ CmdID.CmdClockParkGetInfoCsReq, CmdID.CmdClockParkGetInfoScRsp },
    .{ CmdID.CmdGetGunPlayDataCsReq, CmdID.CmdGetGunPlayDataScRsp },
    .{ CmdID.CmdDifficultyAdjustmentGetDataCsReq, CmdID.CmdDifficultyAdjustmentGetDataScRsp },
    .{ CmdID.CmdGetExpeditionDataCsReq, CmdID.CmdGetExpeditionDataScRsp },
    .{ CmdID.CmdRaidCollectionDataCsReq, CmdID.CmdRaidCollectionDataScRsp },
    .{ CmdID.CmdGetRaidInfoCsReq, CmdID.CmdGetRaidInfoScRsp },
    .{ CmdID.CmdGetLoginActivityCsReq, CmdID.CmdGetLoginActivityScRsp },
    .{ CmdID.CmdGetTrialActivityDataCsReq, CmdID.CmdGetTrialActivityDataScRsp },
    .{ CmdID.CmdGetJukeboxDataCsReq, CmdID.CmdGetJukeboxDataScRsp },
    .{ CmdID.CmdGetLoginChatInfoCsReq, CmdID.CmdGetLoginChatInfoScRsp },
    .{ CmdID.CmdGetMarkChestCsReq, CmdID.CmdGetMarkChestScRsp },
    .{ CmdID.CmdUpdateTrackMainMissionIdCsReq, CmdID.CmdUpdateTrackMainMissionIdScRsp },
    .{ CmdID.CmdGetNpcMessageGroupCsReq, CmdID.CmdGetNpcMessageGroupScRsp },
    .{ CmdID.CmdGetAllSaveRaidCsReq, CmdID.CmdGetAllSaveRaidScRsp },
    .{ CmdID.CmdGetAssistHistoryCsReq, CmdID.CmdGetAssistHistoryScRsp },
    .{ CmdID.CmdGetEraFlipperDataCsReq, CmdID.CmdGetEraFlipperDataScRsp },
    .{ CmdID.CmdGetRechargeGiftInfoCsReq, CmdID.CmdGetRechargeGiftInfoScRsp },
    .{ CmdID.CmdGetRechargeBenefitInfoCsReq, CmdID.CmdGetRechargeBenefitInfoScRsp },
    .{ CmdID.CmdRelicSmartWearGetPlanCsReq, CmdID.CmdRelicSmartWearGetPlanScRsp },
    .{ CmdID.CmdRelicSmartWearGetPinRelicCsReq, CmdID.CmdRelicSmartWearGetPinRelicScRsp },
    .{ CmdID.CmdSetGrowthTargetAvatarCsReq, CmdID.CmdSetGrowthTargetAvatarScRsp },
    .{ CmdID.CmdGetPreAvatarActivityListCsReq, CmdID.CmdGetPreAvatarActivityListScRsp },
    .{ CmdID.CmdGetUnreleasedBlockInfoCsReq, CmdID.CmdGetUnreleasedBlockInfoScRsp },
    .{ CmdID.CmdPBPIGABCJED, CmdID.CmdABJBJOCBPLH },
    .{ CmdID.CmdEKNCLPMCCNE, CmdID.CmdNJHPBNBHOLL },
    .{ CmdID.CmdOCPJHDOFIMC, CmdID.CmdKGIPBNHOJLG },
    .{ CmdID.CmdCJGIAPJKIDL, CmdID.CmdDAEDKDPBMIM },
    .{ CmdID.CmdHEDNPLNCICC, CmdID.CmdGJDJCDBBHOE },
    .{ CmdID.CmdAIEAADPOFKA, CmdID.CmdDAHLBDGMHCH },
    .{ CmdID.CmdOPHHNPGIKNK, CmdID.CmdHAIBDDPANJJ },
};

const SuppressLogList = [_]CmdID{
    CmdID.CmdSceneEntityMoveCsReq,
    // Spammy packets seen in logs.txt; suppress to avoid log/CPU overhead.
    CmdID.CmdSceneUpdatePositionVersionNotify,
    CmdID.CmdCEMEPHAFBEN,
    CmdID.CmdPKBPGMGMDAC,
};

fn isSuppressed(cmd_id_u32: u32) bool {
    for (SuppressLogList) |c| {
        if (@intFromEnum(c) == cmd_id_u32) return true;
    }
    return false;
}

fn fnv1a64(s: []const u8) u64 {
    var h: u64 = 14695981039346656037;
    for (s) |c| {
        h ^= c;
        h *%= 1099511628211;
    }
    return h;
}

fn hashU32(x: u32) u64 {
    // FNV-1a over the 4 bytes; stable and cheap.
    var h: u64 = 14695981039346656037;
    h ^= @as(u8, @truncate(x));
    h *%= 1099511628211;
    h ^= @as(u8, @truncate(x >> 8));
    h *%= 1099511628211;
    h ^= @as(u8, @truncate(x >> 16));
    h *%= 1099511628211;
    h ^= @as(u8, @truncate(x >> 24));
    h *%= 1099511628211;
    return h;
}

fn nextPow2(n: usize) usize {
    var p: usize = 1;
    while (p < n) p <<= 1;
    return p;
}

const HandlerEntry = struct {
    used: bool = false,
    cs: u32 = 0,
    func: Action = undefined,
};

const HandlerTable = blk: {
    @setEvalBranchQuota(500_000);
    const size = nextPow2(@max(HandlerList.len * 2, 64));
    const mask = size - 1;
    var table: [size]HandlerEntry = [_]HandlerEntry{.{}} ** size;

    for (HandlerList) |h| {
        const cs_u32: u32 = @intFromEnum(h[0]);
        var idx: usize = @intCast(hashU32(cs_u32) & mask);
        while (table[idx].used) : (idx = (idx + 1) & mask) {}
        table[idx] = .{ .used = true, .cs = cs_u32, .func = h[1] };
    }

    break :blk table;
};

fn findHandler(cmd_id_u32: u32) ?Action {
    const mask = HandlerTable.len - 1;
    var idx: usize = @intCast(hashU32(cmd_id_u32) & mask);
    var probes: usize = 0;
    while (probes < HandlerTable.len) : (probes += 1) {
        const e = HandlerTable[idx];
        if (!e.used) return null;
        if (e.cs == cmd_id_u32) return e.func;
        idx = (idx + 1) & mask;
    }
    return null;
}

const NameEntry = struct {
    used: bool = false,
    id: u32 = 0,
    name: []const u8 = "",
};

const CmdIdNameTable = blk: {
    @setEvalBranchQuota(2_000_000);
    const fields = @typeInfo(CmdID).@"enum".fields;
    const size = nextPow2(@max(fields.len * 2, 64));
    const mask = size - 1;
    var table: [size]NameEntry = [_]NameEntry{.{}} ** size;

    for (fields) |f| {
        const id_u32: u32 = @intCast(f.value);
        var idx: usize = @intCast(hashU32(id_u32) & mask);
        while (table[idx].used) : (idx = (idx + 1) & mask) {}
        table[idx] = .{ .used = true, .id = id_u32, .name = f.name };
    }

    break :blk table;
};

fn cmdNameFromId(cmd_id_u32: u32) ?[]const u8 {
    const mask = CmdIdNameTable.len - 1;
    var idx: usize = @intCast(hashU32(cmd_id_u32) & mask);
    var probes: usize = 0;
    while (probes < CmdIdNameTable.len) : (probes += 1) {
        const e = CmdIdNameTable[idx];
        if (!e.used) return null;
        if (e.id == cmd_id_u32) return e.name;
        idx = (idx + 1) & mask;
    }
    return null;
}

const ScBaseEntry = struct {
    used: bool = false,
    hash: u64 = 0,
    base: []const u8 = "",
    sc: CmdID = CmdID.CmdPlayerGetTokenCsReq, // placeholder (unused when used=false)
};

const AutoReplyEntry = struct {
    used: bool = false,
    cs: u32 = 0,
    sc: CmdID = CmdID.CmdPlayerGetTokenCsReq, // placeholder
};

const AutoReplyTable = blk: {
    @setEvalBranchQuota(2_000_000);
    const fields = @typeInfo(CmdID).@"enum".fields;

    // Build a base-name -> ScRsp CmdID hash table for fast comptime lookup.
    var sc_count: usize = 0;
    for (fields) |f| {
        if (std.mem.endsWith(u8, f.name, "ScRsp")) sc_count += 1;
    }
    const sc_table_size = nextPow2(@max(sc_count * 2, 64));
    var sc_table: [sc_table_size]ScBaseEntry = [_]ScBaseEntry{.{}} ** sc_table_size;
    const sc_mask = sc_table_size - 1;

    for (fields) |f| {
        if (!std.mem.endsWith(u8, f.name, "ScRsp")) continue;
        const base = f.name[0 .. f.name.len - "ScRsp".len];
        const h = fnv1a64(base);
        var idx: usize = @intCast(h & sc_mask);
        while (sc_table[idx].used) : (idx = (idx + 1) & sc_mask) {}
        sc_table[idx] = .{ .used = true, .hash = h, .base = base, .sc = @enumFromInt(f.value) };
    }

    const findScByBase = struct {
        fn f(sc_table_inner: []const ScBaseEntry, sc_mask_inner: usize, base: []const u8, h: u64) ?CmdID {
            var idx: usize = @intCast(h & sc_mask_inner);
            var probes: usize = 0;
            while (probes < sc_table_inner.len) : (probes += 1) {
                const e = sc_table_inner[idx];
                if (!e.used) return null;
                if (e.hash == h and std.mem.eql(u8, e.base, base)) return e.sc;
                idx = (idx + 1) & sc_mask_inner;
            }
            return null;
        }
    }.f;

    // Count CsReq that have a matching ScRsp.
    var pair_count: usize = 0;
    for (fields) |f| {
        if (!std.mem.endsWith(u8, f.name, "CsReq")) continue;
        const base = f.name[0 .. f.name.len - "CsReq".len];
        const h = fnv1a64(base);
        if (findScByBase(&sc_table, sc_mask, base, h) != null) pair_count += 1;
    }

    const table_size = nextPow2(@max(pair_count * 2, 64));
    var table: [table_size]AutoReplyEntry = [_]AutoReplyEntry{.{}} ** table_size;
    const mask = table_size - 1;

    for (fields) |f| {
        if (!std.mem.endsWith(u8, f.name, "CsReq")) continue;
        const base = f.name[0 .. f.name.len - "CsReq".len];
        const h = fnv1a64(base);
        const sc = findScByBase(&sc_table, sc_mask, base, h) orelse continue;

        const cs_u32: u32 = @intCast(f.value);
        const key_hash = hashU32(cs_u32);
        var idx: usize = @intCast(key_hash & mask);
        while (table[idx].used) : (idx = (idx + 1) & mask) {}
        table[idx] = .{ .used = true, .cs = cs_u32, .sc = sc };
    }

    break :blk table;
};

fn autoReplySc(cmd_id_u32: u32) ?CmdID {
    const mask = AutoReplyTable.len - 1;
    var idx: usize = @intCast(hashU32(cmd_id_u32) & mask);
    var probes: usize = 0;
    while (probes < AutoReplyTable.len) : (probes += 1) {
        const e = AutoReplyTable[idx];
        if (!e.used) return null;
        if (e.cs == cmd_id_u32) return e.sc;
        idx = (idx + 1) & mask;
    }
    return null;
}

pub fn handle(session: *Session, packet: *const Packet) !void {
    var arena = ArenaAllocator.init(session.allocator);
    defer arena.deinit();

    const cmd_id_u32: u32 = packet.cmd_id;

    if (findHandler(cmd_id_u32)) |handler_fn| {
        try handler_fn(session, packet, arena.allocator());
        if (!isSuppressed(cmd_id_u32)) {
            if (cmdNameFromId(cmd_id_u32)) |name| {
                log.debug("packet {s}({}) was handled", .{ name, cmd_id_u32 });
            } else {
                log.debug("packet id {} was handled", .{cmd_id_u32});
            }
        }
        return;
    }

    inline for (DummyCmdList) |pair| {
        if (@intFromEnum(pair[0]) == cmd_id_u32) {
            try session.send_empty(pair[1]);
            return;
        }
    }

    if (autoReplySc(cmd_id_u32)) |sc| {
        try session.send_empty(sc);
        if (!isSuppressed(cmd_id_u32)) {
            const sc_u32: u32 = @intFromEnum(sc);
            if (cmdNameFromId(cmd_id_u32)) |cs_name| {
                if (cmdNameFromId(sc_u32)) |sc_name| {
                    log.debug("auto-replied {s}({}) -> {s}({})", .{ cs_name, cmd_id_u32, sc_name, sc_u32 });
                } else {
                    log.debug("auto-replied {s}({}) -> id {}", .{ cs_name, cmd_id_u32, sc_u32 });
                }
            } else {
                log.debug("auto-replied empty rsp for id {}", .{cmd_id_u32});
            }
        }
        return;
    }

    if (cmdNameFromId(cmd_id_u32)) |name| {
        log.warn("packet {s}({}) was ignored", .{ name, cmd_id_u32 });
    } else {
        log.warn("packet id {} was ignored", .{cmd_id_u32});
    }
}
