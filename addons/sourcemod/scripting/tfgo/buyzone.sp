static float g_DynamicBuyZoneCenters[view_as<int>(TFTeam_Blue) + 1][3];
static float g_DynamicBuyzoneRadii[view_as<int>(TFTeam_Blue) + 1];

void CalculateDynamicBuyZones()
{
	// Calculate average position of each info_player_start for each team
	for (int team = view_as<int>(TFTeam_Red); team <= view_as<int>(TFTeam_Blue); team++)
	{
		ArrayList teamspawns = new ArrayList(view_as<int>(TFTeam_Blue));
		
		// Collect info_player_teamspawns for team
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
		
		// Go through each collected info_player_teamspawn for this team and calculate average
		for (int i = 0; i < teamspawns.Length; i++)
		{
			float origin[3];
			teamspawns.GetArray(i, origin, sizeof(origin));
			
			for (int j = 0; j < sizeof(origin); j++)
			{
				g_DynamicBuyZoneCenters[team][j] += origin[j] / teamspawns.Length;
			}
			
			// Find maximum distance between all spawns
			for (int j = 0; j < teamspawns.Length; j++)
			{
				float originToCompare[3];
				teamspawns.GetArray(j, originToCompare, sizeof(originToCompare));
				float distance = GetVectorDistance(origin, originToCompare);
				g_DynamicBuyzoneRadii[team] = distance > g_DynamicBuyzoneRadii[team] ? distance : g_DynamicBuyzoneRadii[team];
			}
		}
		// Give players at outermost spawns some room to walk before buyzone ends
		g_DynamicBuyzoneRadii[team] += 100.0;
		
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
		float radius = tfgo_buyzone_radius_override.IntValue > -1 ? tfgo_buyzone_radius_override.FloatValue : g_DynamicBuyzoneRadii[team];
		if (distance <= radius && !g_IsPlayerInDynamicBuyZone[client]) // Player has entered buy zone
		{
			g_IsPlayerInDynamicBuyZone[client] = !g_IsPlayerInDynamicBuyZone[client];
			if (player.ActiveBuyMenu == null)
				DisplayMainBuyMenu(client);
		}
		else if (distance > radius && g_IsPlayerInDynamicBuyZone[client]) // Player has left buy zone
		{
			g_IsPlayerInDynamicBuyZone[client] = !g_IsPlayerInDynamicBuyZone[client];
			if (player.ActiveBuyMenu != null)
			{
				player.ActiveBuyMenu.Cancel();
				PrintHintText(client, "%T", "BuyMenu_NotInBuyZone", LANG_SERVER);
			}
		}
	}
}
