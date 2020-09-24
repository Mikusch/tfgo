static float DynamicBuyZoneCenters[view_as<int>(TFTeam_Blue) + 1][3];
static float DynamicBuyzoneRadii[view_as<int>(TFTeam_Blue) + 1];
static bool IsPlayerInDynamicBuyZone[TF_MAXPLAYERS];

void ClearDynamicBuyZones()
{
	for (int i = 0; i < sizeof(DynamicBuyZoneCenters); i++)
	{
		for (int j = 0; j < sizeof(DynamicBuyZoneCenters[]); j++)
		{
			DynamicBuyZoneCenters[i][j] = 0.0;
		}
	}
	
	for (int i = 0; i < sizeof(DynamicBuyzoneRadii); i++)
	{
		DynamicBuyzoneRadii[i] = 0.0;
	}
}

void CalculateDynamicBuyZones()
{
	ClearDynamicBuyZones();
	
	for (TFTeam team = TFTeam_Red; team <= TFTeam_Blue; team++)
	{
		ArrayList teamspawns = new ArrayList(view_as<int>(TFTeam_Blue));
		
		// Collect info_player_teamspawn origins for current team for easy iteration
		int teamspawn = MaxClients + 1;
		while ((teamspawn = FindEntityByClassname(teamspawn, "info_player_teamspawn")) > -1)
		{
			TFTeam initialTeam = view_as<TFTeam>(GetEntProp(teamspawn, Prop_Data, "m_iInitialTeamNum"));
			if (team == initialTeam)
			{
				float origin[3];
				GetEntPropVector(teamspawn, Prop_Data, "m_vecAbsOrigin", origin);
				teamspawns.PushArray(origin);
			}
		}
		
		for (int i = 0; i < teamspawns.Length; i++)
		{
			float origin1[3];
			teamspawns.GetArray(i, origin1, sizeof(origin1));
			
			// Add all team spawn origins together
			AddVectors(origin1, DynamicBuyZoneCenters[team], DynamicBuyZoneCenters[team]);
			
			// Determine buy zone radius by finding the maximum distance between all team spawns
			for (int j = 0; j < teamspawns.Length; j++)
			{
				float origin2[3];
				teamspawns.GetArray(j, origin2, sizeof(origin2));
				float distance = GetVectorDistance(origin1, origin2);
				DynamicBuyzoneRadii[team] = FloatMax(distance, DynamicBuyzoneRadii[team]);
			}
		}
		
		// Determine buy zone center by calculating the average team spawn position
		ScaleVector(DynamicBuyZoneCenters[team], 1.0 / teamspawns.Length);
		
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
		
		float distance = GetVectorDistance(DynamicBuyZoneCenters[team], origin);
		if (!IsPlayerInDynamicBuyZone[client] && distance <= DynamicBuyzoneRadii[team])	// Player has entered buy zone
		{
			IsPlayerInDynamicBuyZone[client] = true;
			if (player.ActiveBuyMenu == null)
				BuyMenu_DisplayMainBuyMenu(client);
		}
		else if (IsPlayerInDynamicBuyZone[client] && distance > DynamicBuyzoneRadii[team])	// Player has left buy zone
		{
			IsPlayerInDynamicBuyZone[client] = false;
			if (player.ActiveBuyMenu != null)
			{
				player.ActiveBuyMenu.Cancel();
				PrintHintText(client, "%t", "BuyMenu_NotInBuyZone");
			}
		}
	}
}

void ResetPlayerBuyZoneStates()
{
	for (int i = 0; i < sizeof(IsPlayerInDynamicBuyZone); i++)
	{
		IsPlayerInDynamicBuyZone[i] = false;
	}
}
