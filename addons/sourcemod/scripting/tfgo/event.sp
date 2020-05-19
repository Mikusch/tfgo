void Event_Init()
{
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("post_inventory_application", Event_PostInventoryApplication);
	HookEvent("arena_round_start", Event_ArenaRoundStart);
	HookEvent("arena_win_panel", Event_ArenaWinPanel);
	HookEvent("teamplay_round_start", Event_TeamplayRoundStart);
	HookEvent("teamplay_point_captured", Event_TeamplayPointCaptured);
	HookEvent("teamplay_broadcast_audio", Event_Pre_TeamplayBroadcastAudio, EventHookMode_Pre);
}

Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	TFTeam team = view_as<TFTeam>(event.GetInt("team"));
	
	// Cap player account at highest of the team
	int highestAccount = tfgo_startmoney.IntValue;
	for (int client = 1; client <= MaxClients; client++)
	{
		int account = TFGOPlayer(client).Account;
		if (IsClientInGame(client) && TF2_GetClientTeam(client) == team && account > highestAccount)
			highestAccount = account;
	}
	
	TFGOPlayer player = TFGOPlayer(GetClientOfUserId(event.GetInt("userid")));
	if (player.Account > highestAccount)
		player.Account = highestAccount;
	
	player.RemoveAllItems(true);
}

Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	TFGOPlayer attacker = TFGOPlayer(GetClientOfUserId(event.GetInt("attacker")));
	TFGOPlayer victim = TFGOPlayer(GetClientOfUserId(event.GetInt("userid")));
	
	char victimName[PLATFORM_MAX_PATH];
	GetClientName(victim.Client, victimName, sizeof(victimName));
	
	// Grant kill award to attacker/assister
	if (IsValidClient(attacker.Client))
	{
		float factor = tfgo_cash_player_killed_enemy_factor.FloatValue;
		int killAward = RoundFloat(tfgo_cash_player_killed_enemy_default.IntValue * factor);
		
		int inflictorEntindex = event.GetInt("inflictor_entindex");
		char classname[PLATFORM_MAX_PATH];
		if (IsValidEntity(inflictorEntindex) && GetEntityClassname(inflictorEntindex, classname, sizeof(classname)) && StrEqual(classname, "obj_sentrygun"))
		{
			// We do this so sentry guns kills don't report as kills with the Engineer's held weapon
			attacker.AddToAccount(killAward, "%T", "Player_Cash_Award_Killed_Enemy_Generic", LANG_SERVER, killAward);
		}
		else
		{
			if (attacker == victim) // Suicide
			{
				if (g_IsMainRoundActive)
				{
					g_HasPlayerSuicided[victim.Client] = true;
					
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
						
						attacker.AddToAccount(killAward, "%T", "Player_Cash_Award_Killed_Enemy_Generic", LANG_SERVER, killAward);
						PrintToChat(attacker.Client, "%T", "Player_Cash_Award_ExplainSuicide_YouGotCash", LANG_SERVER, killAward, victimName);
					}
					
					delete enemies;
				}
			}
			else // Weapon kill
			{
				// TODO: Localized text for all weapons, not just the original (UserMessage SayText2?)
				int defindex = Config_GetOriginalItemDefIndex(event.GetInt("weapon_def_index"));
				
				char weaponName[PLATFORM_MAX_PATH];
				TF2_GetItemName(defindex, weaponName, sizeof(weaponName));
				
				TFGOWeapon weapon;
				if (g_AvailableWeapons.GetByDefIndex(defindex, weapon) > 0 && weapon.killAward != 0)
					killAward = RoundFloat(weapon.killAward * factor);
				
				attacker.AddToAccount(killAward, "%T", "Player_Cash_Award_Killed_Enemy", LANG_SERVER, killAward, weaponName);
			}
		}
		
		// Grant assist award
		TFGOPlayer assister = TFGOPlayer(GetClientOfUserId(event.GetInt("assister")));
		if (IsValidClient(assister.Client))
		{
			int activeWeapon = GetEntPropEnt(assister.Client, Prop_Send, "m_hActiveWeapon");
			if (IsValidEntity(activeWeapon))
			{
				int defindex = GetEntProp(activeWeapon, Prop_Send, "m_iItemDefinitionIndex");
				
				TFGOWeapon weapon;
				if (g_AvailableWeapons.GetByDefIndex(defindex, weapon) > 0 && weapon.killAward != 0)
					killAward = RoundFloat(weapon.killAward * factor);
			}
			
			assister.AddToAccount(killAward / 2, "%T", "Player_Cash_Award_Assist_Enemy", LANG_SERVER, killAward / 2, victimName);
		}
	}
	
	if (g_IsMainRoundActive || g_IsBonusRoundActive)
		victim.RemoveAllItems(true);
	
	if (victim.ActiveBuyMenu != null)
		victim.ActiveBuyMenu.Cancel();
}

Action Event_PostInventoryApplication(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	// Remove any weapons they shouldn't have
	TF2_CheckClientWeapons(client);
	
	TFGOPlayer player = TFGOPlayer(client);
	player.ApplyLoadout();
	
	if (tfgo_free_armor.IntValue >= 1)
		player.ArmorValue = TF2_GetMaxHealth(client);
	if (tfgo_free_armor.IntValue >= 2)
		player.HasHelmet = true;
	
	if (player.ActiveBuyMenu != null)
		player.ActiveBuyMenu.Cancel();
	
	// Open buy menu on respawn
	BuyMenu_DisplayMainBuyMenu(client);
}

Action Event_ArenaRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_IsMainRoundActive = true;
	g_IsBuyTimeActive = true;
	g_BuyTimeTimer = CreateTimer(tfgo_buytime.FloatValue, Timer_OnBuyTimeExpire, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action Event_ArenaWinPanel(Event event, const char[] name, bool dontBroadcast)
{
	g_IsMainRoundActive = false;
	g_IsBonusRoundActive = true;
	
	int winreason = event.GetInt("winreason");
	
	if (winreason == WINREASON_STALEMATE)
	{
		TFGOTeam red = TFGOTeam(TFTeam_Red);
		TFGOTeam blue = TFGOTeam(TFTeam_Blue);
		red.PrintToChat("%T", "Team_Cash_Award_no_income_stalemate", LANG_SERVER);
		blue.PrintToChat("%T", "Team_Cash_Award_no_income_stalemate", LANG_SERVER);
		red.ConsecutiveLosses++;
		blue.ConsecutiveLosses++;
	}
	else
	{
		// Determine winning/losing team
		TFGOTeam winningTeam = TFGOTeam(view_as<TFTeam>(event.GetInt("winning_team")));
		TFGOTeam losingTeam = TFGOTeam(TF2_GetEnemyTeam(winningTeam.Team));
		
		if (winreason == WINREASON_CUSTOM_OUT_OF_TIME) // Attackers ran out of time
		{
			winningTeam.AddToClientAccounts(tfgo_cash_team_win_by_time_running_out_bomb.IntValue, "%T", "Team_Cash_Award_Win_Time", LANG_SERVER, tfgo_cash_team_win_by_time_running_out_bomb.IntValue);
			losingTeam.PrintToChat("%T", "Team_Cash_Award_no_income_out_of_time", LANG_SERVER);
		}
		else
		{
			if (winreason == WINREASON_ALL_POINTS_CAPTURED || winreason == WINREASON_DEFEND_UNTIL_TIME_LIMIT) // Bomb detonated or defused
			{
				if (g_BombPlantingTeam == winningTeam.Team)
				{
					winningTeam.AddToClientAccounts(tfgo_cash_team_terrorist_win_bomb.IntValue, "%T", "Team_Cash_Award_T_Win_Bomb", LANG_SERVER, tfgo_cash_team_terrorist_win_bomb.IntValue);
				}
				else
				{
					winningTeam.AddToClientAccounts(tfgo_cash_team_win_by_defusing_bomb.IntValue, "%T", "Team_Cash_Award_Win_Defuse_Bomb", LANG_SERVER, tfgo_cash_team_win_by_defusing_bomb.IntValue);
					losingTeam.AddToClientAccounts(tfgo_cash_team_planted_bomb_but_defused.IntValue, "%T", "Team_Cash_Award_Planted_Bomb_But_Defused", LANG_SERVER, tfgo_cash_team_planted_bomb_but_defused.IntValue);
				}
			}
			else if (winreason == WINREASON_OPPONENTS_DEAD) // All enemies eliminated
			{
				winningTeam.AddToClientAccounts(tfgo_cash_team_elimination.IntValue, "%T", "Team_Cash_Award_Elim_Bomb", LANG_SERVER, tfgo_cash_team_elimination.IntValue);
			}
			
			for (int client = 1; client <= MaxClients; client++)
			{
				if (IsClientInGame(client) && TF2_GetClientTeam(client) == losingTeam.Team)
				{
					// Do not give losing bonus to players that deliberately suicided
					if (g_HasPlayerSuicided[client])
						CPrintToChat(client, "%T", "Team_Cash_Award_no_income_suicide", LANG_SERVER);
					else
						TFGOPlayer(client).AddToAccount(losingTeam.LoseIncome, "%T", "Team_Cash_Award_Loser_Bonus", LANG_SERVER, losingTeam.LoseIncome);
				}
			}
		}
		
		// Adjust consecutive loss count for each team
		losingTeam.ConsecutiveLosses++;
		winningTeam.ConsecutiveLosses--;
	}
	
	static int roundsPlayed;
	roundsPlayed++;
	if (tfgo_halftime.BoolValue && roundsPlayed == tfgo_maxrounds.IntValue / 2)
	{
		SDKCall_SetSwitchTeams(true);
		Forward_OnHalfTime();
	}
	else if (roundsPlayed == tfgo_maxrounds.IntValue)
	{
		roundsPlayed = 0;
		SDKCall_SetScrambleTeams(true);
		Forward_OnMaxRounds();
	}
}

Action Event_TeamplayRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	ResetRoundState();
	
	g_IsBonusRoundActive = false;
	g_IsMainRoundActive = false;
	
	MusicKit_PlayKitsToClients(Music_StartRound);
	
	// Bomb can freely tick and explode through the bonus time and we cancel it here
	g_IsBombTicking = false;
	g_BuyTimeTimer = null;
	g_TenSecondBombTimer = null;
	g_BombDetonationTimer = null;
	g_BombExplosionTimer = null;
}

Action Event_TeamplayPointCaptured(Event event, const char[] name, bool dontBroadcast)
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
