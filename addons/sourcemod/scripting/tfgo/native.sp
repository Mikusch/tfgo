void Native_AskLoad()
{
	CreateNative("TFGO_GetWeaponCost", Native_GetWeaponCost);
}

int Native_GetWeaponCost(Handle plugin, int numParams)
{
	int defindex = GetNativeCell(1);
	int index = g_AvailableWeapons.FindValue(defindex, 0);
	if (index > -1)
	{
		TFGOWeapon weapon;
		g_AvailableWeapons.GetArray(index, weapon, sizeof(weapon));
		return weapon.price;
	}
	
	return -1;
}
