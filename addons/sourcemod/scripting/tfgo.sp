#pragma semicolon 1

#include <morecolors>

#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf_econ_data>
#include <dhooks>

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

// TFGO stuff

#define TFGO_MINLOSESTREAK 0
#define TFGO_MAXLOSESTREAK 4

#define TFGO_STARTING_BALANCE			800
#define TFGO_MAX_BALANCE 				16000
#define TFGO_CAPTURE_WIN_REWARD			3500
#define TFGO_ELIMINATION_WIN_REWARD		3250

int g_iLoseStreak[TF_TEAMS + 1] =  { 1, ... };
int g_iLoseStreakCompensation[TFGO_MAXLOSESTREAK + 1] =  { 1400, 1900, 2400, 2900, 3400 };
int g_iBalance[TF_MAXPLAYERS + 1] =  { TFGO_STARTING_BALANCE, ... };

//

Handle g_hHudSync;
Handle g_hBuytimeTimer;
Handle g_h10SecondRoundTimer;
Handle g_h10SecondBombTimer;
Handle g_hBombExplosionTimer;
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

// Game state
bool g_bWaitingForPlayers;
bool g_bBuytimeActive;
bool g_bRoundStarted;
bool g_bRoundActive;
bool g_bBombPlanted;
int g_iBombSiteCP;
int g_iBombPlanterTeam;

// ConVars
ConVar tfgo_buytime;

ConVar tf_arena_max_streak;
ConVar tf_arena_first_blood;
ConVar tf_arena_round_time;
ConVar tf_arena_use_queue;
ConVar tf_arena_preround_time;

// SDK functions
Handle g_hSDKEquipWearable;
Handle g_hSDKRemoveWearable;
Handle g_hSDKGetEquippedWearable;
Handle g_hSetWinningTeam;

// Weapons purchased using the buy menu
int g_iPlayerLoadout[TF_MAXPLAYERS + 1][10][6];

methodmap TFGOPlayer
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
	
	public void AddToBalance(int value, char[] reason)
	{
		g_iBalance[this] += value;
		CPrintToChat(view_as<int>(this), "{money}+$%d{default}: %s.", value, reason);
	}
	
	public void RemoveFromBalance(int value, char[] reason)
	{
		g_iBalance[this] -= value;
		CPrintToChat(view_as<int>(this), "{alert}-$%d{default}: %s.", value, reason);
	}
}

methodmap TFGOTeam
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
	
	public void AddToTeamBalance(int money, const char[] reason)
	{
		for (int iClient = 1; iClient <= MaxClients; iClient++)
		{
			if (IsClientConnected(iClient) && view_as<int>(this) == GetClientTeam(iClient))
			{
				g_iBalance[iClient] += money;
				CPrintToChat(iClient, "{money}+$%d{default}: %s.", money, reason);
			}
		}
	}
}


#include "tfgo/sound.sp"
#include "tfgo/cash.sp"
#include "tfgo/buymenu.sp"


public Plugin myinfo =  {
	name = "Team Fortress:Global Offensive", 
	author = "Mikusch", 
	description = "A Team Fortress2gamemode inspired by Counter-Strike: Global Offensive", 
	version = "1.0", 
	url = "https: //github.com/Mikusch/tfgo"
};

public void OnPluginStart()
{
	// TODO: Choose a music kit for the entire game, only change on arena scramble
	LoadTranslations("common.phrases.txt");
	
	SDKInit();
	
	g_hHudSync = CreateHudSynchronizer();
	
	g_sCurrencypackPlayerMap = CreateTrie();
	g_sCurrencypackValueMap = CreateTrie();
	g_iCashToKillerMap = CreateTrie();
	
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
	HookEvent("teamplay_point_captured", Event_Teamplay_Point_Captured);
	
	tf_arena_max_streak = FindConVar("tf_arena_max_streak");
	tf_arena_first_blood = FindConVar("tf_arena_first_blood");
	tf_arena_round_time = FindConVar("tf_arena_round_time");
	tf_arena_use_queue = FindConVar("tf_arena_use_queue");
	tf_arena_preround_time = FindConVar("tf_arena_preround_time");
	tfgo_buytime = CreateConVar("tfgo_buytime", "45", "How many seconds after spawning players can buy items for", _, true, tf_arena_preround_time.FloatValue);
	
	Config_Init();
	Config_Refresh();
	
	CAddColor("alert", 0xEA4141);
	CAddColor("money", 0xA2FE47);
	
	Toggle_ConVars(true);
}

public void OnPluginEnd()
{
	Toggle_ConVars(false);
}

public void OnMapStart()
{
	DHookGamerules(g_hSetWinningTeam, false);
	PrecacheSounds();
	PrecacheModels();
}

void PrecacheModels()
{
	PrecacheModel("models/items/currencypack_large.mdl");
	PrecacheModel("models/items/currencypack_medium.mdl");
	PrecacheModel("models/items/currencypack_small.mdl");
	PrecacheModel("models/props_td/atom_bomb.mdl");
}

// Prevent round from ending
// Called every frame after the round is supposed to  end
public MRESReturn Hook_SetWinningTeam(Handle hParams)
{
	if (g_bBombPlanted)
	{
		return MRES_Supercede;
	}
	else
	{
		return MRES_Ignored;
	}
}

public Action Event_Arena_Match_MaxStreak(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 0; i < sizeof(g_iBalance); i++)g_iBalance[i] = TFGO_STARTING_BALANCE;
	for (int i = 0; i < sizeof(g_iLoseStreak); i++)g_iLoseStreak[i] = TFGO_STARTING_BALANCE;
}

public Action Event_Player_Death(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int customKill = event.GetInt("customkill");
	if (g_bRoundActive)
	{
		if (customKill == TF_CUSTOM_SUICIDE && attacker == victim)
		{
			TFGOPlayer(victim).RemoveFromBalance(300, "Penalty for suiciding");
		}
		else if (customKill == TF_CUSTOM_HEADSHOT)
		{
			SpawnCash(attacker, victim, 100, true);
		}
		else
		{
			SpawnCash(attacker, victim, 100);
		}
	}
	
	// TODO restore previous weapons IF this death was a suicide in the respawn room
	
	return Plugin_Continue;
}

public void OnClientConnected(int client)
{
	TFGOPlayer tfgoPlayer = TFGOPlayer(client);
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
	
	int iWinningTeam = event.GetInt("winning_team");
	TFGOTeam winning_team = TFGOTeam(iWinningTeam);
	TFGOTeam losing_team;
	if (iWinningTeam == TFTeam_Red)
	{
		losing_team = TFGOTeam(iWinningTeam + 1);
	}
	else if (iWinningTeam == TFTeam_Blue)
	{
		losing_team = TFGOTeam(iWinningTeam - 1);
	}
	
	// adjust lose streak
	losing_team.LoseStreak++;
	winning_team.LoseStreak--;
	
	// add round end rewards
	int iWinReason = event.GetInt("winreason");
	switch (iWinReason)
	{
		case TF_WINREASON_CAPTURE:
		{
			winning_team.AddToTeamBalance(TFGO_CAPTURE_WIN_REWARD, "Team award for capturing all control points");
		}
		case TF_WINREASON_ELIMINATION:
		{
			winning_team.AddToTeamBalance(TFGO_ELIMINATION_WIN_REWARD, "Team award for eliminating the enemy team");
		}
	}
	int compensation = g_iLoseStreakCompensation[losing_team.LoseStreak];
	losing_team.AddToTeamBalance(compensation, "Income for losing");
	
	if (g_h10SecondRoundTimer != null)
	{
		KillTimer(g_h10SecondRoundTimer);
		g_h10SecondRoundTimer = null;
	}
	
	if (g_hBuytimeTimer != null)
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
}

public Action DisableBuyMenu(Handle timer)
{
	g_bBuytimeActive = false;
	g_hBuytimeTimer = null;
	CPrintToChatAll("{alert}Alert: {default}The %d second buy period has expired", tfgo_buytime.IntValue);
}

public Action Event_Arena_Round_Start(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundActive = true;
	g_h10SecondRoundTimer = CreateTimer(tf_arena_round_time.FloatValue - CSGO_ROUNDTENSECCOUNT_LENGTH, Play10SecondWarning);
	PlayRoundActionMusic();
}

public Action Event_Player_ChangeClass(Event event, const char[] name, bool dontBroadcast) {
	// during setup time, refund money if player had weapons and changed class
	int client = GetClientOfUserId(event.GetInt("userid"));
	return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (strcmp(classname, "func_respawnroom") == 0)
	{
		SDKHook(entity, SDKHook_StartTouch, Entity_StartTouch_RespawnRoom);
		SDKHook(entity, SDKHook_EndTouch, Entity_EndTouch_RespawnRoom);
	}
}

public Action Entity_StartTouch_RespawnRoom(int entity, int client)
{
	if (client <= MaxClients && IsClientConnected(client) && g_bBuytimeActive)
	{
		// TODO: auto-open buy menu
	}
}

public Action Entity_EndTouch_RespawnRoom(int entity, int client)
{
	if (client <= MaxClients && IsClientConnected(client) && g_bBuytimeActive)
	{
		// TODO: auto-close buy menu
		CPrintToChat(client, "{alert}Alert: {default}You have left the buy zone");
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
	
	int offset = GameConfGetOffset(hGameData, "SetWinningTeam");
	g_hSetWinningTeam = DHookCreate(offset, HookType_GameRules, ReturnType_Void, ThisPointer_Ignore, Hook_SetWinningTeam);
	DHookAddParam(g_hSetWinningTeam, HookParamType_Int);
	DHookAddParam(g_hSetWinningTeam, HookParamType_Int);
	DHookAddParam(g_hSetWinningTeam, HookParamType_Bool);
	DHookAddParam(g_hSetWinningTeam, HookParamType_Bool);
	DHookAddParam(g_hSetWinningTeam, HookParamType_Bool);
	DHookAddParam(g_hSetWinningTeam, HookParamType_Bool);
	
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
	
	delete hGameData;
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
	TFGOPlayer tfgoPlayer = TFGOPlayer(iClient);
	
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

public Action Event_Teamplay_Point_Captured(Event event, const char[] sName, bool bDontBroadcast)
{
	if (g_bBombPlanted)
	{
		if (g_iBombSiteCP == event.GetInt("cp") && g_iBombPlanterTeam != event.GetInt("team"))
		{
			g_bBombPlanted = false; // this causes the game to end due to the SetWinningTeam hook
			PrintToChatAll("bomb was defused!");
		}
	}
	else
	{
		g_bBombPlanted = true;
		g_iBombSiteCP = event.GetInt("cp");
		g_iBombPlanterTeam = event.GetInt("team");
		char cappers[64];
		event.GetString("cappers", cappers, sizeof(cappers));
		int firstCapper = cappers[0];
		
		// spawn bomb
		float origin[3];
		GetClientAbsOrigin(firstCapper, origin);
		float angles[3];
		GetClientAbsAngles(firstCapper, angles);
		int bombProp = EntIndexToEntRef(CreateEntityByName("prop_dynamic_override"));
		SetEntityModel(bombProp, "models/props_td/atom_bomb.mdl");
		EmitAmbientSound("mvm/sentrybuster/mvm_sentrybuster_loop.wav", origin, bombProp);
		DispatchKeyValue(bombProp, "Skin", "1");
		DispatchSpawn(bombProp);
		TeleportEntity(bombProp, origin, angles, NULL_VECTOR);
		
		// set round time to 45 seconds
		int team_round_timer = FindEntityByClassname(TF_MAXPLAYERS + 1, "team_round_timer");
		if (team_round_timer > -1)
		{
			SetVariantInt(45);
			AcceptEntityInput(team_round_timer, "SetTime");
		}
		
		if (g_h10SecondBombTimer != null)
		{
			KillTimer(g_h10SecondBombTimer);
			g_h10SecondBombTimer = null;
		}
		
		g_h10SecondBombTimer = CreateTimer(45.0 - 10.0, Play10SecondBombWarning);
		g_hBombExplosionTimer = CreateTimer(45.0, DetonateBomb, bombProp);
		
		
		if (g_h10SecondRoundTimer != null)
		{
			KillTimer(g_h10SecondRoundTimer);
			g_h10SecondRoundTimer = null;
		}
		
		StopRoundActionMusic();
		StopSoundForAll(SNDCHAN_AUTO, "valve_csgo_01/roundtenseccount.mp3");
		EmitSoundToAll("valve_csgo_01/bombplanted.mp3");
	}
}

public Action DetonateBomb(Handle timer, int bomb)
{
	StopSoundForAll(SNDCHAN_AUTO, "mvm/sentrybuster/mvm_sentrybuster_loop.wav"); // TODO this shit doesn't stop
	EmitSoundToAll("mvm/mvm_bomb_explode.wav", bomb, _, SNDLEVEL_ROCKET); // TODO this shit doesn't play
	RemoveEntity(bomb); // But this does happen...?
	// TODO
	//g_iBombPlanterTeam
}
