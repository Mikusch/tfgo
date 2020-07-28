void Event_Init()
{
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("post_inventory_application", Event_PostInventoryApplication);
	HookEvent("arena_round_start", Event_ArenaRoundStart);
	HookEvent("arena_win_panel", Event_ArenaWinPanel);
	HookEvent("teamplay_round_start", Event_TeamplayRoundStart);
	HookEvent("teamplay_point_captured", Event_TeamplayPointCaptured);
	HookEvent("teamplay_broadcast_audio", Event_Pre_TeamplayBroadcastAudio, EventHookMode_Pre);
	HookEvent("teamplay_game_over", Event_TeamplayGameOver);
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


Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	//Prevent latespawn
	if (GameRules_GetRoundState() != RoundState_Preround)
		ForcePlayerSuicide(client);
}

Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	TFGOPlayer attacker = TFGOPlayer(GetClientOfUserId(event.GetInt("attacker")));
	TFGOPlayer victim = TFGOPlayer(GetClientOfUserId(event.GetInt("userid")));
	
	char victimName[PLATFORM_MAX_PATH];
	GetClientName2(victim.Client, victimName, sizeof(victimName));
	
	// Grant kill award to attacker/assister
	if (IsValidClient(attacker.Client) && attacker != victim)
	{
		float factor = tfgo_cash_player_killed_enemy_factor.FloatValue;
		int killAward = RoundFloat(tfgo_cash_player_killed_enemy_default.IntValue * factor);
		
		int inflictorEntindex = event.GetInt("inflictor_entindex");
		char classname[PLATFORM_MAX_PATH];
		if (IsValidEntity(inflictorEntindex) && GetEntityClassname(inflictorEntindex, classname, sizeof(classname)) && StrEqual(classname, "obj_sentrygun"))
		{
			// We do this so sentry guns kills don't report as kills with the Engineer's held weapon
			attacker.AddToAccount(killAward, "%t", "Player_Cash_Award_Killed_Enemy_Generic", killAward);
		}
		else
		{
			if (event.GetInt("customkill") == TF_CUSTOM_SUICIDE) // Suicide
			{
				if (GameRules_GetRoundState() == RoundState_Stalemate)
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
						GetClientName2(attacker.Client, attackerName, sizeof(attackerName));
						
						// CS:GO does special chat messages for suicides
						for (int client = 1; client <= MaxClients; client++)
						{
							if (!IsClientInGame(client))
								continue;
							
							if (TF2_GetClientTeam(client) <= TFTeam_Spectator)
								CPrintToChat(client, "%t", "Player_Cash_Award_ExplainSuicide_Spectators", attackerName, killAward, victimName);
							else if (GetClientTeam(client) == GetClientTeam(victim.Client))
								CPrintToChat(client, "%t", "Player_Cash_Award_ExplainSuicide_EnemyGotCash", victimName);
							else if (attacker.Client != client)
								CPrintToChat(client, "%t", "Player_Cash_Award_ExplainSuicide_TeammateGotCash", attackerName, killAward, victimName);
						}
						
						attacker.AddToAccount(killAward, "%t", "Player_Cash_Award_Killed_Enemy_Generic", killAward);
						CPrintToChat(attacker.Client, "%t", "Player_Cash_Award_ExplainSuicide_YouGotCash", killAward, victimName);
					}
					
					delete enemies;
				}
			}
			else if (attacker != victim) // Weapon kill
			{
				int defindex = Config_GetOriginalItemDefIndex(event.GetInt("weapon_def_index"));
				
				char weaponName[PLATFORM_MAX_PATH];
				TF2_GetItemName(defindex, weaponName, sizeof(weaponName));
				
				TFGOWeapon weapon;
				if (g_AvailableWeapons.GetByDefIndex(defindex, weapon) > 0 && weapon.killAward != 0)
					killAward = RoundFloat(weapon.killAward * factor);
				
				attacker.AddToAccount(killAward, "%t", "Player_Cash_Award_Killed_Enemy", killAward, weaponName);
				
				MusicKit_PlayClientMusicKit(victim.Client, Music_DeathCam, false);
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
			
			assister.AddToAccount(killAward / 2, "%t", "Player_Cash_Award_Assist_Enemy", killAward / 2, victimName);
		}
	}
	
	if (GameRules_GetRoundState() != RoundState_Preround)
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
	g_IsBuyTimeActive = true;
	g_BuyTimeTimer = CreateTimer(tfgo_buytime.FloatValue, Timer_OnBuyTimeExpire, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action Event_ArenaWinPanel(Event event, const char[] name, bool dontBroadcast)
{
	int winreason = event.GetInt("winreason");
	
	if (winreason == WINREASON_STALEMATE)
	{
		TFGOTeam red = TFGOTeam(TFTeam_Red);
		TFGOTeam blue = TFGOTeam(TFTeam_Blue);
		red.PrintToChat("%t", "Team_Cash_Award_no_income_stalemate");
		blue.PrintToChat("%t", "Team_Cash_Award_no_income_stalemate");
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
			winningTeam.AddToClientAccounts(tfgo_cash_team_win_by_time_running_out_bomb.IntValue, "%t", "Team_Cash_Award_Win_Time", tfgo_cash_team_win_by_time_running_out_bomb.IntValue);
			losingTeam.PrintToChat("%t", "Team_Cash_Award_no_income_out_of_time");
		}
		else
		{
			if (winreason == WINREASON_ALL_POINTS_CAPTURED || winreason == WINREASON_DEFEND_UNTIL_TIME_LIMIT) // Bomb detonated or defused
			{
				if (g_BombPlantingTeam == winningTeam.Team)
				{
					winningTeam.AddToClientAccounts(tfgo_cash_team_terrorist_win_bomb.IntValue, "%t", "Team_Cash_Award_T_Win_Bomb", tfgo_cash_team_terrorist_win_bomb.IntValue);
				}
				else
				{
					winningTeam.AddToClientAccounts(tfgo_cash_team_win_by_defusing_bomb.IntValue, "%t", "Team_Cash_Award_Win_Defuse_Bomb", tfgo_cash_team_win_by_defusing_bomb.IntValue);
					losingTeam.AddToClientAccounts(tfgo_cash_team_planted_bomb_but_defused.IntValue, "%t", "Team_Cash_Award_Planted_Bomb_But_Defused", tfgo_cash_team_planted_bomb_but_defused.IntValue);
				}
			}
			else if (winreason == WINREASON_OPPONENTS_DEAD) // All enemies eliminated
			{
				winningTeam.AddToClientAccounts(tfgo_cash_team_elimination.IntValue, "%t", "Team_Cash_Award_Elim_Bomb", tfgo_cash_team_elimination.IntValue);
			}
			
			for (int client = 1; client <= MaxClients; client++)
			{
				if (IsClientInGame(client) && TF2_GetClientTeam(client) == losingTeam.Team)
				{
					// Do not give losing bonus to players that deliberately suicided
					if (g_HasPlayerSuicided[client])
						CPrintToChat(client, "%t", "Team_Cash_Award_no_income_suicide");
					else
						TFGOPlayer(client).AddToAccount(losingTeam.LoseIncome, "%t", "Team_Cash_Award_Loser_Bonus", losingTeam.LoseIncome);
				}
			}
		}
		
		// Adjust consecutive loss count for each team
		losingTeam.ConsecutiveLosses++;
		winningTeam.ConsecutiveLosses--;
		
		// Play MVP anthem
		g_MVP = event.GetInt("player_1");
		if (IsValidClient(g_MVP) && MusicKit_HasCustomMusicKit(g_MVP))
		{
			MusicKit_PlayMVPAnthem(g_MVP);
			
			char mvpName[MAX_NAME_LENGTH];
			GetClientName2(g_MVP, mvpName, sizeof(mvpName));
			
			char kit[PLATFORM_MAX_PATH];
			Forward_GetMusicKitName(g_MVP, kit, sizeof(kit));
			
			// Use internal name as fallback
			if (kit[0] == '\0')
				TFGOPlayer(g_MVP).GetMusicKit(kit, sizeof(kit));
			
			for (int client = 1; client <= MaxClients; client++)
			{
				if (IsClientInGame(client))
				{
					if (client == g_MVP)
						PrintToChat(client, "%t", "Playing_MVP_MusicKit_Yours");
					else
						CPrintToChat(client, "%t", "Playing_MVP_MusicKit", mvpName, kit);
				}
			}
		}
	}
}

Action Event_TeamplayRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	ResetRoundState();
	
	MusicKit_PlayAllClientMusicKits(Music_StartRound);
	
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

Action Event_TeamplayGameOver(Event event, const char[] name, bool dontBroadcast)
{
	FindConVar("sv_alltalk").BoolValue = true;
	MusicKit_PlayClientMusicKit(client, Music_HalfTime);
}
