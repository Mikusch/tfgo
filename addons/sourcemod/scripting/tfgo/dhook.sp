static Handle DHookPlayerMayCapturePoint;
static Handle DHookSetWinningTeam;
static Handle DHookHandleSwitchTeams;
static Handle DHookHandleScrambleTeams;
static Handle DHookFlagsMayBeCapped;
static Handle DHookGiveNamedItem;

static int HookIdsGiveNamedItem[TF_MAXPLAYERS] =  { -1, ... };

void DHook_Init(GameData gamedata)
{
	DHookPlayerMayCapturePoint = DHook_CreateVirtual(gamedata, "CTeamplayRules::PlayerMayCapturePoint");
	DHookSetWinningTeam = DHook_CreateVirtual(gamedata, "CTeamplayRules::SetWinningTeam");
	DHookHandleSwitchTeams = DHook_CreateVirtual(gamedata, "CTeamplayRules::HandleSwitchTeams");
	DHookHandleScrambleTeams = DHook_CreateVirtual(gamedata, "CTeamplayRules::HandleScrambleTeams");
	DHookFlagsMayBeCapped = DHook_CreateVirtual(gamedata, "CTFGameRules::FlagsMayBeCapped");
	DHookGiveNamedItem = DHook_CreateVirtual(gamedata, "CTFPlayer::GiveNamedItem");
	
	DHook_CreateDetour(gamedata, "CTFPlayer::PickupWeaponFromOther", Detour_PickupWeaponFromOther);
	DHook_CreateDetour(gamedata, "CTeamplayRoundBasedRules::State_Enter", Detour_StateEnter);
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
	DHookGamerules(DHookPlayerMayCapturePoint, true, _, DHook_PlayerMayCapturePoint_Post);
	DHookGamerules(DHookSetWinningTeam, false, _, DHook_SetWinningTeam);
	DHookGamerules(DHookHandleSwitchTeams, false, _, DHook_HandleSwitchTeams);
	DHookGamerules(DHookHandleScrambleTeams, false, _, DHook_HandleScrambleTeams);
	DHookGamerules(DHookFlagsMayBeCapped, true, _, DHook_FlagsMayBeCapped_Post);
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

public MRESReturn Detour_StateEnter(Handle params)
{
	RoundState newState = view_as<RoundState>(DHookGetParam(params, 1));
	ConVar mp_maxrounds = FindConVar("mp_maxrounds");
	
	static int roundsPlayed;
	
	switch (newState)
	{
		// Handle half-time
		case RoundState_Preround:
		{
			ConVar sv_alltalk = FindConVar("sv_alltalk");
			
			static float halfTimeEndTime;
			static bool alltalkToggled;
			
			if (halfTimeEndTime == 0.0 && tfgo_halftime.BoolValue && roundsPlayed == mp_maxrounds.IntValue / 2)
			{
				// Show scoreboard, freeze input, and play music kit to clients
				for (int client = 1; client <= MaxClients; client++)
				{
					if (IsClientInGame(client))
					{
						TF2_AddCondition(client, TFCond_FreezeInput, TFCondDuration_Infinite);
						ShowVGUIPanel(client, "scores");
						MusicKit_PlayClientMusicKit(client, Music_HalfTime);
					}
				}
				
				// Let opponents express their love for eachother
				if (!sv_alltalk.BoolValue)
				{
					sv_alltalk.BoolValue = true;
					alltalkToggled = true;
				}
				
				halfTimeEndTime = GetGameTime() + tfgo_halftime_duration.FloatValue;
				Forward_OnHalfTimeStarted();
			}
			
			if (halfTimeEndTime != 0.0 && halfTimeEndTime <= GetGameTime() && Forward_HasHalfTimeEnded())
			{
				// Hide scoreboard
				for (int client = 1; client <= MaxClients; client++)
				{
					if (IsClientInGame(client))
						ShowVGUIPanel(client, "scores", _, false);
				}
				
				// Initiate side switch/team scramble
				if (tfgo_halftime_scramble.BoolValue)
					SDKCall_SetScrambleTeams(Forward_ShouldSwitchTeams());
				else
					SDKCall_SetSwitchTeams(Forward_ShouldSwitchTeams());
				
				if (alltalkToggled)
				{
					sv_alltalk.BoolValue = false;
					alltalkToggled = false;
				}
				
				halfTimeEndTime = 0.0;
			}
			else if (halfTimeEndTime != 0.0)
			{
				// Do not allow TF2 to transition to preround
				return MRES_Supercede;
			}
		}
		// Track number of rounds played
		case RoundState_TeamWin:
		{
			roundsPlayed++;
			
			// Reset it for the next map
			if (roundsPlayed == mp_maxrounds.IntValue)
				roundsPlayed = 0;
		}
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_PlayerMayCapturePoint_Post(Handle returnVal, Handle params)
{
	int client = DHookGetParam(params, 1);
	if (DHookGetReturn(returnVal))
	{
		if (!g_IsBombPlanted && IsValidClient(client) && TFGOTeam(TF2_GetClientTeam(client)).IsAttacking)
		{
			DHookSetReturn(returnVal, IsBomb(GetEntPropEnt(client, Prop_Send, "m_hItem")));
			return MRES_Supercede;
		}
	}
	
	return MRES_Ignored;
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
	
	for (TFTeam team = TFTeam_Red; team <= TFTeam_Blue; team++)
	{
		TFGOTeam(team).ConsecutiveLosses = STARTING_CONSECUTIVE_LOSSES;
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
	PrintToChatAll("%t", "TF_TeamsScrambled");
	EmitGameSoundToAll(GAMESOUND_ANNOUNCER_TEAM_SCRAMBLE);
}

public MRESReturn DHook_FlagsMayBeCapped_Post(Handle returnVal, Handle params)
{
	DHookSetReturn(returnVal, true);
	return MRES_Supercede;
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
