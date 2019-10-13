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

// Stolen from SZF
stock void TF2_CreateAndEquipWeapon(int iClient, int defindex)
{
	TFClassType nClass = TF2_GetPlayerClass(iClient);
	int iSlot = TF2Econ_GetItemSlot(defindex, nClass);
	
	//Remove sniper scope and slowdown cond if have one, otherwise can cause client crashes
	if (TF2_IsPlayerInCondition(iClient, TFCond_Zoomed))
	{
		TF2_RemoveCondition(iClient, TFCond_Zoomed);
		TF2_RemoveCondition(iClient, TFCond_Slowed);
	}
	
	//Force crit reset
	int iRevengeCrits = GetEntProp(iClient, Prop_Send, "m_iRevengeCrits");
	if (iRevengeCrits > 0)
	{
		SetEntProp(iClient, Prop_Send, "m_iRevengeCrits", 0);
		TF2_RemoveCondition(iClient, TFCond_Kritzkrieged);
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
		
		DispatchSpawn(iWeapon);
		SetEntProp(iWeapon, Prop_Send, "m_bValidatedAttachedEntity", true);
		
		if (StrContains(sClassname, "tf_wearable") == 0)
			SDK_EquipWearable(iClient, iWeapon);
		else
			EquipPlayerWeapon(iClient, iWeapon);
	}
	
	
	if (StrContains(sClassname, "tf_wearable") == 0)
	{
		if (GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon") <= MaxClients)
		{
			//Looks like player's active weapon got replaced into wearable, fix that by using melee
			int iMelee = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Melee);
			SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iMelee);
		}
	}
	else
	{
		SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
	}
	
	//Set ammo as weapon's max ammo
	if (HasEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType")) //Wearables dont have ammo netprop
	{
		int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
		if (iAmmoType > -1)
		{
			//We want to set gas passer ammo empty, because thats how normal gas passer works
			int iMaxAmmo;
			if (defindex == 1180)
			{
				iMaxAmmo = 0;
				SetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 0.0, 1);
			}
			else
			{
				iMaxAmmo = SDK_GetMaxAmmo(iClient, iAmmoType);
			}
			
			SetEntProp(iClient, Prop_Send, "m_iAmmo", iMaxAmmo, _, iAmmoType);
		}
	}
}

// SDK stocks

stock void SDK_EquipWearable(int client, int wearable)
{
	if (g_hSDKEquipWearable != null)
		SDKCall(g_hSDKEquipWearable, client, wearable);
}

stock void SDK_RemoveWearable(int client, int wearable)
{
	if (g_hSDKRemoveWearable != null)
		SDKCall(g_hSDKRemoveWearable, client, wearable);
}

stock int SDK_GetEquippedWearable(int client, int slot)
{
	if (g_hSDKGetEquippedWearable != null)
		return SDKCall(g_hSDKGetEquippedWearable, client, slot);
	
	return -1;
}

stock int SDK_GetMaxAmmo(int client, int slot)
{
	if (g_hSDKGetMaxAmmo != null)
		return SDKCall(g_hSDKGetMaxAmmo, client, slot, -1);
	return -1;
}
