#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <dhooks>
#include <memorypatch>
#include <morecolors>
#include <tf_econ_data>
#include <tfgo>

#pragma newdecls required


#define PLUGIN_VERSION "1.0"
#define PLUGIN_VERSION_REVISION "manual"

#define TF_MAXPLAYERS 32

#define MODEL_BOMB "models/props_td/atom_bomb.mdl"

#define PARTICLE_BOMB_EXPLOSION "mvm_hatch_destroy"

#define SOUND_BOMB_BEEPING ")player/cyoa_pda_beep3.wav"
#define GAMESOUND_BOMB_EXPLOSION "MVM.BombExplodes"
#define GAMESOUND_BOMB_WARNING "MVM.BombWarning"
#define GAMESOUND_PLAYER_PURCHASE "MVM.PlayerUpgraded"
#define GAMESOUND_ANNOUNCER_BOMB_PLANTED "Announcer.SecurityAlert"
#define GAMESOUND_ANNOUNCER_TEAM_SCRAMBLE "Announcer.AM_TeamScrambleRandom"

#define BOMB_EXPLOSION_DAMAGE 500.0
#define BOMB_EXPLOSION_RADIUS 800.0

#define MIN_CONSECUTIVE_LOSSES 0
#define STARTING_CONSECUTIVE_LOSSES 1

#define HELMET_PRICE 350
#define KEVLAR_PRICE 650
#define ASSAULTSUIT_PRICE 1000


const TFTeam TFTeam_CT = TFTeam_Red;
const TFTeam TFTeam_T = TFTeam_Blue;

// Source hit group standards (from shareddefs.h)
enum
{
	HITGROUP_GENERIC = 0, 
	HITGROUP_HEAD, 
	HITGROUP_CHEST, 
	HITGROUP_STOMACH, 
	HITGROUP_LEFTARM, 
	HITGROUP_RIGHTARM, 
	HITGROUP_LEFTLEG, 
	HITGROUP_RIGHTLEG, 
	HITGROUP_GEAR
};

// Buy menu results (from cs_player.h)
enum BuyResult
{
	BUY_BOUGHT, 
	BUY_ALREADY_HAVE, 
	BUY_CANT_AFFORD, 
	BUY_PLAYER_CANT_BUY, 
	BUY_NOT_ALLOWED, 
	BUY_INVALID_ITEM, 
};

// TF2 arena win reasons
enum
{
	WinReason_PointCaptured = 1, 
	WinReason_Elimination, 
	WinReason_AllPointsCaptured = 4, 
	WinReason_Stalemate
};

// TF2 weapon loadout slots
enum
{
	WeaponSlot_Primary = 0, 
	WeaponSlot_Secondary, 
	WeaponSlot_Melee, 
	WeaponSlot_PDABuild, 
	WeaponSlot_PDADisguise = 3, 
	WeaponSlot_PDADestroy, 
	WeaponSlot_InvisWatch = 4, 
	WeaponSlot_BuilderEngie, 
	WeaponSlot_Unknown1, 
	WeaponSlot_Head, 
	WeaponSlot_Misc1, 
	WeaponSlot_Action, 
	WeaponSlot_Misc2
};

// TF2 item qualities
enum TFQuality
{
	TFQual_None = -1, 
	TFQual_Normal = 0, 
	TFQual_Genuine, 
	TFQual_Rarity2, 
	TFQual_Vintage, 
	TFQual_Rarity3, 
	TFQual_Unusual, 
	TFQual_Unique, 
	TFQual_Community, 
	TFQual_Developer, 
	TFQual_Selfmade, 
	TFQual_Customized, 
	TFQual_Strange, 
	TFQual_Completed, 
	TFQual_Haunted, 
	TFQual_Collectors, 
	TFQual_Decorated
};


// Timers
Handle g_BuyTimeTimer;
Handle g_TenSecondRoundTimer;
Handle g_TenSecondBombTimer;
Handle g_BombDetonationTimer;
Handle g_BombExplosionTimer;

// Other handles
MemoryPatch g_PickupWeaponPatch;
StringMap g_AvailableMusicKits;
ArrayList g_AvailableWeapons;

// Map
bool g_MapHasRespawnRoom;

// Bomb & Bomb Site
int g_BombRef;
int g_BombSiteRef;
float g_BombPlantedTime;
float g_BombNextBeepTime;
bool g_IsBombTicking;

// Game state
bool g_IsBuyTimeActive;
bool g_IsMainRoundActive;
bool g_IsBonusRoundActive;
bool g_IsBombPlanted;

TFTeam g_BombPlantingTeam;
bool g_HasPlayerSuicided[TF_MAXPLAYERS + 1];
bool g_IsPlayerInDynamicBuyZone[TF_MAXPLAYERS + 1];
int g_RoundsPlayed;

// ConVars
ConVar tfgo_all_weapons_can_headshot;
ConVar tfgo_free_armor;
ConVar tfgo_max_armor;
ConVar tfgo_buytime;
ConVar tfgo_consecutive_loss_max;
ConVar tfgo_buyzone_radius_override;
ConVar tfgo_bombtimer;
ConVar tfgo_maxrounds;
ConVar tfgo_halftime;
ConVar tfgo_startmoney;
ConVar tfgo_maxmoney;
ConVar tfgo_cash_player_bomb_planted;
ConVar tfgo_cash_player_bomb_defused;
ConVar tfgo_cash_player_killed_enemy_default;
ConVar tfgo_cash_player_killed_enemy_factor;
ConVar tfgo_cash_team_elimination;
ConVar tfgo_cash_team_loser_bonus;
ConVar tfgo_cash_team_loser_bonus_consecutive_rounds;
ConVar tfgo_cash_team_terrorist_win_bomb;
ConVar tfgo_cash_team_win_by_defusing_bomb;
ConVar tfgo_cash_team_planted_bomb_but_defused;

ConVar tf_arena_first_blood;
ConVar tf_arena_round_time;
ConVar tf_arena_use_queue;
ConVar tf_arena_preround_time;
ConVar tf_arena_override_cap_enable_time;
ConVar tf_weapon_criticals;
ConVar tf_weapon_criticals_melee;
ConVar mp_bonusroundtime;


#include "tfgo/musickits.sp"
MusicKit g_CurrentMusicKit;

#include "tfgo/stocks.sp"
#include "tfgo/config.sp"
#include "tfgo/methodmaps.sp"
#include "tfgo/sound.sp"
#include "tfgo/buymenu.sp"
#include "tfgo/buyzone.sp"
#include "tfgo/forward.sp"
#include "tfgo/native.sp"
#include "tfgo/sdk.sp"


public Plugin pluginInfo =  {
	name = "Team Fortress: Global Offensive Arena", 
	author = "Mikusch", 
	description = "A Team Fortress 2 gamemode inspired by Counter-Strike: Global Offensive", 
	version = PLUGIN_VERSION..."."...PLUGIN_VERSION_REVISION, 
	url = "https://github.com/Mikusch/tfgo"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	Forward_AskLoad();
	Native_AskLoad();
	RegPluginLibrary("tfgo");
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases.txt");
	LoadTranslations("tfgo.phrases.txt");
	
	// Events
	HookEvent("player_team", Event_Player_Team);
	HookEvent("player_death", Event_Player_Death);
	HookEvent("post_inventory_application", Event_Post_Inventory_Application);
	HookEvent("teamplay_round_start", Event_Teamplay_Round_Start);
	HookEvent("arena_round_start", Event_Arena_Round_Start);
	HookEvent("teamplay_broadcast_audio", Event_Pre_Teamplay_Broadcast_Audio, EventHookMode_Pre);
	HookEvent("teamplay_point_captured", Event_Teamplay_Point_Captured);
	HookEvent("arena_win_panel", Event_Arena_Win_Panel);
	
	// Collect ConVars
	tf_arena_first_blood = FindConVar("tf_arena_first_blood");
	tf_arena_round_time = FindConVar("tf_arena_round_time");
	tf_arena_use_queue = FindConVar("tf_arena_use_queue");
	tf_arena_preround_time = FindConVar("tf_arena_preround_time");
	tf_arena_override_cap_enable_time = FindConVar("tf_arena_override_cap_enable_time");
	tf_weapon_criticals = FindConVar("tf_weapon_criticals");
	tf_weapon_criticals_melee = FindConVar("tf_weapon_criticals_melee");
	mp_bonusroundtime = FindConVar("mp_bonusroundtime");
	
	// Create TFGO ConVars
	tfgo_all_weapons_can_headshot = CreateConVar("tfgo_all_weapons_can_headshot", "0", "Whether all weapons that deal bullet damage should be able to headshot");
	tfgo_free_armor = CreateConVar("tfgo_free_armor", "0", "Determines whether kevlar (1+) and/or helmet (2+) are given automatically", _, true, 0.0, true, 2.0);
	tfgo_max_armor = CreateConVar("tfgo_max_armor", "2", "Determines the highest level of armor allowed to be purchased. (0) None, (1) Kevlar, (2) Helmet", _, true, 0.0, true, 2.0);
	tfgo_buytime = CreateConVar("tfgo_buytime", "20", "How many seconds after spawning players can buy items for", _, true, tf_arena_preround_time.FloatValue);
	tfgo_consecutive_loss_max = CreateConVar("tfgo_consecutive_loss_max", "4", "The maximum of consecutive losses for each team that will be kept track of", _, true, float(STARTING_CONSECUTIVE_LOSSES));
	tfgo_buyzone_radius_override = CreateConVar("tfgo_buyzone_radius_override", "-1", "Overrides the default calculated buyzone radius on maps with no respawn room");
	tfgo_bombtimer = CreateConVar("tfgo_bombtimer", "40", "How long from when the bomb is planted until it blows", _, true, 10.0);
	tfgo_maxrounds = CreateConVar("tfgo_maxrounds", "15", "Maximum number of rounds to play before a team scramble occurs", _, true, 0.0);
	tfgo_halftime = CreateConVar("tfgo_halftime", "1", "Determines whether the match switches sides in a halftime event");
	tfgo_startmoney = CreateConVar("tfgo_startmoney", "800", "Amount of money each player gets when they reset", _, true, 0.0);
	tfgo_maxmoney = CreateConVar("tfgo_maxmoney", "16000", "Maximum amount of money allowed in a player's account", _, true, 0.0);
	tfgo_cash_player_bomb_planted = CreateConVar("tfgo_cash_player_bomb_planted", "300", "Cash award for each player that planted the bomb");
	tfgo_cash_player_bomb_defused = CreateConVar("tfgo_cash_player_bomb_defused", "300", "Cash award for each player that defused the bomb");
	tfgo_cash_player_killed_enemy_default = CreateConVar("tfgo_cash_player_killed_enemy_default", "300", "Default cash award for eliminating an enemy player");
	tfgo_cash_player_killed_enemy_factor = CreateConVar("tfgo_cash_player_killed_enemy_factor", "1", "The factor each kill award is multiplied with");
	tfgo_cash_team_elimination = CreateConVar("tfgo_cash_team_elimination", "3250", "Team cash award for winning by eliminating the enemy team");
	tfgo_cash_team_loser_bonus = CreateConVar("tfgo_cash_team_loser_bonus", "1400", "Team cash bonus for losing");
	tfgo_cash_team_loser_bonus_consecutive_rounds = CreateConVar("tfgo_cash_team_loser_bonus_consecutive_rounds", "500", "Team cash bonus for losing consecutive rounds");
	tfgo_cash_team_terrorist_win_bomb = CreateConVar("tfgo_cash_team_terrorist_win_bomb", "3500", "Team cash award for winning by detonating the bomb");
	tfgo_cash_team_win_by_defusing_bomb = CreateConVar("tfgo_cash_team_win_by_defusing_bomb", "3500", "Team cash award for winning by defusing the bomb");
	tfgo_cash_team_planted_bomb_but_defused = CreateConVar("tfgo_cash_team_planted_bomb_but_defused", "800", "Team cash bonus for planting the bomb and losing");
	
	Toggle_ConVars(true);
	
	// Initializing globals
	SDK_Init();
	MusicKit_Init();
	Config_Init();
	
	AddCommandListener(CommandListener_Build, "build");
	AddCommandListener(CommandListener_Destroy, "destroy");
	
	CAddColor("negative", 0xEA4141);
	CAddColor("positive", 0xA2FF47);
	
	// In case of late plugin load
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientConnected(client))
			OnClientConnected(client);
		
		if (IsClientInGame(client))
			OnClientPutInServer(client);
	}
}

public void OnPluginEnd()
{
	Toggle_ConVars(false);
	
	for (int client = 1; client <= MaxClients; client++)
	{
		SDK_UnhookClientEntity(client);
	}
	
	if (g_PickupWeaponPatch != null)
		g_PickupWeaponPatch.Disable();
}

public void OnMapStart()
{
	// Allow players to buy stuff on the first round
	g_IsBuyTimeActive = true;
	
	SDK_HookGamerules();
	ResetRoundState();
	
	PrecacheSounds();
	PrecacheModels();
	PrecacheParticleSystems();
	PrecacheMusicKits();
	
	// Pick random music kit for the game
	ChooseRandomMusicKit();
	
	if (FindEntityByClassname(MaxClients + 1, "func_respawnroom") > -1)
	{
		g_MapHasRespawnRoom = true;
	}
	else
	{
		g_MapHasRespawnRoom = false;
		CalculateDynamicBuyZones();
	}
}

public void OnClientConnected(int client)
{
	TFGOPlayer(client).Reset();
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_PreThink, Client_PreThink);
	SDKHook(client, SDKHook_TraceAttack, Client_TraceAttack);
	SDK_HookClientEntity(client);
}

public void Client_PreThink(int client)
{
	TFGOPlayer player = TFGOPlayer(client);
	
	SetHudTextParams(0.05, 0.325, 0.1, 162, 255, 71, 255, _, 0.0, 0.0, 0.0);
	ShowHudText(client, -1, "$%d", player.Account);
	
	if (player.ArmorValue > 0)
	{
		SetHudTextParams(-1.0, 0.85, 0.1, 255, 255, 255, 255, _, 0.0, 0.0, 0.0);
		ShowHudText(client, -1, "%T", "HUD_Armor", LANG_SERVER, player.ArmorValue);
	}
	
	if (!g_MapHasRespawnRoom && g_IsBuyTimeActive)
		DisplayMenuInDynamicBuyZone(client);
}

public void OnClientDisconnect(int client)
{
	SDKUnhook(client, SDKHook_PreThink, Client_PreThink);
	SDKUnhook(client, SDKHook_TraceAttack, Client_TraceAttack);
	SDK_UnhookClientEntity(client);
	
	// Force-end round if last client in team disconnects during active bomb
	if (g_IsBombPlanted && IsValidClient(client))
	{
		TFTeam team = TF2_GetClientTeam(client);
		if (team > TFTeam_Spectator && g_BombPlantingTeam != team && GetAlivePlayerCountForTeam(team) <= 0)
			g_IsBombPlanted = false;
	}
}

public Action Client_TraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
	bool changed;
	
	// Allow every weapon with damagetype DMG_BULLET or DMG_BUCKSHOT to deal crits on headshot
	if (tfgo_all_weapons_can_headshot.BoolValue && damagetype & (DMG_BULLET | DMG_BUCKSHOT))
	{
		damagetype |= DMG_USE_HITLOCATIONS;
		changed = true;
	}
	
	// Hitgroup damage modifiers (headshots are already covered by DMG_USE_HITLOCATIONS)
	switch (hitgroup)
	{
		case HITGROUP_STOMACH:
		{
			damage *= 1.25;
			changed = true;
		}
		case HITGROUP_LEFTLEG, HITGROUP_RIGHTLEG:
		{
			damage *= 0.75;
			changed = true;
		}
	}
	
	// Armor damage reduction
	TFGOPlayer player = TFGOPlayer(victim);
	if (!(damagetype & (DMG_FALL | DMG_DROWN)) && player.IsArmored(hitgroup))
	{
		int weapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
		if (weapon != -1)
		{
			int defIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
			int index = g_AvailableWeapons.FindValue(defIndex, 0);
			if (index != -1)
			{
				WeaponConfig config;
				g_AvailableWeapons.GetArray(index, config, sizeof(config));
				
				if (config.armorPenetration < 1.0) // Armor penetration >= 100% bypasses armor
				{
					player.ArmorValue -= RoundFloat(damage);
					damage *= config.armorPenetration;
					changed = true;
				}
			}
		}
		
		if (player.ArmorValue <= 0)
			player.HasHelmet = false;
	}
	
	return changed ? Plugin_Changed : Plugin_Continue;
}

public void OnGameFrame()
{
	if (!g_IsBombTicking || g_BombRef == INVALID_ENT_REFERENCE)return;
	
	if (GetGameTime() > g_BombNextBeepTime)
	{
		float timerLength = tfgo_bombtimer.FloatValue;
		float complete = ((g_BombPlantedTime + timerLength - GetGameTime()) / timerLength);
		complete = clamp(complete, 0.0, 1.0);
		
		float attenuation = min(0.3 + 0.6 * complete, 1.0);
		EmitSoundToAll(SOUND_BOMB_BEEPING, g_BombRef, SNDCHAN_AUTO, ATTN_TO_SNDLEVEL(attenuation));
		float freq = max(0.1 + 0.9 * complete, 0.15);
		g_BombNextBeepTime = GetGameTime() + freq;
	}
}

public void ChooseRandomMusicKit()
{
	StringMapSnapshot snapshot = g_AvailableMusicKits.Snapshot();
	char name[PLATFORM_MAX_PATH];
	snapshot.GetKey(GetRandomInt(0, snapshot.Length - 1), name, sizeof(name));
	delete snapshot;
	
	g_AvailableMusicKits.GetArray(name, g_CurrentMusicKit, sizeof(g_CurrentMusicKit));
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "func_respawnroom"))
	{
		SDKHook(entity, SDKHook_StartTouch, Hook_RespawnRoom_StartTouch);
		SDKHook(entity, SDKHook_EndTouch, Hook_RespawnRoom_EndTouch);
	}
	else if (StrEqual(classname, "game_end"))
	{
		// Superceding SetWinningTeam causes some maps to force a map change on capture
		RemoveEntity(entity);
	}
	else if (StrEqual(classname, "tf_logic_arena"))
	{
		SDKHook(entity, SDKHook_Spawn, Hook_LogicArena_Spawn);
	}
	else if (StrEqual(classname, "trigger_capture_area"))
	{
		SDKHook(entity, SDKHook_Spawn, Hook_CaptureArea_Spawn);
	}
	else if (StrEqual(classname, "team_control_point_master"))
	{
		SDKHook(entity, SDKHook_Spawn, Hook_ControlPointMaster_Spawn);
	}
}

public void Hook_LogicArena_Spawn(int entity)
{
	DispatchKeyValueFloat(entity, "CapEnableDelay", 0.0);
}

public void Hook_CaptureArea_Spawn(int entity)
{
	// Arena maps typically have very long capture times, allow maps a bit of control and cut them in half
	DispatchKeyValueFloat(entity, "area_time_to_cap", GetEntPropFloat(entity, Prop_Data, "m_flCapTime") / 2);
}

public void Hook_ControlPointMaster_Spawn(int entity)
{
	DispatchKeyValue(entity, "cpm_restrict_team_cap_win", "1");
}

public Action Event_Player_Team(Event event, const char[] name, bool dontBroadcast)
{
	TFTeam team = view_as<TFTeam>(event.GetInt("team"));
	
	// Cap player account at highest of the team
	int highestAccount = tfgo_startmoney.IntValue;
	for (int client = 1; client <= MaxClients; client++)
	{
		int account = TFGOPlayer(client).Account;
		if (IsClientInGame(client) && TF2_GetClientTeam(client) == team && account > highestAccount)
			highestAccount = account;
	}
	
	TFGOPlayer player = TFGOPlayer(GetClientOfUserId(event.GetInt("userid")));
	if (player.Account > highestAccount)
		player.Account = highestAccount;
	
	player.RemoveAllItems(true);
}

public Action Event_Player_Death(Event event, const char[] name, bool dontBroadcast)
{
	TFGOPlayer attacker = TFGOPlayer(GetClientOfUserId(event.GetInt("attacker")));
	TFGOPlayer victim = TFGOPlayer(GetClientOfUserId(event.GetInt("userid")));
	
	char victimName[PLATFORM_MAX_PATH];
	GetClientName(victim.Client, victimName, sizeof(victimName));
	
	// Grant kill award to attacker/assister
	if (IsValidClient(attacker.Client))
	{
		int killAward;
		float factor = tfgo_cash_player_killed_enemy_factor.FloatValue;
		
		// Entity kill (e.g. "obj_sentrygun", "tf_projectile_healing_Bolt", etc.)
		// "player" is a valid entity
		int inflictorEntindex = event.GetInt("inflictor_entindex");
		char classname[PLATFORM_MAX_PATH];
		if (IsValidEntity(inflictorEntindex) && GetEntityClassname(inflictorEntindex, classname, sizeof(classname)) && g_WeaponClassKillAwards.GetValue(classname, killAward))
		{
			attacker.AddToAccount(RoundFloat(killAward * factor), "%T", "Player_Cash_Award_Killed_Enemy_Generic", LANG_SERVER);
		}
		else
		{
			if (attacker == victim) // Suicide
			{
				if (g_IsMainRoundActive)
				{
					g_HasPlayerSuicided[victim.Client] = true;
					killAward = RoundFloat(tfgo_cash_player_killed_enemy_default.IntValue * factor);
					
					ArrayList enemies = new ArrayList();
					for (int client = 1; client <= MaxClients; client++)
					{
						if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) != GetClientTeam(victim.Client))
							enemies.Push(client);
					}
					
					// Re-assign attacker to random enemy player, if present
					if (enemies.Length > 0)
					{
						attacker = TFGOPlayer(enemies.Get(GetRandomInt(0, enemies.Length - 1)));
						
						char attackerName[PLATFORM_MAX_PATH];
						GetClientName(attacker.Client, attackerName, sizeof(attackerName));
						
						// CS:GO does special chat messages for suicides
						for (int client = 1; client <= MaxClients; client++)
						{
							if (!IsClientInGame(client))
								continue;
							
							if (TF2_GetClientTeam(client) <= TFTeam_Spectator)
								PrintToChat(client, "%T", "Player_Cash_Award_ExplainSuicide_Spectators", LANG_SERVER, attackerName, killAward, victimName);
							else if (GetClientTeam(client) == GetClientTeam(victim.Client))
								PrintToChat(client, "%T", "Player_Cash_Award_ExplainSuicide_EnemyGotCash", LANG_SERVER, victimName);
							else if (attacker.Client != client)
								CPrintToChat(client, "%T", "Player_Cash_Award_ExplainSuicide_TeammateGotCash", LANG_SERVER, attackerName, killAward, victimName);
						}
						
						attacker.AddToAccount(killAward, "%T", "Player_Cash_Award_Killed_Enemy_Generic", LANG_SERVER, victimName);
						PrintToChat(attacker.Client, "%T", "Player_Cash_Award_ExplainSuicide_YouGotCash", LANG_SERVER, killAward, victimName);
					}
					
					delete enemies;
				}
			}
			else // Weapon kill
			{
				int defIndex = event.GetInt("weapon_def_index");
				char weapon[PLATFORM_MAX_PATH];
				event.GetString("weapon", weapon, sizeof(weapon));
				
				char weaponName[PLATFORM_MAX_PATH];
				TF2_GetItemName(defIndex, weaponName, sizeof(weaponName));
				
				// Specific weapon kill (e.g. "shotgun_pyro", "prinny_machete", "world", etc.)
				// If not found, determine kill award from the weapon class
				if (!g_WeaponClassKillAwards.GetValue(weapon, killAward))
				{
					TF2Econ_GetItemClassName(defIndex, classname, sizeof(classname));
					if (!g_WeaponClassKillAwards.GetValue(classname, killAward))
						killAward = tfgo_cash_player_killed_enemy_default.IntValue;
				}
				
				attacker.AddToAccount(RoundFloat(killAward * factor), "%T", "Player_Cash_Award_Killed_Enemy", LANG_SERVER, weaponName);
			}
		}
		
		// Grant assist award
		TFGOPlayer assister = TFGOPlayer(GetClientOfUserId(event.GetInt("assister")));
		if (IsValidClient(assister.Client))
		{
			int activeWeapon = GetEntPropEnt(assister.Client, Prop_Send, "m_hActiveWeapon");
			if (activeWeapon > -1)
			{
				int defIndex = GetEntProp(activeWeapon, Prop_Send, "m_iItemDefinitionIndex");
				TF2Econ_GetItemClassName(defIndex, classname, sizeof(classname));
				if (!g_WeaponClassKillAwards.GetValue(classname, killAward))
					killAward = tfgo_cash_player_killed_enemy_default.IntValue;
			}
			else // Assister likely has died
			{
				killAward = tfgo_cash_player_killed_enemy_default.IntValue;
			}
			
			assister.AddToAccount(RoundFloat(killAward * factor) / 2, "%T", "Player_Cash_Award_Assist_Enemy", LANG_SERVER, victimName);
		}
	}
	
	if (g_IsMainRoundActive || g_IsBonusRoundActive)
		victim.RemoveAllItems(true);
	
	if (victim.ActiveBuyMenu != null)
		victim.ActiveBuyMenu.Cancel();
}

public Action Event_Post_Inventory_Application(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidClient(client))
	{
		TFGOPlayer player = TFGOPlayer(client);
		player.ApplyLoadout();
		
		if (tfgo_free_armor.IntValue >= 1)
			player.ArmorValue = TF2_GetMaxHealth(client);
		if (tfgo_free_armor.IntValue >= 2)
			player.HasHelmet = true;
		
		if (player.ActiveBuyMenu != null)
			player.ActiveBuyMenu.Cancel();
		
		// Open buy menu on respawn
		DisplayMainBuyMenu(client);
	}
}

public Action Event_Teamplay_Round_Start(Event event, const char[] name, bool dontBroadcast)
{
	ResetRoundState();
	
	g_IsBonusRoundActive = false;
	g_IsMainRoundActive = false;
	
	g_CurrentMusicKit.StopMusicForAll(Music_WonRound);
	g_CurrentMusicKit.StopMusicForAll(Music_LostRound);
	g_CurrentMusicKit.PlayMusicToAll(Music_StartRound);
	
	// Bomb can freely tick and explode through the bonus time and we cancel it here
	g_IsBombTicking = false;
	g_BuyTimeTimer = null;
	g_TenSecondBombTimer = null;
	g_BombDetonationTimer = null;
	g_BombExplosionTimer = null;
}

public Action Timer_OnBuyTimeExpire(Handle timer)
{
	if (g_BuyTimeTimer != timer)return;
	
	g_IsBuyTimeActive = false;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			TFGOPlayer player = TFGOPlayer(client);
			if (player.ActiveBuyMenu != null)
			{
				player.ActiveBuyMenu.Cancel();
				PrintHintText(client, "%T", "BuyMenu_OutOfTime", LANG_SERVER, tfgo_buytime.IntValue);
			}
		}
	}
}

public Action Event_Arena_Round_Start(Event event, const char[] name, bool dontBroadcast)
{
	g_IsMainRoundActive = true;
	g_IsBuyTimeActive = true;
	g_BuyTimeTimer = CreateTimer(tfgo_buytime.FloatValue, Timer_OnBuyTimeExpire, _, TIMER_FLAG_NO_MAPCHANGE);
	g_TenSecondRoundTimer = CreateTimer(tf_arena_round_time.FloatValue - 10.0, Timer_PlayTenSecondRoundWarning, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_PlayTenSecondRoundWarning(Handle timer)
{
	if (g_TenSecondRoundTimer != timer)return;
	
	g_CurrentMusicKit.StopMusicForAll(Music_StartAction);
	g_CurrentMusicKit.PlayMusicToAll(Music_RoundTenSecCount);
}

public Action Event_Teamplay_Point_Captured(Event event, const char[] name, bool dontBroadcast)
{
	TFTeam team = view_as<TFTeam>(event.GetInt("team"));
	char[] cappers = new char[MaxClients];
	event.GetString("cappers", cappers, MaxClients);
	
	ArrayList capperList = new ArrayList();
	for (int i = 0; i < strlen(cappers); i++)
	{
		int capper = cappers[i];
		capperList.Push(capper);
	}
	
	g_IsBombPlanted = !g_IsBombPlanted;
	if (g_IsBombPlanted)
		PlantBomb(team, event.GetInt("cp"), capperList);
	else
		DefuseBomb(team, capperList);
}

void PlantBomb(TFTeam team, int cpIndex, ArrayList cappers)
{
	g_BombPlantingTeam = team;
	g_BombPlantedTime = GetGameTime();
	g_BombNextBeepTime = g_BombPlantedTime + 1.0;
	g_IsBombTicking = true;
	
	// Award capture bonus to cappers
	for (int i = 0; i < cappers.Length; i++)
	{
		int capper = cappers.Get(i);
		TFGOPlayer(capper).AddToAccount(tfgo_cash_player_bomb_planted.IntValue, "%T", "Player_Cash_Award_Bomb_Planted", LANG_SERVER);
	}
	
	// Cancel arena timer
	RemoveEntity(FindEntityByClassname(MaxClients + 1, "team_round_timer"));
	
	int cp = MaxClients + 1;
	while ((cp = FindEntityByClassname(cp, "team_control_point")) > -1)
	{
		if (GetEntProp(cp, Prop_Data, "m_iPointIndex") == cpIndex)
		{
			// Remember the active bomb site
			g_BombSiteRef = EntIndexToEntRef(cp);
		}
		else
		{
			// Lock every other control point in the map
			SetVariantInt(1);
			AcceptEntityInput(cp, "SetLocked");
		}
	}
	
	// Spawn bomb prop on first capper
	int capper = cappers.Get(0);
	float origin[3];
	GetEntPropVector(capper, Prop_Send, "m_vecOrigin", origin);
	float angles[3];
	GetEntPropVector(capper, Prop_Send, "m_angRotation", angles);
	
	// Create a new bomb
	int prop = CreateEntityByName("prop_dynamic_override");
	SetEntityModel(prop, MODEL_BOMB);
	DispatchSpawn(prop);
	TeleportEntity(prop, origin, angles, NULL_VECTOR);
	g_BombRef = EntIndexToEntRef(prop);
	
	g_TenSecondBombTimer = CreateTimer(tfgo_bombtimer.FloatValue - 10.0, Timer_PlayTenSecondBombWarning, _, TIMER_FLAG_NO_MAPCHANGE);
	g_BombDetonationTimer = CreateTimer(tfgo_bombtimer.FloatValue, Timer_DetonateBomb, _, TIMER_FLAG_NO_MAPCHANGE);
	
	// Play Sounds
	g_CurrentMusicKit.StopMusicForAll(Music_StartAction);
	g_CurrentMusicKit.StopMusicForAll(Music_RoundTenSecCount);
	g_CurrentMusicKit.PlayMusicToAll(Music_BombPlanted);
	EmitGameSoundToAll(GAMESOUND_ANNOUNCER_BOMB_PLANTED);
	EmitBombSeeGameSounds();
	
	// Reset timers
	g_TenSecondRoundTimer = null;
	
	// Show text on screen
	char message[PLATFORM_MAX_PATH];
	Format(message, sizeof(message), "%T", "Bomb_Planted", LANG_SERVER, tfgo_bombtimer.IntValue);
	ShowGameMessage(message, "ico_notify_sixty_seconds");
	
	Forward_BombPlanted(team, cappers);
	delete cappers;
}

public Action Timer_PlayTenSecondBombWarning(Handle timer)
{
	if (g_TenSecondBombTimer != timer || !g_IsMainRoundActive) return;
	
	g_CurrentMusicKit.StopMusicForAll(Music_BombPlanted);
	g_CurrentMusicKit.PlayMusicToAll(Music_BombTenSecCount);
}

public Action Timer_DetonateBomb(Handle timer)
{
	if (g_BombDetonationTimer != timer) return;
	
	g_IsBombTicking = false;
	EmitGameSoundToAll(GAMESOUND_BOMB_WARNING, g_BombRef);
	
	// Time's up, no more defusing
	SetVariantInt(1);
	AcceptEntityInput(g_BombSiteRef, "SetLocked");
	
	// For dramatic effect
	g_BombExplosionTimer = CreateTimer(1.0, Timer_ExplodeBomb, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_ExplodeBomb(Handle timer)
{
	if (g_BombExplosionTimer != timer) return;
	
	g_IsBombPlanted = false;
	
	TF2_ForceRoundWin(g_BombPlantingTeam, WinReason_PointCaptured);
	
	float origin[3];
	GetEntPropVector(g_BombRef, Prop_Send, "m_vecOrigin", origin);
	TF2_Explode(_, origin, BOMB_EXPLOSION_DAMAGE, BOMB_EXPLOSION_RADIUS, PARTICLE_BOMB_EXPLOSION);
	EmitGameSoundToAll(GAMESOUND_BOMB_EXPLOSION, g_BombRef);
	RemoveEntity(g_BombRef);
	
	Forward_BombDetonated(g_BombPlantingTeam);
}

void DefuseBomb(TFTeam team, ArrayList cappers)
{
	g_IsBombTicking = false;
	g_TenSecondBombTimer = null;
	g_BombDetonationTimer = null;
	
	for (int i = 0; i < cappers.Length; i++)
	{
		int capper = cappers.Get(i);
		TFGOPlayer(capper).AddToAccount(tfgo_cash_player_bomb_defused.IntValue, "%T", "Player_Cash_Award_Bomb_Defused", LANG_SERVER);
	}
	
	TF2_ForceRoundWin(team, WinReason_PointCaptured);
	
	Forward_BombDefused(team, cappers, tfgo_bombtimer.FloatValue - (GetGameTime() - g_BombPlantedTime));
	delete cappers;
}

public Action Event_Arena_Win_Panel(Event event, const char[] name, bool dontBroadcast)
{
	g_IsMainRoundActive = false;
	g_IsBonusRoundActive = true;
	g_TenSecondRoundTimer = null;
	
	int winreason = event.GetInt("winreason");
	
	if (winreason == WinReason_Stalemate)
	{
		TFGOTeam red = TFGOTeam(TFTeam_Red);
		TFGOTeam blue = TFGOTeam(TFTeam_Blue);
		red.AddToClientAccounts(0, "%T", "Team_Cash_Award_no_income", LANG_SERVER);
		blue.AddToClientAccounts(0, "%T", "Team_Cash_Award_no_income", LANG_SERVER);
		red.ConsecutiveLosses++;
		blue.ConsecutiveLosses++;
	}
	else
	{
		// Determine winning/losing team
		TFGOTeam winningTeam = TFGOTeam(view_as<TFTeam>(event.GetInt("winning_team")));
		TFGOTeam losingTeam = winningTeam.Team == TFTeam_Red ? TFGOTeam(TFTeam_Blue) : TFGOTeam(TFTeam_Red);
		
		if (winreason == WinReason_PointCaptured || winreason == WinReason_AllPointsCaptured)
		{
			if (g_BombPlantingTeam == winningTeam.Team)
			{
				winningTeam.AddToClientAccounts(tfgo_cash_team_terrorist_win_bomb.IntValue, "%T", "Team_Cash_Award_T_Win_Bomb", LANG_SERVER);
			}
			else
			{
				winningTeam.AddToClientAccounts(tfgo_cash_team_win_by_defusing_bomb.IntValue, "%T", "Team_Cash_Award_Win_Defuse_Bomb", LANG_SERVER);
				losingTeam.AddToClientAccounts(tfgo_cash_team_planted_bomb_but_defused.IntValue, "%T", "Team_Cash_Award_Planted_Bomb_But_Defused", LANG_SERVER);
			}
		}
		else if (winreason == WinReason_Elimination)
		{
			winningTeam.AddToClientAccounts(tfgo_cash_team_elimination.IntValue, "%T", "Team_Cash_Award_Elim_Bomb", LANG_SERVER);
		}
		
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client) && TF2_GetClientTeam(client) == losingTeam.Team)
			{
				// Do not give losing bonus to players that deliberately suicided
				if (g_HasPlayerSuicided[client])
					TFGOPlayer(client).AddToAccount(0, "%T", "Team_Cash_Award_no_income_suicide", LANG_SERVER);
				else
					TFGOPlayer(client).AddToAccount(losingTeam.LoseIncome, "%T", "Team_Cash_Award_Loser_Bonus", LANG_SERVER);
			}
		}
		
		// Adjust consecutive loss count for each team
		losingTeam.ConsecutiveLosses++;
		winningTeam.ConsecutiveLosses--;
	}

	g_RoundsPlayed++;
	if (tfgo_halftime.BoolValue && g_RoundsPlayed == tfgo_maxrounds.IntValue / 2)
	{
		SDK_SetSwitchTeams(true);
	}
	else if (g_RoundsPlayed == tfgo_maxrounds.IntValue)
	{
		g_RoundsPlayed = 0;
		SDK_SetScrambleTeams(true);
	}
}

public void ResetRoundState()
{
	g_IsBombPlanted = false;
	g_BombPlantingTeam = TFTeam_Unassigned;
	
	for (int i = 0; i < sizeof(g_HasPlayerSuicided); i++)
	{
		g_HasPlayerSuicided[i] = false;
	}
	
	for (int i = 0; i < sizeof(g_IsPlayerInDynamicBuyZone); i++)
	{
		g_IsPlayerInDynamicBuyZone[i] = false;
	}
}

public Action CommandListener_Build(int client, const char[] command, int args)
{
	// Check if player owns Construction PDA
	if (TFGOPlayer(client).GetWeaponFromLoadout(TFClass_Engineer, WeaponSlot_PDABuild) != -1)
		return Plugin_Continue;
	
	// Block build by default
	return Plugin_Handled;
}

public Action CommandListener_Destroy(int client, const char[] command, int args)
{
	// Check if player owns Destruction PDA
	if (TFGOPlayer(client).GetWeaponFromLoadout(TFClass_Engineer, WeaponSlot_PDADestroy) != -1)
		return Plugin_Continue;
	
	// Block destroy by default
	return Plugin_Handled;
}

void PrecacheModels()
{
	PrecacheModel(MODEL_BOMB);
}

void PrecacheParticleSystems()
{
	PrecacheParticleSystem(PARTICLE_BOMB_EXPLOSION);
}

void Toggle_ConVars(bool toggle)
{
	static bool arenaFirstBlood;
	static bool arenaUseQueue;
	static int arenaPreRoundTime;
	static int arenaRoundTime;
	static int arenaOverrideCapEnableTime;
	static bool weaponCriticals;
	static bool weaponCriticalsMelee;
	static int bonusRoundTime;
	
	if (toggle)
	{
		arenaFirstBlood = tf_arena_first_blood.BoolValue;
		tf_arena_first_blood.BoolValue = false;
		
		arenaUseQueue = tf_arena_use_queue.BoolValue;
		tf_arena_use_queue.BoolValue = false;
		
		// mp_freezetime
		arenaPreRoundTime = tf_arena_preround_time.IntValue;
		tf_arena_preround_time.IntValue = 15;
		
		// mp_roundtime
		arenaRoundTime = tf_arena_round_time.IntValue;
		tf_arena_round_time.IntValue = 115;
		
		arenaOverrideCapEnableTime = tf_arena_override_cap_enable_time.IntValue;
		tf_arena_override_cap_enable_time.IntValue = -1;
		
		weaponCriticals = tf_weapon_criticals.BoolValue;
		tf_weapon_criticals.BoolValue = false;
		
		weaponCriticalsMelee = tf_weapon_criticals_melee.BoolValue;
		tf_weapon_criticals_melee.BoolValue = false;
		
		// mp_round_restart_delay
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
		tf_weapon_criticals.BoolValue = weaponCriticals;
		tf_weapon_criticals_melee.BoolValue = weaponCriticalsMelee;
		mp_bonusroundtime.IntValue = bonusRoundTime;
	}
}
