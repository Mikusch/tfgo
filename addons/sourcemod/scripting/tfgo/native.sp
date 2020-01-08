void Native_AskLoad()
{
	CreateNative("TFGO_GetWeaponCost", Native_GetWeaponCost);
}

public int Native_GetWeaponCost(Handle plugin, int numParams)
{
	int defindex = GetNativeCell(1);
	int index = g_AvailableWeapons.FindValue(defindex, 0);
	if (index > -1)
	{
		WeaponConfig config;
		g_AvailableWeapons.GetArray(index, config, sizeof(config));
		return config.price;
	}
	
	return -1;
}
