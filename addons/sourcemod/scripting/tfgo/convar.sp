ConVar tf_arena_first_blood;
ConVar tf_arena_override_cap_enable_time;
ConVar tf_arena_preround_time;
ConVar tf_arena_round_time;
ConVar tf_arena_use_queue;
ConVar mp_bonusroundtime;
ConVar tf_weapon_criticals;
ConVar tf_weapon_criticals_melee;

void ConVar_Init()
{
	tfgo_free_armor = CreateConVar("tfgo_free_armor", "0", "Determines whether kevlar (1+) and/or helmet (2+) are given automatically", _, true, 0.0, true, 2.0);
	tfgo_max_armor = CreateConVar("tfgo_max_armor", "2", "Determines the highest level of armor allowed to be purchased. (0) None, (1) Kevlar, (2) Helmet", _, true, 0.0, true, 2.0);
	tfgo_buytime = CreateConVar("tfgo_buytime", "20", "How many seconds after spawning players can buy items for", _, true, 15.0);
	tfgo_consecutive_loss_max = CreateConVar("tfgo_consecutive_loss_max", "4", "The maximum of consecutive losses for each team that will be kept track of", _, true, float(STARTING_CONSECUTIVE_LOSSES));
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
	tfgo_cash_team_win_by_time_running_out_bomb = CreateConVar("tfgo_cash_team_win_by_time_running_out_bomb", "3250", "Team cash bonus for running down the clock");
	tfgo_cash_team_loser_bonus_consecutive_rounds = CreateConVar("tfgo_cash_team_loser_bonus_consecutive_rounds", "500", "Team cash bonus for losing consecutive rounds");
	tfgo_cash_team_terrorist_win_bomb = CreateConVar("tfgo_cash_team_terrorist_win_bomb", "3500", "Team cash award for winning by detonating the bomb");
	tfgo_cash_team_win_by_defusing_bomb = CreateConVar("tfgo_cash_team_win_by_defusing_bomb", "3500", "Team cash award for winning by defusing the bomb");
	tfgo_cash_team_planted_bomb_but_defused = CreateConVar("tfgo_cash_team_planted_bomb_but_defused", "800", "Team cash bonus for planting the bomb and losing");
	
	tf_arena_first_blood = FindConVar("tf_arena_first_blood");
	tf_arena_override_cap_enable_time = FindConVar("tf_arena_override_cap_enable_time");
	tf_arena_preround_time = FindConVar("tf_arena_preround_time");
	tf_arena_round_time = FindConVar("tf_arena_round_time");
	tf_arena_use_queue = FindConVar("tf_arena_use_queue");
	mp_bonusroundtime = FindConVar("mp_bonusroundtime");
	tf_weapon_criticals = FindConVar("tf_weapon_criticals");
	tf_weapon_criticals_melee = FindConVar("tf_weapon_criticals_melee");
}

void ConVar_Enable()
{
	tf_arena_first_blood.SetBool(false);
	tf_arena_override_cap_enable_time.SetInt(-1);
	tf_arena_preround_time.SetInt(15);
	tf_arena_round_time.SetInt(115);
	tf_arena_use_queue.SetBool(false);
	mp_bonusroundtime.SetInt(7);
	tf_weapon_criticals.SetBool(false);
	tf_weapon_criticals_melee.SetBool(false);
}

void ConVar_Disable()
{
	tf_arena_first_blood.RestoreDefault();
	tf_arena_override_cap_enable_time.RestoreDefault();
	tf_arena_preround_time.RestoreDefault();
	tf_arena_round_time.RestoreDefault();
	tf_arena_use_queue.RestoreDefault();
	mp_bonusroundtime.RestoreDefault();
	tf_weapon_criticals.RestoreDefault();
	tf_weapon_criticals_melee.RestoreDefault();
}
