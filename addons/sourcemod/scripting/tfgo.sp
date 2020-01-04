#pragma semicolon 1

#include <morecolors>
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf_econ_data>
#include <dhooks>
#include <memorypatch>
#include <tfgo>

#pragma newdecls required


#define PLUGIN_VERSION "1.0"
#define PLUGIN_VERSION_REVISION "manual"

#define TF_MAXPLAYERS 32

#define BOMB_MODEL "models/props_td/atom_bomb.mdl"
#define BOMB_EXPLOSION_PARTICLE "mvm_hatch_destroy"
#define BOMB_BEEPING_SOUND "player/cyoa_pda_beep3.wav"
#define BOMB_WARNING_SOUND "mvm/mvm_bomb_warning.wav"
#define BOMB_EXPLOSION_SOUND "mvm/mvm_bomb_explode.wav"
#define PLAYER_PURCHASE_SOUND "mvm/mvm_bought_upgrade.wav"

#define BOMB_EXPLOSION_DAMAGE 500.0
#define BOMB_EXPLOSION_RADIUS 800.0

#define ARMOR_RATIO 0.2

#define MIN_CONSECUTIVE_LOSSES 0
#define STARTING_CONSECUTIVE_LOSSES 1


// Source hit group standards
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
}


// Timers
Handle g_BuyTimeTimer;
Handle g_TenSecondRoundTimer;
Handle g_TenSecondBombTimer;
Handle g_BombDetonationTimer;
Handle g_BombDetonationWarningTimer;
Handle g_BombBeepingTimer;

// Other handles
MemoryPatch g_PickupWeaponPatch;
StringMap g_AvailableMusicKits;
ArrayList g_AvailableWeapons;
ArrayList g_AvailableEquipment;

// Map
bool g_MapHasRespawnRoom;

// Game state
bool g_IsBuyTimeActive;
bool g_IsMainRoundActive;
bool g_IsBonusRoundActive;
bool g_IsBombPlanted;
bool g_IsBombDetonated;
bool g_IsBombDefused;
float g_BombPlantedTime;
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
ConVar tf_use_fixed_weaponspreads;
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
	tf_use_fixed_weaponspreads = FindConVar("tf_use_fixed_weaponspreads");
	tf_weapon_criticals = FindConVar("tf_weapon_criticals");
	tf_weapon_criticals_melee = FindConVar("tf_weapon_criticals_melee");
	mp_bonusroundtime = FindConVar("mp_bonusroundtime");
	
	// Create TFGO ConVars
	tfgo_all_weapons_can_headshot = CreateConVar("tfgo_all_weapons_can_headshot", "0", "Whether all weapons that deal bullet damage should be able to headshot");
	tfgo_free_armor = CreateConVar("tfgo_free_armor", "2", "Determines whether kevlar (1+) and/or helmet (2+) are given automatically", _, true, 0.0, true, 2.0);
	tfgo_max_armor = CreateConVar("tfgo_max_armor", "2", "Determines the highest level of armor allowed to be purchased. (0) None, (1) Kevlar, (2) Helmet", _, true, 0.0, true, 2.0);
	tfgo_buytime = CreateConVar("tfgo_buytime", "45", "How many seconds after spawning players can buy items for", _, true, tf_arena_preround_time.FloatValue);
	tfgo_consecutive_loss_max = CreateConVar("tfgo_consecutive_loss_max", "4", "The maximum of consecutive losses for each team that will be kept track of", _, true, float(STARTING_CONSECUTIVE_LOSSES));
	tfgo_buytime = CreateConVar("tfgo_buytime", "45", "How many seconds after spawning players can buy items for", _, true, 0.0);
	tfgo_consecutive_loss_max = CreateConVar("tfgo_consecutive_loss_max", "4", "The maximum of consecutive losses for each team that will be kept track of", _, true, 0.0);
	tfgo_buyzone_radius_override = CreateConVar("tfgo_buyzone_radius_override", "-1", "Overrides the default calculated buyzone radius on maps with no respawn room");
	tfgo_bombtimer = CreateConVar("tfgo_bombtimer", "45", "How long from when the bomb is planted until it blows", _, true, 10.0);
	tfgo_maxrounds = CreateConVar("tfgo_maxrounds", "15", "Maximum number of rounds to play before a team scramble occurs", _, true, 0.0);
	tfgo_halftime = CreateConVar("tfgo_halftime", "1", "Determines whether the match switches sides in a halftime event");
	tfgo_startmoney = CreateConVar("tfgo_startmoney", "1000", "Amount of money each player gets when they reset", _, true, 0.0);
	tfgo_maxmoney = CreateConVar("tfgo_maxmoney", "10000", "Maximum amount of money allowed in a player's account", _, true, 0.0);
	tfgo_cash_player_bomb_planted = CreateConVar("tfgo_cash_player_bomb_planted", "200", "Cash award for each player that planted the bomb");
	tfgo_cash_player_bomb_defused = CreateConVar("tfgo_cash_player_bomb_defused", "200", "Cash award for each player that defused the bomb");
	tfgo_cash_player_killed_enemy_default = CreateConVar("tfgo_cash_player_killed_enemy_default", "300", "Default cash award for eliminating an enemy player");
	tfgo_cash_player_killed_enemy_factor = CreateConVar("tfgo_cash_player_killed_enemy_factor", "0.5", "The factor each kill award is multiplied with");
	tfgo_cash_team_elimination = CreateConVar("tfgo_cash_team_elimination", "2700", "Team cash award for winning by eliminating the enemy team");
	tfgo_cash_team_loser_bonus = CreateConVar("tfgo_cash_team_loser_bonus", "2400", "Team cash bonus for losing");
	tfgo_cash_team_loser_bonus_consecutive_rounds = CreateConVar("tfgo_cash_team_loser_bonus_consecutive_rounds", "0", "Team cash bonus for losing consecutive rounds");
	tfgo_cash_team_terrorist_win_bomb = CreateConVar("tfgo_cash_team_terrorist_win_bomb", "2700", "Team cash award for winning by detonating the bomb");
	tfgo_cash_team_win_by_defusing_bomb = CreateConVar("tfgo_cash_team_win_by_defusing_bomb", "2700", "Team cash award for winning by defusing the bomb");
	tfgo_cash_team_planted_bomb_but_defused = CreateConVar("tfgo_cash_team_planted_bomb_but_defused", "200", "Team cash bonus for planting the bomb and losing");
	
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
	
	int func_respawnroom = FindEntityByClassname(-1, "func_respawnroom");
	if (func_respawnroom <= -1)
	{
		g_MapHasRespawnRoom = false;
		
		LogMessage("This map is missing a func_respawnroom entity, calculating buy zones based on info_player_teamspawn entities");
		CalculateDynamicBuyZones();
	}
	else
	{
		g_MapHasRespawnRoom = true;
	}
}

public void OnClientConnected(int client)
{
	ResetPlayer(client, false);
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_PreThink, Client_PreThink);
	SDKHook(client, SDKHook_TraceAttack, Client_TraceAttack);
}

stock void ResetPlayer(int client, bool notify = true)
{
	TFGOPlayer player = TFGOPlayer(client);
	player.ResetBalance();
	
	if (notify && IsValidClient(client))
		CPrintToChat(client, "%T", "Info_Player_Reset", LANG_SERVER);
}

public void Client_PreThink(int client)
{
	TFGOPlayer player = TFGOPlayer(client);
	
	SetHudTextParams(0.05, 0.325, 0.1, 162, 255, 71, 255, _, 0.0, 0.0, 0.0);
	ShowHudText(client, -1, "$%d", player.Balance);
	
	if (player.Armor > 0)
	{
		SetHudTextParams(-1.0, 0.85, 0.1, 255, 255, 255, 255, _, 0.0, 0.0, 0.0);
		ShowHudText(client, -1, "Armor: %d", player.Armor);
	}
	
	if (!g_MapHasRespawnRoom && g_IsBuyTimeActive)
		DisplayMenuInDynamicBuyZone(client);
}

public void OnClientDisconnect(int client)
{
	SDKUnhook(client, SDKHook_PreThink, Client_PreThink);
	SDKUnhook(client, SDKHook_TraceAttack, Client_TraceAttack);
	
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
	
	// Allow every weapon with damagetype DMG_BULLET to deal crits on headshot
	if (tfgo_all_weapons_can_headshot.BoolValue && damagetype & (DMG_BULLET | DMG_BUCKSHOT))
	{
		damagetype |= DMG_USE_HITLOCATIONS;
		changed = true;
	}
	
	TFGOPlayer player = TFGOPlayer(victim);
	
	if (player.Armor > 0 && !(damagetype & (DMG_FALL | DMG_DROWN | DMG_POISON | DMG_RADIATION))) // Armor doesn't protect against fall or drown damage
	{
		// Armor only shields chest, stomach and arms; helmet expands this to the head
		if ((hitgroup >= HITGROUP_CHEST && hitgroup <= HITGROUP_RIGHTARM) || (player.HasHelmet && hitgroup == HITGROUP_HEAD))
		{
			int activeWeapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
			if (activeWeapon != -1)
			{
				int defindex = GetEntProp(activeWeapon, Prop_Send, "m_iItemDefinitionIndex");
				int index = g_AvailableWeapons.FindValue(defindex, 0);
				if (index != -1)
				{
					Weapon weapon;
					g_AvailableWeapons.GetArray(index, weapon, sizeof(weapon));
					
					// Armor penetration >= 100% can bypass armor entirely
					if (weapon.armorPenetration < 1.0)
					{
						player.Armor -= RoundFloat(damage); // Deduct absorbed damage from armor points
						damage *= weapon.armorPenetration; // Modify damage
						changed = true;
					}
				}
			}
			else
			{
				player.Armor -= RoundFloat(damage);
				damage *= ARMOR_RATIO; // Armor shields 80% of all damage from non-weapon sources by default
				changed = true;
			}
		}
	}
	
	return changed ? Plugin_Changed : Plugin_Continue;
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
		SDKHook(entity, SDKHook_StartTouch, Hook_OnStartTouchBuyZone);
		SDKHook(entity, SDKHook_EndTouch, Hook_OnEndTouchBuyZone);
	}
	else if (StrEqual(classname, "tf_logic_arena"))
	{
		SDKHook(entity, SDKHook_SpawnPost, OnArenaLogicSpawned);
	}
	else if (StrEqual(classname, "trigger_capture_area"))
	{
		SDKHook(entity, SDKHook_SpawnPost, OnCaptureAreaSpawned);
	}
}

public void OnArenaLogicSpawned(int entity)
{
	SetEntPropFloat(entity, Prop_Data, "m_flTimeToEnableCapPoint", 0.0);
}

public void OnCaptureAreaSpawned(int entity)
{
	SetEntPropFloat(entity, Prop_Data, "m_flCapTime", GetEntPropFloat(entity, Prop_Data, "m_flCapTime") / 2);
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
			attacker.AddToBalance(RoundFloat(killAward * factor), "%T", "Player_Cash_Award_Killed_Enemy_Generic", LANG_SERVER);
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
						
						attacker.AddToBalance(killAward, "%T", "Player_Cash_Award_Killed_Enemy_Generic", LANG_SERVER, victimName);
						PrintToChat(attacker.Client, "%T", "Player_Cash_Award_ExplainSuicide_YouGotCash", LANG_SERVER, killAward, victimName);
					}
					
					delete enemies;
				}
			}
			else // Weapon kill
			{
				int weaponDefIndex = event.GetInt("weapon_def_index");
				char weapon[PLATFORM_MAX_PATH];
				event.GetString("weapon", weapon, sizeof(weapon));
				
				char weaponName[PLATFORM_MAX_PATH];
				TF2_GetItemName(weaponDefIndex, weaponName, sizeof(weaponName));
				
				// Specific weapon kill (e.g. "shotgun_pyro", "prinny_machete", "world", etc.)
				// If not found, determine kill award from the weapon class
				if (!g_WeaponClassKillAwards.GetValue(weapon, killAward))
				{
					TF2Econ_GetItemClassName(weaponDefIndex, classname, sizeof(classname));
					if (!g_WeaponClassKillAwards.GetValue(classname, killAward))
						killAward = tfgo_cash_player_killed_enemy_default.IntValue;
				}
				
				attacker.AddToBalance(RoundFloat(killAward * factor), "%T", "Player_Cash_Award_Killed_Enemy", LANG_SERVER, weaponName);
			}
		}
		
		// Grant assist award
		TFGOPlayer assister = TFGOPlayer(GetClientOfUserId(event.GetInt("assister")));
		if (IsValidClient(assister.Client))
		{
			int activeWeapon = GetEntPropEnt(assister.Client, Prop_Send, "m_hActiveWeapon");
			if (activeWeapon > -1)
			{
				int weaponDefIndex = GetEntProp(activeWeapon, Prop_Send, "m_iItemDefinitionIndex");
				TF2Econ_GetItemClassName(weaponDefIndex, classname, sizeof(classname));
				if (!g_WeaponClassKillAwards.GetValue(classname, killAward))
					killAward = tfgo_cash_player_killed_enemy_default.IntValue;
			}
			else // Assister likely has died
			{
				killAward = tfgo_cash_player_killed_enemy_default.IntValue;
			}
			
			assister.AddToBalance(RoundFloat(killAward * factor) / 2, "%T", "Player_Cash_Award_Assist_Enemy", LANG_SERVER, victimName);
		}
	}
	
	if (g_IsBombPlanted)
	{
		TFTeam victimTeam = TF2_GetClientTeam(victim.Client);
		// End the round if every member of the non-planting team died
		if (g_BombPlantingTeam != victimTeam && GetAlivePlayerCountForTeam(victimTeam) - 1 <= 0 && !(event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER))
			g_IsBombPlanted = false;
	}
	
	if (g_IsMainRoundActive || g_IsBonusRoundActive)
		victim.ClearLoadout();
	
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
		
		if (tfgo_free_armor.IntValue >= 1) player.Armor = TF2_GetMaxHealth(client);
		if (tfgo_free_armor.IntValue >= 2) player.HasHelmet = true;
		
		if (player.ActiveBuyMenu != null)
			player.ActiveBuyMenu.Cancel();
		
		// Open buy menu on respawn
		DisplayMainBuyMenu(client);
	}
}

public Action Event_Teamplay_Round_Start(Event event, const char[] name, bool dontBroadcast)
{
	ResetRoundState();
	
	g_IsBuyTimeActive = true;
	g_IsBonusRoundActive = false;
	g_IsMainRoundActive = false;
	g_BuyTimeTimer = CreateTimer(tfgo_buytime.FloatValue, OnBuyTimeExpire, _, TIMER_FLAG_NO_MAPCHANGE);
	
	g_CurrentMusicKit.StopMusicForAll(Music_WonRound);
	g_CurrentMusicKit.StopMusicForAll(Music_LostRound);
	g_CurrentMusicKit.PlayMusicToAll(Music_StartRound);
	
	// Bomb can freely tick and explode through the bonus time and we cancel it here
	g_BombBeepingTimer = null;
	g_TenSecondBombTimer = null;
	g_BombDetonationWarningTimer = null;
	g_BombDetonationTimer = null;
}

public Action OnBuyTimeExpire(Handle timer)
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
	g_TenSecondRoundTimer = CreateTimer(tf_arena_round_time.FloatValue - 10.0, PlayTenSecondRoundWarning, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action PlayTenSecondRoundWarning(Handle timer)
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

void PlantBomb(TFTeam team, int cp, ArrayList cappers)
{
	g_BombPlantingTeam = team;
	g_BombPlantedTime = GetGameTime();
	
	// Award capture bonus to cappers
	for (int i = 0; i < cappers.Length; i++)
	{
		int capper = cappers.Get(i);
		TFGOPlayer(capper).AddToBalance(tfgo_cash_player_bomb_planted.IntValue, "%T", "Player_Cash_Award_Bomb_Planted", LANG_SERVER);
	}
	
	// Superceding SetWinningTeam causes arena mode to force a map change on capture
	int game_end;
	while ((game_end = FindEntityByClassname(game_end, "game_end")) > -1)
		AcceptEntityInput(game_end, "Kill");
	
	// Superceding SetWinningTeam causes arena mode to create a game_text entity announcing the winning team
	int game_text;
	while ((game_text = FindEntityByClassname(game_text, "game_text")) > -1)
	{
		char entityMessage[PLATFORM_MAX_PATH];
		GetEntPropString(game_text, Prop_Data, "m_iszMessage", entityMessage, sizeof(entityMessage));
		
		char message[PLATFORM_MAX_PATH];
		GetTeamName(view_as<int>(team), message, sizeof(message));
		StrCat(message, sizeof(message), " Wins the Game!");
		
		// To not mess with any other game_text entities
		if (StrEqual(entityMessage, message))
			AcceptEntityInput(game_text, "Kill");
	}
	
	// Set arena round time to bomb detonation time
	int team_round_timer = FindEntityByClassname(-1, "team_round_timer");
	if (team_round_timer > -1)
	{
		SetVariantInt(tfgo_bombtimer.IntValue + 1);
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
	}
	
	int trigger_capture_area;
	while ((trigger_capture_area = FindEntityByClassname(trigger_capture_area, "trigger_capture_area")) > -1)
	{
		// Adjust defuse time
		SetEntPropFloat(trigger_capture_area, Prop_Data, "m_flCapTime", GetEntPropFloat(trigger_capture_area, Prop_Data, "m_flCapTime") / 0.75);
	}
	
	// Spawn bomb prop on first capper
	int capper = cappers.Get(0);
	float origin[3];
	GetEntPropVector(capper, Prop_Send, "m_vecOrigin", origin);
	float angles[3];
	GetEntPropVector(capper, Prop_Send, "m_angRotation", angles);
	
	int bomb = CreateEntityByName("prop_dynamic_override");
	SetEntityModel(bomb, BOMB_MODEL);
	DispatchSpawn(bomb);
	TeleportEntity(bomb, origin, angles, NULL_VECTOR);
	
	// Set up timers
	g_TenSecondBombTimer = CreateTimer(tfgo_bombtimer.FloatValue - 10.0, PlayTenSecondBombWarning, EntIndexToEntRef(bomb), TIMER_FLAG_NO_MAPCHANGE);
	g_BombBeepingTimer = CreateTimer(1.0, PlayBombBeep, EntIndexToEntRef(bomb), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	g_BombDetonationWarningTimer = CreateTimer(tfgo_bombtimer.FloatValue - 1.5, PlayBombExplosionWarning, EntIndexToEntRef(bomb), TIMER_FLAG_NO_MAPCHANGE);
	g_BombDetonationTimer = CreateTimer(tfgo_bombtimer.FloatValue, DetonateBomb, EntIndexToEntRef(bomb), TIMER_FLAG_NO_MAPCHANGE);
	
	// Play Sounds
	g_CurrentMusicKit.StopMusicForAll(Music_StartAction);
	g_CurrentMusicKit.StopMusicForAll(Music_RoundTenSecCount);
	g_CurrentMusicKit.PlayMusicToAll(Music_BombPlanted);
	PlayAnnouncerBombAlert();
	ShoutBombWarnings();
	
	// Reset timers
	g_TenSecondRoundTimer = null;
	
	// Show text on screen
	char message[PLATFORM_MAX_PATH];
	Format(message, sizeof(message), "%T", "Alert_Bomb_Planted", LANG_SERVER, tfgo_bombtimer.IntValue);
	ShowGameMessage(message, "ico_notify_sixty_seconds");
	
	Forward_BombPlanted(team, cappers);
	delete cappers;
}

public Action PlayBombBeep(Handle timer, int bomb)
{
	if (g_BombBeepingTimer != timer)return Plugin_Stop;
	
	float origin[3];
	GetEntPropVector(bomb, Prop_Send, "m_vecOrigin", origin);
	EmitAmbientSound(BOMB_BEEPING_SOUND, origin, bomb);
	return Plugin_Continue;
}

public Action PlayTenSecondBombWarning(Handle timer, int bomb)
{
	if (g_TenSecondBombTimer != timer)return;
	
	g_BombBeepingTimer = CreateTimer(0.5, PlayBombBeep, bomb, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	
	if (g_IsMainRoundActive)
	{
		g_CurrentMusicKit.StopMusicForAll(Music_BombPlanted);
		g_CurrentMusicKit.PlayMusicToAll(Music_BombTenSecCount);
	}
}

public Action PlayBombExplosionWarning(Handle timer, int bomb)
{
	if (g_BombDetonationWarningTimer != timer)return;
	
	g_BombBeepingTimer = null;
	
	float origin[3];
	GetEntPropVector(bomb, Prop_Send, "m_vecOrigin", origin);
	EmitAmbientSound(BOMB_WARNING_SOUND, origin, bomb, SNDLEVEL_RAIDSIREN);
}

public Action DetonateBomb(Handle timer, int bombRef)
{
	if (g_BombDetonationTimer != timer)return;
	
	g_IsBombDetonated = true;
	g_IsBombPlanted = false;
	
	// Only call this after we set g_IsBombPlanted to false or the game softlocks
	TF2_ForceRoundWin(g_BombPlantingTeam, Winreason_PointCaptured);
	
	int bomb = EntRefToEntIndex(bombRef);
	float origin[3];
	GetEntPropVector(bomb, Prop_Send, "m_vecOrigin", origin);
	TF2_Explode(_, origin, BOMB_EXPLOSION_DAMAGE, BOMB_EXPLOSION_RADIUS, BOMB_EXPLOSION_PARTICLE, BOMB_EXPLOSION_SOUND);
	RemoveEntity(bomb);
	
	Forward_BombDetonated(g_BombPlantingTeam);
}

void DefuseBomb(TFTeam team, ArrayList cappers)
{
	g_BombBeepingTimer = null;
	g_TenSecondBombTimer = null;
	g_BombDetonationWarningTimer = null;
	g_BombDetonationTimer = null;
	
	for (int i = 0; i < cappers.Length; i++)
	{
		int capper = cappers.Get(i);
		TFGOPlayer(capper).AddToBalance(tfgo_cash_player_bomb_defused.IntValue, "%T", "Player_Cash_Award_Bomb_Defused", LANG_SERVER);
	}
	
	g_IsBombDefused = true;
	TF2_ForceRoundWin(team, Winreason_PointCaptured);
	
	Forward_BombDefused(team, cappers, tfgo_bombtimer.FloatValue - (GetGameTime() - g_BombPlantedTime));
	delete cappers;
}

public Action Event_Arena_Win_Panel(Event event, const char[] name, bool dontBroadcast)
{
	g_IsMainRoundActive = false;
	g_IsBonusRoundActive = true;
	g_TenSecondRoundTimer = null;
	
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
	if (winreason == Winreason_PointCaptured || winreason == Winreason_AllPointsCaptured)
	{
		if (g_BombPlantingTeam == winningTeam.Team)
		{
			winningTeam.AddToClientBalances(tfgo_cash_team_terrorist_win_bomb.IntValue, "%T", "Team_Cash_Award_T_Win_Bomb", LANG_SERVER);
		}
		else
		{
			winningTeam.AddToClientBalances(tfgo_cash_team_win_by_defusing_bomb.IntValue, "%T", "Team_Cash_Award_Win_Defuse_Bomb", LANG_SERVER);
			losingTeam.AddToClientBalances(tfgo_cash_team_planted_bomb_but_defused.IntValue, "%T", "Team_Cash_Award_Planted_Bomb_But_Defused", LANG_SERVER);
		}
	}
	else if (winreason == Winreason_Elimination)
	{
		winningTeam.AddToClientBalances(tfgo_cash_team_elimination.IntValue, "%T", "Team_Cash_Award_Elim_Bomb", LANG_SERVER);
	}
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && TF2_GetClientTeam(client) == losingTeam.Team)
		{
			// Do not give losing bonus to players that deliberately suicided
			if (g_HasPlayerSuicided[client])
				TFGOPlayer(client).AddToBalance(0, "%T", "Team_Cash_Award_no_income_suicide", LANG_SERVER);
			else
				TFGOPlayer(client).AddToBalance(losingTeam.LoseIncome, "%T", "Team_Cash_Award_Loser_Bonus", LANG_SERVER);
		}
	}
	
	// Adjust consecutive loss count for each team
	losingTeam.ConsecutiveLosses++;
	winningTeam.ConsecutiveLosses--;
	
	g_RoundsPlayed++;
	if (tfgo_halftime.BoolValue && g_RoundsPlayed == RoundFloat(tfgo_maxrounds.IntValue / 2.0))
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
	g_IsBombDetonated = false;
	g_IsBombDefused = false;
	g_BombPlantingTeam = TFTeam_Unassigned;
	for (int i = 0; i < sizeof(g_HasPlayerSuicided); i++)g_HasPlayerSuicided[i] = false;
	for (int i = 0; i < sizeof(g_IsPlayerInDynamicBuyZone); i++)g_IsPlayerInDynamicBuyZone[i] = false;
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
	static bool useFixedWeaponSpreads;
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
		tf_arena_preround_time.IntValue = 5;
		
		// mp_roundtime
		arenaRoundTime = tf_arena_round_time.IntValue;
		tf_arena_round_time.IntValue = 135;
		
		arenaOverrideCapEnableTime = tf_arena_override_cap_enable_time.IntValue;
		tf_arena_override_cap_enable_time.IntValue = -1;
		
		useFixedWeaponSpreads = tf_use_fixed_weaponspreads.BoolValue;
		tf_use_fixed_weaponspreads.BoolValue = true;
		
		weaponCriticals = tf_weapon_criticals.BoolValue;
		tf_weapon_criticals.BoolValue = false;
		
		weaponCriticalsMelee = tf_weapon_criticals_melee.BoolValue;
		tf_weapon_criticals_melee.BoolValue = false;
		
		// mp_round_restart_delay
		bonusRoundTime = mp_bonusroundtime.IntValue;
		mp_bonusroundtime.IntValue = 10;
	}
	else
	{
		tf_arena_first_blood.BoolValue = arenaFirstBlood;
		tf_arena_use_queue.BoolValue = arenaUseQueue;
		tf_arena_preround_time.IntValue = arenaPreRoundTime;
		tf_arena_round_time.IntValue = arenaRoundTime;
		tf_arena_override_cap_enable_time.IntValue = arenaOverrideCapEnableTime;
		tf_use_fixed_weaponspreads.BoolValue = useFixedWeaponSpreads;
		tf_weapon_criticals.BoolValue = weaponCriticals;
		tf_weapon_criticals_melee.BoolValue = weaponCriticalsMelee;
		mp_bonusroundtime.IntValue = bonusRoundTime;
	}
}
