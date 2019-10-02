#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf_econ_data>


#define TF_MAXPLAYERS 	32

#define TFGO_STARTING_MONEY				1000
#define TFGO_KILL_REWARD_PRIMARY		50
#define TFGO_KILL_REWARD_SECONDARY		150
#define TFGO_KILL_REWARD_MELEE			450
#define TFGO_MAX_MONEY 					16000
#define TFGO_CAPTURE_WIN_BONUS			2700
#define TFGO_ELIMINATION_WIN_BONUS		2300
#define TFGO_LOSS_BONUS 					2400

Handle g_hHudSync;
Handle g_hBuytimeTimer;
Handle g_h10SecondWarningTimer;
Handle g_hCurrencyPackDestroyTimer;

// Default weapon index for each class and slot (stolen from VSH-Rewrite)
int g_iDefaultWeaponIndex[][] =  {
	{ -1, -1, -1, -1, -1, -1 },  // Unknown
	{ 13, 23, 0, -1, -1, -1 },  // Scout
	{ 14, 16, 3, -1, -1, -1 },  // Sniper
	{ 18, 10, 6, -1, -1, -1 },  // Soldier
	{ 19, 20, 1, -1, -1, -1 },  // Demoman
	{ 17, 29, 8, -1, -1, -1 },  // Medic
	{ 15, 11, 5, -1, -1, -1 },  // Heavy
	{ 21, 12, 2, -1, -1, -1 },  // Pyro
	{ 24, 735, 4, 27, 30, -1 },  // Spy
	{ 9, 22, 7, 25, 26, 28 },  // Engineer
};

// Weapons purchased using the buy menu
int g_iPurchasedWeaponIndex[TF_MAXPLAYERS + 1][];
int g_iBalance[TF_MAXPLAYERS + 1];

bool g_bBuytimeActive;
bool g_bRoundStarted;
bool g_bRoundActive;

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

StringMap g_sCurrencypackPlayerMap;


#include "tfgo/sound.sp"
#include "tfgo/cash.sp"


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
	tfgo_buytime = CreateConVar("tfgo_buytime", "45", "How many seconds after spawning players can buy items for", _, true, 5.0);
	
	g_hHudSync = CreateHudSynchronizer();
	
	g_sCurrencypackPlayerMap = CreateTrie();
	LoadTranslations("common.phrases.txt");
	
	HookEvent("player_spawn", Event_Player_Spawn);
	HookEvent("player_death", Event_Player_Death);
	HookEvent("arena_win_panel", Event_Arena_Win_Panel);
	HookEvent("player_changeclass", Event_Player_ChangeClass);
	HookEvent("arena_round_start", Event_Arena_Round_Start);
	HookEvent("teamplay_round_start", Event_Teamplay_Round_Start);
	HookEvent("arena_match_maxstreak", Event_Arena_Match_MaxStreak);
	HookEvent("teamplay_broadcast_audio", Event_Broadcast_Audio, EventHookMode_Pre);
	HookEvent("post_inventory_application", Event_PlayerInventoryUpdate);
	
	AddCommandListener(Client_KillCommand, "kill");
	AddCommandListener(Client_KillCommand, "explode");
	
	tf_arena_max_streak = FindConVar("tf_arena_max_streak");
	tf_arena_first_blood = FindConVar("tf_arena_first_blood");
	tf_arena_round_time = FindConVar("tf_arena_round_time");
	tf_arena_use_queue = FindConVar("tf_arena_use_queue");
	tf_arena_preround_time = FindConVar("tf_arena_preround_time");
	
	Toggle_ConVars(true);
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
	for (int i = 0; i < sizeof(g_iBalance); i++)
	{
		g_iBalance[i] = 0;
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
	
	if (g_bRoundActive)
	{
		CreateDeathCash(client);
	}
	
	// TODO restore previous weapons IF this death was a suicide
	
	return Plugin_Continue;
}

public void OnClientConnected(int client)
{
	g_iBalance[client] = TFGO_STARTING_MONEY;
}

public Action Event_Arena_Win_Panel(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundStarted = false;
	
	if (g_h10SecondWarningTimer != null) 
	{
		KillTimer(g_h10SecondWarningTimer);
		g_h10SecondWarningTimer = null;
	}

	StopSoundForAll(SNDCHAN_AUTO, "valve_csgo_01/roundtenseccount.mp3");
	
	// TODO award round end money
	return Plugin_Continue;
}

public Action Event_Teamplay_Round_Start(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundStarted = true;
	g_bRoundActive = false;
	g_bBuytimeActive = true;
	g_hBuytimeTimer = CreateTimer(tfgo_buytime.FloatValue, DisableBuyMenu);
	PlayRoundStartMusic();
	
	for (int iClient = 1; iClient < MaxClients; iClient++)
	{
		if (IsClientInGame(iClient))
		{
			SetHudTextParams(-1.0, 0.75, tfgo_buytime.FloatValue, 0, 133, 67, 140);
			ShowSyncHudText(iClient, g_hHudSync, "$%d", g_iBalance[iClient]);
		}
	}
	
	PrintToChatAll("Buy time has started!");
}

public Action DisableBuyMenu(Handle timer) {
	PrintToChatAll("Buy time is over!");
	g_bBuytimeActive = false;
}

public Action Event_Arena_Round_Start(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundActive = true;
	g_h10SecondWarningTimer = CreateTimer(tf_arena_round_time.FloatValue - CSGO_ROUNDTENSECCOUNT_LENGTH, Play10SecondWarning);
	PlayRoundActionMusic();
}

public Action Event_Player_ChangeClass(Event event, const char[] name, bool dontBroadcast) {
	// during setup time, refund money if player had weapons and changed class
	int client = GetClientOfUserId(event.GetInt("userid"));
	return Plugin_Continue;
}

// called when a new client spawns or someone spawns after they died
void SetStartingWeapons(int client) {
	TF2_RemoveItemInSlot(client, 0); // remove primary
	
	// TODO: Set default secondary, except for Medic, Engineer and Spy
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (strcmp(classname, "func_respawnroom") == 0) {
		SDKHook(entity, SDKHook_StartTouch, Entity_StartTouch_RespawnRoom);
		SDKHook(entity, SDKHook_EndTouch, Entity_EndTouch_RespawnRoom);
	}
}

public Action Entity_StartTouch_RespawnRoom(int entity, int client)
{
	if (client <= MaxClients && IsClientConnected(client) && g_bBuytimeActive)
	{
		PrintToServer("%d entered spawn", client);
	}
}

public Action Entity_EndTouch_RespawnRoom(int entity, int client)
{
	if (client <= MaxClients && IsClientConnected(client) && g_bBuytimeActive)
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
		tf_arena_round_time.IntValue = 30;
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

stock void TF2_RemoveItemInSlot(int client, int slot)
{
	TF2_RemoveWeaponSlot(client, slot);
	
	int iWearable = SDK_GetEquippedWearable(client, slot);
	if (iWearable > MaxClients)
	{
		SDK_RemoveWearable(client, iWearable);
		AcceptEntityInput(iWearable, "Kill");
	}
}

stock int TF2_CreateAndEquipWeapon(int iClient, int iIndex)
{
	char sClassname[256];
	TF2Econ_GetItemClassName(iIndex, sClassname, sizeof(sClassname));
	TF2Econ_TranslateWeaponEntForClass(sClassname, sizeof(sClassname), TF2_GetPlayerClass(iClient));
	
	int iWeapon = CreateEntityByName(sClassname);
	if (IsValidEntity(iWeapon))
	{
		SetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex", iIndex);
		SetEntProp(iWeapon, Prop_Send, "m_bInitialized", 1);
		
		DispatchSpawn(iWeapon);
		SetEntProp(iWeapon, Prop_Send, "m_bValidatedAttachedEntity", true);
		
		if (StrContains(sClassname, "tf_wearable") == 0)
			SDK_EquipWearable(iClient, iWeapon);
		else
			EquipPlayerWeapon(iClient, iWeapon);
	}
	
	return iWeapon;
}

// Note: sent when a player gets a whole new set of items, aka touches a resupply locker / respawn cabinet or spawns in.
public Action Event_PlayerInventoryUpdate(Event event, const char[] sName, bool bDontBroadcast)
{
	// TODO
}

public Action Client_KillCommand(int iClient, const char[] sCommand, int iArgs)
{
	if (g_bRoundStarted)
	{
		PrintToChat(iClient, "-$100 for suiciding");
		// TODO: Money Penalty for suicide during round
	}
	
	return Plugin_Continue;
}
