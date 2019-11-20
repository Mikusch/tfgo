#define WEAPON_GAS_PASSER 1180
#define ATTRIB_MAX_HEALTH_ADDITIVE_BONUS 26

stock int GetAlivePlayersInTeam(TFTeam team)
{
	int count = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && IsPlayerAlive(client) && TF2_GetClientTeam(client) == team)
			count++;
	}
	return count;
}

stock int IntAbs(int num)
{
	return num < 0 ? num * -1 : num;
}

stock void TF2_ForceRoundWin(TFTeam team, int winReason, bool forceMapReset = true, bool switchTeams = false)
{
	int entity = CreateEntityByName("game_round_win");
	char strWinReason[8];
	IntToString(winReason, strWinReason, sizeof(strWinReason));
	DispatchKeyValue(entity, "win_reason", strWinReason);
	DispatchKeyValue(entity, "force_map_reset", forceMapReset ? "1" : "0");
	DispatchKeyValue(entity, "switch_teams", switchTeams ? "1" : "0");
	DispatchSpawn(entity);
	SetVariantInt(view_as<int>(team));
	AcceptEntityInput(entity, "SetTeam");
	AcceptEntityInput(entity, "RoundWin");
	RemoveEntity(entity);
}

stock void TF2_Explode(int attacker = -1, float origin[3], float damage, float radius, const char[] particle, const char[] sound)
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

stock void TF2_RemoveItemInSlot(int client, int slot)
{
	TF2_RemoveWeaponSlot(client, slot);
	int wearable = SDK_GetEquippedWearable(client, slot);
	if (wearable > MaxClients)
	{
		SDK_RemoveWearable(client, wearable);
		AcceptEntityInput(wearable, "Kill");
	}
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
		char localizedName[256];
		TF2Econ_GetLocalizedItemName(defindex, localizedName, sizeof(localizedName));
		Format(buffer, maxlength, "%T", localizedName, LANG_SERVER);
	}
}

stock void TF2_CreateAndEquipWeapon(int client, int defindex)
{
	TFClassType nClass = TF2_GetPlayerClass(client);
	int iSlot = TF2_GetSlotInItem(defindex, nClass);
	
	// Remove sniper scope and slowdown cond if have one, otherwise can cause client crashes
	if (TF2_IsPlayerInCondition(client, TFCond_Zoomed))
	{
		TF2_RemoveCondition(client, TFCond_Zoomed);
		TF2_RemoveCondition(client, TFCond_Slowed);
	}
	
	// If player already have item in his inv, remove it before we generate new weapon for him, otherwise some weapons can glitch out...
	int entity = GetPlayerWeaponSlot(client, iSlot);
	if (entity > MaxClients && IsValidEdict(entity))
		TF2_RemoveWeaponSlot(client, iSlot);
	
	// Remove wearable if have one
	int wearable = SDK_GetEquippedWearable(client, iSlot);
	if (wearable > MaxClients)
	{
		SDK_RemoveWearable(client, wearable);
		AcceptEntityInput(wearable, "Kill");
	}
	
	// Generate and equip weapon
	char className[256];
	TF2Econ_GetItemClassName(defindex, className, sizeof(className));
	TF2Econ_TranslateWeaponEntForClass(className, sizeof(className), TF2_GetPlayerClass(client));
	
	int weapon = CreateEntityByName(className);
	if (IsValidEntity(weapon))
	{
		SetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex", defindex);
		SetEntProp(weapon, Prop_Send, "m_bInitialized", 1);
		
		if (DispatchSpawn(weapon))
		{
			SetEntProp(weapon, Prop_Send, "m_bValidatedAttachedEntity", true);
			
			if (StrContains(className, "tf_wearable") == 0)
				SDK_EquipWearable(client, weapon);
			else
				EquipPlayerWeapon(client, weapon);
			
			TF2_EquipWeapon(client, weapon, className, sizeof(className));
			
			// Set ammo as weapon's max ammo
			if (HasEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType")) //Wearables dont have ammo netprop
			{
				int ammoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
				if (ammoType > -1)
				{
					// We want to set gas passer ammo empty, because thats how normal gas passer works
					int maxAmmo;
					if (defindex == WEAPON_GAS_PASSER)
						SetEntPropFloat(client, Prop_Send, "m_flItemChargeMeter", 0.0, 1);
					else
						maxAmmo = SDK_GetMaxAmmo(client, ammoType);
					
					SetEntProp(client, Prop_Send, "m_iAmmo", maxAmmo, _, ammoType);
				}
			}
			
			// Add health to player if needed
			ArrayList staticAttribs = TF2Econ_GetItemStaticAttributes(defindex);
			int index = staticAttribs.FindValue(ATTRIB_MAX_HEALTH_ADDITIVE_BONUS, 0);
			if (index > -1)
				SetEntityHealth(client, GetClientHealth(client) + RoundFloat(staticAttribs.Get(index, 1)));
			delete staticAttribs;
		}
	}
}

stock void TF2_EquipWeapon(int client, int weapon, char[] className = NULL_STRING, int classNameLength = 0)
{
	if (IsValidEntity(weapon))
	{
		int defindex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
		
		if (IsNullString(className))
		{
			TF2Econ_GetItemClassName(defindex, className, classNameLength);
			TF2Econ_TranslateWeaponEntForClass(className, classNameLength, TF2_GetPlayerClass(client));
		}
		
		if (StrContains(className, "tf_wearable") == 0 || StrContains(className, "tf_weapon_parachute") == 0)
		{
			if (GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon") <= MaxClients)
			{
				// Looks like player's active weapon got replaced into wearable, fix that by using melee
				int iMelee = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
				SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", iMelee);
			}
		}
		else if (StrContains(className, "tf_weapon_invis") == 0)
		{
			// Invis watches glitch out when switched to
			return;
		}
		else
		{
			SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
		}
	}
}

stock int TF2_GetSlotInItem(int defindex, TFClassType class)
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
					case 1:slot = WeaponSlot_Primary; // Revolver
					case 4:slot = WeaponSlot_Secondary; // Sapper
					case 5:slot = WeaponSlot_PDADisguise; // Disguise Kit
					case 6:slot = WeaponSlot_InvisWatch; // Invis Watch
				}
			}
			
			case TFClass_Engineer:
			{
				switch (slot)
				{
					case 4:slot = WeaponSlot_BuilderEngie; // Toolbox
					case 5:slot = WeaponSlot_PDABuild; // Construction PDA
					case 6:slot = WeaponSlot_PDADestroy; // Destruction PDA
				}
			}
		}
	}
	
	return slot;
}

stock void ShowGameMessage(const char[] message, const char[] icon, float time = 5.0, int displayToTeam = 0, int teamColor = 0)
{
	int msg = CreateEntityByName("game_text_tf");
	if (msg > MaxClients)
	{
		DispatchKeyValue(msg, "message", message);
		switch (displayToTeam)
		{
			case 2:DispatchKeyValue(msg, "display_to_team", "2");
			case 3:DispatchKeyValue(msg, "display_to_team", "3");
			default:DispatchKeyValue(msg, "display_to_team", "0");
		}
		switch (teamColor)
		{
			case 2:DispatchKeyValue(msg, "background", "2");
			case 3:DispatchKeyValue(msg, "background", "3");
			default:DispatchKeyValue(msg, "background", "0");
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

stock void ModelIndexToString(int index, char[] model, int size)
{
	int table = FindStringTable("modelprecache");
	ReadStringTable(table, index, model, size);
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

// SDK stocks

stock void SDK_EquipWearable(int client, int wearable)
{
	if (g_SDKEquipWearable != null)
		SDKCall(g_SDKEquipWearable, client, wearable);
}

stock void SDK_RemoveWearable(int client, int wearable)
{
	if (g_SDKRemoveWearable != null)
		SDKCall(g_SDKRemoveWearable, client, wearable);
}

stock int SDK_GetEquippedWearable(int client, int slot)
{
	if (g_SDKGetEquippedWearable != null)
		return SDKCall(g_SDKGetEquippedWearable, client, slot);
	
	return -1;
}

stock int SDK_GetMaxAmmo(int client, int slot)
{
	if (g_SDKGetMaxAmmo != null)
		return SDKCall(g_SDKGetMaxAmmo, client, slot, -1);
	return -1;
}

stock int SDK_CreateDroppedWeapon(int fromWeapon, int client, const float origin[3], const float angles[3])
{
	char clsname[32];
	if (GetEntityNetClass(fromWeapon, clsname, sizeof(clsname)))
	{
		int itemOffset = FindSendPropInfo(clsname, "m_Item");
		if (itemOffset == -1)
			ThrowError("Failed to find m_Item on %s", clsname);
		
		char model[PLATFORM_MAX_PATH];
		int modelidx = GetEntProp(fromWeapon, Prop_Send, "m_iWorldModelIndex");
		ModelIndexToString(modelidx, model, sizeof(model));
		
		int droppedWeapon = SDKCall(g_SDKCreateDroppedWeapon, client, origin, angles, model, GetEntityAddress(fromWeapon) + view_as<Address>(itemOffset));
		if (droppedWeapon != INVALID_ENT_REFERENCE)
			SDKCall(g_SDKInitDroppedWeapon, droppedWeapon, client, fromWeapon, false, false);
		return droppedWeapon;
	}
	
	return -1;
}
