#define CONFIG_FILE "configs/tfgo/tfgo.cfg"

enum struct Weapon
{
	int defindex;
	int cost;
	float armorPenetration;
}

enum struct Equipment
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
				
				g_AvailableWeapons.PushArray(weapon, sizeof(weapon));
			}
			while (kv.GotoNextKey(false));
			kv.GoBack();
		}
		kv.GoBack();
	}
}

public void ReadEquipmentConfig(KeyValues kv)
{
	if (kv.JumpToKey("Equipment", false))
	{
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				char id[PLATFORM_MAX_PATH];
				kv.GetSectionName(id, sizeof(id));
				
				Equipment equipment;
				equipment.id = StringToInt(id);
				equipment.cost = kv.GetNum("cost", -1);
				
				g_AvailableEquipment.PushArray(equipment, sizeof(equipment));
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
	if (g_AvailableWeapons == null) g_AvailableWeapons = new ArrayList(sizeof(Weapon));
	if (g_AvailableEquipment == null) g_AvailableEquipment = new ArrayList(sizeof(Equipment));
	
	// Read config
	KeyValues kv = new KeyValues("Config");
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), CONFIG_FILE);
	if (kv.ImportFromFile(path))
	{
		ReadKillAwardConfig(kv);
		ReadWeaponConfig(kv);
		ReadEquipmentConfig(kv);
		delete kv;
	}
}
