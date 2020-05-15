#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <dhooks>
#include <memorypatch>
#include <morecolors>
#include <tf_econ_data>
#include <tfgo>

#pragma semicolon 1
#pragma newdecls required


#define PLUGIN_VERSION "1.1"
#define PLUGIN_VERSION_REVISION "manual"

#define TF_MAXPLAYERS	33

#define WEAPON_GAS_PASSER					1180
#define ATTRIB_MAX_HEALTH_ADDITIVE_BONUS	26

#define MODEL_BOMB	"models/props_td/atom_bomb.mdl"

#define PARTICLE_BOMB_EXPLOSION	"mvm_hatch_destroy"

#define SOUND_BOMB_BEEPING					")misc/rd_finale_beep01.wav"
#define GAMESOUND_BOMB_EXPLOSION			"MVM.BombExplodes"
#define GAMESOUND_BOMB_WARNING				"MVM.BombWarning"
#define GAMESOUND_PLAYER_PURCHASE			"MVM.PlayerUpgraded"
#define GAMESOUND_ANNOUNCER_BOMB_PLANTED	"Announcer.SecurityAlert"
#define GAMESOUND_ANNOUNCER_TEAM_SCRAMBLE	"Announcer.AM_TeamScrambleRandom"

#define BOMB_EXPLOSION_DAMAGE	500.0
#define BOMB_EXPLOSION_RADIUS	800.0

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


// Timers
Handle g_BuyTimeTimer;
Handle g_TenSecondBombTimer;
Handle g_BombDetonationTimer;
Handle g_BombExplosionTimer;

// Other handles
MemoryPatch g_PickupWeaponPatch;
TFGOWeaponList g_AvailableWeapons;
StringMap g_AvailableMusicKits;

// Map
bool g_MapHasRespawnRoom;

// Bomb & Bomb Site
int g_BombRef;
int g_BombSiteRef;
float g_BombBlow;
float g_BombNextBeep;
bool g_IsBombTicking;

// Game state
bool g_IsBuyTimeActive;
bool g_IsMainRoundActive;
bool g_IsBonusRoundActive;
bool g_IsBombPlanted;
bool g_SkipGiveNamedItemHook;

TFTeam g_BombPlantingTeam;
bool g_HasPlayerSuicided[TF_MAXPLAYERS];

// ConVars
ConVar tfgo_free_armor;
ConVar tfgo_max_armor;
ConVar tfgo_buytime;
ConVar tfgo_consecutive_loss_max;
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
ConVar tfgo_cash_team_win_by_time_running_out_bomb;
ConVar tfgo_cash_team_loser_bonus_consecutive_rounds;
ConVar tfgo_cash_team_terrorist_win_bomb;
ConVar tfgo_cash_team_win_by_defusing_bomb;
ConVar tfgo_cash_team_planted_bomb_but_defused;


#include "tfgo/methodmaps.sp"

#include "tfgo/musickits.sp"
MusicKit g_CurrentMusicKit; // TODO: Rework music kits and remove me!

#include "tfgo/buymenu.sp"
#include "tfgo/buyzone.sp"
#include "tfgo/config.sp"
#include "tfgo/console.sp"
#include "tfgo/convar.sp"
#include "tfgo/dhook.sp"
#include "tfgo/entoutput.sp"
#include "tfgo/event.sp"
#include "tfgo/forward.sp"
#include "tfgo/native.sp"
#include "tfgo/sdkcall.sp"
#include "tfgo/sdkhook.sp"
#include "tfgo/sound.sp"
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
	EntOutput_Init();
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
	delete gamedata;
	
	ConVar_Enable();
	
	AddNormalSoundHook(NormalSoundHook);
	
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
}

public void OnMapStart()
{
	// Allow players to buy stuff on the first round
	g_IsBuyTimeActive = true;
	
	DHook_HookGamerules();
	ResetRoundState();
	
	Sound_Precache();
	
	MusicKit_Precache();
	
	PrecacheModel(MODEL_BOMB);
	
	PrecacheParticleSystem(PARTICLE_BOMB_EXPLOSION);
	
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
	
	// Clear attackers and defenders from previous map
	for (int team = view_as<int>(TFTeam_Red); team <= view_as<int>(TFTeam_Blue); team++)
	{
		TFGOTeam tfgoTeam = TFGOTeam(view_as<TFTeam>(team));
		tfgoTeam.IsAttacking = false;
		tfgoTeam.IsDefending = false;
	}
	
	// Determine attacking and defending team(s)
	int cp = MaxClients + 1;
	while ((cp = FindEntityByClassname(cp, "team_control_point")) > -1)
	{
		TFTeam defaultOwner = view_as<TFTeam>(GetEntProp(cp, Prop_Data, "m_iDefaultOwner"));
		if (defaultOwner == TFTeam_Unassigned)	// Neutral CP, both teams are attacking AND defending this point
		{
			for (int team = view_as<int>(TFTeam_Red); team <= view_as<int>(TFTeam_Blue); team++)
			{
				TFGOTeam tfgoTeam = TFGOTeam(view_as<TFTeam>(team));
				tfgoTeam.IsAttacking = true;
				tfgoTeam.IsDefending = true;
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
	else if (StrEqual(classname, "team_control_point_master"))
		SDKHook_HookTeamControlPointMaster(entity);
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
				PrintHintText(client, "%T", "BuyMenu_OutOfTime", LANG_SERVER, tfgo_buytime.IntValue);
			}
		}
	}
}

Action Timer_OnBombTenSecCount(Handle timer)
{
	if (g_TenSecondBombTimer != timer || !g_IsMainRoundActive) return;
	
	g_CurrentMusicKit.StopMusicForAll(Music_BombPlanted);
	g_CurrentMusicKit.PlayMusicToAll(Music_BombTenSecCount);
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
	
	if (g_IsMainRoundActive)
		TF2_ForceRoundWin(g_BombPlantingTeam, WINREASON_ALL_POINTS_CAPTURED);
	
	float origin[3];
	GetEntPropVector(g_BombRef, Prop_Send, "m_vecOrigin", origin);
	TF2_Explode(_, origin, BOMB_EXPLOSION_DAMAGE, BOMB_EXPLOSION_RADIUS, PARTICLE_BOMB_EXPLOSION);
	EmitGameSoundToAll(GAMESOUND_BOMB_EXPLOSION, g_BombRef);
	RemoveEntity(g_BombRef);
	
	Forward_OnBombDetonated(g_BombPlantingTeam);
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
	
	// Award capture bonus to cappers
	for (int i = 0; i < cappers.Length; i++)
	{
		int capper = cappers.Get(i);
		TFGOPlayer(capper).AddToAccount(tfgo_cash_player_bomb_planted.IntValue, "%T", "Player_Cash_Award_Bomb_Planted", LANG_SERVER, tfgo_cash_player_bomb_planted.IntValue);
	}
	
	// Cancel arena timer
	int timer = MaxClients + 1;
	while ((timer = FindEntityByClassname(timer, "team_round_timer")) > -1)
		RemoveEntity(timer);
	
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
	
	// Create a new bomb
	int prop = CreateEntityByName("prop_dynamic_override");
	if (IsValidEntity(prop))
	{
		g_BombRef = EntIndexToEntRef(prop);
		SetEntityModel(prop, MODEL_BOMB);
		
		if (DispatchSpawn(prop))
		{
			int capper = cappers.Get(0);
			float origin[3], angles[3];
			GetEntPropVector(capper, Prop_Send, "m_vecOrigin", origin);
			GetEntPropVector(capper, Prop_Send, "m_angRotation", angles);
			
			TeleportEntity(prop, origin, angles, NULL_VECTOR);
		}
	}
	
	g_TenSecondBombTimer = CreateTimer(tfgo_bombtimer.FloatValue - 10.0, Timer_OnBombTenSecCount, _, TIMER_FLAG_NO_MAPCHANGE);
	g_BombDetonationTimer = CreateTimer(tfgo_bombtimer.FloatValue, Timer_OnBombTimerExpire, _, TIMER_FLAG_NO_MAPCHANGE);
	
	// Play Sounds
	g_CurrentMusicKit.StopMusicForAll(Music_StartAction);
	g_CurrentMusicKit.StopMusicForAll(Music_RoundTenSecCount);
	g_CurrentMusicKit.PlayMusicToAll(Music_BombPlanted);
	EmitGameSoundToAll(GAMESOUND_ANNOUNCER_BOMB_PLANTED);
	EmitBombSeeGameSounds();
	
	// Show text on screen
	char message[PLATFORM_MAX_PATH];
	Format(message, sizeof(message), "%T", "Bomb_Planted", LANG_SERVER, tfgo_bombtimer.IntValue);
	TF2_ShowGameMessage(message, "ico_notify_sixty_seconds");
	
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
		TFGOPlayer(capper).AddToAccount(tfgo_cash_player_bomb_defused.IntValue, "%T", "Player_Cash_Award_Bomb_Defused", LANG_SERVER, tfgo_cash_player_bomb_defused.IntValue);
	}
	
	TF2_ForceRoundWin(team, WINREASON_ALL_POINTS_CAPTURED);
	
	Forward_OnBombDefused(team, cappers, g_BombBlow - GetGameTime());
	delete cappers;
}

void ResetRoundState()
{
	g_IsBombPlanted = false;
	g_BombPlantingTeam = TFTeam_Unassigned;
	
	for (int i = 0; i < sizeof(g_HasPlayerSuicided); i++)
	{
		g_HasPlayerSuicided[i] = false;
	}
	
	ResetPlayerBuyZoneStates();
}

void ChooseRandomMusicKit()
{
	StringMapSnapshot snapshot = g_AvailableMusicKits.Snapshot();
	char name[PLATFORM_MAX_PATH];
	snapshot.GetKey(GetRandomInt(0, snapshot.Length - 1), name, sizeof(name));
	delete snapshot;
	
	g_AvailableMusicKits.GetArray(name, g_CurrentMusicKit, sizeof(g_CurrentMusicKit));
}
