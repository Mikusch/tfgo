float g_avgPlayerStartOrigin[view_as<int>(TFTeam_Blue) + 1][3];
float g_dynamicBuyzoneRadius[view_as<int>(TFTeam_Blue) + 1];

public void CalculateDynamicBuyZones()
{
	// Reset buy zones from previous map
	for (int i = 0; i < sizeof(g_avgPlayerStartOrigin); i++)
		for (int j = 0; j < sizeof(g_avgPlayerStartOrigin[]); j++)
			g_avgPlayerStartOrigin[i][j] = 0.0;
	
	for (int i = 0; i < sizeof(g_dynamicBuyzoneRadius); i++)
		g_dynamicBuyzoneRadius[i] = 0.0;
	
	// Calculate average position of each info_player_start for each team
	for (int team = view_as<int>(TFTeam_Red); team <= view_as<int>(TFTeam_Blue); team++)
	{
		ArrayList teamspawns = new ArrayList(3);
		
		// Collect info_player_teamspawns for team
		int info_player_teamspawn;
		while ((info_player_teamspawn = FindEntityByClassname(info_player_teamspawn, "info_player_teamspawn")) > -1)
		{
			int initialTeamNum = GetEntProp(info_player_teamspawn, Prop_Data, "m_iInitialTeamNum");
			if (team == initialTeamNum)
			{
				float origin[3];
				GetEntPropVector(info_player_teamspawn, Prop_Send, "m_vecOrigin", origin);
				teamspawns.PushArray(origin);
			}
		}
		
		// Go through each collected info_player_teamspawn for this team and calculate average
		for (int i = 0; i < teamspawns.Length; i++)
		{
			float origin[3];
			teamspawns.GetArray(i, origin, sizeof(origin));
			
			for (int j = 0; j < sizeof(origin); j++)
				g_avgPlayerStartOrigin[team][j] += origin[j] / teamspawns.Length;
			
			// Determine maximum distance between each spawn
			for (int j = 0; j < teamspawns.Length; j++)
			{
				float originToCompare[3];
				teamspawns.GetArray(j, originToCompare, sizeof(originToCompare));
				float distance = GetVectorDistance(origin, originToCompare);
				g_dynamicBuyzoneRadius[team] = distance > g_dynamicBuyzoneRadius[team] ? distance : g_dynamicBuyzoneRadius[team];
			}
		}
		// Give players at outermost spawns some room to walk before buyzone ends
		g_dynamicBuyzoneRadius[team] += 100.0;
		
		delete teamspawns;
	}
}

public Action Hook_OnStartTouchBuyZone(int entity, int client)
{
	if (g_isBuyTimeActive && 0 < client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == GetEntProp(entity, Prop_Data, "m_iTeamNum"))
		DisplaySlotSelectionMenu(client);
}

public Action Hook_OnEndTouchBuyZone(int entity, int client)
{
	if (g_isBuyTimeActive && 0 < client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == GetEntProp(entity, Prop_Data, "m_iTeamNum"))
	{
		TFGOPlayer player = TFGOPlayer(client);
		if (player.ActiveBuyMenu != null)
		{
			player.ActiveBuyMenu.Cancel();
			PrintHintText(client, "%T", "BuyMenu_NotInBuyZone", LANG_SERVER);
		}
	}
}

public void DisplayMenuInDynamicBuyZone(int client)
{
	if (IsClientInGame(client) && IsPlayerAlive(client))
	{
		TFGOPlayer player = TFGOPlayer(client);
		
		int team = GetClientTeam(client);
		float origin[3];
		GetClientAbsOrigin(client, origin);
		
		float distance = GetVectorDistance(g_avgPlayerStartOrigin[team], origin);
		
		float radius = tfgo_buyzone_radius_override.IntValue > -1 ? tfgo_buyzone_radius_override.FloatValue : g_dynamicBuyzoneRadius[team];
		if (distance <= radius) // Player is in buy zone
		{
			if (player.ActiveBuyMenu == null)
				DisplaySlotSelectionMenu(client);
		}
		else // Player has left buy zone
		{
			if (player.ActiveBuyMenu != null)
			{
				player.ActiveBuyMenu.Cancel();
				PrintHintText(client, "%T", "BuyMenu_NotInBuyZone", LANG_SERVER);
			}
		}
	}
}
