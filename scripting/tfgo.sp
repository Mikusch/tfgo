#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf_econ_data>

// TF2 stuff

#define TF_MAXPLAYERS 32
#define TF_TEAMS 3
#define TF_WINREASON_CAPTURE  	1
#define TF_WINREASON_ELIMINATION  2
#define TF_CLASSES  9

#define	 TFTeam_Unassigned 	0
#define	 TFTeam_Spectator 	1
#define  TFTeam_Red 		2
#define  TFTeam_Blue 		3

// Money stuff

#define TFGO_MINLOSESTREAK 0
#define TFGO_MAXLOSESTREAK 4

#define TFGO_STARTING_BALANCE			1000
#define TFGO_MAX_BALANCE 				16000
#define TFGO_CAPTURE_WIN_REWARD			3500
#define TFGO_ELIMINATION_WIN_REWARD		3250

int g_iLoseStreak[TF_TEAMS + 1] =  { 1, ... };
int g_iLoseStreakCompensation[TFGO_MAXLOSESTREAK + 1] =  { 1400, 1900, 2400, 2900, 3400 };
int g_iBalance[TF_MAXPLAYERS + 1] =  { TFGO_STARTING_BALANCE, ... };

//

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

bool g_bWaitingForPlayers;
bool g_bBuytimeActive;
bool g_bRoundStarted;
bool g_bRoundActive;

StringMap g_sCurrencypackPlayerMap;

// ConVars

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


#include "tfgo/sound.sp"
#include "tfgo/cash.sp"
#include "tfgo/loadout.sp"

// Weapons purchased using the buy menu
int g_iPlayerLoadout[TF_MAXPLAYERS + 1][10][6];

methodmap TFGOPlayer __nullable__
{
	public TFGOPlayer(int iClient)
	{
		return view_as<TFGOPlayer>(iClient);
	}
	
	property int iClient
	{
		public get()
		{
			return view_as<int>(this);
		}
	}
	
	property int iBalance
	{
		public get()
		{
			return g_iBalance[this];
		}
		public set(int val)
		{
			g_iBalance[this] = val;
		}
	}
	
	public int GetEffectiveWeapon(TFClassType eClass, int iSlot)
	{
		int iWeapon = g_iPlayerLoadout[this][eClass][iSlot];
		if (iWeapon == -1)
		{
			return g_iDefaultWeaponIndex[eClass][iSlot];
		}
		else
		{
			return iWeapon;
		}
	}
}

methodmap TFGOTeam __nullable__
{
	public TFGOTeam(int iTeam)
	{
		return view_as<TFGOTeam>(iTeam);
	}
	
	property int LoseStreak
	{
		public get()
		{
			return g_iLoseStreak[this];
		}
		
		public set(int val)
		{
			if (val > TFGO_MAXLOSESTREAK)
			{
				g_iLoseStreak[this] = TFGO_MAXLOSESTREAK;
			}
			else if (val < TFGO_MINLOSESTREAK)
			{
				g_iLoseStreak[this] = TFGO_MINLOSESTREAK;
			}
			else
			{
				g_iLoseStreak[this] = val;
			}
		}
	}
	
	public void AddToTeamBalance(int money)
	{
		for (int iClient = 0; iClient <= MaxClients; iClient++)
		{
			g_iBalance[iClient] += money;
		}
	}
}


public Plugin myinfo =  {
	name = "Team Fortress: Global Offensive", 
	author = "Mikusch", 
	description = "A Team Fortress 2 gamemode inspired by Counter-Strike: Global Offensive", 
	version = "1.0", 
	url = "https://github.com/Mikusch/tfgo"
};

public void OnPluginStart()
{
	// TODO: Choose a music kit for the entire game, only change on arena scramble
	
	SDKInit();
	tfgo_buytime = CreateConVar("tfgo_buytime", "30", "How many seconds after spawning players can buy items for", _, true, 5.0);
	
	g_hHudSync = CreateHudSynchronizer();
	
	g_sCurrencypackPlayerMap = CreateTrie();
	LoadTranslations("common.phrases.txt");
	
	HookEvent("player_death", Event_Player_Death);
	HookEvent("arena_win_panel", Event_Arena_Win_Panel);
	HookEvent("player_changeclass", Event_Player_ChangeClass);
	HookEvent("arena_round_start", Event_Arena_Round_Start);
	HookEvent("teamplay_round_start", Event_Teamplay_Round_Start);
	HookEvent("arena_match_maxstreak", Event_Arena_Match_MaxStreak);
	HookEvent("teamplay_broadcast_audio", Event_Broadcast_Audio, EventHookMode_Pre);
	HookEvent("post_inventory_application", Event_PlayerInventoryUpdate);
	HookEvent("teamplay_waiting_begins", Event_Teamplay_Waiting_Begins);
	HookEvent("teamplay_waiting_ends", Event_Teamplay_Waiting_Ends);
	
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
	int g_iBalance[TF_MAXPLAYERS + 1] =  { TFGO_STARTING_BALANCE, ... };
	int g_iLoseStreak[TF_TEAMS + 1] =  { 1, ... };
}

public Action Event_Player_Death(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (g_bRoundActive)
	{
		CreateDeathCash(client);
		
		if (event.GetInt("customkill") == TF_CUSTOM_SUICIDE)
		{
			PrintToChat(client, "-$100 for suiciding");
		}
	}
	
	// TODO restore previous weapons IF this death was a suicide in the respawn room
	
	return Plugin_Continue;
}

public void OnClientConnected(int client)
{
	TFGOPlayer tfgoPlayer = new TFGOPlayer(client);
	tfgoPlayer.iBalance = TFGO_STARTING_BALANCE;
	
	// Give the player some music from the music kit while they wait
	if (g_bWaitingForPlayers)
	{
		EmitSoundToClient(client, "valve_csgo_01/chooseteam.mp3");
	}
}

public Action Event_Arena_Win_Panel(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundStarted = false;
	
	int iWinReason = event.GetInt("winreason");
	switch (iWinReason)
	{
		case TF_WINREASON_CAPTURE:
		{
			PrintToChatAll("bonus for capping");
		}
		
		case TF_WINREASON_ELIMINATION:
		{
			PrintToChatAll("no bonus for killing everyone");
		}
	}
	
	int iWinningTeam = event.GetInt("winning_team");
	TFGOTeam winning_team = new TFGOTeam(iWinningTeam);
	TFGOTeam losing_team;
	if (iWinningTeam == TFTeam_Red)
	{
		losing_team = new TFGOTeam(iWinningTeam + 1);
	}
	else if (iWinningTeam == TFTeam_Blue)
	{
		losing_team = new TFGOTeam(iWinningTeam - 1);
	}
	
	losing_team.LoseStreak++;
	winning_team.LoseStreak--;
	PrintToChatAll("wining team losestreak %d", winning_team.LoseStreak);
	PrintToChatAll("losing team losestreak %d", losing_team.LoseStreak);
	
	if (g_h10SecondWarningTimer != null)
	{
		KillTimer(g_h10SecondWarningTimer);
		g_h10SecondWarningTimer = null;
	}
	else if (g_hBuytimeTimer != null)
	{
		KillTimer(g_hBuytimeTimer);
		g_hBuytimeTimer = null;
	}
	
	StopRoundActionMusic();
	StopSoundForAll(SNDCHAN_AUTO, "valve_csgo_01/roundtenseccount.mp3");
	
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
	g_hBuytimeTimer = null;
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
	int client = GetClientOfUserId(event.GetInt("userid"));
	SetStartingWeapons(client, TF2_GetPlayerClass(client));
}

// called when a new client spawns or someone spawns after they died
void SetStartingWeapons(int iClient, int iClass)
{
	TFGOPlayer tfgoPlayer = new TFGOPlayer(iClient);
	
	for (int i = 0; i++; i < 2)
	{
		TF2_RemoveItemInSlot(iClient, i);
		TF2_CreateAndEquipWeapon(iClient, tfgoPlayer.GetEffectiveWeapon(iClass, i));
	}
	
	
	// TODO: Set default secondary, except for Medic, Engineer and Spy
}

public Action Event_Teamplay_Waiting_Begins(Event event, const char[] sName, bool bDontBroadcast)
{
	g_bWaitingForPlayers = true;
}

public Action Event_Teamplay_Waiting_Ends(Event event, const char[] sName, bool bDontBroadcast)
{
	g_bWaitingForPlayers = false;
	StopSoundForAll(SNDCHAN_AUTO, "valve_csgo_01/chooseteam.mp3");
}
