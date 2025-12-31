package main

var RedirectDomains = []string{
	".hoyoverse.com",
	".mihoyo.com",
	".yuanshen.com",
	".bhsr.com",
	".starrails.com",
	".juequling.com",
	".zenlesszonezero.com",
	".bh3.com",
	".honkaiimpact3.com",
	".mob.com",
	".hyg.com",
}

var AlwaysIgnoreDomains = []string{
	"autopatchcn.yuanshen.com",
	"autopatchhk.yuanshen.com",
	"autopatchcn.juequling.com",
	"autopatchos.zenlesszonezero.com",
	"autopatchcn.bhsr.com",
	"autopatchos.starrails.com",
}

var BlockUrls = []string{
	"/data_abtest_api/config/experiment/list",
	"/common/hkrpg_global/announcement/api/getAlertPic",
	"/common/hkrpg_global/announcement/api/getAlertAnn",
	"/hkrpg_global/combo/red_dot/list",
	"/sdk/upload",
	"/sdk/dataUpload",
	"/common/h5log/log/batch",
	"/crash/dataUpload",
	"/crashdump/dataUpload",
	"/client/event/dataUpload",
	"/log",
	"/asm/dataUpload",
	"/sophon/dataUpload",
	"/apm/dataUpload",
	"/2g/dataUpload",
	"/v1/firelog/legacy/log",
	"/h5/upload",
	"/_ts",
	"/perf/config/verify",
	"/ptolemaios_api/api/reportStrategyData",
	"/combo/box/api/config/sdk/combo",
	"/hkrpg_global/combo/granter/api/compareProtocolVersion",
	"/admin/mi18n",
	"/combo/box/api/config/sw/precache",
	"/hkrpg_global/mdk/agreement/api/getAgreementInfos",
	"/device-fp/api/getExtList",
	"/admin/mi18n/plat_os/m09291531181441/m09291531181441-version.json",
	"/admin/mi18n/plat_oversea/m2020030410/m2020030410-version.json",
}

var ForceRedirectOnUrlContains = []string{
	"/query_dispatch",
	"/query_gateway",
	"/query_region_list",
	"/query_cur_region",
}
