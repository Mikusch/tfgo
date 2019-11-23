void Native_AskLoad()
{
	CreateNative("TFGO_GetWeaponCost", Native_GetWeaponCost);
}

public int Native_GetWeaponCost(Handle plugin, int numParams)
{
	int defindex = GetNativeCell(1);
	int index = g_availableWeapons.FindValue(defindex, 0);
	if (index > -1)
	{
		Weapon weapon;
		g_availableWeapons.GetArray(index, weapon, sizeof(weapon));
		return weapon.cost;
	}
	
	ThrowError("Invalid weapon with index %d", defindex);
	return -1;
}
