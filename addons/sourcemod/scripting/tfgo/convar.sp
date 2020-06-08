enum struct ConVarInfo
{
	ConVar convar;
	float value;
	float defaultValue;
}

static ArrayList ConVars;

void ConVar_Init()
{
	char value[32];
	Format(value, sizeof(value), "%s.%s", PLUGIN_VERSION, PLUGIN_VERSION_REVISION);
	CreateConVar("tfgo_version", value, "The current TF:GO version", FCVAR_NOTIFY | FCVAR_DONTRECORD | FCVAR_SPONLY);
	
	tfgo_free_armor = CreateConVar("tfgo_free_armor", "0", "Determines whether kevlar (1+) and/or helmet (2+) are given automatically", _, true, 0.0, true, 2.0);
	tfgo_max_armor = CreateConVar("tfgo_max_armor", "2", "Determines the highest level of armor allowed to be purchased. (0) None, (1) Kevlar, (2) Helmet", _, true, 0.0, true, 2.0);
	tfgo_buytime = CreateConVar("tfgo_buytime", "20", "How many seconds after spawning players can buy items for", _, true, 15.0);
	tfgo_consecutive_loss_max = CreateConVar("tfgo_consecutive_loss_max", "4", "The maximum of consecutive losses for each team that will be kept track of", _, true, float(STARTING_CONSECUTIVE_LOSSES));
	tfgo_bombtimer = CreateConVar("tfgo_bombtimer", "40", "How long from when the bomb is planted until it blows", _, true, 10.0);
	tfgo_halftime = CreateConVar("tfgo_halftime", "1", "Determines whether the match switches sides in a halftime event");
	tfgo_startmoney = CreateConVar("tfgo_startmoney", "800", "Amount of money each player gets when they reset", _, true, 0.0);
	tfgo_maxmoney = CreateConVar("tfgo_maxmoney", "16000", "Maximum amount of money allowed in a player's account", _, true, 0.0);
	tfgo_cash_player_bomb_planted = CreateConVar("tfgo_cash_player_bomb_planted", "300", "Cash award for each player that planted the bomb");
	tfgo_cash_player_bomb_defused = CreateConVar("tfgo_cash_player_bomb_defused", "300", "Cash award for each player that defused the bomb");
	tfgo_cash_player_killed_enemy_default = CreateConVar("tfgo_cash_player_killed_enemy_default", "300", "Default cash award for eliminating an enemy player");
	tfgo_cash_player_killed_enemy_factor = CreateConVar("tfgo_cash_player_killed_enemy_factor", "1", "The factor each kill award is multiplied with");
	tfgo_cash_team_elimination = CreateConVar("tfgo_cash_team_elimination", "3250", "Team cash award for winning by eliminating the enemy team");
	tfgo_cash_team_loser_bonus = CreateConVar("tfgo_cash_team_loser_bonus", "1400", "Team cash bonus for losing");
	tfgo_cash_team_win_by_time_running_out_bomb = CreateConVar("tfgo_cash_team_win_by_time_running_out_bomb", "3250", "Team cash bonus for running down the clock");
	tfgo_cash_team_loser_bonus_consecutive_rounds = CreateConVar("tfgo_cash_team_loser_bonus_consecutive_rounds", "500", "Team cash bonus for losing consecutive rounds");
	tfgo_cash_team_terrorist_win_bomb = CreateConVar("tfgo_cash_team_terrorist_win_bomb", "3500", "Team cash award for winning by detonating the bomb");
	tfgo_cash_team_win_by_defusing_bomb = CreateConVar("tfgo_cash_team_win_by_defusing_bomb", "3500", "Team cash award for winning by defusing the bomb");
	tfgo_cash_team_planted_bomb_but_defused = CreateConVar("tfgo_cash_team_planted_bomb_but_defused", "800", "Team cash bonus for planting the bomb and losing");
	
	ConVars = new ArrayList(sizeof(ConVarInfo));
	
	ConVar_Add("mp_blockstyle", 0.0);
	ConVar_Add("mp_bonusroundtime", 7.0);
	ConVar_Add("mp_capstyle", 0.0);
	ConVar_Add("mp_maxrounds", 15.0);
	ConVar_Add("tf_arena_first_blood", 0.0);
	ConVar_Add("tf_arena_override_cap_enable_time", -1.0);
	ConVar_Add("tf_arena_preround_time", 15.0);
	ConVar_Add("tf_arena_round_time", 115.0);
	ConVar_Add("tf_arena_use_queue", 0.0);
	ConVar_Add("tf_weapon_criticals", 0.0);
}

void ConVar_Add(const char[] name, float value)
{
	ConVarInfo info;
	info.convar = FindConVar(name);
	info.value = value;
	ConVars.PushArray(info);
}

void ConVar_Enable()
{
	for (int i = 0; i < ConVars.Length; i++)
	{
		ConVarInfo info;
		ConVars.GetArray(i, info);
		info.defaultValue = info.convar.FloatValue;
		ConVars.SetArray(i, info);
		
		info.convar.SetFloat(info.value);
		info.convar.AddChangeHook(ConVar_OnChanged);
	}
}

void ConVar_Disable()
{
	for (int i = 0; i < ConVars.Length; i++)
	{
		ConVarInfo info;
		ConVars.GetArray(i, info);
		
		info.convar.RemoveChangeHook(ConVar_OnChanged);
		info.convar.SetFloat(info.defaultValue);
	}
}

void ConVar_OnChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	int index = ConVars.FindValue(convar, ConVarInfo::convar);
	if (index != -1)
	{
		ConVarInfo info;
		ConVars.GetArray(index, info);
		float value = StringToFloat(newValue);
		
		if (value != info.value)
			info.convar.SetFloat(info.value);
	}
}
