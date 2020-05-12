#define CONFIG_FILE	"configs/tfgo/%s.cfg"

static StringMap WeaponReskins;

void Config_Init()
{
	g_AvailableWeapons = new TFGOWeaponList();
	WeaponReskins = new StringMap();
	
	char path[PLATFORM_MAX_PATH];
	
	BuildPath(Path_SM, path, sizeof(path), CONFIG_FILE, "tfgo");
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
	
	BuildPath(Path_SM, path, sizeof(path), CONFIG_FILE, "reskins");
	kv = new KeyValues("Reskins");
	if (kv.ImportFromFile(path))
	{
		char key[PLATFORM_MAX_PATH];
		if (kv.GetSectionName(key, sizeof(key)))
		{
			int originalDefindex = StringToInt(key);
			
			char value[PLATFORM_MAX_PATH];
			kv.GetString(NULL_STRING, value, sizeof(value));
			
			char defindexes[64][32];
			int count = ExplodeString(value, ";", defindexes, sizeof(defindexes), sizeof(defindexes[]));
			
			for (int i = 0; i < count; i++)
			{
				WeaponReskins.SetValue(defindexes[i], originalDefindex);
			}
			
			kv.GoBack();
		}
	}
	delete kv;
}

int SortFunc_SortAvailableWeaponsByName(int index1, int index2, Handle array, Handle hndl)
{
	ArrayList list = view_as<ArrayList>(array);
	
	TFGOWeapon weapon1, weapon2;
	list.GetArray(index1, weapon1, sizeof(weapon1));
	list.GetArray(index2, weapon2, sizeof(weapon2));
	
	char name1[PLATFORM_MAX_PATH], name2[PLATFORM_MAX_PATH];
	TF2_GetItemName(weapon1.defindex, name1, sizeof(name1));
	TF2_GetItemName(weapon2.defindex, name2, sizeof(name2));
	
	return strcmp(name1, name2);
}

stock int Config_GetOriginalItemDefIndex(int defindex)
{
	int originalDefindex;
	
	char defindexString[8];
	IntToString(defindex, defindexString, sizeof(defindexString));
	
	if (WeaponReskins.GetValue(defindexString, originalDefindex))
		return originalDefindex;
	else
		return defindex;
}
