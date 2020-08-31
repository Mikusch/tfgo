#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <dhooks>
#include <memorypatch>
#include <morecolors>
#include <tf_econ_data>
#include <loadsoundscript>
#include <tfgo>

#pragma semicolon 1
#pragma newdecls required


#define PLUGIN_VERSION			"1.4.0"
#define PLUGIN_VERSION_REVISION	"manual"

#define TF_MAXPLAYERS	33

#define CAPHUD_PARITY_BITS	6
#define CAPHUD_PARITY_MASK	((1 << CAPHUD_PARITY_BITS) - 1)

#define SF_CAP_POINT_HIDEFLAG	(1 << 0)

#define ATTRIB_MAX_HEALTH_ADDITIVE_BONUS	26

#define PARTICLE_BOMB_EXPLOSION	"mvm_hatch_destroy"

#define SOUND_BOMB_BEEPING					")misc/rd_finale_beep01.wav"
#define GAMESOUND_BOMB_ENEMYRETURNED		"MVM.AttackDefend.EnemyReturned"
#define GAMESOUND_BOMB_EXPLOSION			"MVM.BombExplodes"
#define GAMESOUND_BOMB_WARNING				"MVM.BombWarning"
#define GAMESOUND_PLAYER_PURCHASE			"MVM.PlayerUpgraded"
#define GAMESOUND_ANNOUNCER_BOMB_PLANTED	"Announcer.SecurityAlert"
#define GAMESOUND_ANNOUNCER_TEAM_SCRAMBLE	"Announcer.AM_TeamScrambleRandom"

#define BOMB_TARGETNAME	"tfgo_bomb"

#define BOMB_PLANT_TIME		3.0
#define BOMB_DEFUSE_TIME	10.0

#define BOMB_EXPLOSION_DAMAGE	500.0
#define BOMB_EXPLOSION_RADIUS	1750.0

#define MIN_CONSECUTIVE_LOSSES		0
#define STARTING_CONSECUTIVE_LOSSES	1

#define HELMET_PRICE		350
#define KEVLAR_PRICE		650
#define ASSAULTSUIT_PRICE	1000
#define DEFUSEKIT_PRICE		400


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

// TF2 win reasons (from teamplayroundbased_gamerules.h)
enum
{
	WINREASON_NONE = 0, 
	WINREASON_ALL_POINTS_CAPTURED, 
	WINREASON_OPPONENTS_DEAD, 
	WINREASON_FLAG_CAPTURE_LIMIT, 
	WINREASON_DEFEND_UNTIL_TIME_LIMIT, 
	WINREASON_STALEMATE, 
	WINREASON_TIMELIMIT, 
	WINREASON_WINLIMIT, 
	WINREASON_WINDIFFLIMIT, 
	WINREASON_RD_REACTOR_CAPTURED, 
	WINREASON_RD_CORES_COLLECTED, 
	WINREASON_RD_REACTOR_RETURNED, 
	WINREASON_PD_POINTS, 
	WINREASON_SCORED, 
	WINREASON_STOPWATCH_WATCHING_ROUNDS, 
	WINREASON_STOPWATCH_WATCHING_FINAL_ROUND, 
	WINREASON_STOPWATCH_PLAYING_ROUNDS, 
	
	// Add custom win reasons below
	WINREASON_CUSTOM_OUT_OF_TIME
};

enum ETFGameType
{
	TF_GAMETYPE_UNDEFINED = 0, 
	TF_GAMETYPE_CTF, 
	TF_GAMETYPE_CP, 
	TF_GAMETYPE_ESCORT, 
	TF_GAMETYPE_ARENA, 
	TF_GAMETYPE_MVM, 
	TF_GAMETYPE_RD, 
	TF_GAMETYPE_PASSTIME, 
	TF_GAMETYPE_PD, 
	
	TF_GAMETYPE_COUNT
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


methodmap TFGOWeaponList < ArrayList
{
	public TFGOWeaponList()
	{
		return view_as<TFGOWeaponList>(new ArrayList(sizeof(TFGOWeapon)));
	}
	
	public void ReadConfig(KeyValues kv)
	{
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				TFGOWeapon weapon;
				weapon.ReadConfig(kv);
				this.PushArray(weapon, sizeof(weapon));
			}
			while (kv.GotoNextKey(false));
			kv.GoBack();
		}
		kv.GoBack();
	}
	
	public int GetByDefIndex(int defindex, TFGOWeapon weapon)
	{
		int i = this.FindValue(Config_GetOriginalItemDefIndex(defindex), TFGOWeapon::defindex);
		return i != -1 ? this.GetArray(i, weapon) : 0;
	}
}

enum MusicType
{
	Music_HalfTime, 
	Music_StartRound, 
	Music_StartAction, 
	Music_BombPlanted, 
	Music_BombTenSecCount, 
	Music_TenSecCount, 
	Music_WonRound, 
	Music_LostRound, 
	Music_DeathCam, 
	Music_MVPAnthem
}


// Timers
Handle g_BuyTimeTimer;
Handle g_TenSecondBombTimer;
Handle g_BombDetonationTimer;
Handle g_BombExplosionTimer;

// Other handles
Handle g_CashEarnedHudSync;
Handle g_AccountHudSync;
Handle g_ArmorHudSync;
MemoryPatch g_PickupWeaponPatch;
MemoryPatch g_RespawnRoomTouchPatch;
MemoryPatch g_FlagTouchPatch;
TFGOWeaponList g_AvailableWeapons;

// Map
bool g_MapHasRespawnRoom;

// Bomb & Bomb Site
int g_BombRef;
int g_BombSiteRef;
float g_BombBlow;
float g_BombNextBeep;
bool g_IsBombTicking;

// Game state
bool g_ArenaGameType;
bool g_IsBuyTimeActive;
bool g_IsBombPlanted;
bool g_SkipGiveNamedItemHook;
int g_MVP;

TFTeam g_BombPlantingTeam;

// ConVars
ConVar tfgo_free_armor;
ConVar tfgo_max_armor;
ConVar tfgo_buytime;
ConVar tfgo_consecutive_loss_max;
ConVar tfgo_bombtimer;
ConVar tfgo_halftime;
ConVar tfgo_halftime_duration;
ConVar tfgo_halftime_scramble;
ConVar tfgo_startmoney;
ConVar tfgo_maxmoney;
ConVar tfgo_cash_player_bomb_planted;
ConVar tfgo_cash_player_bomb_defused;
ConVar tfgo_cash_player_killed_enemy_default;
ConVar tfgo_cash_player_killed_enemy_factor;
ConVar tfgo_cash_team_elimination;
ConVar tfgo_cash_team_loser_bonus;
ConVar tfgo_cash_team_win_by_time_running_out_bomb;
ConVar tfgo_cash_team_loser_bonus_consecutive_rounds;
ConVar tfgo_cash_team_terrorist_win_bomb;
ConVar tfgo_cash_team_win_by_defusing_bomb;
ConVar tfgo_cash_team_planted_bomb_but_defused;


#include "tfgo/methodmaps.sp"


#include "tfgo/buymenu.sp"
#include "tfgo/buyzone.sp"
#include "tfgo/config.sp"
#include "tfgo/console.sp"
#include "tfgo/convar.sp"
#include "tfgo/dhook.sp"
#include "tfgo/event.sp"
#include "tfgo/forward.sp"
#include "tfgo/musickits.sp"
#include "tfgo/native.sp"
#include "tfgo/sdkcall.sp"
#include "tfgo/sdkhook.sp"
#include "tfgo/stocks.sp"


public Plugin pluginInfo =  {
	name = "Team Fortress: Global Offensive Arena", 
	author = "Mikusch", 
	description = "A Team Fortress 2 gamemode inspired by Counter-Strike: Global Offensive", 
	version = PLUGIN_VERSION..."."...PLUGIN_VERSION_REVISION, 
	url = "https://github.com/Mikusch/tfgo"
};

//-----------------------------------------------------------------------------
// Forwards
//-----------------------------------------------------------------------------

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
	
	Config_Init();
	Console_Init();
	ConVar_Init();
	Event_Init();
	MusicKit_Init();
	
	GameData gamedata = new GameData("tfgo");
	
	DHook_Init(gamedata);
	SDKCall_Init(gamedata);
	MemoryPatch.SetGameData(gamedata);
	
	g_PickupWeaponPatch = new MemoryPatch("Patch_PickupWeaponFromOther");
	if (g_PickupWeaponPatch != null)
		g_PickupWeaponPatch.Enable();
	else
		LogMessage("Failed to create patch: Patch_PickupWeaponFromOther");
	
	g_RespawnRoomTouchPatch = new MemoryPatch("Patch_RespawnRoomTouch");
	if (g_RespawnRoomTouchPatch != null)
		g_RespawnRoomTouchPatch.Enable();
	else
		LogMessage("Failed to create patch: Patch_RespawnRoomTouch");
	
	g_FlagTouchPatch = new MemoryPatch("Patch_FlagTouch");
	if (g_FlagTouchPatch != null)
		g_FlagTouchPatch.Enable();
	else
		LogMessage("Failed to create patch: Patch_FlagTouch");
	
	delete gamedata;
	
	HookEntityOutput("team_round_timer", "On10SecRemain", EntOutput_On10SecRemain);
	
	g_CashEarnedHudSync = CreateHudSynchronizer();
	g_AccountHudSync = CreateHudSynchronizer();
	g_ArmorHudSync = CreateHudSynchronizer();
	
	ConVar_Enable();
	
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
	ConVar_Disable();
	
	for (int client = 1; client <= MaxClients; client++)
	{
		DHook_UnhookClientEntity(client);
	}
	
	if (g_PickupWeaponPatch != null)
		g_PickupWeaponPatch.Disable();
	
	if (g_RespawnRoomTouchPatch != null)
		g_RespawnRoomTouchPatch.Disable();
	
	if (g_FlagTouchPatch != null)
		g_FlagTouchPatch.Disable();
	
	//Restore arena if needed
	if (g_ArenaGameType)
		GameRules_SetProp("m_nGameType", TF_GAMETYPE_ARENA);
}

public void OnMapStart()
{
	// Allow players to buy stuff on the first round
	g_IsBuyTimeActive = true;
	
	if (GameRules_GetRoundState() == RoundState_Pregame && view_as<ETFGameType>(GameRules_GetProp("m_nGameType")) == TF_GAMETYPE_ARENA)
	{
		// Enable waiting for players
		g_ArenaGameType = true;
		GameRules_SetProp("m_nGameType", TF_GAMETYPE_UNDEFINED);
	}
	
	DHook_HookGamerules();
	ResetRoundState();
	
	// Precache
	MusicKit_Precache();
	PrecacheParticleSystem(PARTICLE_BOMB_EXPLOSION);
	PrecacheSound(SOUND_BOMB_BEEPING);
	PrecacheScriptSound(GAMESOUND_BOMB_ENEMYRETURNED);
	PrecacheScriptSound(GAMESOUND_BOMB_EXPLOSION);
	PrecacheScriptSound(GAMESOUND_BOMB_WARNING);
	PrecacheScriptSound(GAMESOUND_PLAYER_PURCHASE);
	PrecacheScriptSound(GAMESOUND_ANNOUNCER_BOMB_PLANTED);
	PrecacheScriptSound(GAMESOUND_ANNOUNCER_TEAM_SCRAMBLE);
	
	// Pick a random music kit for everyone (sub-plugins can override this!)
	for (int client = 1; client <= MaxClients; client++)
	{
		MusicKit_SetRandomDefaultMusicKit(client);
	}
	
	if (FindEntityByClassname(MaxClients + 1, "func_respawnroom") > -1)
	{
		g_MapHasRespawnRoom = true;
	}
	else
	{
		g_MapHasRespawnRoom = false;
		CalculateDynamicBuyZones();
	}
	
	// Clear attackers and defenders from previous map
	for (int i = view_as<int>(TFTeam_Red); i <= view_as<int>(TFTeam_Blue); i++)
	{
		TFGOTeam team = TFGOTeam(view_as<TFTeam>(i));
		team.IsAttacking = false;
		team.IsDefending = false;
	}
	
	// Determine attacking and defending team(s) based on default control point owners
	int cp = MaxClients + 1;
	while ((cp = FindEntityByClassname(cp, "team_control_point")) > -1)
	{
		TFTeam defaultOwner = view_as<TFTeam>(GetEntProp(cp, Prop_Data, "m_iDefaultOwner"));
		if (defaultOwner == TFTeam_Unassigned)	// Neutral CP, both teams are attacking AND defending this point
		{
			for (int i = view_as<int>(TFTeam_Red); i <= view_as<int>(TFTeam_Blue); i++)
			{
				TFGOTeam team = TFGOTeam(view_as<TFTeam>(i));
				team.IsAttacking = true;
				team.IsDefending = true;
			}
		}
		else	// CP owned by RED or BLU, enemy is attacking
		{
			TFGOTeam(TF2_GetEnemyTeam(defaultOwner)).IsAttacking = true;
			TFGOTeam(defaultOwner).IsDefending = true;
		}
	}
}

public void OnClientConnected(int client)
{
	TFGOPlayer(client).Reset();
}

public void OnClientPutInServer(int client)
{
	SDKHook_HookClient(client);
	DHook_HookClientEntity(client);
}

public void OnClientDisconnect(int client)
{
	DHook_UnhookClientEntity(client);
	
	// Force-end round if last client in team disconnects during active bomb
	if (g_IsBombPlanted && IsValidClient(client))
	{
		TFTeam team = TF2_GetClientTeam(client);
		if (team > TFTeam_Spectator && g_BombPlantingTeam != team && TF2_GetAlivePlayerCountForTeam(team) <= 0)
			g_IsBombPlanted = false;
	}
}

public void OnGameFrame()
{
	//Make sure other plugins is not overriding gamerules prop
	if (g_ArenaGameType && view_as<ETFGameType>(GameRules_GetProp("m_nGameType")) != TF_GAMETYPE_UNDEFINED)
		GameRules_SetProp("m_nGameType", TF_GAMETYPE_UNDEFINED);
	
	if (!g_IsBombTicking) return;
	
	if (GetGameTime() > g_BombNextBeep)
	{
		float complete = FloatClamp(((g_BombBlow - GetGameTime()) / tfgo_bombtimer.FloatValue), 0.0, 1.0);
		
		float attenuation = FloatMin(0.3 + 0.6 * complete, 1.0);
		EmitSoundToAll(SOUND_BOMB_BEEPING, g_BombRef, SNDCHAN_AUTO, ATTN_TO_SNDLEVEL(attenuation));
		
		float freq = FloatMax(0.1 + 0.9 * complete, 0.15);
		g_BombNextBeep = GetGameTime() + freq;
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "func_respawnroom"))
		SDKHook_HookFuncRespawnRoom(entity);
	else if (StrEqual(classname, "tf_logic_arena"))
		SDKHook_HookTFLogicArena(entity);
	else if (StrEqual(classname, "trigger_capture_area"))
		SDKHook_HookTriggerCaptureArea(entity);
	else if (StrEqual(classname, "team_control_point"))
		SDKHook_HookTeamControlPoint(entity);
	else if (StrEqual(classname, "team_control_point_master"))
		SDKHook_HookTeamControlPointMaster(entity);
	else if (StrEqual(classname, "tf_gamerules"))
		SDKHook_HookGameRules(entity);
}

public void TF2_OnWaitingForPlayersStart()
{
	// Set game type back to arena after waiting for players calculations are done
	g_ArenaGameType = false;
	GameRules_SetProp("m_nGameType", TF_GAMETYPE_ARENA);
}

public Action TF2_OnGiveNamedItem(int client, char[] classname, int defindex)
{
	if (g_SkipGiveNamedItemHook)
	{
		g_SkipGiveNamedItemHook = false;
		return Plugin_Continue;
	}
	
	TFClassType class = TF2_GetPlayerClass(client);
	int slot = TF2_GetItemSlot(defindex, class);
	
	if (0 <= slot <= WeaponSlot_BuilderEngie && TFGOPlayer(client).GetWeaponFromLoadout(class, slot) != Config_GetOriginalItemDefIndex(defindex))
		return Plugin_Handled;
	
	return Plugin_Continue;
}

//-----------------------------------------------------------------------------
// Timer Callbacks
//-----------------------------------------------------------------------------

Action Timer_DistributeBombs(Handle timer)
{
	for (TFTeam team = TFTeam_Red; team <= TFTeam_Blue; team++)
	{
		if (!TFGOTeam(team).IsAttacking)
			continue;
		
		int[] clients = new int[MaxClients];
		int total;
		
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsValidClient(client) && IsPlayerAlive(client) && TF2_GetClientTeam(client) == team)
			{
				clients[total++] = client;
			}
		}
		
		if (total)
		{
			int client = clients[GetRandomInt(0, total - 1)];
			
			int bomb = CreateEntityByName("item_teamflag");
			if (IsValidEntity(bomb))
			{
				DispatchKeyValue(bomb, "targetname", BOMB_TARGETNAME);
				DispatchKeyValue(bomb, "ReturnTime", "0");
				DispatchKeyValue(bomb, "flag_model", "models/props_td/atom_bomb.mdl");
				DispatchKeyValue(bomb, "trail_effect", "3");
				DispatchKeyValue(bomb, "GameType", "2");
				
				float origin[3], angles[3];
				GetClientAbsOrigin(client, origin);
				GetClientAbsAngles(client, angles);
				TeleportEntity(bomb, origin, angles, NULL_VECTOR);	// Needs to be done before DispatchSpawn to set its reset point
				
				if (DispatchSpawn(bomb))
				{
					SetVariantInt(view_as<int>(team));
					AcceptEntityInput(bomb, "SetTeam");
					AcceptEntityInput(bomb, "Enable");
					
					HookSingleEntityOutput(bomb, "OnDrop", EntOutput_OnBombDrop);
					SDKHook_HookBomb(bomb);
					
					SDKCall_PickUp(bomb, client);
				}
			}
		}
	}
}

Action Timer_OnBuyTimeExpire(Handle timer)
{
	if (g_BuyTimeTimer != timer) return;
	
	g_IsBuyTimeActive = false;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			TFGOPlayer player = TFGOPlayer(client);
			if (player.ActiveBuyMenu != null)
			{
				player.ActiveBuyMenu.Cancel();
				PrintHintText(client, "%t", "BuyMenu_OutOfTime", tfgo_buytime.IntValue);
			}
		}
	}
}

Action Timer_OnBombTenSecCount(Handle timer)
{
	if (g_TenSecondBombTimer != timer || GameRules_GetRoundState() != RoundState_Stalemate) return;
	
	MusicKit_PlayAllClientMusicKits(Music_BombTenSecCount);
}

Action Timer_OnBombTimerExpire(Handle timer)
{
	if (g_BombDetonationTimer != timer) return;
	
	g_IsBombTicking = false;
	EmitGameSoundToAll(GAMESOUND_BOMB_WARNING, g_BombRef);
	
	// Time's up, no more defusing
	SetVariantInt(1);
	AcceptEntityInput(g_BombSiteRef, "SetLocked");
	
	// For dramatic effect
	g_BombExplosionTimer = CreateTimer(1.0, Timer_OnBombExplode, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_OnBombExplode(Handle timer)
{
	if (g_BombExplosionTimer != timer) return;
	
	g_IsBombPlanted = false;
	
	if (GameRules_GetRoundState() == RoundState_Stalemate)
		TF2_ForceRoundWin(g_BombPlantingTeam, WINREASON_ALL_POINTS_CAPTURED);
	
	float bombOrigin[3], bombAngles[3];
	GetEntPropVector(g_BombRef, Prop_Send, "m_vecOrigin", bombOrigin);
	GetEntPropVector(g_BombRef, Prop_Send, "m_angRotation", bombAngles);
	
	// Deal blast damage to clients in range of the bomb
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && IsPlayerAlive(client))
		{
			float clientOrigin[3];
			GetClientAbsOrigin(client, clientOrigin);
			float distance = GetVectorDistance(clientOrigin, bombOrigin);
			if (distance < BOMB_EXPLOSION_RADIUS)
				SDKHooks_TakeDamage(client, g_BombRef, g_BombRef, (BOMB_EXPLOSION_DAMAGE / BOMB_EXPLOSION_RADIUS) * (BOMB_EXPLOSION_RADIUS - distance), DMG_BLAST, _, bombOrigin);
		}
	}
	
	// Damage buildings in range
	int obj = MaxClients + 1;
	while ((obj = FindEntityByClassname(obj, "obj_*")) > -1)
	{
		float objOrigin[3];
		GetEntPropVector(obj, Prop_Data, "m_vecAbsOrigin", objOrigin);
		float distance = GetVectorDistance(objOrigin, bombOrigin);
		if (distance < BOMB_EXPLOSION_RADIUS)
		{
			SetVariantInt(RoundFloat((BOMB_EXPLOSION_DAMAGE / BOMB_EXPLOSION_RADIUS) * (BOMB_EXPLOSION_RADIUS - distance)));
			AcceptEntityInput(obj, "RemoveHealth", g_BombRef, g_BombRef);
		}
	}
	
	TF2_SpawnParticle(PARTICLE_BOMB_EXPLOSION, bombOrigin, bombAngles);
	EmitGameSoundToAll(GAMESOUND_BOMB_EXPLOSION, g_BombRef);
	RemoveEntity(g_BombRef);
	
	Forward_OnBombDetonated(g_BombPlantingTeam);
}

//-----------------------------------------------------------------------------
// Entity Output Callbacks
//-----------------------------------------------------------------------------

void EntOutput_On10SecRemain(const char[] output, int caller, int activator, float delay)
{
	if (GameRules_GetRoundState() == RoundState_Stalemate)
		MusicKit_PlayAllClientMusicKits(Music_TenSecCount);
}

void EntOutput_OnBombDrop(const char[] output, int caller, int activator, float delay)
{
	// Prevent the bomb from resetting instantly
	SetEntPropFloat(caller, Prop_Send, "m_flResetTime", 0.0);
	
	// Reset the bomb if it comes in contact with a lethal trigger_hurt
	int trigger = MaxClients + 1;
	while ((trigger = FindEntityByClassname(trigger, "trigger_hurt")) > -1)
	{
		if (GetEntProp(trigger, Prop_Data, "m_bDisabled") || GetEntPropFloat(trigger, Prop_Data, "m_flDamage") < 300.0)
			continue;
		
		float origin[3];
		GetEntPropVector(caller, Prop_Data, "m_vecAbsOrigin", origin);
		
		if (PointIsWithin(trigger, origin))
		{
			AcceptEntityInput(caller, "ForceReset", trigger);
			
			for (int client = 1; client <= MaxClients; client++)
			{
				if (IsClientInGame(client))
				{
					if (GetClientTeam(client) == GetEntProp(caller, Prop_Data, "m_iTeamNum"))
					{
						char message[256];
						Format(message, sizeof(message), "%t", "Bomb_YoursReturned", client);
						TF2_ShowAnnotationToClient(client, caller, message, _, "mvm/mvm_warning.wav");
					}
					else
					{
						EmitGameSoundToClient(client, GAMESOUND_BOMB_ENEMYRETURNED);
					}
				}
			}
			
			break;
		}
	}
}

//-----------------------------------------------------------------------------
// Plugin Functions
//-----------------------------------------------------------------------------

void PlantBomb(TFTeam team, int cpIndex, ArrayList cappers)
{
	g_BombPlantingTeam = team;
	g_BombBlow = GetGameTime() + tfgo_bombtimer.FloatValue;
	g_IsBombTicking = true;
	
	// Don't beep right away, leave time for the planting sound
	g_BombNextBeep = GetGameTime() + 1.0;
	
	for (int i = 0; i < cappers.Length; i++)
	{
		int capper = cappers.Get(i);
		
		// Award bonus to cappers
		TFGOPlayer(capper).AddToAccount(tfgo_cash_player_bomb_planted.IntValue, "%t", "Player_Cash_Award_Bomb_Planted", tfgo_cash_player_bomb_planted.IntValue);
		
		// If no bomb was dropped yet, look for the first capper with a bomb
		int item = GetEntPropEnt(capper, Prop_Send, "m_hItem");
		if (IsBomb(item))
		{
			AcceptEntityInput(item, "ForceDrop");
			g_BombRef = EntIndexToEntRef(item);
		}
	}
	
	// Cancel arena timer
	int timer = MaxClients + 1;
	while ((timer = FindEntityByClassname(timer, "team_round_timer")) > -1)
		RemoveEntity(timer);
	
	char bombSiteTargetname[256];
	
	int cp = MaxClients + 1;
	while ((cp = FindEntityByClassname(cp, "team_control_point")) > -1)
	{
		int pointIndex = GetEntProp(cp, Prop_Data, "m_iPointIndex");
		if (pointIndex == cpIndex)
		{
			// Remember active bomb site
			g_BombSiteRef = EntIndexToEntRef(cp);
			GetEntPropString(cp, Prop_Data, "m_iName", bombSiteTargetname, sizeof(bombSiteTargetname));
			
			// Show active bomb site on HUD
			int objResource = FindEntityByClassname(MaxClients + 1, "tf_objective_resource");
			if (objResource != -1)
			{
				int size = GetEntPropArraySize(objResource, Prop_Send, "m_bCPIsVisible");
				for (int i = 0; i < size; i++)
				{
					if (pointIndex == i)
					{
						SetEntProp(objResource, Prop_Send, "m_bCPIsVisible", true, _, i);
						SetEntProp(objResource, Prop_Send, "m_bControlPointsReset", true);
						break;
					}
				}
			}
		}
		else
		{
			// Lock every other control point in the map
			SetVariantInt(1);
			AcceptEntityInput(cp, "SetLocked");
		}
	}
	
	int area = MaxClients + 1;
	while ((area = FindEntityByClassname(area, "trigger_capture_area")) > -1)
	{
		char capPointName[256];
		if (GetEntPropString(area, Prop_Data, "m_iszCapPointName", capPointName, sizeof(capPointName)) > 0 && StrEqual(capPointName, bombSiteTargetname))
		{
			TF2_SetAreaTimeToCap(area, BOMB_DEFUSE_TIME);
			break;
		}
	}
	
	// Remove every other bomb still in the map
	int teamflag = MaxClients + 1;
	while ((teamflag = FindEntityByClassname(teamflag, "item_teamflag")) > -1)
	{
		if (teamflag != EntRefToEntIndex(g_BombRef) && IsBomb(teamflag))
		{
			AcceptEntityInput(teamflag, "ForceDrop");	// Gets rid of the player glow
			RemoveEntity(teamflag);
		}
	}
	
	g_TenSecondBombTimer = CreateTimer(tfgo_bombtimer.FloatValue - 10.0, Timer_OnBombTenSecCount, _, TIMER_FLAG_NO_MAPCHANGE);
	g_BombDetonationTimer = CreateTimer(tfgo_bombtimer.FloatValue, Timer_OnBombTimerExpire, _, TIMER_FLAG_NO_MAPCHANGE);
	
	// Play Sounds
	MusicKit_PlayAllClientMusicKits(Music_BombPlanted);
	EmitGameSoundToAll(GAMESOUND_ANNOUNCER_BOMB_PLANTED);
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && IsPlayerAlive(client) && TF2_GetClientTeam(client) != g_BombPlantingTeam)
		{
			SetVariantString("IsMvMDefender:1");
			AcceptEntityInput(client, "AddContext");
			SetVariantString("TLK_MVM_BOMB_PICKUP");
			AcceptEntityInput(client, "SpeakResponseConcept");
			AcceptEntityInput(client, "ClearContext");
		}
	}
	
	// Show text on screen
	char message[PLATFORM_MAX_PATH];
	Format(message, sizeof(message), "%T", "Bomb_Planted", LANG_SERVER, tfgo_bombtimer.IntValue);
	TF2_ShowGameMessage(message, "ico_notify_sixty_seconds", .teamColor = view_as<int>(team));
	
	// Hides the bomb in HUD
	GameRules_SetProp("m_bPlayingHybrid_CTF_CP", false);
	
	Forward_OnBombPlanted(team, cappers);
	delete cappers;
}

void DefuseBomb(TFTeam team, ArrayList cappers)
{
	g_IsBombTicking = false;
	g_TenSecondBombTimer = null;
	g_BombDetonationTimer = null;
	
	for (int i = 0; i < cappers.Length; i++)
	{
		int capper = cappers.Get(i);
		TFGOPlayer(capper).AddToAccount(tfgo_cash_player_bomb_defused.IntValue, "%t", "Player_Cash_Award_Bomb_Defused", tfgo_cash_player_bomb_defused.IntValue);
	}
	
	TF2_ForceRoundWin(team, WINREASON_ALL_POINTS_CAPTURED);
	
	Forward_OnBombDefused(team, cappers, g_BombBlow - GetGameTime());
	delete cappers;
}

void ResetRoundState()
{
	g_IsBombPlanted = false;
	g_BombPlantingTeam = TFTeam_Unassigned;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		TFGOPlayer(client).HasSuicided = false;
	}
	
	ResetPlayerBuyZoneStates();
}
