#pragma semicolon 1

#include <morecolors>
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf_econ_data>
#include <dhooks>

#pragma newdecls required

// TF2 stuff
#define TF_MAXPLAYERS					32
#define TF_NUMTEAMS						3
#define TF_NUMCLASSES					9
#define TF_NUMSLOTS						6
#define TF_ARENA_WINREASON_CAPTURE		1
#define TF_ARENA_WINREASON_ELIMINATION	2

// TFGO stuff
#define TFGO_MINLOSESTREAK				0
#define TFGO_MAXLOSESTREAK				4
#define TFGO_STARTING_BALANCE			800
#define TFGO_MIN_BALANCE				0
#define TFGO_MAX_BALANCE				16000
#define TFGO_CAPTURE_WIN_REWARD			3500
#define TFGO_ELIMINATION_WIN_REWARD		3250
#define TFGO_CAPPER_BONUS				300
#define TFGO_SUICIDE_PENALTY			-300

#define TFGO_BOMB_DETONATION_TIME		45.0

int g_iLoseStreak[TF_NUMTEAMS + 1] =  { 1, ... };
int g_iLoseStreakCompensation[TFGO_MAXLOSESTREAK + 1] =  { 1400, 1900, 2400, 2900, 3400 };
int g_iBalance[TF_MAXPLAYERS + 1] =  { TFGO_STARTING_BALANCE, ... };

// Timers
Handle g_hHudSync;
Handle g_hBuytimeTimer;
Handle g_h10SecondRoundTimer;
Handle g_h10SecondBombTimer;
Handle g_hBombTimer;

// Other handles
Menu g_hActiveBuyMenus[TF_MAXPLAYERS + 1];

/**
Pre-defined default weapons for each slot
-1 indicates the weapon in this slot should not be changed
**/
int g_iDefaultWeaponIndex[][] =  {
	{ -1, -1, 30758, -1, -1, -1 },  //Unknown
	{ -1, 23, 30758, -1, -1, -1 },  //Scout
	{ -1, 16, 30758, -1, -1, -1 },  //Sniper
	{ -1, 10, 30758, -1, -1, -1 },  //Soldier
	{ 19, -1, 30758, -1, -1, -1 },  //Demoman
	{ 17, -1, 30758, -1, -1, -1 },  //Medic
	{ -1, 11, 30758, -1, -1, -1 },  //Heavy
	{ -1, 12, 30758, -1, -1, -1 },  //Pyro
	{ 24, -1, 30758, -1, -1, -1 },  //Spy
	{ 9, 22, 30758, -1, -1, -1 } //Engineer
};

int g_iLoadoutWeaponIndex[TF_MAXPLAYERS + 1][TF_NUMCLASSES + 1][TF_NUMSLOTS + 1];

// Game state
bool g_bWaitingForPlayers;
bool g_bBuyTimeActive;
bool g_bRoundActive;
bool g_bRoundInBonusTime;
bool g_bBombPlanted;
int g_iBombPlanterTeam;

// ConVars
ConVar tfgo_buytime;

ConVar tf_arena_first_blood;
ConVar tf_arena_round_time;
ConVar tf_arena_use_queue;
ConVar tf_arena_preround_time;
ConVar mp_bonusroundtime;

// SDK functions
Handle g_hSDKEquipWearable;
Handle g_hSDKRemoveWearable;
Handle g_hSDKGetEquippedWearable;
Handle g_hSetWinningTeam;
Handle g_hSDKGetMaxAmmo;

// TODO: This is kinda crappy right now because it uses two data structures to get simple information
// But it works for now, so I will just leave it now and attempt to change it later
enum struct TFGOWeaponEntry
{
	int index;
	int cost;
	int killReward;
}

// Config data
ArrayList weaponList;
StringMap killRewardMap;


#include "tfgo/stocks.sp"
#include "tfgo/methodmaps.sp"
#include "tfgo/sound.sp"
#include "tfgo/config.sp"
#include "tfgo/buymenu.sp"


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
	LoadTranslations("common.phrases.txt");
	LoadTranslations("tfgo.phrases.txt");
	
	for (int client = 0; client < sizeof(g_iLoadoutWeaponIndex); client++)
	for (int class = 0; class < sizeof(g_iLoadoutWeaponIndex[]); class++)
	for (int slot = 0; slot < sizeof(g_iLoadoutWeaponIndex[][]); slot++)
	g_iLoadoutWeaponIndex[client][class][slot] = -1;
	
	SDK_Init();
	
	g_hHudSync = CreateHudSynchronizer();
	
	HookEvent("player_death", Event_Player_Death);
	HookEvent("arena_win_panel", Event_Arena_Win_Panel);
	HookEvent("arena_round_start", Event_Arena_Round_Start);
	HookEvent("teamplay_round_start", Event_Teamplay_Round_Start);
	HookEvent("arena_match_maxstreak", Event_Arena_Match_MaxStreak);
	HookEvent("teamplay_broadcast_audio", Event_Pre_Broadcast_Audio, EventHookMode_Pre);
	HookEvent("teamplay_waiting_begins", Event_Teamplay_Waiting_Begins);
	HookEvent("teamplay_waiting_ends", Event_Teamplay_Waiting_Ends);
	HookEvent("post_inventory_application", Event_Post_Inventory_Application);
	HookEvent("teamplay_point_captured", Event_Teamplay_Point_Captured);
	
	tf_arena_first_blood = FindConVar("tf_arena_first_blood");
	tf_arena_round_time = FindConVar("tf_arena_round_time");
	tf_arena_use_queue = FindConVar("tf_arena_use_queue");
	tf_arena_preround_time = FindConVar("tf_arena_preround_time");
	mp_bonusroundtime = FindConVar("mp_bonusroundtime");
	tfgo_buytime = CreateConVar("tfgo_buytime", "45", "How many seconds after spawning players can buy items for", _, true, tf_arena_preround_time.FloatValue);
	
	CAddColor("alert", 0xEA4141);
	CAddColor("money", 0xA2FE47);
	
	Toggle_ConVars(true);
}

public void OnAllPluginsLoaded()
{
	// Reading config requires TF2 econ data dependency to be loaded
	Config_Init();
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
	
	int func_respawnroom = FindEntityByClassname(-1, "func_respawnroom");
	if (func_respawnroom <= -1)
	{
		LogMessage("This map is missing a func_respawnroom entity; cannot define a buy zone");
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (strcmp(classname, "func_respawnroom") == 0)
	{
		SDKHook(entity, SDKHook_StartTouch, Entity_StartTouch_RespawnRoom);
		SDKHook(entity, SDKHook_EndTouch, Entity_EndTouch_RespawnRoom);
	}
}

void PrecacheModels()
{
	PrecacheModel("models/props_td/atom_bomb.mdl");
}

// Prevent round from ending
// Called every frame after the round is supposed to end
public MRESReturn Hook_SetWinningTeam(Handle hParams)
{
	int team = DHookGetParam(hParams, 1);
	int winReason = DHookGetParam(hParams, 2);
	//PrintToServer("team: %d, winreason: %d is bomb planted: %b", team, winReason, g_bBombPlanted);
	if (g_bBombPlanted)
	{
		return MRES_Supercede;
	}
	else
	{
		return MRES_Ignored;
	}
}

public Action Event_Teamplay_Point_Captured(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bBombPlanted) // planted
	{
		g_iBombPlanterTeam = event.GetInt("team");
		
		// Award capture bonus to cappers
		char[] cappers = new char[MaxClients];
		event.GetString("cappers", cappers, MaxClients);
		for (int i = 0; i < strlen(cappers); i++)
		{
			int capper = cappers[i];
			TFGOPlayer(capper).AddToBalance(TFGO_CAPPER_BONUS, "Award for planting bomb");
		}
		
		// Spawn bomb prop
		float pos[3];
		float ang[3];
		GetClientAbsOrigin(cappers[0], pos);
		GetClientAbsAngles(cappers[0], ang);
		int bomb = CreateEntityByName("prop_dynamic_override");
		SetEntityModel(bomb, "models/props_td/atom_bomb.mdl");
		DispatchSpawn(bomb);
		TeleportEntity(bomb, pos, ang, NULL_VECTOR);
		
		// We need to kill this or the server will force a map change on cap
		int game_end;
		while ((game_end = FindEntityByClassname(game_end, "game_end")) > -1)
		{
			AcceptEntityInput(game_end, "Kill");
		}
		
		// Superceding SetWinningTeam causes arena mode to create a game_text entity announcing the winning team
		int game_text;
		while ((game_text = FindEntityByClassname(game_text, "game_text")) > -1)
		{
			char m_iszMessage[256];
			GetEntPropString(game_text, Prop_Data, "m_iszMessage", m_iszMessage, sizeof(m_iszMessage));
			
			char message[256];
			GetTeamName(event.GetInt("team"), message, sizeof(message));
			StrCat(message, sizeof(message), " Wins the Game!");
			
			// To not mess with any other game_text entities
			if (strcmp(m_iszMessage, message) == 0)
			{
				AcceptEntityInput(game_text, "Kill");
			}
		}
		
		// Add time
		int team_round_timer = FindEntityByClassname(-1, "team_round_timer");
		if (team_round_timer > -1)
		{
			SetVariantInt(45 + 1);
			AcceptEntityInput(team_round_timer, "SetTime");
		}
		
		// Set up timers
		g_h10SecondBombTimer = CreateTimer(TFGO_BOMB_DETONATION_TIME - 10.0, Play10SecondBombWarning);
		g_hBombTimer = CreateTimer(TFGO_BOMB_DETONATION_TIME, DetonateBomb, EntIndexToEntRef(bomb));
		
		if (g_h10SecondRoundTimer != null)
			delete g_h10SecondRoundTimer;
		
		// Play Sounds
		StopRoundActionMusic();
		StopSoundForAll(SNDCHAN_AUTO, "tfgo/music/valve_csgo_01/bombtenseccount.mp3");
		EmitSoundToAll("tfgo/music/valve_csgo_01/bombplanted.mp3");
		PlayAnnouncerBombAlert();
		ShoutBombWarnings();
		
		// Show text on screen
		char message[256] = "The bomb has been planted.\n%d seconds to detonation.";
		Format(message, sizeof(message), message, RoundFloat(TFGO_BOMB_DETONATION_TIME));
		ShowGameMessage(message, "ico_time_60");
	}
	else // defused
	{
		if (g_h10SecondBombTimer != null)
			delete g_h10SecondBombTimer;
		
		if (g_hBombTimer != null)
			delete g_hBombTimer;
	}
	
	g_bBombPlanted = !g_bBombPlanted;
}

public Action DetonateBomb(Handle timer, int bombProp)
{
	g_bBombPlanted = false;
	
	float vec[3];
	GetEntPropVector(bombProp, Prop_Send, "m_vecOrigin", vec);
	TF2_Explode(_, vec, 500.0, 788.0, "mvm_hatch_destroy", "mvm/mvm_bomb_explode.wav");
	RemoveEntity(bombProp);
}

public Action Event_Arena_Match_MaxStreak(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 0; i < sizeof(g_iBalance); i++)g_iBalance[i] = TFGO_STARTING_BALANCE;
	for (int i = 0; i < sizeof(g_iLoseStreak); i++)g_iLoseStreak[i] = TFGO_STARTING_BALANCE;
}

public Action Event_Player_Death(Event event, const char[] name, bool dontBroadcast)
{
	TFGOPlayer attacker = TFGOPlayer(GetClientOfUserId(event.GetInt("attacker")));
	TFGOPlayer victim = TFGOPlayer(GetClientOfUserId(event.GetInt("userid")));
	int defindex = event.GetInt("weapon_def_index");
	int customkill = event.GetInt("customkill");
	int assister = event.GetInt("assister");
	
	if (customkill == TF_CUSTOM_SUICIDE && attacker == victim)
	{
		// TODO compensate random alive enemy player for this suicide ($300)
		if (g_bRoundActive)victim.AddToBalance(TFGO_SUICIDE_PENALTY, "Penalty for suiciding");
	}
	else if (attacker.Client >= 1 && attacker.Client <= 32)
	{
		char weaponName[255];
		TF2Econ_GetItemName(defindex, weaponName, sizeof(weaponName));
		char msg[255];
		Format(msg, sizeof(msg), "Award for neutralizing an enemy with %s", weaponName);
		
		char weaponclass[255];
		TF2Econ_GetItemClassName(defindex, weaponclass, sizeof(weaponclass));
		
		TFGOWeapon weapon = TFGOWeapon(defindex);
		attacker.AddToBalance(weapon.KillReward, msg);
		if (assister != -1)
		{
			char attackerName[255];
			GetClientName(attacker.Client, attackerName, sizeof(attackerName));
			Format(msg, sizeof(msg), "Award for assisting %s in neutralizing an enemy", attackerName);
			TFGOPlayer(GetClientOfUserId(assister)).AddToBalance(weapon.KillReward / 2, msg);
		}
	}
	
	if (g_bRoundActive || g_bRoundInBonusTime)victim.ClearLoadout();
	
	
	if (g_bBombPlanted)
	{
		int victimTeam = GetClientTeam(GetClientOfUserId(event.GetInt("userid")));
		if (g_iBombPlanterTeam != victimTeam && GetAliveTeamCount(victimTeam) - 1 <= 0) // -1 because it doesn't work properly in player_death
		{
			// End the round if every member of the non-planting team died
			// TODO: the planting team still loses even if the bomb does detonate
			g_bBombPlanted = false;
		}
	}
	
	if (victim.ActiveBuyMenu != null)
	{
		victim.ActiveBuyMenu.Cancel();
	}
	
	return Plugin_Continue;
}

public void OnClientDisconnect(int client)
{
	if (g_bBombPlanted)
	{
		// TODO team alive check to  end the round during bomb plant
	}
}

public void OnClientConnected(int client)
{
	TFGOPlayer(client).Balance = TFGO_STARTING_BALANCE;
	// Give the player some music from the music kit while they wait
	if (g_bWaitingForPlayers)
	{
		EmitSoundToClient(client, "tfgo/music/valve_csgo_01/chooseteam.mp3");
	}
}

public Action Event_Arena_Win_Panel(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundActive = false;
	g_bRoundInBonusTime = true;
	
	// Determine winning/losing team
	TFGOTeam winningTeam = TFGOTeam(view_as<TFTeam>(event.GetInt("winning_team")));
	TFGOTeam losingTeam;
	switch (winningTeam.Team)
	{
		case TFTeam_Red:
		{
			losingTeam = TFGOTeam(TFTeam_Blue);
		}
		case TFTeam_Blue:
		{
			losingTeam = TFGOTeam(TFTeam_Red);
		}
	}
	
	// Add round end team awards
	int winReason = event.GetInt("winreason");
	switch (winReason)
	{
		case TF_ARENA_WINREASON_CAPTURE:
		{
			if (g_iBombPlanterTeam == event.GetInt("winning_team"))
			{
				winningTeam.AddToTeamBalance(TFGO_CAPTURE_WIN_REWARD, "Team award for detonating bomb");
			}
			else
			{
				winningTeam.AddToTeamBalance(TFGO_CAPTURE_WIN_REWARD, "Team award for defusing bomb");
			}
		}
		/*
		TODO: A map with multiple CPs triggers winreason 4 but the bomb planting logic doesn't support this yet
		case 4:
		{
			winningTeam.AddToTeamBalance(TFGO_CAPTURE_WIN_REWARD, "Team award for capturing all control points");
		}
		*/
		case TF_ARENA_WINREASON_ELIMINATION:
		{
			winningTeam.AddToTeamBalance(TFGO_ELIMINATION_WIN_REWARD, "Team award for eliminating the enemy team");
		}
	}
	int compensation = g_iLoseStreakCompensation[losingTeam.LoseStreak];
	losingTeam.AddToTeamBalance(compensation, "Income for losing");
	
	// Adjust team lose streaks
	losingTeam.LoseStreak++;
	winningTeam.LoseStreak--;
	
	// Reset timers
	if (g_hBuytimeTimer != null)
		delete g_hBuytimeTimer;
	
	if (g_h10SecondRoundTimer != null)
		delete g_h10SecondRoundTimer;
	
	if (g_h10SecondBombTimer != null)
		delete g_h10SecondBombTimer;
	
	// Everyone who survives the post-victory time gets to keep their weapons
	CreateTimer(mp_bonusroundtime.FloatValue - 0.1, SaveWeaponsForAlivePlayers);
}

public Action SaveWeaponsForAlivePlayers(Handle timer)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && IsPlayerAlive(client))
		{
			for (int slot = 0; slot < TF_NUMSLOTS; slot++)
			{
				int defindex = TF2_GetItemInSlot(client, slot);
				if (defindex > -1)
				{
					TFGOWeapon weapon = TFGOWeapon(defindex);
					if (weapon.IsInBuyMenu())
					{
						TFGOPlayer(client).AddToLoadout(defindex);
					}
				}
			}
		}
	}
}

public Action Event_Post_Inventory_Application(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsClientInGame(client))
	{
		ShowMainBuyMenu(client);
		TFGOPlayer player = TFGOPlayer(client);
		player.ShowMoneyHudDisplay(tfgo_buytime.FloatValue);
		player.ApplyLoadout();
	}
	
	return Plugin_Handled;
}

public Action Event_Arena_Round_Start(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundActive = true;
	g_h10SecondRoundTimer = CreateTimer(tf_arena_round_time.FloatValue - 12.7, Play10SecondWarning);
}

public Action Event_Teamplay_Round_Start(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundInBonusTime = false;
	g_bRoundActive = false;
	g_bBuyTimeActive = true;
	g_hBuytimeTimer = CreateTimer(tfgo_buytime.FloatValue, OnBuyTimeExpire);
	
	PlayRoundStartMusic();
	
	for (int client = 1; client < MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			ShowMainBuyMenu(client);
			TFGOPlayer(client).ShowMoneyHudDisplay(tfgo_buytime.FloatValue);
		}
	}
}

public Action OnBuyTimeExpire(Handle timer)
{
	g_bBuyTimeActive = false;
	g_hBuytimeTimer = null;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			TFGOPlayer player = TFGOPlayer(client);
			
			if (player.ActiveBuyMenu != null)
			{
				player.ActiveBuyMenu.Cancel();
			}
		}
	}
	
	if (!g_bBombPlanted)
	{
		char message[256] = "The %d second buy period has expired";
		Format(message, sizeof(message), message, tfgo_buytime.IntValue);
		ShowGameMessage(message, "ico_notify_ten_seconds");
	}
}

public Action Event_Teamplay_Waiting_Begins(Event event, const char[] sName, bool bDontBroadcast)
{
	g_bWaitingForPlayers = true;
}

public Action Event_Teamplay_Waiting_Ends(Event event, const char[] sName, bool bDontBroadcast)
{
	g_bWaitingForPlayers = false;
	StopSoundForAll(SNDCHAN_AUTO, "tfgo/music/valve_csgo_01/chooseteam.mp3");
}

public Action Entity_StartTouch_RespawnRoom(int entity, int client)
{
	if (client <= MaxClients && IsClientConnected(client))
	{
		if (GetEntProp(entity, Prop_Data, "m_iTeamNum") == GetClientTeam(client))
		{
			ShowMainBuyMenu(client);
		}
	}
}

public Action Entity_EndTouch_RespawnRoom(int entity, int client)
{
	if (client <= MaxClients && IsClientConnected(client))
	{
		if (GetEntProp(entity, Prop_Data, "m_iTeamNum") == GetClientTeam(client))
		{
			TFGOPlayer player = TFGOPlayer(client);
			if (player.ActiveBuyMenu != null)
			{
				player.ActiveBuyMenu.Cancel();
			}
			
			if (g_bBuyTimeActive)
			{
				CPrintToChat(client, "{alert}Alert: {default}You have left the buy zone");
			}
		}
	}
}

void Toggle_ConVars(bool toggle)
{
	static bool bArenaFirstBlood;
	static bool bArenaUseQueue;
	static int iArenaRoundTime;
	static int iBonusRoundtime;
	
	if (toggle)
	{
		bArenaFirstBlood = tf_arena_first_blood.BoolValue;
		tf_arena_first_blood.BoolValue = false;
		
		bArenaUseQueue = tf_arena_use_queue.BoolValue;
		tf_arena_use_queue.BoolValue = false;
		
		iArenaRoundTime = tf_arena_round_time.IntValue;
		tf_arena_round_time.IntValue = 135;
		
		iBonusRoundtime = mp_bonusroundtime.IntValue;
		mp_bonusroundtime.IntValue = 7;
	}
	else
	{
		tf_arena_first_blood.BoolValue = bArenaFirstBlood;
		tf_arena_use_queue.BoolValue = bArenaUseQueue;
		tf_arena_round_time.IntValue = iArenaRoundTime;
		mp_bonusroundtime.IntValue = iBonusRoundtime;
	}
}

void SDK_Init()
{
	Handle config = LoadGameConfigFile("tfgo");
	int offset;
	
	offset = GameConfGetOffset(config, "SetWinningTeam");
	g_hSetWinningTeam = DHookCreate(offset, HookType_GameRules, ReturnType_Void, ThisPointer_Ignore, Hook_SetWinningTeam);
	DHookAddParam(g_hSetWinningTeam, HookParamType_Int);
	DHookAddParam(g_hSetWinningTeam, HookParamType_Int);
	DHookAddParam(g_hSetWinningTeam, HookParamType_Bool);
	DHookAddParam(g_hSetWinningTeam, HookParamType_Bool);
	DHookAddParam(g_hSetWinningTeam, HookParamType_Bool);
	DHookAddParam(g_hSetWinningTeam, HookParamType_Bool);
	if (g_hSetWinningTeam == null)
		LogMessage("Failed to create DHook: SetWinningTeam");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(config, SDKConf_Virtual, "CBasePlayer::EquipWearable");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKEquipWearable = EndPrepSDKCall();
	if (g_hSDKEquipWearable == null)
		LogMessage("Failed to create call: CBasePlayer::EquipWearable");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(config, SDKConf_Virtual, "CBasePlayer::RemoveWearable");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKRemoveWearable = EndPrepSDKCall();
	if (g_hSDKRemoveWearable == null)
		LogMessage("Failed to create call: CBasePlayer::RemoveWearable");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(config, SDKConf_Signature, "CTFPlayer::GetEquippedWearableForLoadoutSlot");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKGetEquippedWearable = EndPrepSDKCall();
	if (g_hSDKGetEquippedWearable == null)
		LogMessage("Failed to create call: CTFPlayer::GetEquippedWearableForLoadoutSlot");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(config, SDKConf_Signature, "CTFPlayer::GetMaxAmmo");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetMaxAmmo = EndPrepSDKCall();
	if (g_hSDKGetMaxAmmo == null)
		LogMessage("Failed to create call: CTFPlayer::GetMaxAmmo");
	
	delete config;
}
