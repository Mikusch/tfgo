#pragma semicolon 1
#pragma newdecls required

#include<sourcemod>
#include<sdktools>
#include<sdkhooks>
#include <tf2_stocks>

#define TF_MAXPLAYERS 	32

#define TFGO_STARTING_MONEY				1000
#define TFGO_KILL_REWARD_PRIMARY		50
#define TFGO_KILL_REWARD_SECONDARY		150
#define TFGO_KILL_REWARD_MELEE			450
#define TFGO_MAX_MONEY 					16000
#define TFGO_CAPTURE_WIN_BONUS			2700
#define TFGO_ELIMINATION_WIN_BONUS		2300
#define TFGO_LOSS_BONUS 					2400

char g_EngineerMvmCollectCredits[][PLATFORM_MAX_PATH] = 
{
	"vo/engineer_mvm_collect_credits01.mp3", 
	"vo/engineer_mvm_collect_credits02.mp3", 
	"vo/engineer_mvm_collect_credits03.mp3"
};

char g_HeavyMvmCollectCredits[][PLATFORM_MAX_PATH] = 
{
	"vo/heavy_mvm_collect_credits01.mp3", 
	"vo/heavy_mvm_collect_credits02.mp3", 
	"vo/heavy_mvm_collect_credits03.mp3", 
	"vo/heavy_mvm_collect_credits04.mp3"
};

char g_MedicMvmCollectCredits[][PLATFORM_MAX_PATH] = 
{
	"vo/medic_mvm_collect_credits01.mp3", 
	"vo/medic_mvm_collect_credits02.mp3", 
	"vo/medic_mvm_collect_credits03.mp3", 
	"vo/medic_mvm_collect_credits04.mp3"
};

char g_SoldierMvmCollectCredits[][PLATFORM_MAX_PATH] = 
{
	"vo/soldier_mvm_collect_credits01.mp3", 
	"vo/soldier_mvm_collect_credits02.mp3"
};

static bool g_dropCurrencyPacks;
static bool g_buytimeActive;
static int g_balance[TF_MAXPLAYERS + 1];

static Handle g_destroyCurrencyPackTimer;
static Handle g_buytimeTimer;
static Handle g_hudSync;

ConVar tfgo_buytime;

ConVar tf_arena_max_streak;
ConVar tf_arena_first_blood;
ConVar tf_arena_round_time;
ConVar tf_arena_use_queue;

static StringMap g_currencypackPlayerMap;

public Plugin myinfo =  {
	name = "Team Fortress: Global Offensive", 
	author = "Mikusch", 
	description = "A Team Fortress 2 gamemode inspired by Counter-Strike: Global Offensive", 
	version = "1.0", 
	url = "https://github.com/Mikusch/tfgo"
};

public void OnPluginStart()
{
	tfgo_buytime = CreateConVar("tfgo_buytime", "30", "How many seconds after round start players can buy items for", _, true, 5.0);
	
	g_hudSync = CreateHudSynchronizer();
	
	g_currencypackPlayerMap = CreateTrie();
	LoadTranslations("common.phrases.txt");
	
	HookEvent("player_spawn", Event_Player_Spawn);
	HookEvent("player_death", Event_Player_Death);
	HookEvent("arena_win_panel", Event_Teamplay_Round_Win);
	HookEvent("player_changeclass", Event_Player_ChangeClass);
	HookEvent("arena_round_start", Event_Arena_Round_Start);
	HookEvent("teamplay_round_start", Event_Teamplay_Round_Start);
	HookEvent("arena_match_maxstreak", Event_Arena_Match_MaxStreak);
	
	tf_arena_max_streak = FindConVar("tf_arena_max_streak");
	tf_arena_first_blood = FindConVar("tf_arena_first_blood");
	tf_arena_round_time = FindConVar("tf_arena_round_time");
	tf_arena_use_queue = FindConVar("tf_arena_use_queue");
	
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

void PrecacheSounds()
{
	PrecacheSound("mvm/mvm_money_vanish.wav");
	for (int i = 0; i < sizeof(g_EngineerMvmCollectCredits); i++)PrecacheSound(g_EngineerMvmCollectCredits[i]);
	for (int i = 0; i < sizeof(g_HeavyMvmCollectCredits); i++)PrecacheSound(g_HeavyMvmCollectCredits[i]);
	for (int i = 0; i < sizeof(g_MedicMvmCollectCredits); i++)PrecacheSound(g_MedicMvmCollectCredits[i]);
	for (int i = 0; i < sizeof(g_SoldierMvmCollectCredits); i++)PrecacheSound(g_SoldierMvmCollectCredits[i]);
}

void PrecacheModels()
{
	PrecacheModel("models/items/currencypack_large.mdl");
	PrecacheModel("models/items/currencypack_medium.mdl");
	PrecacheModel("models/items/currencypack_small.mdl");
}

public Action Event_Arena_Match_MaxStreak(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 0; i < sizeof(g_balance); i++)
	{
		g_balance[i] = 0;
	}
}


public Action Event_Player_Spawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	RemoveWeapons(client);
	
	int weapon = GetPlayerWeaponSlot(client, 2);
	EquipPlayerWeapon(client, weapon);
	
	return Plugin_Continue;
}

public Action Event_Player_Death(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (g_dropCurrencyPacks)
	{
		int iCurrencyPack = EntIndexToEntRef(CreateEntityByName("item_currencypack_medium"));
		if (DispatchSpawn(iCurrencyPack))
		{
			char key[32];
			IntToString(iCurrencyPack, key, sizeof(key));
			g_currencypackPlayerMap.SetValue(key, client);
			SDKHook(iCurrencyPack, SDKHook_Touch, Cash_OnTouch);
			SDKHook(iCurrencyPack, SDKHook_SpawnPost, Cash_OnSpawnPost);
			float origin[3];
			GetClientAbsOrigin(client, origin);
			TeleportEntity(iCurrencyPack, origin, NULL_VECTOR, NULL_VECTOR);
			CreateTimer(30.0, Destroy_Currency_Pack, iCurrencyPack);
		}
	}

	return Plugin_Continue;
}

public void OnClientConnected(int client)
{
	g_balance[client] = TFGO_STARTING_MONEY;
}

public Action Destroy_Currency_Pack(Handle timer, int entity)
{
	if (IsValidEntity(entity)) {
		float vec[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vec);
		EmitAmbientSound("mvm/mvm_money_vanish.wav", vec); // TODO: sound plays even after round restart
		RemoveEntity(entity);
	}
}

public Action Event_Teamplay_Round_Win(Event event, const char[] name, bool dontBroadcast)
{
	g_dropCurrencyPacks = false;
	return Plugin_Continue;
}

public Action Event_Teamplay_Round_Start(Event event, const char[] name, bool dontBroadcast)
{
	char buytime[32];
	tfgo_buytime.GetString(buytime, sizeof(buytime));
	PrintToServer("buytime is %s", buytime);
	g_buytimeTimer = CreateTimer(StringToFloat(buytime), DisableBuyMenu);
	PrintToChatAll("Buy time has started!");
	g_buytimeActive = true;
}

public Action Event_Arena_Round_Start(Event event, const char[] name, bool dontBroadcast)
{
	g_dropCurrencyPacks = true;
	return Plugin_Continue;
}

public Action DisableBuyMenu(Handle timer) {
	PrintToChatAll("Buy time is over!");
	g_buytimeActive = false;
}

public Action Event_Player_ChangeClass(Event event, const char[] name, bool dontBroadcast) {
	// during setup time, refund money if player had weapons and changed class
	int client = GetClientOfUserId(event.GetInt("userid"));
	return Plugin_Continue;
}

void RemoveWeapons(int client) {
	TF2_RemoveWeaponSlot(client, 0); // Primary
	TF2_RemoveWeaponSlot(client, 1); // Secondary
	
	// special cases
	switch (TF2_GetPlayerClass(client))
	{
		case TFClass_Spy:
		{
			TF2_RemoveWeaponSlot(client, 4); // Invis Watch
		}
		case TFClass_Engineer:
		{
			TF2_RemoveWeaponSlot(client, 3); // Construction PDA
		}
	}
}

public Action Prevent_Touch(int entity)
{
	return Plugin_Handled;
}

public void Cash_OnSpawnPost(int entity)
{
	// After the 2015 Halloween update, currency packs will not spawn if there's no nav mesh. This allows Cash to spawn on maps without a nav mesh!
	SetEntProp(entity, Prop_Send, "m_bDistributed", true);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "func_respawnroom")) {
		SDKHook(entity, SDKHook_StartTouch, Player_EnteredSpawn);
		SDKHook(entity, SDKHook_EndTouch, Player_ExitedSpawn);
	}
}

public Action Player_EnteredSpawn(int entity, int client)
{
	if (client <= MaxClients && IsClientConnected(client))
	{
		PrintToServer("%d entered spawn", client);
	}
}

public Action Player_ExitedSpawn(int entity, int client)
{
	if (IsClientConnected(client))
	{
		PrintToServer("%d left spawn", client);
	}
}

public Action Cash_OnTouch(int entity, int client)
{
	char key[32];
	IntToString(EntIndexToEntRef(entity), key, sizeof(key));
	int iCashOwner;
	g_currencypackPlayerMap.GetValue(key, iCashOwner);
	
	
	if (TF2_GetClientTeam(iCashOwner) == TF2_GetClientTeam(client))
	{
		// disallow picking up your own team's cash
		return Plugin_Handled;
	}
	
	switch (TF2_GetPlayerClass(client))
	{
		case TFClass_Soldier:
		{
			int iRandom = GetRandomInt(0, sizeof(g_SoldierMvmCollectCredits) - 1);
			EmitSoundToAll(g_SoldierMvmCollectCredits[iRandom], client, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
		}
		case TFClass_Engineer:
		{
			int iRandom = GetRandomInt(0, sizeof(g_EngineerMvmCollectCredits) - 1);
			EmitSoundToAll(g_EngineerMvmCollectCredits[iRandom], client, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
		}
		case TFClass_Heavy:
		{
			int iRandom = GetRandomInt(0, sizeof(g_HeavyMvmCollectCredits) - 1);
			EmitSoundToAll(g_HeavyMvmCollectCredits[iRandom], client, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
		}
		case TFClass_Medic:
		{
			int iRandom = GetRandomInt(0, sizeof(g_MedicMvmCollectCredits) - 1);
			EmitSoundToAll(g_MedicMvmCollectCredits[iRandom], client, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
		}
	}
	
	g_balance[client] += 100;
	RemoveEntity(entity); // fix for money teleporting to world spawn after pickup
	
	PrintToChat(client, "You have picked up $%d and now have $%d!", 100, g_balance[client]);
	return Plugin_Continue;
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
