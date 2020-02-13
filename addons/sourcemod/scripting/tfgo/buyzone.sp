static float g_DynamicBuyZoneCenters[view_as<int>(TFTeam_Blue) + 1][3];
static float g_DynamicBuyzoneRadii[view_as<int>(TFTeam_Blue) + 1];
static bool g_IsPlayerInDynamicBuyZone[TF_MAXPLAYERS + 1];

void ClearDynamicBuyZones()
{
	for (int i = 0; i < sizeof(g_DynamicBuyZoneCenters); i++)
	{
		for (int j = 0; j < sizeof(g_DynamicBuyZoneCenters[]); j++)
		{
			g_DynamicBuyZoneCenters[i][j] = 0.0;
		}
	}
	
	for (int i = 0; i < sizeof(g_DynamicBuyzoneRadii); i++)
	{
		g_DynamicBuyzoneRadii[i] = 0.0;
	}
}

void CalculateDynamicBuyZones()
{
	ClearDynamicBuyZones();
	
	for (int team = view_as<int>(TFTeam_Red); team <= view_as<int>(TFTeam_Blue); team++)
	{
		ArrayList teamspawns = new ArrayList(view_as<int>(TFTeam_Blue));
		
		// Collect info_player_teamspawn origins for current team for easy iteration
		int teamspawn = MaxClients + 1;
		while ((teamspawn = FindEntityByClassname(teamspawn, "info_player_teamspawn")) > -1)
		{
			int initialTeamNum = GetEntProp(teamspawn, Prop_Data, "m_iInitialTeamNum");
			if (team == initialTeamNum)
			{
				float origin[3];
				GetEntPropVector(teamspawn, Prop_Send, "m_vecOrigin", origin);
				teamspawns.PushArray(origin);
			}
		}
		
		for (int i = 0; i < teamspawns.Length; i++)
		{
			float origin1[3];
			teamspawns.GetArray(i, origin1, sizeof(origin1));
			
			// Add all team spawn origins together
			AddVectors(origin1, g_DynamicBuyZoneCenters[team], g_DynamicBuyZoneCenters[team]);
			
			// Determine buy zone radius by finding the maximum distance between all team spawns
			for (int j = 0; j < teamspawns.Length; j++)
			{
				float origin2[3];
				teamspawns.GetArray(j, origin2, sizeof(origin2));
				float distance = GetVectorDistance(origin1, origin2);
				g_DynamicBuyzoneRadii[team] = FloatMax(distance, g_DynamicBuyzoneRadii[team]);
			}
		}
		
		// Determine buy zone center by calculating the average team spawn position
		ScaleVector(g_DynamicBuyZoneCenters[team], 1.0 / teamspawns.Length);
		
		delete teamspawns;
	}
}

void DisplayMenuInDynamicBuyZone(int client)
{
	if (IsClientInGame(client) && IsPlayerAlive(client))
	{
		TFGOPlayer player = TFGOPlayer(client);
		
		int team = GetClientTeam(client);
		float origin[3];
		GetClientAbsOrigin(client, origin);
		
		float distance = GetVectorDistance(g_DynamicBuyZoneCenters[team], origin);
		if (!g_IsPlayerInDynamicBuyZone[client] && distance <= g_DynamicBuyzoneRadii[team]) // Player has entered buy zone
		{
			g_IsPlayerInDynamicBuyZone[client] = true;
			if (player.ActiveBuyMenu == null)
				DisplayMainBuyMenu(client);
		}
		else if (g_IsPlayerInDynamicBuyZone[client] && distance > g_DynamicBuyzoneRadii[team]) // Player has left buy zone
		{
			g_IsPlayerInDynamicBuyZone[client] = false;
			if (player.ActiveBuyMenu != null)
			{
				player.ActiveBuyMenu.Cancel();
				PrintHintText(client, "%T", "BuyMenu_NotInBuyZone", LANG_SERVER);
			}
		}
	}
}

void ResetPlayerBuyZoneStates()
{
	for (int i = 0; i < sizeof(g_IsPlayerInDynamicBuyZone); i++)
	{
		g_IsPlayerInDynamicBuyZone[i] = false;
	}
}

Action SDKHook_FuncRespawnRoom_StartTouch(int entity, int client)
{
	if (g_IsBuyTimeActive && IsValidClient(client) && GetClientTeam(client) == GetEntProp(entity, Prop_Data, "m_iTeamNum"))
		DisplayMainBuyMenu(client);
}

Action SDKHook_FuncRespawnRoom_EndTouch(int entity, int client)
{
	if (g_IsBuyTimeActive && IsValidClient(client) && GetClientTeam(client) == GetEntProp(entity, Prop_Data, "m_iTeamNum"))
	{
		TFGOPlayer player = TFGOPlayer(client);
		if (player.ActiveBuyMenu != null)
		{
			player.ActiveBuyMenu.Cancel();
			PrintHintText(client, "%T", "BuyMenu_NotInBuyZone", LANG_SERVER);
		}
	}
}
