void SDKHook_HookClient(int client)
{
	SDKHook(client, SDKHook_PreThink, SDKHook_Client_PreThink);
	SDKHook(client, SDKHook_TraceAttack, SDKHook_Client_TraceAttack);
}

void SDKHook_HookFuncRespawnRoom(int entity)
{
	SDKHook(entity, SDKHook_StartTouch, SDKHook_FuncRespawnRoom_StartTouch);
	SDKHook(entity, SDKHook_EndTouch, SDKHook_FuncRespawnRoom_EndTouch);
}

void SDKHook_HookTFLogicArena(int entity)
{
	SDKHook(entity, SDKHook_Spawn, SDKHook_TFLogicArena_Spawn);
}

void SDKHook_HookTriggerCaptureArea(int entity)
{
	SDKHook(entity, SDKHook_Spawn, SDKHook_TriggerCaptureArea_Spawn);
	SDKHook(entity, SDKHook_StartTouch, SDKHook_TriggerCaptureArea_StartTouch);
	SDKHook(entity, SDKHook_EndTouch, SDKHook_TriggerCaptureArea_EndTouch);
}

void SDKHook_HookTeamControlPoint(int entity)
{
	SDKHook(entity, SDKHook_Spawn, SDKHook_TeamControlPoint_Spawn);
}

void SDKHook_HookTeamControlPointMaster(int entity)
{
	SDKHook(entity, SDKHook_Spawn, SDKHook_TeamControlPointMaster_Spawn);
}

void SDKHook_HookGameRules(int entity)
{
	SDKHook(entity, SDKHook_Spawn, SDKHook_GameRules_Spawn);
}

void SDKHook_HookBomb(int entity)
{
	SDKHook(entity, SDKHook_Touch, SDKHook_Bomb_Touch);
}

Action SDKHook_Client_PreThink(int client)
{
	TFGOPlayer player = TFGOPlayer(client);
	
	SetHudTextParams(0.05, 0.325, 0.1, 162, 255, 71, 255, _, 0.0, 0.0, 0.0);
	ShowSyncHudText(client, g_AccountHudSync, "$%d", player.Account);
	
	if (player.ArmorValue > 0)
	{
		SetHudTextParams(-1.0, 0.95, 0.1, 255, 255, 255, 255, _, 0.0, 0.0, 0.0);
		ShowSyncHudText(client, g_ArmorHudSync, "%s %d", player.HasHelmet ? "⛨" : "⛉", player.ArmorValue);
	}
	
	if (!g_MapHasRespawnRoom && g_IsBuyTimeActive)
		DisplayMenuInDynamicBuyZone(client);
}

Action SDKHook_Client_TraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
	Action action = Plugin_Continue;
	
	int activeWeapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
	
	// Headshots
	if (IsValidEntity(activeWeapon))
	{
		int defindex = GetEntProp(activeWeapon, Prop_Send, "m_iItemDefinitionIndex");
		TFGOWeapon config;
		if (g_AvailableWeapons.GetByDefIndex(defindex, config) > 0 && config.canHeadshot)
		{
			damagetype |= DMG_USE_HITLOCATIONS;
			action = Plugin_Changed;
		}
	}
	
	// Other hitgroup damage modifiers
	switch (hitgroup)
	{
		case HITGROUP_STOMACH:
		{
			damage *= 1.25;
			action = Plugin_Changed;
		}
		case HITGROUP_LEFTLEG, HITGROUP_RIGHTLEG:
		{
			damage *= 0.75;
			action = Plugin_Changed;
		}
	}
	
	// Armor damage reduction
	if (TF2_GetClientTeam(victim) != TF2_GetClientTeam(attacker) || victim == attacker)
	{
		TFGOPlayer player = TFGOPlayer(victim);
		if (!(damagetype & (DMG_FALL | DMG_DROWN)) && player.IsArmored(hitgroup) && IsValidEntity(activeWeapon))
		{
			int defindex = GetEntProp(activeWeapon, Prop_Send, "m_iItemDefinitionIndex");
			TFGOWeapon config;
			if (g_AvailableWeapons.GetByDefIndex(defindex, config) > 0 && config.armorPenetration < 1.0) // Armor penetration >= 100% bypasses armor
			{
				player.ArmorValue -= RoundFloat(damage);
				damage *= config.armorPenetration;
				action = Plugin_Changed;
				
				if (player.ArmorValue <= 0)
					player.HasHelmet = false;
			}
		}
	}
	
	return action;
}

Action SDKHook_FuncRespawnRoom_StartTouch(int entity, int client)
{
	if (g_IsBuyTimeActive && IsValidClient(client) && GetClientTeam(client) == GetEntProp(entity, Prop_Data, "m_iTeamNum"))
	{
		TFGOPlayer(client).InBuyZone = true;
		BuyMenu_DisplayMainBuyMenu(client);
	}
}

Action SDKHook_FuncRespawnRoom_EndTouch(int entity, int client)
{
	if (g_IsBuyTimeActive && IsValidClient(client) && GetClientTeam(client) == GetEntProp(entity, Prop_Data, "m_iTeamNum"))
	{
		TFGOPlayer player = TFGOPlayer(client);
		player.InBuyZone = false;
		
		if (player.ActiveBuyMenu != null)
		{
			player.ActiveBuyMenu.Cancel();
			PrintHintText(client, "%t", "BuyMenu_NotInBuyZone");
		}
	}
}

Action SDKHook_TFLogicArena_Spawn(int entity)
{
	DispatchKeyValueFloat(entity, "CapEnableDelay", 0.0);
}

Action SDKHook_TriggerCaptureArea_Spawn(int entity)
{
	DispatchKeyValueFloat(entity, "area_time_to_cap", BOMB_PLANT_TIME);
	DispatchKeyValue(entity, "team_cancap_2", "1");
	DispatchKeyValue(entity, "team_cancap_3", "1");
	DispatchKeyValue(entity, "team_numcap_2", "1");
	DispatchKeyValue(entity, "team_numcap_3", "1");
}

Action SDKHook_TriggerCaptureArea_StartTouch(int entity, int other)
{
	if (IsValidClient(other) && TFGOPlayer(other).CanDefuse() && TFGOPlayer(other).HasDefuseKit)
	{
		// Player with a defuse kit has entered the point, reduce cap time
		TF2_SetAreaTimeToCap(entity, BOMB_DEFUSE_TIME / 2);
	}
}

Action SDKHook_TriggerCaptureArea_EndTouch(int entity, int other)
{
	if (IsValidClient(other) && TFGOPlayer(other).CanDefuse() && TFGOPlayer(other).HasDefuseKit)
	{
		// Player with a defuse kit has left the point, we need to check if anyone else still on the point has one
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client) && client != other && TFGOPlayer(client).CanDefuse() && TFGOPlayer(client).HasDefuseKit)
				return;
		}
		
		// No one else on the point has a defuse kit, reset the cap time
		TF2_SetAreaTimeToCap(entity, BOMB_DEFUSE_TIME);
	}
}

Action SDKHook_TeamControlPoint_Spawn(int entity)
{
	SetEntProp(entity, Prop_Data, "m_spawnflags", GetEntProp(entity, Prop_Data, "m_spawnflags") | SF_CAP_POINT_HIDEFLAG);
	
	// The SetLocked input does not work at all if a previous point is set
	for (int i = 0; i < MAX_PREVIOUS_POINTS; i++)
	{
		for (int team = view_as<int>(TFTeam_Red); team <= view_as<int>(TFTeam_Blue); team++)
		{
			char key[32];
			Format(key, sizeof(key), "team_previouspoint_%d_%d", team, i);
			DispatchKeyValue(entity, key, "");
		}
	}
	
	DispatchKeyValue(entity, "point_start_locked", "0");
}

Action SDKHook_TeamControlPointMaster_Spawn(int entity)
{
	DispatchKeyValue(entity, "cpm_restrict_team_cap_win", "1");
}

Action SDKHook_GameRules_Spawn(int entity)
{
	DispatchKeyValue(entity, "ctf_overtime", "0");
}

Action SDKHook_Bomb_Touch(int entity, int other)
{
	// Planted bombs can't be picked up
	return g_IsBombPlanted ? Plugin_Handled : Plugin_Continue;
}
