#define CONFIG_FILE "tfgo.cfg"
#define MAXLEN_CONFIG_VALUE 256

public void PopulateWeaponList(KeyValues kv)
{
	if (kv.JumpToKey("Weapons", false)) //Jump to "Weapons"
	{
		if (kv.GotoFirstSubKey(false)) // Go to the first key of weapon index
		{
			do // Loop through each weapon index
			{
				char sIndex[MAXLEN_CONFIG_VALUE];
				kv.GetSectionName(sIndex, sizeof(sIndex)); // Index of the weapon
				
				// Set weapon data
				TFGOWeaponEntry weapon;
				weapon.DefIndex = StringToInt(sIndex);
				weapon.Cost = kv.GetNum("cost", -1);
				
				int length = weaponList.Length;
				weaponList.Resize(length + 1);
				weaponList.Set(length, StringToInt(sIndex), 0);
				weaponList.SetArray(length, weapon, sizeof(weapon));
			}
			while (kv.GotoNextKey(false));
			kv.GoBack();
		}
		kv.GoBack();
	}
}

void PopulateKillRewardMap(KeyValues kv)
{
	if (kv.JumpToKey("KillAwards", false))
	{
		if (kv.GotoFirstSubKey(false)) // Go to the first key of weapon index
		{
			do // Loop through each weapon index
			{
				char weaponClass[MAXLEN_CONFIG_VALUE];
				kv.GetSectionName(weaponClass, sizeof(weaponClass)); // weapon class
				killAwardMap.SetValue(weaponClass, kv.GetNum(NULL_STRING, 100));
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
		killAwardMap = CreateTrie();
	
	if (weaponList == null)
		weaponList = new ArrayList(3);
	
	
	KeyValues kv = new KeyValues("Config");
	char path[255];
	BuildPath(Path_SM, path, sizeof(path), "configs/tfgo/tfgo.cfg");
	if (!kv.ImportFromFile(path))return;
	
	//Load every indexs
	PopulateKillRewardMap(kv);
	PopulateWeaponList(kv);
	
	delete kv;
} 