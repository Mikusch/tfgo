#define CONFIG_FILE "configs/tfgo/tfgo.cfg"

enum struct WeaponConfig
{
	int defIndex;
	int price;
	float armorPenetration;
}

StringMap g_WeaponClassKillAwards;

public void ReadWeaponConfig(KeyValues kv)
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
	if (g_WeaponClassKillAwards == null) g_WeaponClassKillAwards = new StringMap();
	if (g_AvailableWeapons == null) g_AvailableWeapons = new ArrayList(sizeof(WeaponConfig));
	
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
}
