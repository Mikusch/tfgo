static Handle DHookSetWinningTeam;
static Handle DHookHandleSwitchTeams;
static Handle DHookHandleScrambleTeams;
static Handle DHookGiveNamedItem;

static int HookIdsGiveNamedItem[TF_MAXPLAYERS] =  { -1, ... };

void DHook_Init(GameData gamedata)
{
	DHookSetWinningTeam = DHook_CreateVirtual(gamedata, "CTFGameRules::SetWinningTeam");
	DHookGiveNamedItem = DHook_CreateVirtual(gamedata, "CTFPlayer::GiveNamedItem");
	DHookHandleSwitchTeams = DHook_CreateVirtual(gamedata, "CTFGameRules::HandleSwitchTeams");
	DHookHandleScrambleTeams = DHook_CreateVirtual(gamedata, "CTFGameRules::HandleScrambleTeams");
	
	DHook_CreateDetour(gamedata, "CTFPlayer::PickupWeaponFromOther", Detour_PickupWeaponFromOther);
}

static Handle DHook_CreateVirtual(GameData gamedata, const char[] name)
{
	Handle hook = DHookCreateFromConf(gamedata, name);
	if (!hook)
		LogError("Failed to create hook: %s", name);
	
	return hook;
}

static void DHook_CreateDetour(GameData gamedata, const char[] name, DHookCallback preCallback = INVALID_FUNCTION, DHookCallback postCallback = INVALID_FUNCTION)
{
	Handle detour = DHookCreateFromConf(gamedata, name);
	if (!detour)
	{
		LogError("Failed to create detour: %s", name);
	}
	else
	{
		if (preCallback != INVALID_FUNCTION)
			if (!DHookEnableDetour(detour, false, preCallback))
				LogError("Failed to enable pre detour: %s", name);
		
		if (postCallback != INVALID_FUNCTION)
			if (!DHookEnableDetour(detour, true, postCallback))
				LogError("Failed to enable post detour: %s", name);
		
		delete detour;
	}
}

void DHook_HookGamerules()
{
	DHookGamerules(DHookSetWinningTeam, false, _, DHook_SetWinningTeam);
	DHookGamerules(DHookHandleSwitchTeams, false, _, DHook_HandleSwitchTeams);
	DHookGamerules(DHookHandleScrambleTeams, false, _, DHook_HandleScrambleTeams);
}

void DHook_HookClientEntity(int client)
{
	HookIdsGiveNamedItem[client] = DHookEntity(DHookGiveNamedItem, false, client, DHookRemoval_GiveNamedItem, DHook_GiveNamedItem);
}

void DHook_UnhookClientEntity(int client)
{
	if (HookIdsGiveNamedItem[client] != -1)
	{
		DHookRemoveHookID(HookIdsGiveNamedItem[client]);
		HookIdsGiveNamedItem[client] = -1;
	}
}

public MRESReturn Detour_PickupWeaponFromOther(int client, Handle returnVal, Handle params)
{
	int weapon = DHookGetParam(params, 1); // tf_dropped_weapon
	int defindex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
	TFGOPlayer(client).AddToLoadout(defindex);
	Forward_OnClientPickupWeapon(client, defindex);
}

public MRESReturn DHook_SetWinningTeam(Handle params)
{
	TFTeam team = DHookGetParam(params, 1);
	int winReason = DHookGetParam(params, 2);
	
	// Allow planting team to die
	if (g_IsBombPlanted && team != g_BombPlantingTeam && winReason == WINREASON_OPPONENTS_DEAD)
	{
		return MRES_Supercede;
	}
	else if (winReason == WINREASON_STALEMATE)
	{
		for (int i = view_as<int>(TFTeam_Red); i <= view_as<int>(TFTeam_Blue); i++)
		{
			// Only a non-attacking team can get the time win, and only if this stalemate is a result of the timer running out
			if (!TFGOTeam(view_as<TFTeam>(i)).IsAttacking && GetAlivePlayerCount() > 0)
			{
				DHookSetParam(params, 1, i);
				DHookSetParam(params, 2, WINREASON_CUSTOM_OUT_OF_TIME);
				return MRES_ChangedOverride;
			}
		}
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_HandleSwitchTeams()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		TFGOPlayer(client).Reset();
	}
	
	for (int team = view_as<int>(TFTeam_Red); team <= view_as<int>(TFTeam_Blue); team++)
	{
		TFGOTeam(view_as<TFTeam>(team)).ConsecutiveLosses = STARTING_CONSECUTIVE_LOSSES;
	}
}

public MRESReturn DHook_HandleScrambleTeams()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		TFGOPlayer(client).Reset();
	}
	
	for (int team = view_as<int>(TFTeam_Red); team <= view_as<int>(TFTeam_Blue); team++)
	{
		TFGOTeam(view_as<TFTeam>(team)).ConsecutiveLosses = STARTING_CONSECUTIVE_LOSSES;
		SetTeamScore(team, 0);
	}
	
	// Arena informs the players of a team switch but not of a scramble, wtf?
	Event alert = CreateEvent("teamplay_alert");
	alert.SetInt("alert_type", 0);
	alert.Fire();
	PrintToChatAll("%T", "TF_TeamsScrambled", LANG_SERVER);
	EmitGameSoundToAll(GAMESOUND_ANNOUNCER_TEAM_SCRAMBLE);
}

public MRESReturn DHook_GiveNamedItem(int client, Handle returnVal, Handle params)
{
	// Block if one of the pointers is null
	if (DHookIsNullParam(params, 1) || DHookIsNullParam(params, 3))
	{
		DHookSetReturn(returnVal, 0);
		return MRES_Supercede;
	}
	
	char classname[256];
	DHookGetParamString(params, 1, classname, sizeof(classname));
	int defindex = DHookGetParamObjectPtrVar(params, 3, 4, ObjectValueType_Int) & 0xFFFF;
	
	Action action = TF2_OnGiveNamedItem(client, classname, defindex);
	
	if (action == Plugin_Handled)
	{
		DHookSetReturn(returnVal, 0);
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public void DHookRemoval_GiveNamedItem(int hookId)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (HookIdsGiveNamedItem[client] == hookId)
		{
			HookIdsGiveNamedItem[client] = -1;
			return;
		}
	}
}
