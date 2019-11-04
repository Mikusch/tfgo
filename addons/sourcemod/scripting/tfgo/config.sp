#define CONFIG_FILE "configs/tfgo/tfgo.cfg"
#define DEFAULT_KILL_AWARD  100

enum struct Weapon
{
	int defindex;
	int cost;
	int killAward;
	ArrayList variants;
}

StringMap g_weaponClassKillAwards;

public void ReadWeaponConfig(KeyValues kv)
{
	if (kv.JumpToKey("Weapons", false))
	{
		if (kv.GotoFirstSubKey(false))
		{
			do // Loop through each weapon definition index
			{
				char defindex[256];
				kv.GetSectionName(defindex, sizeof(defindex));
				
				// Set basic weapon data
				Weapon weapon;
				weapon.defindex = StringToInt(defindex);
				weapon.cost = kv.GetNum("cost", -1);
				
				// Fetch kill award
				int killAward = kv.GetNum("killAward", -1);
				if (killAward <= -1)
				{
					char class[256];
					TF2Econ_GetItemClassName(weapon.defindex, class, sizeof(class));
					g_weaponClassKillAwards.GetValue(class, killAward);
				}
				weapon.killAward = killAward;
				
				// Variants
				char variantsString[256];
				kv.GetString("variants", variantsString, sizeof(variantsString));
				ArrayList variantList = new ArrayList();
				if (strlen(variantsString) > 0)
				{
					char buffers[32][256]; // max. 32 variants
					for (int i = 0; i < sizeof(buffers); i++)buffers[i] = "-1"; // because 0 = Bat
					ExplodeString(variantsString, ";", buffers, sizeof(buffers), sizeof(buffers[]));
					
					for (int i = 0; i < sizeof(buffers); i++)
					{
						int variantDefIndex = StringToInt(TrimString(buffers[i]));
						if (variantDefIndex > -1)
							variantList.Push(variantDefIndex);
					}
				}
				weapon.variants = variantList;
				
				int length = g_availableWeapons.Length;
				g_availableWeapons.Resize(length + 1);
				g_availableWeapons.Set(length, weapon.defindex, 0);
				g_availableWeapons.SetArray(length, weapon, sizeof(weapon));
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
				char class[256];
				kv.GetSectionName(class, sizeof(class)); // Weapon class
				g_weaponClassKillAwards.SetValue(class, kv.GetNum(NULL_STRING, DEFAULT_KILL_AWARD));
			}
			while (kv.GotoNextKey(false));
			kv.GoBack();
			
		}
		kv.GoBack();
	}
}

public int GetEffectiveKillAward(int defindex)
{
	int killAward;
	int index = g_availableWeapons.FindValue(defindex, 0);
	if (index > -1)
	{
		Weapon weapon;
		g_availableWeapons.GetArray(index, weapon, sizeof(weapon));
		killAward = weapon.killAward;
	}
	else
	{
		char weaponclass[256];
		TF2Econ_GetItemClassName(defindex, weaponclass, sizeof(weaponclass));
		if (!g_weaponClassKillAwards.GetValue(weaponclass, killAward))
			return DEFAULT_KILL_AWARD;
	}
	return killAward;
}

void Config_Init()
{
	if (g_weaponClassKillAwards == null)
		g_weaponClassKillAwards = new StringMap();
	
	if (g_availableWeapons == null)
	{
		Weapon weapon;
		g_availableWeapons = new ArrayList(1 + sizeof(weapon));
	}
	
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
