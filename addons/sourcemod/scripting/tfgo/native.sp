void Native_AskLoad()
{
	CreateNative("TFGO_GetWeapon", NativeCall_GetWeapon);
	CreateNative("TFGO_RegisterMusicKit", NativeCall_RegisterMusicKit);
	CreateNative("TFGO_SetClientMusicKit", NativeCall_SetClientMusicKit);
}

int NativeCall_GetWeapon(Handle plugin, int numParams)
{
	int defindex = GetNativeCell(1);
	TFGOWeapon weapon;
	int copied = g_AvailableWeapons.GetByDefIndex(defindex, weapon);
	SetNativeArray(2, weapon, sizeof(weapon));
	return copied;
}

int NativeCall_RegisterMusicKit(Handle plugin, int numParams)
{
	char name[PLATFORM_MAX_PATH], path[PLATFORM_MAX_PATH];
	GetNativeString(1, name, sizeof(name));
	GetNativeString(2, path, sizeof(path));
	bool isDefault = GetNativeCell(3);
	bool precache = GetNativeCell(4);
	MusicKit_Register(name, path, isDefault, precache);
}

int NativeCall_SetClientMusicKit(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	char kit[PLATFORM_MAX_PATH];
	GetNativeString(2, kit, sizeof(kit));
	MusicKit_SetMusicKit(client, kit);
}
