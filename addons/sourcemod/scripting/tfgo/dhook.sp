/*
 * Copyright (C) 2020  Mikusch
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

static DynamicHook DHookPlayerMayCapturePoint;
static DynamicHook DHookTimerMayExpire;
static DynamicHook DHookSetWinningTeam;
static DynamicHook DHookHandleSwitchTeams;
static DynamicHook DHookHandleScrambleTeams;
static DynamicHook DHookFlagsMayBeCapped;
static DynamicHook DHookGiveNamedItem;

void DHook_Init(GameData gamedata)
{
	DHookPlayerMayCapturePoint = DHook_CreateVirtualHook(gamedata, "CTeamplayRules::PlayerMayCapturePoint");
	DHookTimerMayExpire = DHook_CreateVirtualHook(gamedata, "CTeamplayRules::TimerMayExpire");
	DHookSetWinningTeam = DHook_CreateVirtualHook(gamedata, "CTeamplayRules::SetWinningTeam");
	DHookHandleSwitchTeams = DHook_CreateVirtualHook(gamedata, "CTeamplayRules::HandleSwitchTeams");
	DHookHandleScrambleTeams = DHook_CreateVirtualHook(gamedata, "CTeamplayRules::HandleScrambleTeams");
	DHookFlagsMayBeCapped = DHook_CreateVirtualHook(gamedata, "CTFGameRules::FlagsMayBeCapped");
	DHookGiveNamedItem = DHook_CreateVirtualHook(gamedata, "CTFPlayer::GiveNamedItem");
	
	DHook_CreateDetour(gamedata, "CTFPlayer::PickupWeaponFromOther", Detour_PickupWeaponFromOther);
	DHook_CreateDetour(gamedata, "CTeamplayRoundBasedRules::State_Enter", Detour_StateEnter);
}

static DynamicHook DHook_CreateVirtualHook(GameData gamedata, const char[] name)
{
	DynamicHook hook = DynamicHook.FromConf(gamedata, name);
	if (!hook)
		LogError("Failed to create virtual hook: %s", name);
	
	return hook;
}

static void DHook_CreateDetour(GameData gamedata, const char[] name, DHookCallback callbackPre = INVALID_FUNCTION, DHookCallback callbackPost = INVALID_FUNCTION)
{
	DynamicDetour detour = DynamicDetour.FromConf(gamedata, name);
	if (!detour)
	{
		LogError("Failed to create detour: %s", name);
	}
	else
	{
		if (callbackPre != INVALID_FUNCTION)
			detour.Enable(Hook_Pre, callbackPre);
		
		if (callbackPost != INVALID_FUNCTION)
			detour.Enable(Hook_Post, callbackPost);
	}
}

void DHook_HookGamerules()
{
	DHookPlayerMayCapturePoint.HookGamerules(Hook_Post, DHook_PlayerMayCapturePoint_Post);
	DHookTimerMayExpire.HookGamerules(Hook_Post, DHook_TimerMayExpire_Post);
	DHookSetWinningTeam.HookGamerules(Hook_Pre, DHook_SetWinningTeam);
	DHookHandleSwitchTeams.HookGamerules(Hook_Pre, DHook_HandleSwitchTeams);
	DHookHandleScrambleTeams.HookGamerules(Hook_Pre, DHook_HandleScrambleTeams);
	DHookFlagsMayBeCapped.HookGamerules(Hook_Post, DHook_FlagsMayBeCapped_Post);
}

void DHook_HookClientEntity(int client)
{
	DHookGiveNamedItem.HookEntity(Hook_Pre, client, DHook_GiveNamedItem);
}

public MRESReturn Detour_PickupWeaponFromOther(int client, DHookReturn ret, DHookParam param)
{
	int weapon = param.Get(1); // tf_dropped_weapon
	int defindex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
	TFGOPlayer(client).AddToLoadout(defindex);
	Forward_OnClientPickupWeapon(client, defindex);
	
	return MRES_Ignored;
}

public MRESReturn Detour_StateEnter(DHookParam param)
{
	RoundState newState = view_as<RoundState>(param.Get(1));
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

public MRESReturn DHook_PlayerMayCapturePoint_Post(DHookReturn ret, DHookParam param)
{
	int client = param.Get(1);
	if (ret.Value)
	{
		if (!g_IsBombPlanted && IsValidClient(client) && TFGOTeam(TF2_GetClientTeam(client)).IsAttacking)
		{
			ret.Value = IsBomb(GetEntPropEnt(client, Prop_Send, "m_hItem"));
			return MRES_Supercede;
		}
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_TimerMayExpire_Post(DHookReturn ret)
{
	// Always allow the timer to expire
	ret.Value = true;
	return MRES_Supercede;
}

public MRESReturn DHook_SetWinningTeam(DHookParam param)
{
	TFTeam team = param.Get(1);
	int winReason = param.Get(2);
	
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
				param.Set(1, i);
				param.Set(2, WINREASON_CUSTOM_OUT_OF_TIME);
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
	
	return MRES_Ignored;
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
	
	return MRES_Ignored;
}

public MRESReturn DHook_FlagsMayBeCapped_Post(DHookReturn ret)
{
	ret.Value = true;
	return MRES_Supercede;
}

public MRESReturn DHook_GiveNamedItem(int client, DHookReturn ret, DHookParam param)
{
	// Block if one of the pointers is null
	if (param.IsNull(1) || param.IsNull(3))
	{
		ret.Value = 0;
		return MRES_Supercede;
	}
	
	char classname[256];
	param.GetString(1, classname, sizeof(classname));
	int defindex = param.GetObjectVar(3, 4, ObjectValueType_Int) & 0xFFFF;
	
	Action action = TF2_OnGiveNamedItem(client, classname, defindex);
	
	if (action == Plugin_Handled)
	{
		ret.Value = 0;
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}
