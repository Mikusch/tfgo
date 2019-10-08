#define CONFIG_FILE "tfgo.cfg"
#define MAXLEN_CONFIG_VALUE 256

enum struct TFGOWeapon
{
	/**
	* The item definition index of this weapon
	**/
	int index;
	
	/**
	* The price of this weapon in the buy menu
	* If this value is -1, the weapon won't show up in the buy menu
	*/
	int cost;
	
	/**
	* How much money this weapon should grant upon a successful kill
	*/
	int killReward;
}

methodmap KillRewardMap < StringMap
{
	public KillRewardMap()
	{
		return view_as<KillRewardMap>(CreateTrie());
	}
	
	public void Populate(KeyValues kv)
	{
		if (kv.JumpToKey("KillRewards", false))
		{
			if (kv.GotoFirstSubKey(false)) // Go to the first key of weapon index
			{
				do // Loop through each weapon index
				{
					char weaponClass[MAXLEN_CONFIG_VALUE];
					kv.GetSectionName(weaponClass, sizeof(weaponClass)); // weapon class
					this.SetValue(weaponClass, kv.GetNum(NULL_STRING, 100));
				}
				while (kv.GotoNextKey(false));
				kv.GoBack();
				
			}
			kv.GoBack();
		}
	}
}

KillRewardMap g_hKillRewardMap;

methodmap WeaponList < ArrayList
{
	public WeaponList()
	{
		return view_as<WeaponList>(new ArrayList(3)); // 0 for int index, 1 for TFGOWeapon
	}
	
	public void Populate(KeyValues kv)
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
					TFGOWeapon weapon;
					weapon.index = StringToInt(sIndex);
					weapon.cost = kv.GetNum("cost", -1);
					
					int killReward = kv.GetNum("kill_reward_override", -1);
					if (killReward < 0)
					{
						char key[255];
						TF2Econ_GetItemClassName(weapon.index, key, sizeof(key));
						g_hKillRewardMap.GetValue(key, killReward);
					}
					weapon.killReward = killReward;
					
					int length = this.Length;
					this.Resize(length + 1);
					this.Set(length, StringToInt(sIndex), 0);
					this.SetArray(length, weapon, sizeof(weapon));
				}
				while (kv.GotoNextKey(false));
				kv.GoBack();
			}
			kv.GoBack();
		}
	}
	
	
	public void GetWeaponInfoForIndex(int weaponIndex, TFGOWeapon buf)
	{
		int listIndex = this.FindValue(weaponIndex, 0);
		if (listIndex >= 0)
		{
			this.GetArray(listIndex, buf);
		}
	}
};

WeaponList g_ConfigIndex;


public void GetWeaponInfoForIndex(int weaponIndex, TFGOWeapon buf)
{
	g_ConfigIndex.GetWeaponInfoForIndex(weaponIndex, buf);
}

void Config_Init()
{
	if (g_hKillRewardMap == null)
		g_hKillRewardMap = new KillRewardMap();
	
	if (g_ConfigIndex == null)
		g_ConfigIndex = new WeaponList();

	
	KeyValues kv = new KeyValues("Config");
	char path[255];
	BuildPath(Path_SM, path, sizeof(path), "configs/tfgo/tfgo.cfg");
	if (!kv.ImportFromFile(path))return;
	
	//Load every indexs
	g_hKillRewardMap.Populate(kv);
	g_ConfigIndex.Populate(kv);
	
	delete kv;
} 