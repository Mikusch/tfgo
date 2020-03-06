#define CONFIG_FILE			"configs/tfgo/tfgo.cfg"
#define CONFIG_MAX_LENGTH	64

enum struct TFGOWeapon
{
	int defindex;
	int price;
	int killAward;
	float armorPenetration;
	bool isDefault;
	
	void ReadConfig(KeyValues kv)
	{
		this.defindex = kv.GetNum("defindex", -1);
		this.price = kv.GetNum("price");
		this.killAward = kv.GetNum("kill_award", tfgo_cash_player_killed_enemy_default.IntValue);
		this.armorPenetration = kv.GetFloat("armor_penetration", 1.0);
		this.isDefault = view_as<bool>(kv.GetNum("is_default"));
	}
}

methodmap WeaponConfig < ArrayList
{
	public WeaponConfig()
	{
		return view_as<WeaponConfig>(new ArrayList(sizeof(TFGOWeapon)));
	}
	
	public void ReadConfig(KeyValues kv)
	{
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				TFGOWeapon weapon;
				weapon.ReadConfig(kv);
				this.PushArray(weapon, sizeof(weapon));
			}
			while (kv.GotoNextKey(false));
			kv.GoBack();
		}
		kv.GoBack();
	}
	
	public int GetByDefIndex(int defindex, TFGOWeapon buffer)
	{
		int index = this.FindValue(defindex);
		return index != -1 ? this.GetArray(index, buffer, sizeof(buffer)) : 0;
	}
	
	public int GetInt(int index, int block = 0, bool asChar = false)
	{
		return this.Get(index, block, asChar);
	}
}

WeaponConfig g_AvailableWeapons;

void Config_Init()
{
	g_AvailableWeapons = new WeaponConfig();
	
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
