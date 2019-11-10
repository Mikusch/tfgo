#define WEAPON_GAS_PASSER 1180
#define ATTRIB_MAX_HEALTH_ADDITIVE_BONUS 26

stock int GetAliveTeamCount(int team)
{
	int number = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == team)number++;
	}
	return number;
}

stock int IntAbs(int num)
{
	if (num < 0)return num * -1;
	return num;
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

// Taken from VSH Rewrite
stock void TF2_Explode(int iAttacker = -1, float flPos[3], float flDamage, float flRadius, const char[] strParticle, const char[] strSound)
{
	int iBomb = CreateEntityByName("tf_generic_bomb");
	DispatchKeyValueVector(iBomb, "origin", flPos);
	DispatchKeyValueFloat(iBomb, "damage", flDamage);
	DispatchKeyValueFloat(iBomb, "radius", flRadius);
	DispatchKeyValue(iBomb, "health", "1");
	DispatchKeyValue(iBomb, "explode_particle", strParticle);
	DispatchKeyValue(iBomb, "sound", strSound);
	DispatchSpawn(iBomb);
	
	if (iAttacker == -1)
		AcceptEntityInput(iBomb, "Detonate");
	else
		SDKHooks_TakeDamage(iBomb, 0, iAttacker, 9999.0);
}

stock void TF2_RemoveItemInSlot(int client, int slot)
{
	TF2_RemoveWeaponSlot(client, slot);
	int iWearable = SDK_GetEquippedWearable(client, slot);
	if (iWearable > MaxClients)
	{
		SDK_RemoveWearable(client, iWearable);
		AcceptEntityInput(iWearable, "Kill");
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

stock TFClassType TF2_GetRandomClass()
{
	return view_as<TFClassType>(GetRandomInt(view_as<int>(TFClass_Scout), view_as<int>(TFClass_Engineer)));
}

// Stolen from SZF
stock void TF2_CreateAndEquipWeapon(int iClient, int defindex)
{
	TFClassType nClass = TF2_GetPlayerClass(iClient);
	int iSlot = TF2_GetSlotInItem(defindex, nClass);
	
	//Remove sniper scope and slowdown cond if have one, otherwise can cause client crashes
	if (TF2_IsPlayerInCondition(iClient, TFCond_Zoomed))
	{
		TF2_RemoveCondition(iClient, TFCond_Zoomed);
		TF2_RemoveCondition(iClient, TFCond_Slowed);
	}
	
	//If player already have item in his inv, remove it before we generate new weapon for him, otherwise some weapons can glitch out...
	int iEntity = GetPlayerWeaponSlot(iClient, iSlot);
	if (iEntity > MaxClients && IsValidEdict(iEntity))
		TF2_RemoveWeaponSlot(iClient, iSlot);
	
	//Remove wearable if have one
	int iWearable = SDK_GetEquippedWearable(iClient, iSlot);
	if (iWearable > MaxClients)
	{
		SDK_RemoveWearable(iClient, iWearable);
		AcceptEntityInput(iWearable, "Kill");
	}
	
	//Generate and equip weapon
	char sClassname[256];
	TF2Econ_GetItemClassName(defindex, sClassname, sizeof(sClassname));
	TF2Econ_TranslateWeaponEntForClass(sClassname, sizeof(sClassname), TF2_GetPlayerClass(iClient));
	
	int iWeapon = CreateEntityByName(sClassname);
	if (IsValidEntity(iWeapon))
	{
		SetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex", defindex);
		SetEntProp(iWeapon, Prop_Send, "m_bInitialized", 1);
		
		if (DispatchSpawn(iWeapon))
		{
			SetEntProp(iWeapon, Prop_Send, "m_bValidatedAttachedEntity", true);
			
			if (StrContains(sClassname, "tf_wearable") == 0)
				SDK_EquipWearable(iClient, iWeapon);
			else
				EquipPlayerWeapon(iClient, iWeapon);
			
			TF2_EquipWeapon(iClient, iWeapon, sClassname, sizeof(sClassname));
			
			//Set ammo as weapon's max ammo
			if (HasEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType")) //Wearables dont have ammo netprop
			{
				int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
				if (iAmmoType > -1)
				{
					//We want to set gas passer ammo empty, because thats how normal gas passer works
					int iMaxAmmo;
					if (defindex == WEAPON_GAS_PASSER)
						SetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 0.0, 1);
					else
						iMaxAmmo = SDK_GetMaxAmmo(iClient, iAmmoType);
					
					SetEntProp(iClient, Prop_Send, "m_iAmmo", iMaxAmmo, _, iAmmoType);
				}
			}
			
			//Add health to player if needed
			ArrayList staticAttribs = TF2Econ_GetItemStaticAttributes(defindex);
			int index = staticAttribs.FindValue(ATTRIB_MAX_HEALTH_ADDITIVE_BONUS, 0);
			if (index > -1)
				SetEntityHealth(iClient, GetClientHealth(iClient) + RoundFloat(staticAttribs.Get(index, 1)));
			delete staticAttribs;
		}
	}
}

stock void TF2_EquipWeapon(int iClient, int iWeapon, char[] sClassname = NULL_STRING, int iClassNameLength = 0)
{
	if (IsValidEntity(iWeapon))
	{
		int defindex = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
		
		if (IsNullString(sClassname))
		{
			TF2Econ_GetItemClassName(defindex, sClassname, iClassNameLength);
			TF2Econ_TranslateWeaponEntForClass(sClassname, iClassNameLength, TF2_GetPlayerClass(iClient));
		}
		
		if (StrContains(sClassname, "tf_wearable") == 0 || StrContains(sClassname, "tf_weapon_parachute") == 0)
		{
			if (GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon") <= MaxClients)
			{
				//Looks like player's active weapon got replaced into wearable, fix that by using melee
				int iMelee = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Melee);
				SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iMelee);
			}
		}
		else if (StrContains(sClassname, "tf_weapon_invis") == 0)
		{
			// Invis watches glitch out when switched to
			return;
		}
		
		else
		{
			SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
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
