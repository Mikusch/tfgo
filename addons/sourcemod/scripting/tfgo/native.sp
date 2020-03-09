void Native_AskLoad()
{
	CreateNative("TFGO_GetWeapon", NativeCall_GetWeapon);
}

int NativeCall_GetWeapon(Handle plugin, int numParams)
{
	int defindex = GetNativeCell(1);
	TFGOWeapon weapon;
	int copied = g_AvailableWeapons.GetByDefIndex(defindex, weapon);
	SetNativeArray(2, weapon, sizeof(weapon));
	return copied;
}
