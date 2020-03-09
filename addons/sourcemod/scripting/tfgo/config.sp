#define CONFIG_FILE	"configs/tfgo/tfgo.cfg"

void Config_Init()
{
	g_AvailableWeapons = new TFGOWeaponList();
	
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), CONFIG_FILE);
	
	KeyValues kv = new KeyValues("Config");
	if (kv.ImportFromFile(path))
	{
		if (kv.JumpToKey("Weapons", false))
		{
			g_AvailableWeapons.ReadConfig(kv);
			g_AvailableWeapons.SortCustom(SortFunc_SortAvailableWeaponsByName);
			kv.GoBack();
		}
	}
	delete kv;
}

int SortFunc_SortAvailableWeaponsByName(int index1, int index2, Handle array, Handle hndl)
{
	ArrayList list = view_as<ArrayList>(array);
	
	TFGOWeapon weapon1;
	list.GetArray(index1, weapon1, sizeof(weapon1));
	TFGOWeapon weapon2;
	list.GetArray(index2, weapon2, sizeof(weapon2));
	
	char name1[PLATFORM_MAX_PATH];
	TF2_GetItemName(weapon1.defindex, name1, sizeof(name1));
	char name2[PLATFORM_MAX_PATH];
	TF2_GetItemName(weapon2.defindex, name2, sizeof(name2));
	
	return strcmp(name1, name2);
}
