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

void SDKHook_HookTeamControlPointMaster(int entity)
{
	SDKHook(entity, SDKHook_Spawn, SDKHook_TeamControlPointMaster_Spawn);
}

Action SDKHook_Client_PreThink(int client)
{
	TFGOPlayer player = TFGOPlayer(client);
	
	SetHudTextParams(0.05, 0.325, 0.1, 162, 255, 71, 255, _, 0.0, 0.0, 0.0);
	ShowHudText(client, -1, "$%d", player.Account);
	
	if (player.ArmorValue > 0)
	{
		SetHudTextParams(-1.0, 0.85, 0.1, 255, 255, 255, 255, _, 0.0, 0.0, 0.0);
		ShowHudText(client, -1, "%t", "HUD_Armor", player.ArmorValue);
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
		BuyMenu_DisplayMainBuyMenu(client);
}

Action SDKHook_FuncRespawnRoom_EndTouch(int entity, int client)
{
	if (g_IsBuyTimeActive && IsValidClient(client) && GetClientTeam(client) == GetEntProp(entity, Prop_Data, "m_iTeamNum"))
	{
		TFGOPlayer player = TFGOPlayer(client);
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
}

Action SDKHook_TriggerCaptureArea_StartTouch(int entity, int other)
{
	if (IsValidClient(other) && CanDefuse(other) && TFGOPlayer(other).HasDefuseKit)
	{
		// Player with a defuse kit has entered the point, reduce cap time
		TF2_SetAreaTimeToCap(entity, BOMB_DEFUSE_TIME / 2);
	}
}

Action SDKHook_TriggerCaptureArea_EndTouch(int entity, int other)
{
	if (IsValidClient(other) && CanDefuse(other) && TFGOPlayer(other).HasDefuseKit)
	{
		// Player with a defuse kit has left the point, we need to check if anyone else still on the point has one
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client) && client != other && CanDefuse(client) && TFGOPlayer(client).HasDefuseKit)
				return;
		}
		
		// No one else on the point has a defuse kit, reset the cap time
		TF2_SetAreaTimeToCap(entity, BOMB_DEFUSE_TIME);
	}
}

Action SDKHook_TeamControlPointMaster_Spawn(int entity)
{
	DispatchKeyValue(entity, "cpm_restrict_team_cap_win", "1");
}
