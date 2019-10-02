#pragma semicolon 1
#pragma newdecls required

#include<sourcemod>
#include<sdktools>
#include<sdkhooks>
#include <tf2_stocks>
#include <tf_econ_data>

#include "tfgo/sound.sp"
#include "tfgo/cash.sp"

#define TF_MAXPLAYERS 	32

#define TFGO_STARTING_MONEY				1000
#define TFGO_KILL_REWARD_PRIMARY		50
#define TFGO_KILL_REWARD_SECONDARY		150
#define TFGO_KILL_REWARD_MELEE			450
#define TFGO_MAX_MONEY 					16000
#define TFGO_CAPTURE_WIN_BONUS			2700
#define TFGO_ELIMINATION_WIN_BONUS		2300
#define TFGO_LOSS_BONUS 					2400



static bool g_buytimeActive;
static Handle g_buytimeTimer;

ConVar tfgo_buytime;

ConVar tf_arena_max_streak;
ConVar tf_arena_first_blood;
ConVar tf_arena_round_time;
ConVar tf_arena_use_queue;
ConVar tf_arena_preround_time;

// SDK functions
Handle g_hSDKEquipWearable = null;
Handle g_hSDKRemoveWearable = null;
Handle g_hSDKGetEquippedWearable = null;

public Plugin myinfo =  {
	name = "Team Fortress: Global Offensive", 
	author = "Mikusch", 
	description = "A Team Fortress 2 gamemode inspired by Counter-Strike: Global Offensive", 
	version = "1.0", 
	url = "https://github.com/Mikusch/tfgo"
};

public void OnPluginStart()
{
	SDKInit();
	tfgo_buytime = CreateConVar("tfgo_buytime", "30", "How many seconds after spawning players can buy items for", _, true, 5.0);
	
	g_hudSync = CreateHudSynchronizer();
	
	g_currencypackPlayerMap = CreateTrie();
	LoadTranslations("common.phrases.txt");
	
	HookEvent("player_spawn", Event_Player_Spawn);
	HookEvent("player_death", Event_Player_Death);
	HookEvent("arena_win_panel", Event_Teamplay_Round_Win);
	HookEvent("player_changeclass", Event_Player_ChangeClass);
	HookEvent("arena_round_start", Event_Arena_Round_Start);
	HookEvent("teamplay_round_start", Event_Teamplay_Round_Start);
	HookEvent("arena_match_maxstreak", Event_Arena_Match_MaxStreak);
	HookEvent("teamplay_broadcast_audio", Event_Broadcast_Audio, EventHookMode_Pre);
	
	tf_arena_max_streak = FindConVar("tf_arena_max_streak");
	tf_arena_first_blood = FindConVar("tf_arena_first_blood");
	tf_arena_round_time = FindConVar("tf_arena_round_time");
	tf_arena_use_queue = FindConVar("tf_arena_use_queue");
	tf_arena_preround_time = FindConVar("tf_arena_preround_time");
	
	Toggle_ConVars(true);
}

public Action Event_Broadcast_Audio(Event event, const char[] name, bool dontBroadcast)
{
	char strAudio[PLATFORM_MAX_PATH];
	event.GetString("sound", strAudio, sizeof(strAudio));
	int iTeam = event.GetInt("team");
	
	if (strcmp(strAudio, "Game.YourTeamWon") == 0)
	{
		EmitSoundToTeam(iTeam, "valve_csgo_01/wonround.mp3");
		return Plugin_Handled;
	}
	else if (strcmp(strAudio, "Game.YourTeamLost") == 0 || strcmp(strAudio, "Game.Stalemate") == 0)
	{
		EmitSoundToTeam(iTeam, "valve_csgo_01/lostround.mp3");
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public void OnPluginEnd()
{
	Toggle_ConVars(false);
}

public void OnMapStart()
{
	PrecacheSounds();
	PrecacheModels();
}

void PrecacheModels()
{
	PrecacheModel("models/items/currencypack_large.mdl");
	PrecacheModel("models/items/currencypack_medium.mdl");
	PrecacheModel("models/items/currencypack_small.mdl");
}

public Action Event_Arena_Match_MaxStreak(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 0; i < sizeof(g_balance); i++)
	{
		g_balance[i] = 0;
	}
}

public Action Event_Player_Spawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	SetStartingWeapons(client);
	
	int weapon = GetPlayerWeaponSlot(client, 2);
	EquipPlayerWeapon(client, weapon);
	
	return Plugin_Continue;
}

public Action Event_Player_Death(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (g_dropCurrencyPacks)
	{
		CreateDeathCash(client);
	}
	
	// TODO restore previous weapons IF this death was a suicide
	
	return Plugin_Continue;
}

public void OnClientConnected(int client)
{
	g_balance[client] = TFGO_STARTING_MONEY;
}

public Action Event_Teamplay_Round_Win(Event event, const char[] name, bool dontBroadcast)
{
	// TODO award round end money
	return Plugin_Continue;
}

public Action Event_Teamplay_Round_Start(Event event, const char[] name, bool dontBroadcast)
{
	g_dropCurrencyPacks = false;
	
	for (int i = 1; i < MaxClients; i++)
	{
		SetHudTextParams(-1.0, 0.75, tfgo_buytime.FloatValue, 0, 133, 67, 140, _, _, _, _);
		ShowSyncHudText(i, g_hudSync, "$%d", g_balance[i]);
	}
	
	g_buytimeTimer = CreateTimer(tfgo_buytime.FloatValue, DisableBuyMenu);
	PrintToChatAll("Buy time has started!");
	g_buytimeActive = true;
}

public Action Event_Arena_Round_Start(Event event, const char[] name, bool dontBroadcast)
{
	g_dropCurrencyPacks = true;
	return Plugin_Continue;
}

public Action DisableBuyMenu(Handle timer) {
	PrintToChatAll("Buy time is over!");
	g_buytimeActive = false;
}

public Action Event_Player_ChangeClass(Event event, const char[] name, bool dontBroadcast) {
	// during setup time, refund money if player had weapons and changed class
	int client = GetClientOfUserId(event.GetInt("userid"));
	return Plugin_Continue;
}

// called when a new client spawns or someone spawns after they died
void SetStartingWeapons(int client) {
	TF2_RemoveWeaponSlot(client, 0); // Primary
	//TF2_RemoveWeaponSlot(client, 1); // Secondary
	
	// special cases
	switch (TF2_GetPlayerClass(client))
	{
		case TFClass_Scout:
		{
			//GivePlayerItem(client, const char[] item, int iSubType)
			char buf[32];
			TF2Econ_GetItemClassName(13, buf, sizeof(buf));
			PrintToChatAll(buf);
		}
		case TFClass_Spy:
		{
			TF2_RemoveWeaponSlot(client, 4); // Invis Watch
		}
		case TFClass_Engineer:
		{
			TF2_RemoveWeaponSlot(client, 3); // Construction PDA
		}
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "func_respawnroom")) {
		SDKHook(entity, SDKHook_StartTouch, Player_EnteredSpawn);
		SDKHook(entity, SDKHook_EndTouch, Player_ExitedSpawn);
	}
}

public Action Player_EnteredSpawn(int entity, int client)
{
	if (client <= MaxClients && IsClientConnected(client))
	{
		PrintToServer("%d entered spawn", client);
	}
}

public Action Player_ExitedSpawn(int entity, int client)
{
	if (IsClientConnected(client))
	{
		PrintToServer("%d left spawn", client);
	}
}

void Toggle_ConVars(bool toggle)
{
	static bool bArenaFirstBlood;
	static bool bArenaUseQueue;
	static int iArenaMaxStreak;
	static int iArenaRoundTime;
	
	if (toggle)
	{
		bArenaFirstBlood = tf_arena_first_blood.BoolValue;
		tf_arena_first_blood.BoolValue = false;
		
		bArenaUseQueue = tf_arena_use_queue.BoolValue;
		tf_arena_use_queue.BoolValue = false;
		
		iArenaMaxStreak = tf_arena_max_streak.IntValue;
		tf_arena_max_streak.IntValue = 8;
		
		iArenaRoundTime = tf_arena_round_time.IntValue;
		tf_arena_round_time.IntValue = 135;
	}
	else
	{
		tf_arena_first_blood.BoolValue = bArenaFirstBlood;
		tf_arena_use_queue.BoolValue = bArenaUseQueue;
		tf_arena_max_streak.IntValue = iArenaMaxStreak;
		tf_arena_round_time.IntValue = iArenaRoundTime;
	}
}

stock void SDK_EquipWearable(int client, int iWearable)
{
	if (g_hSDKEquipWearable != null)
		SDKCall(g_hSDKEquipWearable, client, iWearable);
}
stock void SDK_RemoveWearable(int client, int iWearable)
{
	if (g_hSDKRemoveWearable != null)
		SDKCall(g_hSDKRemoveWearable, client, iWearable);
}
stock int SDK_GetEquippedWearable(int client, int iSlot)
{
	if (g_hSDKGetEquippedWearable != null)
		return SDKCall(g_hSDKGetEquippedWearable, client, iSlot);
	
	return -1;
}

void SDKInit()
{
	Handle hGameData = LoadGameConfigFile("tfgo");
	
	// This function is used to equip wearables 
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CBasePlayer::EquipWearable");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKEquipWearable = EndPrepSDKCall();
	if (g_hSDKEquipWearable == null)
		LogMessage("Failed to create call: CBasePlayer::EquipWearable!");
	
	// This function is used to remove a player wearable properly
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CBasePlayer::RemoveWearable");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKRemoveWearable = EndPrepSDKCall();
	if (g_hSDKRemoveWearable == null)
		LogMessage("Failed to create call: CBasePlayer::RemoveWearable!");
	
	// This function is used to get wearable equipped in loadout slots
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTFPlayer::GetEquippedWearableForLoadoutSlot");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKGetEquippedWearable = EndPrepSDKCall();
	if (g_hSDKGetEquippedWearable == null)
		LogMessage("Failed to create call: CTFPlayer::GetEquippedWearableForLoadoutSlot!");
}

stock int TF2_CreateAndEquipWeapon(int iClient, int iIndex, char[] sAttribs = "", char[] sText = "")
{
	char sClassname[256];
	TF2Econ_GetItemClassName(iIndex, sClassname, sizeof(sClassname));
	TF2Econ_TranslateWeaponEntForClass(sClassname, sizeof(sClassname), TF2_GetPlayerClass(iClient));
	
	int iWeapon = CreateEntityByName(sClassname);
	if (IsValidEntity(iWeapon))
	{
		SetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex", iIndex);
		SetEntProp(iWeapon, Prop_Send, "m_bInitialized", 1);
		
		// Allow quality / level override by updating through the offset.
		char netClass[64];
		GetEntityNetClass(iWeapon, netClass, sizeof(netClass));
		SetEntData(iWeapon, FindSendPropInfo(netClass, "m_iEntityQuality"), 6);
		SetEntData(iWeapon, FindSendPropInfo(netClass, "m_iEntityLevel"), 1);
		
		SetEntProp(iWeapon, Prop_Send, "m_iEntityQuality", 6);
		SetEntProp(iWeapon, Prop_Send, "m_iEntityLevel", 1);
		
		// Attribute shittery inbound
		if (!StrEqual(sAttribs, ""))
		{
			char atts[32][32];
			int iCount = ExplodeString(sAttribs, " ; ", atts, 32, 32);
			if (iCount > 1)
				for (int i = 0; i < iCount; i += 2)
			TF2Attrib_SetByDefIndex(iWeapon, StringToInt(atts[i]), StringToFloat(atts[i + 1]));
		}
		
		DispatchSpawn(iWeapon);
		SetEntProp(iWeapon, Prop_Send, "m_bValidatedAttachedEntity", true);
		
		if (StrContains(sClassname, "tf_wearable") == 0)
			SDK_EquipWearable(iClient, iWeapon);
		else
			EquipPlayerWeapon(iClient, iWeapon);
	}
	
	return iWeapon;
} 