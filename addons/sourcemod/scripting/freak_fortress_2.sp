
#include <morecolors>
#include <tf2_stocks>

#undef REQUIRE_PLUGIN
#include <vsh2>
#define REQUIRE_PLUGIN
#include <sdkhooks>

#define MAX_SUBPLUGIN_NAME		64
#define MAX_ABILITIES_PL		30
#define PLYR					35

#include <cfgmap>
#include "modules/stocks.inc"

#pragma semicolon        1
#pragma newdecls         required

public Plugin myinfo = {
	name           = "VSH2/FF2 Compatibility Engine",
	author         = "Nergal/Assyrianic, BatFoxKid and 01Pollux",
	description    = "Implements FF2's forwards & natives using VSH2's API",
	version        = "1.0b",
	url            = "https://github.com/VSH2-Devs/Vs-Saxton-Hale-2"
};

enum {
	FF2OnMusic,
	FF2OnSpecial,
	FF2OnLoseLife,
	FF2OnBackstab,
	FF2OnPreAbility,
	FF2OnAbility,
	FF2OnQueuePoints,
	FF2OnBossJarated,
	MaxFF2Forwards
};

enum struct FF2ConVars {
	ConVar m_enabled;
	ConVar m_version;
	ConVar m_fljarate;
	ConVar m_flairblast;
	ConVar m_flmusicvol;
	ConVar m_companion_min;
	ConVar m_nextmap;
	ConVar m_pack_name;
	ConVar m_pack_limit;
	ConVar m_pack_scramble;
}

enum {
	HUD_Jump,
	HUD_Weighdown,
	HUD_Lives,
	HUD_TYPES
};

enum struct FF2CompatPlugin {
	FF2ConVars	m_cvars;
	ConfigMap	m_charcfg;
	GlobalForward	m_forwards[MaxFF2Forwards];
	Handle		m_hud[HUD_TYPES];
	bool		m_vsh2;
	bool		m_cheats;
	int		m_queuePoints[PLYR];
	bool		m_queueChecking;
}

FF2CompatPlugin ff2;
VSH2GameMode    vsh2_gm;

#include "modules/ff2/utils.sp"
#include "modules/ff2/forwards.sp"
#include "modules/ff2/handles.sp"
#include "modules/ff2/formula_parser.sp"
#include "modules/ff2/vsh2_bridge.sp"
#include "modules/ff2/natives.sp"
#include "modules/ff2/console.sp"


static void LoadFF2()
{
	ff2.m_charcfg = new ConfigMap("data/freak_fortress_2/characters.cfg");

	ff2.m_hud[HUD_Jump] = vsh2_gm.hHUD;
	ff2.m_hud[HUD_Weighdown] = CreateHudSynchronizer();
		
	InitVSH2Bridge();
	
	for( int i=MaxClients; i > 0; i-- )
		if( IsClientInGame(i) )
			OnClientPutInServer(i);
		
	LoadFF2Plugins();
}

static void UnloadFF2()
{
	UnloadFF2Plugins();
		
	RemoveVSH2Bridge();
	DeleteCfg(ff2.m_charcfg);
}


public void OnPluginEnd()
{
	if( ff2.m_vsh2 ) {
		ff2.m_vsh2 = false;
		UnloadFF2();
	}
}

public void OnLibraryAdded(const char[] name) {
	if( StrEqual(name, "VSH2") && !ff2.m_vsh2) {
		
		InitConVars();
		ff2.m_vsh2 = true;
		LoadFF2();
	}
}

public void OnMapEnd()
{
	if( ff2.m_vsh2 ) {
		ff2_cfgmgr.DeleteAll();
		delete ff2_cfgmgr;
		
		char pack[48];
		ff2.m_cvars.m_pack_name.GetString(pack, sizeof(pack));
		
		ff2_cfgmgr = new FF2BossManager(pack);
	}
}

public void OnLibraryRemoved(const char[] name) {
	if( StrEqual(name, "VSH2") && ff2.m_vsh2) {
		
		ff2.m_vsh2 = false;
		UnloadFF2();
	}
}


public void NextFrame_InitFF2Player(int client)
{
	FF2Player player = FF2Player(client);
	
	player.iMaxLives = 0;
	player.bNoSuperJump = false;
	player.bNoWeighdown = false;
	player.bHideHUD = false;
}

public void OnClientPutInServer(int client)
{
	if ( !ff2.m_vsh2 ) return;
	
	RequestFrame(NextFrame_InitFF2Player, client);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	InitNatives();
	
	ff2.m_forwards[FF2OnMusic]		= new GlobalForward("FF2_OnMusic", ET_Hook, Param_Cell, Param_String, Param_FloatByRef);
	ff2.m_forwards[FF2OnSpecial]		= new GlobalForward("FF2_OnBossSelected", ET_Hook, Param_Cell, Param_String, Param_Cell);
	ff2.m_forwards[FF2OnLoseLife]		= new GlobalForward("FF2_OnLoseLife", ET_Hook, Param_Cell, Param_CellByRef, Param_Cell);
	ff2.m_forwards[FF2OnBackstab]		= new GlobalForward("FF2_OnBackStabbed", ET_Hook, Param_Cell, Param_Cell);
	ff2.m_forwards[FF2OnPreAbility]		= new GlobalForward("FF2_PreAbility", ET_Hook, Param_Cell, Param_String, Param_String, Param_Cell, Param_CellByRef);
	ff2.m_forwards[FF2OnAbility]		= new GlobalForward("FF2_OnAbility", ET_Hook, Param_Cell, Param_String, Param_String, Param_Cell);
	ff2.m_forwards[FF2OnQueuePoints]	= new GlobalForward("FF2_OnAddQueuePoints", ET_Hook, Param_Array);
	ff2.m_forwards[FF2OnBossJarated]	= new GlobalForward("FF2_OnBossJarated", ET_Hook, Param_Cell, Param_Cell, Param_FloatByRef);
	
	RegPluginLibrary("freak_fortress_2");
	
	return APLRes_Success;
}


#if defined _smac_included
public Action SMAC_OnCheatDetected(int client, const char[] module, DetectionType type, Handle info)
{
	if( type == Detection_CvarViolation ) {
		FF2Player player = FF2Player(client);
		if( player.GetPropInt("bNotifySMAC_CVars") ) {
			return Plugin_Stop;
		}
	}
	return Plugin_Continue;
}
#endif
