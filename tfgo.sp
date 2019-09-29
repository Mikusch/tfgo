#pragma semicolon 1
#pragma newdecls required

#include<sourcemod>
#include<sdktools>
#include<sdkhooks>
#include <tf2_stocks>

#define STARTING_BALANCE 1000
#define TF_MAXPLAYERS 	32

static bool canMoneyDrop;
static int g_balance[TF_MAXPLAYERS + 1] = 0;

public Plugin myinfo = {
	name = "Team Fortress: Global Offensive",
	author = "Mikusch",
	description = "My first plugin ever",
	version = "1.0",
	url = "http://www.sourcemod.net/"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases.txt");
	
	HookEvent("player_spawn", Event_Player_Spawn);
	HookEvent("player_death", Event_Player_Death);
	HookEvent("arena_win_panel", Event_Teamplay_Round_Win);
	HookEvent("arena_round_start", Event_Arena_Round_Start);
	HookEvent("player_changeclass", Event_Player_ChangeClass);
}

public void OnMapStart()
{
	PrecacheModel("models/items/currencypack_large.mdl");
	PrecacheModel("models/items/currencypack_medium.mdl");
	PrecacheModel("models/items/currencypack_small.mdl");
}

public Action Event_Player_Spawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	TF2_RemoveWeaponSlot(client, 0);
	TF2_RemoveWeaponSlot(client, 1);
	TF2_RemoveWeaponSlot(client, 4);
	
	int weapon = GetPlayerWeaponSlot(client, 2);
	EquipPlayerWeapon(client, weapon);
	
	return Plugin_Continue;
}

public Action Event_Player_Death(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
		
	if (canMoneyDrop)
	{
		int cpackSmall = CreateEntityByName("item_currencypack_custom");
		if (DispatchSpawn(cpackSmall))
		{
			SDKHook(cpackSmall, SDKHook_Touch, Cash_OnTouch);
			SDKHook(cpackSmall, SDKHook_SpawnPost, Cash_OnSpawnPost);
			float origin[3];
			float angle[3];
			GetClientAbsOrigin(client, origin);
			GetClientAbsAngles(client, angle);
			TeleportEntity(cpackSmall, origin, angle, NULL_VECTOR);
			CreateTimer(30.0, Destroy_Currency_Pack, cpackSmall);
		}
	}

	return Plugin_Continue;
}

public Action Destroy_Currency_Pack(Handle timer, int entity)
{
	RemoveEntity(entity);
}

public Action Event_Teamplay_Round_Win(Event event, const char[] name, bool dontBroadcast)
{
	PrintToServer("Disabling money drops for post-win time");
	canMoneyDrop = false;
	return Plugin_Continue;
}

public Action Event_Arena_Round_Start(Event event, const char[] name, bool dontBroadcast)
{
	PrintToServer("Enabling money drops");
	canMoneyDrop = true;
	return Plugin_Continue;
}

public Action Event_Player_ChangeClass(Event event, const char[] name, bool dontBroadcast) {
	// during setup time, refund money if player had weapons and changed class
	int client = GetClientOfUserId(event.GetInt("userid"));
	return Plugin_Continue;
}

public void removePrimaryAndSecondary(int client) {
	TF2_RemoveWeaponSlot(client, 0);
	TF2_RemoveWeaponSlot(client, 1);
	TF2_RemoveWeaponSlot(client, 3);
	TF2_RemoveWeaponSlot(client, 4);
}

public Action Prevent_Touch(int entity)
{
	return Plugin_Handled;
}

public void Cash_OnSpawnPost(int entity)
{
	// After the 2015 Halloween update, currency packs will not spawn if there's no nav mesh. This allows Crit Cash to spawn on maps without a nav mesh!
	SetEntProp(entity, Prop_Send, "m_bDistributed", true);
}

public Action Cash_OnTouch(int entity, int client)
{
	TFTeam team = TF2_GetClientTeam(client);
	switch(team)
	{
		case TFTeam_Red:
		{
			
		}
		case TFTeam_Blue:
		{
			
		}
	}
	
	g_balance[client] += 100;
	RemoveEntity(entity); // Money gets teleported to the world spawn after pickup, to counteract this we just delete it
	
	PrintToChat(client, "You have picked up $%d!", 100, g_balance[client]);
}
	
public void OnClientAuthorized(int client, const char[] auth)
{
	g_balance[client] = STARTING_BALANCE;
}

int GetPlayerScore(int client)
{
	int resource = GetPlayerResourceEntity();
	return GetEntProp(resource, Prop_Send, "m_iScore", _, client);
}