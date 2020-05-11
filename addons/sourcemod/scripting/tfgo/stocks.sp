#define WEAPON_GAS_PASSER 1180
#define ATTRIB_MAX_HEALTH_ADDITIVE_BONUS 26

stock bool IsValidClient(int client)
{
	return 0 < client <= MaxClients && IsClientInGame(client);
}

stock float FloatMin(float a, float b)
{
	return (a < b) ? a : b;
}

stock float FloatMax(float a, float b)
{
	return (a > b) ? a : b;
}

stock float FloatClamp(float val, float min, float max)
{
	return FloatMax(min, FloatMin(max, val));
}

stock void StrToLower(char[] str)
{
	for (int i = 0; i < strlen(str); i++)
	{
		str[i] = CharToLower(str[i]);
	}
}

stock int PrecacheParticleSystem(const char[] particleSystem)
{
	static int particleEffectNames = INVALID_STRING_TABLE;
	if (particleEffectNames == INVALID_STRING_TABLE)
	{
		if ((particleEffectNames = FindStringTable("ParticleEffectNames")) == INVALID_STRING_TABLE)
		{
			return INVALID_STRING_INDEX;
		}
	}
	
	int index = FindStringIndex2(particleEffectNames, particleSystem);
	if (index == INVALID_STRING_INDEX)
	{
		int numStrings = GetStringTableNumStrings(particleEffectNames);
		if (numStrings >= GetStringTableMaxStrings(particleEffectNames))
		{
			return INVALID_STRING_INDEX;
		}
		
		AddToStringTable(particleEffectNames, particleSystem);
		index = numStrings;
	}
	
	return index;
}

stock void ModelIndexToString(int index, char[] model, int size)
{
	int table = FindStringTable("modelprecache");
	ReadStringTable(table, index, model, size);
}

stock int FindStringIndex2(int tableidx, const char[] str)
{
	char buf[1024];
	int numStrings = GetStringTableNumStrings(tableidx);
	for (int i = 0; i < numStrings; i++)
	{
		ReadStringTable(tableidx, i, buf, sizeof(buf));
		if (StrEqual(buf, str))
		{
			return i;
		}
	}
	
	return INVALID_STRING_INDEX;
}

stock int GetAlivePlayerCount()
{
	int count = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && IsPlayerAlive(client))
			count++;
	}
	return count;
}

stock TFTeam TF2_GetEnemyTeam(TFTeam team)
{
	switch (team)
	{
		case TFTeam_Red: return TFTeam_Blue;
		case TFTeam_Blue: return TFTeam_Red;
		default: return team;
	}
}

stock int TF2_GetAlivePlayerCountForTeam(TFTeam team)
{
	int count = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && IsPlayerAlive(client) && TF2_GetClientTeam(client) == team)
			count++;
	}
	return count;
}

stock int TF2_GetMaxHealth(int client)
{
	return GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, client);
}

stock void TF2_ForceRoundWin(TFTeam team, WinReason winReason, bool forceMapReset = true, bool switchTeams = false)
{
	int entity = CreateEntityByName("game_round_win");
	if (IsValidEntity(entity))
	{
		char winReasonString[4];
		IntToString(view_as<int>(winReason), winReasonString, sizeof(winReasonString));
		DispatchKeyValue(entity, "win_reason", winReasonString);
		DispatchKeyValue(entity, "force_map_reset", forceMapReset ? "1" : "0");
		DispatchKeyValue(entity, "switch_teams", switchTeams ? "1" : "0");
		if (DispatchSpawn(entity))
		{
			SetVariantInt(view_as<int>(team));
			AcceptEntityInput(entity, "SetTeam");
			AcceptEntityInput(entity, "RoundWin");
		}
		RemoveEntity(entity);
	}
}

stock void TF2_Explode(int attacker = -1, float origin[3], float damage, float radius, const char[] particle = NULL_STRING, const char[] sound = NULL_STRING)
{
	int bomb = CreateEntityByName("tf_generic_bomb");
	DispatchKeyValueVector(bomb, "origin", origin);
	DispatchKeyValueFloat(bomb, "damage", damage);
	DispatchKeyValueFloat(bomb, "radius", radius);
	DispatchKeyValue(bomb, "health", "1");
	DispatchKeyValue(bomb, "explode_particle", particle);
	DispatchKeyValue(bomb, "sound", sound);
	DispatchSpawn(bomb);
	
	if (attacker == -1)
		AcceptEntityInput(bomb, "Detonate");
	else
		SDKHooks_TakeDamage(bomb, 0, attacker, 9999.0);
}

stock int TF2_GetItemInSlot(int client, int slot)
{
	int weapon = GetPlayerWeaponSlot(client, slot);
	if (weapon <= -1)
		return -1;
	else
		return GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
}

// Fixes TF2 Econ not returning proper names for stock weapons
stock void TF2_GetItemName(int defindex, char[] buffer, int maxlength)
{
	TF2Econ_GetItemName(defindex, buffer, maxlength);
	if (StrContains(buffer, "TF_WEAPON_") > -1) // This doesn't look like a proper name
	{
		char localizedName[PLATFORM_MAX_PATH];
		TF2Econ_GetLocalizedItemName(defindex, localizedName, sizeof(localizedName));
		Format(buffer, maxlength, "%T", localizedName, LANG_SERVER);
	}
}

stock int TF2_CreateAndEquipWeapon(int client, int defindex, const char[] classname = NULL_STRING)
{
	char classnameCopy[256];
	if (IsNullString(classname))
	{
		TF2Econ_GetItemClassName(defindex, classnameCopy, sizeof(classnameCopy));
		TF2Econ_TranslateWeaponEntForClass(classnameCopy, sizeof(classnameCopy), TF2_GetPlayerClass(client));
	}
	else
	{
		strcopy(classnameCopy, sizeof(classnameCopy), classname);
	}
	
	bool isSapper;
	if ((StrEqual(classnameCopy, "tf_weapon_builder") || StrEqual(classnameCopy, "tf_weapon_sapper")) && TF2_GetPlayerClass(client) == TFClass_Spy)
	{
		isSapper = true;
		
		//Apparently tf_weapon_sapper causes client crashes
		classnameCopy = "tf_weapon_builder";
	}
	
	TFClassType class = TF2_GetPlayerClass(client);
	int iSlot = TF2_GetItemSlot(defindex, class);
	Address pItem = SDKCall_GetLoadoutItem(client, class, iSlot);
	
	int weapon;
	if (pItem && LoadFromAddress(pItem + view_as<Address>(4), NumberType_Int16) == defindex)
	{
		weapon = SDKCall_GetBaseEntity(SDKCall_GiveNamedItem(client, classnameCopy, 0, pItem));
	}
	else
	{
		weapon = CreateEntityByName(classnameCopy);
		
		if (IsValidEntity(weapon))
		{
			SetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex", defindex);
			SetEntProp(weapon, Prop_Send, "m_bInitialized", 1);
			SetEntProp(weapon, Prop_Send, "m_iEntityQuality", 0);
			SetEntProp(weapon, Prop_Send, "m_iEntityLevel", 1);
		}
	}
	
	if (IsValidEntity(weapon))
	{
		if (isSapper)
		{
			SetEntProp(weapon, Prop_Send, "m_iObjectType", TFObject_Sapper);
			SetEntProp(weapon, Prop_Data, "m_iSubType", TFObject_Sapper);
		}
		
		if (DispatchSpawn(weapon))
		{
			SetEntProp(weapon, Prop_Send, "m_bValidatedAttachedEntity", true);
			
			if (StrContains(classnameCopy, "tf_wearable") == 0)
				SDKCall_EquipWearable(client, weapon);
			else
				EquipPlayerWeapon(client, weapon);
		}
	}
	
	return weapon;
}

stock int TF2_GetItemSlot(int defindex, TFClassType class)
{
	int slot = TF2Econ_GetItemSlot(defindex, class);
	if (slot >= 0)
	{
		// Econ reports wrong slots for Engineer and Spy
		switch (class)
		{
			case TFClass_Spy:
			{
				switch (slot)
				{
					case 1: slot = WeaponSlot_Primary; // Revolver
					case 4: slot = WeaponSlot_Secondary; // Sapper
					case 5: slot = WeaponSlot_PDADisguise; // Disguise Kit
					case 6: slot = WeaponSlot_InvisWatch; // Invis Watch
				}
			}
			
			case TFClass_Engineer:
			{
				switch (slot)
				{
					case 4: slot = WeaponSlot_BuilderEngie; // Toolbox
					case 5: slot = WeaponSlot_PDABuild; // Construction PDA
					case 6: slot = WeaponSlot_PDADestroy; // Destruction PDA
				}
			}
		}
	}
	
	return slot;
}

stock void TF2_ShowGameMessage(const char[] message, const char[] icon, float time = 5.0, int displayToTeam = 0, int teamColor = 0)
{
	int msg = CreateEntityByName("game_text_tf");
	if (msg > MaxClients)
	{
		DispatchKeyValue(msg, "message", message);
		switch (displayToTeam)
		{
			case 2: DispatchKeyValue(msg, "display_to_team", "2");
			case 3: DispatchKeyValue(msg, "display_to_team", "3");
			default: DispatchKeyValue(msg, "display_to_team", "0");
		}
		switch (teamColor)
		{
			case 2: DispatchKeyValue(msg, "background", "2");
			case 3: DispatchKeyValue(msg, "background", "3");
			default: DispatchKeyValue(msg, "background", "0");
		}
		DispatchKeyValue(msg, "icon", icon);
		DispatchSpawn(msg);
		
		AcceptEntityInput(msg, "Display");
		
		SetEntPropFloat(msg, Prop_Data, "m_flAnimTime", GetEngineTime() + time);
		
		CreateTimer(0.5, Timer_ShowGameMessage, EntIndexToEntRef(msg), TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
	}
}

Action Timer_ShowGameMessage(Handle timer, int ref)
{
	int msg = EntRefToEntIndex(ref);
	if (msg > MaxClients)
	{
		if (GetEngineTime() > GetEntPropFloat(msg, Prop_Data, "m_flAnimTime"))
		{
			AcceptEntityInput(msg, "Kill");
			return Plugin_Stop;
		}
		
		AcceptEntityInput(msg, "Display");
		return Plugin_Continue;
	}
	
	return Plugin_Stop;
}
