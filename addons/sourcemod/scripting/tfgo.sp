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
#define TF_ARENA_WINREASON_CAPTURE		1
#define TF_ARENA_WINREASON_ELIMINATION	2

// TFGO stuff
#define TFGO_MIN_LOSESTREAK				0
#define TFGO_MAX_LOSESTREAK				4
#define TFGO_STARTING_LOSESTREAK		1

#define TFGO_STARTING_BALANCE			800
#define TFGO_MIN_BALANCE				0
#define TFGO_MAX_BALANCE				16000
#define TFGO_BOMB_DETONATION_WIN_AWARD	3500
#define TFGO_BOMB_DEFUSE_WIN_AWARD		3500
#define TFGO_ELIMINATION_WIN_AWARD		3250
#define TFGO_CAPPER_BONUS				300
#define TFGO_SUICIDE_PENALTY			-300

#define TFGO_BOMB_DETONATION_TIME		45.0


// Timers
Handle g_hHudSync;
Handle g_hBuytimeTimer;
Handle g_h10SecondRoundTimer;
Handle g_h10SecondBombTimer;
Handle g_hBombTimer;
Handle g_hBombExplosionWarningTimer;
Handle g_hBombBeepTimer;

// Other handles
Menu g_hActiveBuyMenus[TF_MAXPLAYERS + 1];

/*
* Pre-defined default weapons for each class and slot.
* -1 indicates this class should start with no weapon in this slot.
*/
int g_iDefaultWeaponIndex[][] =  {
	{ -1, -1, -1, -1, -1, -1 },  // Unknown
	{ -1, 23, 30758, -1, -1, -1 },  // Scout
	{ -1, 16, 30758, -1, -1, -1 },  // Sniper
	{ -1, 10, 30758, -1, -1, -1 },  // Soldier
	{ 19, -1, 30758, -1, -1, -1 },  // Demoman
	{ 17, -1, 30758, -1, -1, -1 },  // Medic
	{ -1, 11, 30758, -1, -1, -1 },  // Heavy
	{ -1, 12, 30758, -1, -1, -1 },  // Pyro
	{ 24, 735, 30758, 27, 30, -1 },  // Spy
	{ 9, 22, 30758, 25, 26, 28 } // Engineer
};

// Player loadouts
int g_iLoadoutWeaponIndex[TF_MAXPLAYERS + 1][view_as<int>(TFClass_Engineer) + 1][view_as<int>(TFWeaponSlot_PDA) + 1];

// Player money
int g_iBalance[TF_MAXPLAYERS + 1] =  { TFGO_STARTING_BALANCE, ... };

// Round loss payouts
int g_iLoseStreak[view_as<int>(TFTeam_Blue) + 1] =  { TFGO_STARTING_LOSESTREAK, ... };
int g_iLoseStreakCompensation[TFGO_MAX_LOSESTREAK + 1] =  { 1400, 1900, 2400, 2900, 3400 };

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
ConVar tf_arena_override_cap_enable_time;
ConVar tf_arena_max_streak;
ConVar mp_bonusroundtime;

// SDK functions
Handle g_hSDKEquipWearable;
Handle g_hSDKRemoveWearable;
Handle g_hSDKGetEquippedWearable;
Handle g_hSetWinningTeam;
Handle g_hSDKGetMaxAmmo;

// Config
// TODO: Allow for more customization of single weapons (attributes, kill award overrides, etc.)
enum struct TFGOWeaponEntry
{
	int DefIndex;
	int Cost;
}

ArrayList weaponList;
StringMap killAwardMap;


#include "tfgo/stocks.sp"
#include "tfgo/methodmaps.sp"
#include "tfgo/sound.sp"
#include "tfgo/config.sp"
#include "tfgo/buymenu.sp"


public Plugin myinfo =  {
	name = "Team Fortress: Global Offensive Arena",
	author = "Mikusch",
	description = "A Team Fortress 2 gamemode inspired by Counter-Strike: Global Offensive",
	version = "1.0",
	url = "https://github.com/Mikusch/tfgo"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases.txt");
	LoadTranslations("tfgo.phrases.txt");

	// Initializing globals
	SDK_Init();
	Config_Init();
	g_hHudSync = CreateHudSynchronizer();
	for (int client = 1; client <= MaxClients; client++)
	    TFGOPlayer(client).ClearLoadout();

	// Events
	HookEvent("player_spawn", Event_Player_Spawn);
	HookEvent("player_team", Event_Player_Team);
	HookEvent("player_death", Event_Player_Death);
	HookEvent("post_inventory_application", Event_Post_Inventory_Application);
	HookEvent("teamplay_round_start", Event_Teamplay_Round_Start);
	HookEvent("arena_round_start", Event_Arena_Round_Start);
	HookEvent("teamplay_broadcast_audio", Event_Pre_Broadcast_Audio, EventHookMode_Pre);
	HookEvent("teamplay_point_captured", Event_Teamplay_Point_Captured);
	HookEvent("arena_win_panel", Event_Arena_Win_Panel);
	HookEvent("arena_match_maxstreak", Event_Arena_Match_MaxStreak);

	// ConVars
	tf_arena_first_blood = FindConVar("tf_arena_first_blood");
	tf_arena_round_time = FindConVar("tf_arena_round_time");
	tf_arena_use_queue = FindConVar("tf_arena_use_queue");
	tf_arena_preround_time = FindConVar("tf_arena_preround_time");
	tf_arena_override_cap_enable_time = FindConVar("tf_arena_override_cap_enable_time");
	tf_arena_max_streak = FindConVar("tf_arena_max_streak");
	mp_bonusroundtime = FindConVar("mp_bonusroundtime");
	tfgo_buytime = CreateConVar("tfgo_buytime", "45", "How many seconds after spawning players can buy items for", _, true, tf_arena_preround_time.FloatValue);

	Toggle_ConVars(true);

	CAddColor("alert", 0xEA4141);
	CAddColor("money", 0xA2FE47);
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
		LogMessage("This map is missing a func_respawnroom entity - unable to define a buy zone");
}

public void OnClientConnected(int client)
{
	// Initialize new player with default values
	TFGOPlayer player = TFGOPlayer(client);
	player.Balance = TFGO_STARTING_BALANCE;
	player.ClearLoadout();

	if (g_bWaitingForPlayers)
		EmitSoundToClient(client, "tfgo/music/valve_csgo_01/chooseteam.mp3");
}

public void OnClientDisconnect(int client)
{
	if (g_bBombPlanted)
	{
		// TODO team alive check to  end the round during bomb plant
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (strcmp(classname, "func_respawnroom") == 0)
	{
		SDKHook(entity, SDKHook_StartTouch, OnStartTouchBuyZone);
		SDKHook(entity, SDKHook_EndTouch, OnEndTouchBuyZone);
	}
}

public Action OnStartTouchBuyZone(int entity, int client)
{
	if (client >= 1 && client <= MaxClients && IsClientInGame(client) && GetEntProp(entity, Prop_Data, "m_iTeamNum") == GetClientTeam(client))
		ShowMainBuyMenu(client);
}

public Action OnEndTouchBuyZone(int entity, int client)
{
	if (client >= 1 && client <= MaxClients && IsClientInGame(client) && GetEntProp(entity, Prop_Data, "m_iTeamNum") == GetClientTeam(client))
	{
		TFGOPlayer player = TFGOPlayer(client);
		if (player.ActiveBuyMenu != null)
			player.ActiveBuyMenu.Cancel();

		if (g_bBuyTimeActive)
			CPrintToChat(client, "{alert}Alert: {default}You have left the buy zone");
	}
}

// Prevent round from ending, called every frame after the round is supposed to end
public MRESReturn Hook_SetWinningTeam(Handle hParams)
{
	//int team = DHookGetParam(hParams, 1);
	//int winReason = DHookGetParam(hParams, 2);
	if (g_bBombPlanted)
		return MRES_Supercede;
	else
		return MRES_Ignored;
}

public Action Event_Player_Spawn(Event event, const char[] name, bool dontBroadcast)
{
	// Granting PDA weapons is utterly broken and causes way too many client crashes
	// The most sane thing to do here is just to disable these classes until I figure something out

	int client = GetClientOfUserId(event.GetInt("userid"));
	TFClassType class = TF2_GetPlayerClass(client);
	if (class == TFClass_Engineer || class == TFClass_Spy)
	{
		TFClassType randomClass = TF2_GetRandomClass();
		while (randomClass == TFClass_Engineer || randomClass == TFClass_Spy)
		{
			randomClass = TF2_GetRandomClass();
		}
		TF2_SetPlayerClass(client, randomClass);
		TF2_RespawnPlayer(client);
		PrintToChat(client, "This class is currently disabled. Your class has been forcibly changed.");
	}
}

public Action Event_Player_Team(Event event, const char[] name, bool dontBroadcast)
{
	// Reset player data on team switch
	TFGOPlayer player = TFGOPlayer(GetClientOfUserId(event.GetInt("userid")));
	player.Balance = TFGO_STARTING_BALANCE;
	player.ClearLoadout();

	// Cancel buy menu if client switched to spectator  (#4)
	if (view_as<TFTeam>(event.GetInt("team")) == TFTeam_Spectator && player.ActiveBuyMenu != null)
		player.ActiveBuyMenu.Cancel();
}

public Action Event_Player_Death(Event event, const char[] name, bool dontBroadcast)
{
	TFGOPlayer attacker = TFGOPlayer(GetClientOfUserId(event.GetInt("attacker")));
	TFGOPlayer victim = TFGOPlayer(GetClientOfUserId(event.GetInt("userid")));
	TFGOPlayer assister = TFGOPlayer(GetClientOfUserId(event.GetInt("assister")));
	TFGOWeapon weapon = TFGOWeapon(event.GetInt("weapon_def_index"));
	int customkill = event.GetInt("customkill");

	if (customkill == TF_CUSTOM_SUICIDE && attacker == victim)
	{
		// TODO: compensate random alive enemy player for this suicide ($300)
		if (g_bRoundActive)
			victim.AddToBalance(TFGO_SUICIDE_PENALTY, "Penalty for suiciding");
	}
	else if (attacker.Client >= 1 && attacker.Client <= MaxClients)
	{
		char weaponName[255];
		TF2Econ_GetItemName(weapon.DefIndex, weaponName, sizeof(weaponName));
		char msg[255];
		Format(msg, sizeof(msg), "Award for neutralizing an enemy with %s", weaponName);

		char weaponclass[255];
		TF2Econ_GetItemClassName(weapon.DefIndex, weaponclass, sizeof(weaponclass));

		attacker.AddToBalance(weapon.KillReward, msg);
		if (assister.Client >= 1 && assister.Client <= MaxClients)
		{
			char attackerName[255];
			GetClientName(attacker.Client, attackerName, sizeof(attackerName));
			Format(msg, sizeof(msg), "Award for assisting %s in neutralizing an enemy", attackerName);
			assister.AddToBalance(weapon.KillReward / 2, msg);
		}
	}

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

	if (g_bRoundActive || g_bRoundInBonusTime)
		victim.ClearLoadout();
	if (victim.ActiveBuyMenu != null)
		victim.ActiveBuyMenu.Cancel();

	return Plugin_Continue;
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

public void TF2_OnWaitingForPlayersStart()
{
	g_bWaitingForPlayers = true;
}

public void TF2_OnWaitingForPlayersEnd()
{
	g_bWaitingForPlayers = false;
	StopSoundForAll(SNDCHAN_AUTO, "tfgo/music/valve_csgo_01/chooseteam.mp3");
}

public Action Event_Teamplay_Round_Start(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundInBonusTime = false;
	g_bRoundActive = false;
	g_bBuyTimeActive = true;
	g_hBuytimeTimer = CreateTimer(tfgo_buytime.FloatValue, OnBuyTimeExpire);

	PlayRoundStartMusic();
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
				player.ActiveBuyMenu.Cancel();
		}
	}

	// No one cares about the buy time if the bomb is already active
	if (!g_bBombPlanted)
	{
		char message[256] = "The %d second buy period has expired";
		Format(message, sizeof(message), message, tfgo_buytime.IntValue);
		ShowGameMessage(message, "ico_notify_ten_seconds");
	}
}

public Action Event_Arena_Round_Start(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundActive = true;
	g_h10SecondRoundTimer = CreateTimer(tf_arena_round_time.FloatValue - 12.7, Play10SecondWarning);
}

public Action Event_Teamplay_Point_Captured(Event event, const char[] name, bool dontBroadcast)
{
	char[] cappers = new char[MaxClients];
	event.GetString("cappers", cappers, MaxClients);

	if (!g_bBombPlanted)
	{
		PlantBomb(event.GetInt("team"), cappers);
	}
	else
	{
		DefuseBomb();
	}

	g_bBombPlanted = !g_bBombPlanted;
}

void PlantBomb(int team, const char[] cappers)
{
	g_iBombPlanterTeam = team;

	// Award capture bonus to cappers
	for (int i = 0; i < strlen(cappers); i++)
	{
		int capper = cappers[i];
		TFGOPlayer(capper).AddToBalance(TFGO_CAPPER_BONUS, "Award for planting the bomb");

		// TODO: Bandaid solution for the game making the planting team lose if they all die
		TF2_AddCondition(capper, TFCond_HalloweenInHell);
	}

	// Spawn bomb prop on position of first capper
	// TODO: Set skin of bomb to team color
	float pos[3];
	float ang[3];
	GetClientAbsOrigin(cappers[0], pos);
	GetClientAbsAngles(cappers[0], ang);
	int bomb = CreateEntityByName("prop_dynamic_override");
	SetEntityModel(bomb, "models/props_td/atom_bomb.mdl");
	DispatchSpawn(bomb);
	TeleportEntity(bomb, pos, ang, NULL_VECTOR);

	// Superceding SetWinningTeam causes arena mode to force a map change on capture
	int game_end;
	while ((game_end = FindEntityByClassname(game_end, "game_end")) > -1)
		AcceptEntityInput(game_end, "Kill");

	// Superceding SetWinningTeam causes arena mode to create a game_text entity announcing the winning team
	int game_text;
	while ((game_text = FindEntityByClassname(game_text, "game_text")) > -1)
	{
		char m_iszMessage[256];
		GetEntPropString(game_text, Prop_Data, "m_iszMessage", m_iszMessage, sizeof(m_iszMessage));

		char message[256];
		GetTeamName(team, message, sizeof(message));
		StrCat(message, sizeof(message), " Wins the Game!");

		// To not mess with any other game_text entities
		if (strcmp(m_iszMessage, message) == 0)
			AcceptEntityInput(game_text, "Kill");
	}

	// Set arena round time to bomb detonation time
	int team_round_timer = FindEntityByClassname(-1, "team_round_timer");
	if (team_round_timer > -1)
	{
		SetVariantInt(RoundFloat(TFGO_BOMB_DETONATION_TIME) + 1);
		AcceptEntityInput(team_round_timer, "SetTime");
	}

	// Set up timers
	g_h10SecondBombTimer = CreateTimer(TFGO_BOMB_DETONATION_TIME - 10.0, Play10SecondBombWarning);
	g_hBombBeepTimer = CreateTimer(1.0, PlayBombBeep, EntIndexToEntRef(bomb), TIMER_REPEAT);
	g_hBombExplosionWarningTimer = CreateTimer(TFGO_BOMB_DETONATION_TIME - 1.5, PlayBombExplosionWarning, EntIndexToEntRef(bomb));
	g_hBombTimer = CreateTimer(TFGO_BOMB_DETONATION_TIME, DetonateBomb, EntIndexToEntRef(bomb));

	if (g_h10SecondRoundTimer != null)
		delete g_h10SecondRoundTimer;

	// Play Sounds
	StopRoundActionMusic();
	StopSoundForAll(SNDCHAN_AUTO, "tfgo/music/valve_csgo_01/roundtenseccount.mp3");
	EmitSoundToAll("tfgo/music/valve_csgo_01/bombplanted.mp3");
	PlayAnnouncerBombAlert();
	ShoutBombWarnings();

	// Show text on screen
	char message[256] = "The bomb has been planted. %d seconds to detonation.";
	Format(message, sizeof(message), message, RoundFloat(TFGO_BOMB_DETONATION_TIME));
	ShowGameMessage(message, "ico_time_60");
}

public Action PlayBombBeep(Handle timer, int bomb)
{
	float m_vecOrigin[3];
	GetEntPropVector(bomb, Prop_Send, "m_vecOrigin", m_vecOrigin);
	EmitAmbientSound("player/cyoa_pda_beep8.wav", m_vecOrigin, bomb);
}

stock Action Play10SecondBombWarning(Handle timer)
{
	StopSoundForAll(SNDCHAN_AUTO, "tfgo/music/valve_csgo_01/bombplanted.mp3");
	EmitSoundToAll("tfgo/music/valve_csgo_01/bombtenseccount.mp3");
}

public Action PlayBombExplosionWarning(Handle timer, int bomb)
{
	float m_vecOrigin[3];
	GetEntPropVector(bomb, Prop_Send, "m_vecOrigin", m_vecOrigin);
	EmitAmbientSound("mvm/mvm_bomb_warning.wav", m_vecOrigin, bomb, SNDLEVEL_RAIDSIREN);
	delete g_hBombBeepTimer;
}

public Action DetonateBomb(Handle timer, int bombProp)
{
	g_bBombPlanted = false;

	if (g_hBombBeepTimer != null)
		delete g_hBombBeepTimer;

	float m_vecOrigin[3];
	GetEntPropVector(bombProp, Prop_Send, "m_vecOrigin", m_vecOrigin);
	TF2_Explode(_, m_vecOrigin, 500.0, 788.0, "mvm_hatch_destroy", "mvm/mvm_bomb_explode.wav");
	RemoveEntity(bombProp);
	delete g_hBombTimer;
}

void DefuseBomb()
{
	if (g_h10SecondBombTimer != null)
		delete g_h10SecondBombTimer;

	if (g_hBombBeepTimer != null)
		delete g_hBombBeepTimer;

	if (g_hBombExplosionWarningTimer != null)
		delete g_hBombExplosionWarningTimer;

	if (g_hBombTimer != null)
		delete g_hBombTimer;
}

public Action Event_Arena_Win_Panel(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundActive = false;
	g_bRoundInBonusTime = true;

	// Determine winning/losing team
	TFGOTeam winning_team = TFGOTeam(view_as<TFTeam>(event.GetInt("winning_team")));
	TFGOTeam losing_team;
	switch (winning_team.Team)
	{
		case TFTeam_Red:losing_team = TFGOTeam(TFTeam_Blue);
		case TFTeam_Blue:losing_team = TFGOTeam(TFTeam_Red);
	}

	// Add round end team awards
	int winreason = event.GetInt("winreason");
	switch (winreason)
	{
		case TF_ARENA_WINREASON_CAPTURE:
		{
			if (g_iBombPlanterTeam == event.GetInt("winning_team"))
				winning_team.AddToTeamBalance(TFGO_BOMB_DETONATION_WIN_AWARD, "Team award for detonating bomb");
			else
				winning_team.AddToTeamBalance(TFGO_BOMB_DEFUSE_WIN_AWARD, "Team award for winning by defusing the bomb");
		}
		case TF_ARENA_WINREASON_ELIMINATION:
		{
			winning_team.AddToTeamBalance(TFGO_ELIMINATION_WIN_AWARD, "Team award for eliminating the enemy team");
		}
	}
	int compensation = g_iLoseStreakCompensation[losing_team.LoseStreak];
	losing_team.AddToTeamBalance(compensation, "Income for losing");

	// Adjust team losing streaks
	losing_team.LoseStreak++;
	winning_team.LoseStreak--;

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
			for (int slot = 0; slot <= view_as<int>(TFWeaponSlot_PDA); slot++)
			{
				int defindex = TF2_GetItemInSlot(client, slot);
				if (defindex > -1)
				{
					TFGOWeapon weapon = TFGOWeapon(defindex);
					if (weapon.IsInBuyMenu())
						TFGOPlayer(client).AddToLoadout(defindex);
				}
			}
		}
	}
}

public Action Event_Arena_Match_MaxStreak(Event event, const char[] name, bool dontBroadcast)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		TFGOPlayer player = TFGOPlayer(client);
		player.Balance = TFGO_STARTING_BALANCE;
		player.ClearLoadout();
	}

	for (int i = 0; i < sizeof(g_iLoseStreak); i++)
	    g_iLoseStreak[i] = TFGO_STARTING_LOSESTREAK;
}

void PrecacheModels()
{
	PrecacheModel("models/props_td/atom_bomb.mdl");
}

void Toggle_ConVars(bool toggle)
{
	static bool arenaFirstBlood;
	static bool arenaUseQueue;
	static int arenaRoundTime;
	static int arenaOverrideCapEnableTime;
	static int arenaMaxStreak;
	static int bonusRoundTime;
	
	if (toggle)
	{
		arenaFirstBlood = tf_arena_first_blood.BoolValue;
		tf_arena_first_blood.BoolValue = false;

		arenaUseQueue = tf_arena_use_queue.BoolValue;
		tf_arena_use_queue.BoolValue = false;

		arenaRoundTime = tf_arena_round_time.IntValue;
		tf_arena_round_time.IntValue = 135;

		arenaOverrideCapEnableTime = tf_arena_override_cap_enable_time.IntValue;
		tf_arena_override_cap_enable_time.IntValue = 15;

		arenaMaxStreak = tf_arena_max_streak.IntValue;
		tf_arena_max_streak.IntValue = 5;

		bonusRoundTime = mp_bonusroundtime.IntValue;
		mp_bonusroundtime.IntValue = 7;
	}
	else
	{
		tf_arena_first_blood.BoolValue = arenaFirstBlood;
		tf_arena_use_queue.BoolValue = arenaUseQueue;
		tf_arena_round_time.IntValue = arenaRoundTime;
		tf_arena_override_cap_enable_time.IntValue = arenaOverrideCapEnableTime;
		tf_arena_max_streak.IntValue = arenaMaxStreak;
		mp_bonusroundtime.IntValue = bonusRoundTime;
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
