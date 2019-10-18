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
Handle g_hudSync;
Handle g_buyTimeTimer;
Handle g_10SecondRoundTimer;
Handle g_10SecondBombTimer;
Handle g_bombDetonationTimer;
Handle g_bombDetonationWarningTimer;
Handle g_bombBeepingTimer;

// Other handles
StringMap g_availableMusicKits;
ArrayList g_availableWeapons;

// Round loss payouts
int g_teamLosingStreaks[view_as<int>(TFTeam_Blue) + 1] =  { TFGO_STARTING_LOSESTREAK, ... };
int g_losingStreakCompensation[TFGO_MAX_LOSESTREAK + 1] =  { 1400, 1900, 2400, 2900, 3400 };

// Map
bool g_mapHasRespawnRoom;

// Game state
bool g_isGameWaitingForPlayers;
bool g_isBuyTimeActive;
bool g_isMainRoundActive;
bool g_isBonusRoundActive;
bool g_isBombPlanted;
int g_bombPlantingTeam;

// ConVars
ConVar tfgo_buytime;

ConVar tf_arena_first_blood;
ConVar tf_arena_round_time;
ConVar tf_arena_use_queue;
ConVar tf_arena_preround_time;
ConVar tf_arena_override_cap_enable_time;
ConVar tf_arena_max_streak;
ConVar tf_weapon_criticals;
ConVar tf_weapon_criticals_melee;
ConVar mp_bonusroundtime;

// SDK functions
Handle g_dHookSetWinningTeam;
Handle g_SDKEquipWearable;
Handle g_SDKRemoveWearable;
Handle g_SDKGetEquippedWearable;
Handle g_SDKGetMaxAmmo;


#include "tfgo/musickits.sp"
MusicKit g_currentMusicKit;

#include "tfgo/stocks.sp"
#include "tfgo/config.sp"
#include "tfgo/methodmaps.sp"
#include "tfgo/sound.sp"
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
	MusicKit_Init();
	g_hudSync = CreateHudSynchronizer();
	for (int client = 1; client <= MaxClients; client++)
	TFGOPlayer(client).ClearLoadout();
	
	// Events
	HookEvent("player_spawn", Event_Player_Spawn);
	HookEvent("player_team", Event_Player_Team);
	HookEvent("player_death", Event_Player_Death);
	HookEvent("post_inventory_application", Event_Post_Inventory_Application);
	HookEvent("teamplay_round_start", Event_Teamplay_Round_Start);
	HookEvent("arena_round_start", Event_Arena_Round_Start);
	HookEvent("teamplay_broadcast_audio", Event_Pre_Teamplay_Broadcast_Audio, EventHookMode_Pre);
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
	tf_weapon_criticals = FindConVar("tf_weapon_criticals");
	tf_weapon_criticals_melee = FindConVar("tf_weapon_criticals_melee");
	mp_bonusroundtime = FindConVar("mp_bonusroundtime");
	tfgo_buytime = CreateConVar("tfgo_buytime", "45", "How many seconds after spawning players can buy items for", _, true, tf_arena_preround_time.FloatValue);
	
	Toggle_ConVars(true);
	
	CAddColor("alert", 0xEA4141);
	CAddColor("money", 0xA2FE47);
}

public void OnAllPluginsLoaded()
{
	Config_Init(); // Config requires TF2 Econ to be loaded
}

public void OnPluginEnd()
{
	Toggle_ConVars(false);
}

public void OnMapStart()
{
	DHookGamerules(g_dHookSetWinningTeam, false);
	
	PrecacheSounds();
	PrecacheModels();
	PrecacheMusicKits();
	
	// Pick random music kit for the game
	ChooseRandomMusicKit();
	
	int func_respawnroom = FindEntityByClassname(-1, "func_respawnroom");
	if (func_respawnroom <= -1)
		LogMessage("This map is missing a func_respawnroom entity - unable to define a buy zone");
}

public void ChooseRandomMusicKit()
{
	StringMapSnapshot snapshot = g_availableMusicKits.Snapshot();
	char name[PLATFORM_MAX_PATH];
	snapshot.GetKey(GetRandomInt(0, snapshot.Length - 1), name, sizeof(name));
	delete snapshot;
	
	g_availableMusicKits.GetArray(name, g_currentMusicKit, sizeof(g_currentMusicKit));
}

public void OnClientConnected(int client)
{
	// Initialize new player with default values
	TFGOPlayer player = TFGOPlayer(client);
	player.Balance = TFGO_STARTING_BALANCE;
	player.ClearLoadout();
	
	if (g_isGameWaitingForPlayers)
		g_currentMusicKit.PlayMusicToClient(client, Music_ChooseTeam);
}

public void OnClientDisconnect(int client)
{
	if (g_isBombPlanted)
	{
		// TODO team alive check to  end the round during bomb plant
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "func_respawnroom"))
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
		
		if (g_isBuyTimeActive)
			CPrintToChat(client, "{alert}Alert: {default}You have left the buy zone");
	}
}

// Prevent round from ending, called every frame after the round is supposed to end
public MRESReturn Hook_SetWinningTeam(Handle hParams)
{
	//int team = DHookGetParam(hParams, 1);
	//int winReason = DHookGetParam(hParams, 2);
	if (g_isBombPlanted)
		return MRES_Supercede;
	else
		return MRES_Ignored;
}

public Action Event_Player_Spawn(Event event, const char[] name, bool dontBroadcast)
{
	ShowMainBuyMenu(GetClientOfUserId(event.GetInt("userid")));
	
	// Granting PDA weapons is utterly broken and causes way too many client crashes
	// The most sane thing to do here is just to disable these classes until I figure something out
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	TFClassType class = TF2_GetPlayerClass(client);
	if (class == TFClass_Spy)
	{
		TFClassType randomClass = TF2_GetRandomClass();
		while (randomClass == TFClass_Spy)
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
	
	// Cap balance at highest of the team
	int balance = GetHighestBalanceInTeam(event.GetInt("team"));
	if (player.Balance > balance)
		player.Balance = balance;
	player.ClearLoadout();
	
	// Cancel buy menu if client switched to spectator  (#4)
	if (view_as<TFTeam>(event.GetInt("team")) == TFTeam_Spectator && player.ActiveBuyMenu != null)
		player.ActiveBuyMenu.Cancel();
}

int GetHighestBalanceInTeam(int team)
{
	int balance = TFGO_STARTING_BALANCE;
	for (int client = 1; client <= MaxClients; client++)
	{
		TFGOPlayer player = TFGOPlayer(client);
		if (IsClientInGame(client) && GetClientTeam(client) == team && player.Balance > balance)
			balance = player.Balance;
	}
	return balance;
}

public Action Event_Player_Death(Event event, const char[] name, bool dontBroadcast)
{
	TFGOPlayer attacker = TFGOPlayer(GetClientOfUserId(event.GetInt("attacker")));
	TFGOPlayer victim = TFGOPlayer(GetClientOfUserId(event.GetInt("userid")));
	TFGOPlayer assister = TFGOPlayer(GetClientOfUserId(event.GetInt("assister")));
	int customkill = event.GetInt("customkill");
	
	// TODO: Check inflictor to reward engineer for sentry kills
	// TODO: Fix environmental kills counting as kills with weapon "default"
	if (customkill == TF_CUSTOM_SUICIDE && attacker == victim)
	{
		// TODO: Compensate random alive enemy player for this suicide ($300)
		if (g_isMainRoundActive)
			victim.AddToBalance(TFGO_SUICIDE_PENALTY, "Penalty for suiciding");
	}
	else if (attacker.Client >= 1 && attacker.Client <= MaxClients)
	{
		int index = g_availableWeapons.FindValue(event.GetInt("weapon_def_index"), 0);
		Weapon weapon;
		g_availableWeapons.GetArray(index, weapon, sizeof(weapon));
		
		char weaponName[255];
		TF2_GetItemName(weapon.defindex, weaponName, sizeof(weaponName));
		char msg[255];
		Format(msg, sizeof(msg), "Award for neutralizing an enemy with %s", weaponName);
		
		attacker.AddToBalance(weapon.killAward, msg);
		if (assister.Client >= 1 && assister.Client <= MaxClients)
		{
			char attackerName[255];
			GetClientName(attacker.Client, attackerName, sizeof(attackerName));
			Format(msg, sizeof(msg), "Award for assisting %s in neutralizing an enemy", attackerName);
			assister.AddToBalance(weapon.killAward / 2, msg);
		}
	}
	
	if (g_isBombPlanted)
	{
		int victimTeam = GetClientTeam(GetClientOfUserId(event.GetInt("userid")));
		if (g_bombPlantingTeam != victimTeam && GetAliveTeamCount(victimTeam) - 1 <= 0) // -1 because it doesn't work properly in player_death
		{
			// End the round if every member of the non-planting team died
			// TODO: the planting team still loses even if the bomb does detonate
			g_isBombPlanted = false;
		}
	}
	
	if (g_isMainRoundActive || g_isBonusRoundActive)
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
	g_isGameWaitingForPlayers = true;
}

public void TF2_OnWaitingForPlayersEnd()
{
	g_isGameWaitingForPlayers = false;
	g_currentMusicKit.StopMusicForAll(Music_ChooseTeam);
}

public Action Event_Teamplay_Round_Start(Event event, const char[] name, bool dontBroadcast)
{
	g_isBonusRoundActive = false;
	g_isMainRoundActive = false;
	g_buyTimeTimer = CreateTimer(tfgo_buytime.FloatValue, OnBuyTimeExpire);
	
	PlayRoundStartMusic();
}

public Action OnBuyTimeExpire(Handle timer)
{
	g_isBuyTimeActive = false;
	g_buyTimeTimer = null;
	
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
	if (!g_isBombPlanted)
	{
		char message[256] = "The %d second buy period has expired";
		Format(message, sizeof(message), message, tfgo_buytime.IntValue);
		ShowGameMessage(message, "ico_notify_ten_seconds");
	}
}

public Action Event_Arena_Round_Start(Event event, const char[] name, bool dontBroadcast)
{
	g_isMainRoundActive = true;
	g_10SecondRoundTimer = CreateTimer(tf_arena_round_time.FloatValue - 12.7, Play10SecondWarning);
}

public Action Event_Teamplay_Point_Captured(Event event, const char[] name, bool dontBroadcast)
{
	char[] cappers = new char[MaxClients];
	event.GetString("cappers", cappers, MaxClients);
	
	if (!g_isBombPlanted)
	{
		PlantBomb(event.GetInt("team"), cappers);
	}
	else
	{
		DefuseBomb();
	}
	
	g_isBombPlanted = !g_isBombPlanted;
}

void PlantBomb(int team, const char[] cappers)
{
	g_bombPlantingTeam = team;
	
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
		if (StrEqual(m_iszMessage, message))
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
	g_10SecondBombTimer = CreateTimer(TFGO_BOMB_DETONATION_TIME - 10.0, Play10SecondBombWarning);
	g_bombBeepingTimer = CreateTimer(1.0, PlayBombBeep, EntIndexToEntRef(bomb), TIMER_REPEAT);
	g_bombDetonationWarningTimer = CreateTimer(TFGO_BOMB_DETONATION_TIME - 1.5, PlayBombExplosionWarning, EntIndexToEntRef(bomb));
	g_bombDetonationTimer = CreateTimer(TFGO_BOMB_DETONATION_TIME, DetonateBomb, EntIndexToEntRef(bomb));
	
	if (g_10SecondRoundTimer != null)
		delete g_10SecondRoundTimer;
	
	// Play Sounds
	g_currentMusicKit.StopMusicForAll(Music_StartAction);
	g_currentMusicKit.StopMusicForAll(Music_RoundTenSecCount);
	g_currentMusicKit.PlayMusicToAll(Music_BombPlanted);
	PlayAnnouncerBombAlert();
	ShoutBombWarnings();
	
	// Show text on screen
	char message[256] = "The bomb has been planted.\n%d seconds to detonation.";
	Format(message, sizeof(message), message, RoundFloat(TFGO_BOMB_DETONATION_TIME));
	ShowGameMessage(message, "ico_notify_sixty_seconds");
}

public Action PlayBombBeep(Handle timer, int bomb)
{
	float m_vecOrigin[3];
	GetEntPropVector(bomb, Prop_Send, "m_vecOrigin", m_vecOrigin);
	EmitAmbientSound("player/cyoa_pda_beep8.wav", m_vecOrigin, bomb);
}

stock Action Play10SecondBombWarning(Handle timer)
{
	g_currentMusicKit.StopMusicForAll(Music_BombPlanted);
	g_currentMusicKit.PlayMusicToAll(Music_BombTenSecCount);
}

public Action PlayBombExplosionWarning(Handle timer, int bomb)
{
	float m_vecOrigin[3];
	GetEntPropVector(bomb, Prop_Send, "m_vecOrigin", m_vecOrigin);
	EmitAmbientSound("mvm/mvm_bomb_warning.wav", m_vecOrigin, bomb, SNDLEVEL_RAIDSIREN);
	delete g_bombBeepingTimer;
}

public Action DetonateBomb(Handle timer, int bombProp)
{
	g_isBombPlanted = false;
	
	if (g_bombBeepingTimer != null)
		delete g_bombBeepingTimer;
	
	float m_vecOrigin[3];
	GetEntPropVector(bombProp, Prop_Send, "m_vecOrigin", m_vecOrigin);
	TF2_Explode(_, m_vecOrigin, 500.0, 788.0, "mvm_hatch_destroy", "mvm/mvm_bomb_explode.wav");
	RemoveEntity(bombProp);
	delete g_bombDetonationTimer;
}

void DefuseBomb()
{
	if (g_10SecondBombTimer != null)
		delete g_10SecondBombTimer;
	
	if (g_bombBeepingTimer != null)
		delete g_bombBeepingTimer;
	
	if (g_bombDetonationWarningTimer != null)
		delete g_bombDetonationWarningTimer;
	
	if (g_bombDetonationTimer != null)
		delete g_bombDetonationTimer;
}

public Action Event_Arena_Win_Panel(Event event, const char[] name, bool dontBroadcast)
{
	g_isMainRoundActive = false;
	g_isBonusRoundActive = true;
	g_isBuyTimeActive = true;
	
	// Determine winning/losing team
	TFGOTeam winningTeam = TFGOTeam(view_as<TFTeam>(event.GetInt("winning_team")));
	TFGOTeam losingTeam;
	switch (winningTeam.Team)
	{
		case TFTeam_Red:losingTeam = TFGOTeam(TFTeam_Blue);
		case TFTeam_Blue:losingTeam = TFGOTeam(TFTeam_Red);
	}
	
	// Add round end team awards
	int winreason = event.GetInt("winreason");
	switch (winreason)
	{
		case TF_ARENA_WINREASON_CAPTURE:
		{
			if (g_bombPlantingTeam == event.GetInt("winning_team"))
				winningTeam.AddToTeamBalance(TFGO_BOMB_DETONATION_WIN_AWARD, "Team award for detonating bomb");
			else
				winningTeam.AddToTeamBalance(TFGO_BOMB_DEFUSE_WIN_AWARD, "Team award for winning by defusing the bomb");
		}
		case TF_ARENA_WINREASON_ELIMINATION:
		{
			winningTeam.AddToTeamBalance(TFGO_ELIMINATION_WIN_AWARD, "Team award for eliminating the enemy team");
		}
	}
	int compensation = g_losingStreakCompensation[losingTeam.LoseStreak];
	losingTeam.AddToTeamBalance(compensation, "Income for losing");
	
	// Adjust team losing streaks
	losingTeam.LoseStreak++;
	winningTeam.LoseStreak--;
	
	// Reset timers
	if (g_buyTimeTimer != null)
		delete g_buyTimeTimer;
	
	if (g_10SecondRoundTimer != null)
		delete g_10SecondRoundTimer;
	
	if (g_10SecondBombTimer != null)
		delete g_10SecondBombTimer;
	
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
					int value = g_availableWeapons.FindValue(defindex, 0);
					if (value > -1) // save only weapons that are buyable from the buy menu
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
	
	for (int i = 0; i < sizeof(g_teamLosingStreaks); i++)
	g_teamLosingStreaks[i] = TFGO_STARTING_LOSESTREAK;
	
	ChooseRandomMusicKit();
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
	static bool weaponCriticals;
	static bool weaponCriticalsMelee;
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
		tf_arena_max_streak.IntValue = 16;
		
		weaponCriticals = tf_weapon_criticals.BoolValue;
		tf_weapon_criticals.BoolValue = false;
		
		weaponCriticalsMelee = tf_weapon_criticals_melee.BoolValue;
		tf_weapon_criticals_melee.BoolValue = false;
		
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
		tf_weapon_criticals.BoolValue = weaponCriticals;
		tf_weapon_criticals_melee.BoolValue = weaponCriticalsMelee;
		mp_bonusroundtime.IntValue = bonusRoundTime;
	}
}

void SDK_Init()
{
	Handle config = LoadGameConfigFile("tfgo");
	int offset;
	
	offset = GameConfGetOffset(config, "SetWinningTeam");
	g_dHookSetWinningTeam = DHookCreate(offset, HookType_GameRules, ReturnType_Void, ThisPointer_Ignore, Hook_SetWinningTeam);
	DHookAddParam(g_dHookSetWinningTeam, HookParamType_Int);
	DHookAddParam(g_dHookSetWinningTeam, HookParamType_Int);
	DHookAddParam(g_dHookSetWinningTeam, HookParamType_Bool);
	DHookAddParam(g_dHookSetWinningTeam, HookParamType_Bool);
	DHookAddParam(g_dHookSetWinningTeam, HookParamType_Bool);
	DHookAddParam(g_dHookSetWinningTeam, HookParamType_Bool);
	if (g_dHookSetWinningTeam == null)
		LogMessage("Failed to create DHook: SetWinningTeam");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(config, SDKConf_Virtual, "CBasePlayer::EquipWearable");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_SDKEquipWearable = EndPrepSDKCall();
	if (g_SDKEquipWearable == null)
		LogMessage("Failed to create call: CBasePlayer::EquipWearable");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(config, SDKConf_Virtual, "CBasePlayer::RemoveWearable");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_SDKRemoveWearable = EndPrepSDKCall();
	if (g_SDKRemoveWearable == null)
		LogMessage("Failed to create call: CBasePlayer::RemoveWearable");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(config, SDKConf_Signature, "CTFPlayer::GetEquippedWearableForLoadoutSlot");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	g_SDKGetEquippedWearable = EndPrepSDKCall();
	if (g_SDKGetEquippedWearable == null)
		LogMessage("Failed to create call: CTFPlayer::GetEquippedWearableForLoadoutSlot");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(config, SDKConf_Signature, "CTFPlayer::GetMaxAmmo");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_SDKGetMaxAmmo = EndPrepSDKCall();
	if (g_SDKGetMaxAmmo == null)
		LogMessage("Failed to create call: CTFPlayer::GetMaxAmmo");
	
	delete config;
}
