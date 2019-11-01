float g_avgPlayerStartOrigin[view_as<int>(TFTeam_Blue) + 1][3];

public void CalculateDynamicBuyZones()
{
	// Reset buy zones from previous map
	for (int i = 0; i < sizeof(g_avgPlayerStartOrigin); i++)
		for (int j = 0; j < sizeof(g_avgPlayerStartOrigin[]); j++)
			g_avgPlayerStartOrigin[i][j] = 0.0;
	
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
			{
				g_avgPlayerStartOrigin[team][j] += origin[j] / teamspawns.Length;
			}
		}
		
		delete teamspawns;
	}
}

public Action Hook_OnStartTouchBuyZone(int entity, int client)
{
	if (g_isBuyTimeActive && client >= 1 && client <= MaxClients && IsClientInGame(client) && GetEntProp(entity, Prop_Data, "m_iTeamNum") == GetClientTeam(client))
		ShowMainBuyMenu(client);
}

public Action Hook_OnEndTouchBuyZone(int entity, int client)
{
	if (g_isBuyTimeActive && client >= 1 && client <= MaxClients && IsClientInGame(client) && GetEntProp(entity, Prop_Data, "m_iTeamNum") == GetClientTeam(client))
	{
		TFGOPlayer player = TFGOPlayer(client);
		if (player.ActiveBuyMenu != null)
		{
			player.ActiveBuyMenu.Cancel();
			PrintHintText(client, "You have left the buy zone");
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
		
		// Calculate total absolute difference between average spawn point and player's current position
		float difference;
		for (int i = 0; i < sizeof(origin); i++)difference += FloatAbs(g_avgPlayerStartOrigin[team][i] - origin[i]);
		
		if (difference <= tfgo_buyzone_radius.FloatValue) // Player is in buy zone
		{
			if (player.ActiveBuyMenu == null)
				ShowMainBuyMenu(client);
		}
		else // Player has left buy zone
		{
			if (player.ActiveBuyMenu != null)
			{
				player.ActiveBuyMenu.Cancel();
				PrintHintText(client, "You have left the buy zone");
			}
		}
	}
}
