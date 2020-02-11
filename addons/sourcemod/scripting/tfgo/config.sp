#define CONFIG_FILE "configs/tfgo/tfgo.cfg"

enum struct WeaponConfig
{
	int defIndex;
	int price;
	float armorPenetration;
}

StringMap g_WeaponClassKillAwards;

void ReadWeaponConfig(KeyValues kv)
{
	if (kv.JumpToKey("Weapons", false))
	{
		if (kv.GotoFirstSubKey(false))
		{
			do // Loop through each weapon definition index
			{
				char defIndex[PLATFORM_MAX_PATH];
				kv.GetSectionName(defIndex, sizeof(defIndex));
				
				// Set basic weapon data
				WeaponConfig config;
				config.defIndex = StringToInt(defIndex);
				config.price = kv.GetNum("price", -1);
				config.armorPenetration = kv.GetFloat("armor_penetration", 1.0);
				
				g_AvailableWeapons.PushArray(config, sizeof(config));
			}
			while (kv.GotoNextKey(false));
			kv.GoBack();
		}
		kv.GoBack();
	}
}

void ReadKillAwardConfig(KeyValues kv)
{
	if (kv.JumpToKey("KillAwards", false))
	{
		if (kv.GotoFirstSubKey(false))
		{
			do // Loop through each weapon class
			{
				char class[PLATFORM_MAX_PATH];
				kv.GetSectionName(class, sizeof(class)); // Weapon class
				StrToLower(class);
				g_WeaponClassKillAwards.SetValue(class, kv.GetNum(NULL_STRING, tfgo_cash_player_killed_enemy_default.IntValue));
			}
			while (kv.GotoNextKey(false));
			kv.GoBack();
			
		}
		kv.GoBack();
	}
}

void Config_Init()
{
	if (g_WeaponClassKillAwards == null)
		g_WeaponClassKillAwards = new StringMap();
	if (g_AvailableWeapons == null)
		g_AvailableWeapons = new ArrayList(sizeof(WeaponConfig));
	
	// Read config
	KeyValues kv = new KeyValues("Config");
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), CONFIG_FILE);
	if (kv.ImportFromFile(path))
	{
		ReadKillAwardConfig(kv);
		ReadWeaponConfig(kv);
		delete kv;
	}
	
	g_AvailableWeapons.SortCustom(SortFunc_SortAvailableWeaponsByName);
}

int SortFunc_SortAvailableWeaponsByName(int index1, int index2, Handle array, Handle hndl)
{
	ArrayList list = view_as<ArrayList>(array);
	
	WeaponConfig config1;
	list.GetArray(index1, config1, sizeof(config1));
	WeaponConfig config2;
	list.GetArray(index2, config2, sizeof(config2));
	
	char name1[PLATFORM_MAX_PATH];
	TF2_GetItemName(config1.defIndex, name1, sizeof(name1));
	char name2[PLATFORM_MAX_PATH];
	TF2_GetItemName(config2.defIndex, name2, sizeof(name2));
	
	return strcmp(name1, name2);
}
