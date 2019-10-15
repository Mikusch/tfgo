#define CONFIG_FILE "configs/tfgo/tfgo.cfg"
#define DEFAULT_KILL_AWARD  100

public void ReadWeaponConfig(KeyValues kv)
{
	if (kv.JumpToKey("Weapons", false))
	{
		if (kv.GotoFirstSubKey(false))
		{
			do // Loop through each weapon definition index
			{
				char defindex[256];
				kv.GetSectionName(defindex, sizeof(defindex)); // Weapon Definition Index
				
				// Set weapon data
				TFGOWeaponEntry weapon;
				weapon.DefIndex = StringToInt(defindex);
				weapon.Cost = kv.GetNum("cost", -1);
				
				int length = weaponList.Length;
				weaponList.Resize(length + 1);
				weaponList.Set(length, StringToInt(defindex), 0);
				weaponList.SetArray(length, weapon, sizeof(weapon));
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
				char weaponClass[256];
				kv.GetSectionName(weaponClass, sizeof(weaponClass)); // Weapon class
				killAwardMap.SetValue(weaponClass, kv.GetNum(NULL_STRING, DEFAULT_KILL_AWARD));
			}
			while (kv.GotoNextKey(false));
			kv.GoBack();
			
		}
		kv.GoBack();
	}
}

void Config_Init()
{
	if (killAwardMap == null)
		killAwardMap = new StringMap();
	
	if (weaponList == null)
		weaponList = new ArrayList(3);

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
