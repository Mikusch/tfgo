#define CONFIG_FILE "configs/tfgo/tfgo.cfg"

enum struct Weapon
{
	int defindex;
	int cost;
	float armorPenetration;
}

enum struct Gear
{
	int id;
	int cost;
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
				char defindex[PLATFORM_MAX_PATH];
				kv.GetSectionName(defindex, sizeof(defindex));
				
				// Set basic weapon data
				Weapon weapon;
				weapon.defindex = StringToInt(defindex);
				weapon.cost = kv.GetNum("cost", -1);
				weapon.armorPenetration = kv.GetFloat("armor_penetration", 0.5);
				
				int length = g_AvailableWeapons.Length;
				g_AvailableWeapons.Resize(length + 1);
				g_AvailableWeapons.Set(length, weapon.defindex, 0);
				g_AvailableWeapons.SetArray(length, weapon, sizeof(weapon));
			}
			while (kv.GotoNextKey(false));
			kv.GoBack();
		}
		kv.GoBack();
	}
}

public void ReadGearConfig(KeyValues kv)
{
	if (kv.JumpToKey("Gear", false))
	{
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				char id[PLATFORM_MAX_PATH];
				kv.GetSectionName(id, sizeof(id));
				
				Gear gear;
				gear.id = StringToInt(id);
				gear.cost = kv.GetNum("cost", -1);
				
				int length = g_AvailableGear.Length;
				g_AvailableGear.Resize(length + 1);
				g_AvailableGear.Set(length, gear.id, 0);
				g_AvailableGear.SetArray(length, gear, sizeof(gear));
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
	if (g_AvailableWeapons == null) g_AvailableWeapons = new ArrayList(sizeof(Weapon) + 1);
	if (g_AvailableGear == null) g_AvailableGear = new ArrayList(sizeof(Gear) + 1);
	
	// Read config
	KeyValues kv = new KeyValues("Config");
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), CONFIG_FILE);
	if (kv.ImportFromFile(path))
	{
		ReadKillAwardConfig(kv);
		ReadWeaponConfig(kv);
		ReadGearConfig(kv);
		delete kv;
	}
}
