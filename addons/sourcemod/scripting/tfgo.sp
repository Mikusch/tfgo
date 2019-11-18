#pragma semicolon 1

#include <morecolors>
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf_econ_data>
#include <dhooks>
#include <memorypatch>

#pragma newdecls required

#define TF_MAXPLAYERS 32

#define BOMB_MODEL "models/props_td/atom_bomb.mdl"
#define BOMB_EXPLOSION_PARTICLE "mvm_hatch_destroy"


// Timers
Handle g_buyTimeTimer;
Handle g_10SecondRoundTimer;
Handle g_10SecondBombTimer;
Handle g_bombDetonationTimer;
Handle g_bombDetonationWarningTimer;
Handle g_bombBeepingTimer;

// Other handles
MemoryPatch g_pickupWepPatch;
Handle g_hudSync;
StringMap g_availableMusicKits;
ArrayList g_availableWeapons;

// Map
bool g_mapHasRespawnRoom;

// Game state
bool g_isBuyTimeActive;
bool g_isMainRoundActive;
bool g_isBonusRoundActive;
bool g_isBombPlanted;
bool g_isBombDetonated;
bool g_isBombDefused;
int g_bombPlantingTeam;

// ConVars
ConVar tfgo_buytime;
ConVar tfgo_buyzone_radius_override;
ConVar tfgo_bomb_timer;
ConVar tfgo_startmoney;
ConVar tfgo_maxmoney;
ConVar tfgo_cash_player_bomb_planted;
ConVar tfgo_cash_player_bomb_defused;
ConVar tfgo_cash_player_suicide_compensation;
ConVar tfgo_cash_team_win_bomb_detonated;
ConVar tfgo_cash_team_win_bomb_defused;
ConVar tfgo_cash_team_win_elimination;

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
Handle g_SDKCreateDroppedWeapon;
Handle g_SDKInitDroppedWeapon;

#include "tfgo/include/tfgo.inc"
#include "tfgo/musickits.sp"
MusicKit g_currentMusicKit;

#include "tfgo/stocks.sp"
#include "tfgo/config.sp"
#include "tfgo/methodmaps.sp"
#include "tfgo/sound.sp"
#include "tfgo/buymenu.sp"
#include "tfgo/buyzone.sp"
#include "tfgo/forward.sp"

public Plugin myinfo =  {
	name = "Team Fortress: Global Offensive Arena", 
	author = "Mikusch", 
	description = "A Team Fortress 2 gamemode inspired by Counter-Strike: Global Offensive", 
	version = "1.0", 
	url = "https://github.com/Mikusch/tfgo"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	Forward_AskLoad();
	RegPluginLibrary("tfgo");
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases.txt");
	LoadTranslations("tfgo.phrases.txt");
	
	// Initializing globals
	SDK_Init();
	MusicKit_Init();
	Config_Init();
	g_hudSync = CreateHudSynchronizer();
	
	// Events
	HookEvent("player_team", Event_Player_Team);
	HookEvent("player_death", Event_Player_Death);
	HookEvent("post_inventory_application", Event_Post_Inventory_Application);
	HookEvent("teamplay_round_start", Event_Teamplay_Round_Start);
	HookEvent("arena_round_start", Event_Arena_Round_Start);
	HookEvent("teamplay_broadcast_audio", Event_Pre_Teamplay_Broadcast_Audio, EventHookMode_Pre);
	HookEvent("teamplay_point_captured", Event_Teamplay_Point_Captured);
	HookEvent("arena_win_panel", Event_Arena_Win_Panel);
	HookEvent("arena_match_maxstreak", Event_Arena_Match_MaxStreak);
	
	// Collect ConVars
	tf_arena_first_blood = FindConVar("tf_arena_first_blood");
	tf_arena_round_time = FindConVar("tf_arena_round_time");
	tf_arena_use_queue = FindConVar("tf_arena_use_queue");
	tf_arena_preround_time = FindConVar("tf_arena_preround_time");
	tf_arena_override_cap_enable_time = FindConVar("tf_arena_override_cap_enable_time");
	tf_arena_max_streak = FindConVar("tf_arena_max_streak");
	tf_weapon_criticals = FindConVar("tf_weapon_criticals");
	tf_weapon_criticals_melee = FindConVar("tf_weapon_criticals_melee");
	mp_bonusroundtime = FindConVar("mp_bonusroundtime");
	
	// Create TFGO ConVars
	tfgo_buytime = CreateConVar("tfgo_buytime", "45", "How many seconds after spawning players can buy items for", _, true, tf_arena_preround_time.FloatValue);
	tfgo_buyzone_radius_override = CreateConVar("tfgo_buyzone_radius_override", "-1", "Overrides the default calculated buyzone radius on maps with no respawn room");
	tfgo_bomb_timer = CreateConVar("tfgo_bomb_timer", "45", "How long from when the bomb is planted until it blows", _, true, 15.0, true, tf_arena_round_time.FloatValue);
	tfgo_startmoney = CreateConVar("tfgo_startmoney", "800", "Amount of money each player gets when they reset");
	tfgo_maxmoney = CreateConVar("tfgo_maxmoney", "16000", "Maximum amount of money allowed in a player's account", _, true, tfgo_startmoney.FloatValue);
	tfgo_cash_player_bomb_planted = CreateConVar("tfgo_cash_player_bomb_planted", "300", "Cash award for each player that planted the bomb");
	tfgo_cash_player_bomb_defused = CreateConVar("tfgo_cash_player_bomb_defused", "300", "Cash award for each player that defused the bomb");
	tfgo_cash_player_suicide_compensation = CreateConVar("tfgo_cash_player_suicide_compensation", "300", "Compensation for an enemy player suiciding");
	tfgo_cash_team_win_bomb_detonated = CreateConVar("tfgo_cash_team_win_bomb_detonated", "3500", "Team cash award for winning by detonating the bomb");
	tfgo_cash_team_win_bomb_defused = CreateConVar("tfgo_cash_team_win_bomb_defused", "3500", "Team cash award for winning by defusing the bomb");
	tfgo_cash_team_win_elimination = CreateConVar("tfgo_cash_team_win_elimination", "3250", "Team cash award for winning by eliminating the enemy team");
	
	Toggle_ConVars(true);
	
	AddCommandListener(Client_BuildCommand, "build");
	AddCommandListener(Client_DestroyCommand, "destroy");
	
	for (int client = 1; client <= MaxClients; client++)
	{
		TFGOPlayer player = TFGOPlayer(client);
		player.ResetBalance();
		player.ClearLoadout();
	}
	
	CAddColor("negative", 0xEA4141);
	CAddColor("positive", 0xA2FF47);
}

public void OnPluginEnd()
{
	Toggle_ConVars(false);
	g_pickupWepPatch.Disable();
}

public void OnMapStart()
{
	// Allow players to buy stuff on the first round
	g_isBuyTimeActive = true;
	
	DHookGamerules(g_dHookSetWinningTeam, false);
	
	ResetGameState();
	
	PrecacheSounds();
	PrecacheModels();
	PrecacheParticleSystems();
	PrecacheMusicKits();
	
	// Pick random music kit for the game
	ChooseRandomMusicKit();
	
	int func_respawnroom = FindEntityByClassname(-1, "func_respawnroom");
	if (func_respawnroom <= -1)
	{
		g_mapHasRespawnRoom = false;
		
		LogMessage("This map is missing a func_respawnroom entity, calculating buy zones based on info_player_teamspawn entities");
		CalculateDynamicBuyZones();
	}
	else
	{
		g_mapHasRespawnRoom = true;
	}
}

public void OnClientConnected(int client)
{
	// Initialize new player with default values
	TFGOPlayer player = TFGOPlayer(client);
	player.ResetBalance();
	player.ClearLoadout();
}

public void OnGameFrame()
{
	if (!g_mapHasRespawnRoom && g_isBuyTimeActive)
	{
		for (int client = 1; client <= MaxClients; client++)
		{
			DisplayMenuInDynamicBuyZone(client);
		}
	}
}

public void OnClientDisconnect(int client)
{
	if (g_isBombPlanted)
	{
		// TODO team alive check to  end the round during bomb plant
	}
}

public void ChooseRandomMusicKit()
{
	StringMapSnapshot snapshot = g_availableMusicKits.Snapshot();
	char name[PLATFORM_MAX_PATH];
	snapshot.GetKey(GetRandomInt(0, snapshot.Length - 1), name, sizeof(name));
	delete snapshot;
	
	g_availableMusicKits.GetArray(name, g_currentMusicKit, sizeof(g_currentMusicKit));
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "func_respawnroom"))
	{
		SDKHook(entity, SDKHook_StartTouch, Hook_OnStartTouchBuyZone);
		SDKHook(entity, SDKHook_EndTouch, Hook_OnEndTouchBuyZone);
	}
	else if (StrEqual(classname, "trigger_capture_area"))
	{
		SDKHook(entity, SDKHook_SpawnPost, OnCaptureAreaSpawned);
	}
}

public void OnCaptureAreaSpawned(int entity)
{
	SetEntPropFloat(entity, Prop_Data, "m_flCapTime", GetEntPropFloat(entity, Prop_Data, "m_flCapTime") / 2);
}

// Prevent round from ending, called every frame after the round is supposed to end
public MRESReturn Hook_SetWinningTeam(Handle hParams)
{
	int team = DHookGetParam(hParams, 1);
	int winReason = DHookGetParam(hParams, 2);
	
	// Bomb is detonated but game wants to award elimination win on multi-CP maps, rewrite it to make it look like a capture
	if (g_isBombDetonated && winReason == view_as<int>(Winreason_Elimination))
	{
		DHookSetParam(hParams, 2, view_as<int>(Winreason_PointCaptured));
		return MRES_ChangedHandled;
	}
	
	// Bomb is defused but game wants to award elimination win on multi-CP maps, rewrite it to make it look like a capture
	else if (g_isBombDefused && team != g_bombPlantingTeam && winReason == view_as<int>(Winreason_Elimination))
	{
		DHookSetParam(hParams, 2, view_as<int>(Winreason_PointCaptured));
		return MRES_ChangedHandled;
	}
	// Sometimes the game is stupid and gives defuse win to the planting team, this should prevent that
	else if (g_isBombDefused && team == g_bombPlantingTeam)
	{
		return MRES_Supercede;
	}
	
	// If this is a capture win from planting the bomb we supercede it, otherwise ignore to grant the defusal win
	else if (g_isBombPlanted && team == g_bombPlantingTeam && (winReason == view_as<int>(Winreason_PointCaptured) || winReason == view_as<int>(Winreason_AllPointsCaptured)))
	{
		return MRES_Supercede;
	}
	
	// Planting team was killed while the bomb was active, do not give elimination win to enemy team
	else if (g_isBombPlanted && team != g_bombPlantingTeam && winReason == view_as<int>(Winreason_Elimination))
	{
		return MRES_Supercede;
	}
	
	// Stalemate
	else if (team == view_as<int>(TFTeam_Unassigned) && winReason == view_as<int>(Winreason_Stalemate))
	{
		TFGOTeam red = TFGOTeam(TFTeam_Red);
		TFGOTeam blue = TFGOTeam(TFTeam_Blue);
		red.AddToTeamBalance(0, "No income for running out of time and surviving");
		blue.AddToTeamBalance(0, "No income for running out of time and surviving");
		red.LoseStreak++;
		blue.LoseStreak++;
		return MRES_Ignored;
	}
	
	// Everything else that doesn't require superceding e.g. eliminating the enemy team
	else
	{
		return MRES_Ignored;
	}
}

public MRESReturn Hook_PickupWeaponFromOther(int client, Handle returnVal, Handle params)
{
	int weapon = DHookGetParam(params, 1); // tf_dropped_weapon
	int defindex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
	TFGOPlayer(client).AddToLoadout(defindex);
}

public Action Event_Player_Team(Event event, const char[] name, bool dontBroadcast)
{
	TFTeam team = view_as<TFTeam>(event.GetInt("team"));
	
	// Cap balance at highest of the team
	int highestBalance = tfgo_startmoney.IntValue;
	for (int client = 1; client <= MaxClients; client++)
	{
		int balance = TFGOPlayer(client).Balance;
		if (IsClientInGame(client) && TF2_GetClientTeam(client) == team && balance > highestBalance)
			highestBalance = balance;
	}
	
	TFGOPlayer player = TFGOPlayer(GetClientOfUserId(event.GetInt("userid")));
	if (player.Balance > highestBalance)
		player.Balance = highestBalance;
	
	player.ClearLoadout();
}

public Action Event_Player_Death(Event event, const char[] name, bool dontBroadcast)
{
	TFGOPlayer attacker = TFGOPlayer(GetClientOfUserId(event.GetInt("attacker")));
	TFGOPlayer victim = TFGOPlayer(GetClientOfUserId(event.GetInt("userid")));
	TFGOPlayer assister = TFGOPlayer(GetClientOfUserId(event.GetInt("assister")));
	int customkill = event.GetInt("customkill");
	int defindex = event.GetInt("weapon_def_index");
	int inflictorEntindex = event.GetInt("inflictor_entindex");
	char weapon[256];
	event.GetString("weapon", weapon, sizeof(weapon));
	
	char victimName[256];
	GetClientName(victim.Client, victimName, sizeof(victimName));
	
	int killAward;
	char msg[256];
	if (attacker.Client >= 1 && attacker.Client <= MaxClients)
	{
		// Entity kill (sentry gun, sandman ball etc.)
		if (inflictorEntindex >= MaxClients)
		{
			char classname[256];
			GetEntityClassname(inflictorEntindex, classname, sizeof(classname));
			g_weaponClassKillAwards.GetValue(weapon, killAward);
			// TODO: More specific messages?
			msg = "Award for neutralizing an enemy";
		}
		
		if (customkill == TF_CUSTOM_SUICIDE && attacker == victim) // Suicide
		{
			if (g_isMainRoundActive)
			{
				// Re-assign attacker to random enemy player
				ArrayList enemies = new ArrayList();
				for (int client = 1; client <= MaxClients; client++)
				{
					if (IsClientInGame(client) && GetClientTeam(client) != GetClientTeam(attacker.Client))
						enemies.Push(client);
				}
				attacker = TFGOPlayer(enemies.Get(GetRandomInt(0, enemies.Length - 1)));
				delete enemies;
				
				killAward = tfgo_cash_player_suicide_compensation.IntValue;
				Format(msg, sizeof(msg), "Compensation for the suicide of %s", victimName);
				PrintToChatAll("An enemy player was awarded compensation for the suicide of %s.", victimName);
			}
		}
		else if (strcmp(weapon, "world") == 0) // Environmental kill
		{
			g_weaponClassKillAwards.GetValue(weapon, killAward);
			msg = "Award for neutralizing an enemy using the environment";
		}
		else if (killAward == 0) // Get kill award from weapon
		{
			killAward = GetEffectiveKillAward(defindex);
			char weaponName[256];
			TF2_GetItemName(defindex, weaponName, sizeof(weaponName));
			Format(msg, sizeof(msg), "Award for neutralizing an enemy with %s", weaponName);
		}
		
		if (killAward != 0)
		{
			// Grant kill award
			attacker.AddToBalance(killAward, msg);
			
			// Grant assist award
			if (assister.Client >= 1 && assister.Client <= MaxClients)
			{
				Format(msg, sizeof(msg), "Award for assisting in neutralizing %s", victimName);
				assister.AddToBalance(killAward / 2, msg);
			}
		}
	}
	
	if (g_isBombPlanted)
	{
		int victimTeam = GetClientTeam(GetClientOfUserId(event.GetInt("userid")));
		// End the round if every member of the non-planting team died
		if (g_bombPlantingTeam != victimTeam && GetAlivePlayersInTeam(victimTeam) - 1 <= 0) // -1 because it doesn't work properly in player_death
			g_isBombPlanted = false;
	}
	
	if (g_isMainRoundActive || g_isBonusRoundActive)
		victim.ClearLoadout();
	
	if (victim.ActiveBuyMenu != null)
		victim.ActiveBuyMenu.Cancel();
}

public Action Event_Post_Inventory_Application(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsClientInGame(client))
	{
		TFGOPlayer player = TFGOPlayer(client);
		player.ShowMoneyHudDisplay(tfgo_buytime.FloatValue);
		player.ApplyLoadout();
		
		// Cancel active buy menu or OnGameFrame will throw a million errors
		if (player.ActiveBuyMenu != null)
			player.ActiveBuyMenu.Cancel();
		
		// func_respawnroom OnStartTouch doesn't fire thus buy menu doesn't get re-opened so we do it manually
		if (g_mapHasRespawnRoom)
			DisplaySlotSelectionMenu(client);
	}
}

public Action Event_Teamplay_Round_Start(Event event, const char[] name, bool dontBroadcast)
{
	g_isBombDetonated = false;
	g_isBonusRoundActive = false;
	g_isMainRoundActive = false;
	g_buyTimeTimer = CreateTimer(tfgo_buytime.FloatValue, OnBuyTimeExpire, _, TIMER_FLAG_NO_MAPCHANGE);
	
	g_currentMusicKit.StopMusicForAll(Music_WonRound);
	g_currentMusicKit.StopMusicForAll(Music_LostRound);
	g_currentMusicKit.PlayMusicToAll(Music_StartRound);
	
	// Bomb can freely tick and explode through the bonus time and we cancel it here
	g_bombBeepingTimer = null;
	g_bombDetonationWarningTimer = null;
	g_bombDetonationTimer = null;
}

public Action OnBuyTimeExpire(Handle timer)
{
	if (g_buyTimeTimer != timer)return;
	
	g_isBuyTimeActive = false;
	
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
	g_10SecondRoundTimer = CreateTimer(tf_arena_round_time.FloatValue - 11.0, Play10SecondWarning, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Play10SecondWarning(Handle timer)
{
	if (g_10SecondRoundTimer != timer)return;
	
	g_currentMusicKit.StopMusicForAll(Music_StartAction);
	g_currentMusicKit.PlayMusicToAll(Music_RoundTenSecCount);
}

public Action Event_Teamplay_Point_Captured(Event event, const char[] name, bool dontBroadcast)
{
	int team = event.GetInt("team");
	char[] cappers = new char[MaxClients];
	event.GetString("cappers", cappers, MaxClients);
	
	ArrayList capperList = new ArrayList();
	for (int i = 0; i < strlen(cappers); i++)
	{
		int capper = cappers[i];
		capperList.Push(capper);
	}
	
	g_isBombPlanted = !g_isBombPlanted;
	if (g_isBombPlanted)
		PlantBomb(team, event.GetInt("cp"), capperList);
	else
		DefuseBomb(team, capperList);
}

void PlantBomb(int team, int cp, ArrayList cappers)
{
	g_bombPlantingTeam = team;
	
	// Award capture bonus to cappers
	for (int i = 0; i < cappers.Length; i++)
	{
		int capper = cappers.Get(i);
		TFGOPlayer(capper).AddToBalance(tfgo_cash_player_bomb_planted.IntValue, "Award for planting the bomb");
	}
	
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
		SetVariantInt(tfgo_bomb_timer.IntValue + 1);
		AcceptEntityInput(team_round_timer, "SetTime");
	}
	
	int team_control_point;
	while ((team_control_point = FindEntityByClassname(team_control_point, "team_control_point")) > -1)
	{
		// Lock every other control point in the map
		if (GetEntProp(team_control_point, Prop_Data, "m_iPointIndex") != cp)
		{
			SetVariantInt(1);
			AcceptEntityInput(team_control_point, "SetLocked");
		}
		else
		{
			// Spawn bomb prop on CP
			// TODO: Set skin of bomb to team color
			float m_vecOrigin[3];
			GetEntPropVector(team_control_point, Prop_Send, "m_vecOrigin", m_vecOrigin);
			float m_angRotation[3];
			GetEntPropVector(team_control_point, Prop_Send, "m_angRotation", m_angRotation);
			
			int bomb = CreateEntityByName("prop_dynamic_override");
			SetEntityModel(bomb, BOMB_MODEL);
			DispatchSpawn(bomb);
			TeleportEntity(bomb, m_vecOrigin, m_angRotation, NULL_VECTOR);
			
			// Set up timers
			g_10SecondBombTimer = CreateTimer(tfgo_bomb_timer.FloatValue - 10.0, Play10SecondBombWarning, _, TIMER_FLAG_NO_MAPCHANGE);
			g_bombBeepingTimer = CreateTimer(1.0, PlayBombBeep, EntIndexToEntRef(bomb), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
			g_bombDetonationWarningTimer = CreateTimer(tfgo_bomb_timer.FloatValue - 1.5, PlayBombExplosionWarning, EntIndexToEntRef(bomb), TIMER_FLAG_NO_MAPCHANGE);
			g_bombDetonationTimer = CreateTimer(tfgo_bomb_timer.FloatValue, DetonateBomb, EntIndexToEntRef(bomb), TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	
	int trigger_capture_area;
	while ((trigger_capture_area = FindEntityByClassname(trigger_capture_area, "trigger_capture_area")) > -1)
	{
		// Adjust defuse time
		SetEntPropFloat(trigger_capture_area, Prop_Data, "m_flCapTime", GetEntPropFloat(trigger_capture_area, Prop_Data, "m_flCapTime") / 0.75);
	}
	
	// Play Sounds
	g_currentMusicKit.StopMusicForAll(Music_StartAction);
	g_currentMusicKit.StopMusicForAll(Music_RoundTenSecCount);
	g_currentMusicKit.PlayMusicToAll(Music_BombPlanted);
	PlayAnnouncerBombAlert();
	ShoutBombWarnings();
	
	// Reset timers
	g_10SecondRoundTimer = null;
	
	// Show text on screen
	char message[256] = "The bomb has been planted.\n%d seconds to detonation.";
	Format(message, sizeof(message), message, tfgo_bomb_timer.IntValue);
	ShowGameMessage(message, "ico_notify_sixty_seconds");
	
	Forward_BombPlanted(team, cappers);
}

public Action PlayBombBeep(Handle timer, int bomb)
{
	if (g_bombBeepingTimer != timer)return Plugin_Stop;
	
	float m_vecOrigin[3];
	GetEntPropVector(bomb, Prop_Send, "m_vecOrigin", m_vecOrigin);
	EmitAmbientSound("player/cyoa_pda_beep3.wav", m_vecOrigin, bomb);
	return Plugin_Continue;
}

public Action Play10SecondBombWarning(Handle timer)
{
	if (g_10SecondBombTimer != timer)return;
	
	g_currentMusicKit.StopMusicForAll(Music_BombPlanted);
	g_currentMusicKit.PlayMusicToAll(Music_BombTenSecCount);
}

public Action PlayBombExplosionWarning(Handle timer, int bomb)
{
	if (g_bombDetonationWarningTimer != timer)return;
	
	float m_vecOrigin[3];
	GetEntPropVector(bomb, Prop_Send, "m_vecOrigin", m_vecOrigin);
	EmitAmbientSound("mvm/mvm_bomb_warning.wav", m_vecOrigin, bomb, SNDLEVEL_RAIDSIREN);
}

public Action DetonateBomb(Handle timer, int bombRef)
{
	if (g_bombDetonationTimer != timer)return;
	
	g_isBombDetonated = true;
	g_isBombPlanted = false;
	
	// Only call this after we set g_isBombPlanted to false or the game softlocks
	TF2_ForceRoundWin(view_as<TFTeam>(g_bombPlantingTeam), view_as<int>(Winreason_AllPointsCaptured));
	
	g_bombBeepingTimer = null; // Or else this timer will try to get m_vecOrigin from a deleted bomb
	
	int bomb = EntRefToEntIndex(bombRef);
	float m_vecOrigin[3];
	GetEntPropVector(bomb, Prop_Send, "m_vecOrigin", m_vecOrigin);
	TF2_Explode(_, m_vecOrigin, 500.0, 800.0, BOMB_EXPLOSION_PARTICLE, "mvm/mvm_bomb_explode.wav");
	RemoveEntity(bomb);
	
	Forward_BombDetonated(g_bombPlantingTeam);
}

void DefuseBomb(int team, ArrayList cappers)
{
	g_bombBeepingTimer = null;
	g_10SecondBombTimer = null;
	g_bombDetonationWarningTimer = null;
	g_bombDetonationTimer = null;
	
	for (int i = 0; i < cappers.Length; i++)
	{
		int capper = cappers.Get(i);
		TFGOPlayer(capper).AddToBalance(tfgo_cash_player_bomb_defused.IntValue, "Award for defusing the bomb");
	}
	
	g_isBombDefused = true;
	TF2_ForceRoundWin(view_as<TFTeam>(team), view_as<int>(Winreason_PointCaptured));
	
	Forward_BombDefused(team, cappers);
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
	if (winreason == view_as<int>(Winreason_PointCaptured) || winreason == view_as<int>(Winreason_AllPointsCaptured))
	{
		if (g_bombPlantingTeam == event.GetInt("winning_team"))
			winningTeam.AddToTeamBalance(tfgo_cash_team_win_bomb_detonated.IntValue, "Team award for detonating bomb");
		else
			winningTeam.AddToTeamBalance(tfgo_cash_team_win_bomb_defused.IntValue, "Team award for winning by defusing the bomb");
	}
	else if (winreason == view_as<int>(Winreason_Elimination))
	{
		winningTeam.AddToTeamBalance(tfgo_cash_team_win_elimination.IntValue, "Team award for eliminating the enemy team");
	}
	
	losingTeam.AddToTeamBalance(losingTeam.LoseIncome, "Income for losing");
	
	// Adjust team losing streaks
	losingTeam.LoseStreak++;
	winningTeam.LoseStreak--;
	
	// Reset timers
	g_10SecondRoundTimer = null;
	g_10SecondBombTimer = null;
	
	// Reset game state
	ResetGameState();
}

public void ResetGameState()
{
	g_isBombPlanted = false;
	g_isBombDetonated = false;
	g_isBombDefused = false;
}

public Action Event_Arena_Match_MaxStreak(Event event, const char[] name, bool dontBroadcast)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		TFGOPlayer player = TFGOPlayer(client);
		player.ResetBalance();
		player.ClearLoadout();
	}
	
	for (int team = 0; team < view_as<int>(TFTeam_Blue); team++)
	TFGOTeam(view_as<TFTeam>(team)).ResetLoseStreak();
	
	ChooseRandomMusicKit();
}

public Action Client_BuildCommand(int client, const char[] command, int args)
{
	// Check if player owns Construction PDA
	if (TFGOPlayer(client).GetWeaponFromLoadout(TFClass_Engineer, WeaponSlot_PDABuild) != -1)
		return Plugin_Continue;
	
	// Block build by default
	return Plugin_Handled;
}

public Action Client_DestroyCommand(int client, const char[] command, int args)
{
	// Check if player owns Destruction PDA
	if (TFGOPlayer(client).GetWeaponFromLoadout(TFClass_Engineer, WeaponSlot_PDADestroy) != -1)
		return Plugin_Continue;
	
	// Block destroy by default
	return Plugin_Handled;
}

void PrecacheModels()
{
	PrecacheModel(BOMB_MODEL);
}

void PrecacheParticleSystems()
{
	PrecacheParticleSystem(BOMB_EXPLOSION_PARTICLE);
}

void Toggle_ConVars(bool toggle)
{
	static bool arenaFirstBlood;
	static bool arenaUseQueue;
	static int arenaPreRoundTime;
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
		
		arenaPreRoundTime = tf_arena_preround_time.IntValue;
		tf_arena_preround_time.IntValue = 15;
		
		arenaRoundTime = tf_arena_round_time.IntValue;
		tf_arena_round_time.IntValue = 135;
		
		arenaOverrideCapEnableTime = tf_arena_override_cap_enable_time.IntValue;
		tf_arena_override_cap_enable_time.IntValue = 15;
		
		arenaMaxStreak = tf_arena_max_streak.IntValue;
		tf_arena_max_streak.IntValue = 8;
		
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
		tf_arena_preround_time.IntValue = arenaPreRoundTime;
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
	GameData config = new GameData("tfgo");
	
	Handle hook = DHookCreateFromConf(config, "CTFPlayer::PickupWeaponFromOther");
	if (hook == null)
		LogMessage("Failed to create hook: CTFPlayer::PickupWeaponFromOther");
	else
		DHookEnableDetour(hook, false, Hook_PickupWeaponFromOther);
	delete hook;
	
	int offset = GameConfGetOffset(config, "SetWinningTeam");
	g_dHookSetWinningTeam = DHookCreate(offset, HookType_GameRules, ReturnType_Void, ThisPointer_Ignore, Hook_SetWinningTeam);
	DHookAddParam(g_dHookSetWinningTeam, HookParamType_Int);
	DHookAddParam(g_dHookSetWinningTeam, HookParamType_Int);
	DHookAddParam(g_dHookSetWinningTeam, HookParamType_Bool);
	DHookAddParam(g_dHookSetWinningTeam, HookParamType_Bool);
	DHookAddParam(g_dHookSetWinningTeam, HookParamType_Bool);
	DHookAddParam(g_dHookSetWinningTeam, HookParamType_Bool);
	if (g_dHookSetWinningTeam == null)
		LogMessage("Failed to create hook: SetWinningTeam");
	
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
	
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(config, SDKConf_Signature, "CTFDroppedWeapon::Create");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_QAngle, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	g_SDKCreateDroppedWeapon = EndPrepSDKCall();
	if (g_SDKCreateDroppedWeapon == null)
		LogMessage("Failed to create call: CTFDroppedWeapon::Create");
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(config, SDKConf_Signature, "CTFDroppedWeapon::InitDroppedWeapon");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	g_SDKInitDroppedWeapon = EndPrepSDKCall();
	if (g_SDKInitDroppedWeapon == null)
		LogMessage("Failed to create call: CTFDroppedWeapon::InitDroppedWeapon");
	
	MemoryPatch.SetGameData(config);
	g_pickupWepPatch = new MemoryPatch("Patch_PickupWeaponFromOther");
	if (g_pickupWepPatch != null)
		g_pickupWepPatch.Enable();
	
	delete config;
}
