// -1 indicates the class should start with no weapon in that slot
static int g_DefaultWeaponIndexes[][] =  {
	{ -1, -1, -1, -1, -1, -1 },  // Unknown
	{ -1, 23, 30758, -1, -1, -1 },  // Scout
	{ -1, 16, 30758, -1, -1, -1 },  // Sniper
	{ -1, 10, 30758, -1, -1, -1 },  // Soldier
	{ 608, 131, 30758, -1, -1, -1 },  // Demoman
	{ 17, -1, 30758, -1, -1, -1 },  // Medic
	{ -1, 11, 30758, -1, -1, -1 },  // Heavy
	{ -1, 12, 30758, -1, -1, -1 },  // Pyro
	{ -1, 735, 4, -1, 30, -1 },  // Spy
	{ 9, 22, 30758, -1, -1, 28 } // Engineer
};

static int g_PlayerLoadoutWeaponIndexes[TF_MAXPLAYERS + 1][view_as<int>(TFClass_Engineer) + 1][WeaponSlot_BuilderEngie + 1];
static int g_PlayerAccounts[TF_MAXPLAYERS + 1];
static int g_PlayerArmorValues[TF_MAXPLAYERS + 1][view_as<int>(TFClass_Engineer) + 1];
static bool g_PlayerHelmets[TF_MAXPLAYERS + 1][view_as<int>(TFClass_Engineer) + 1];
static bool g_PlayerDefuseKits[TF_MAXPLAYERS + 1][view_as<int>(TFClass_Engineer) + 1];
static Menu g_ActiveBuyMenus[TF_MAXPLAYERS + 1];

static int g_TeamConsecutiveLosses[view_as<int>(TFTeam_Blue) + 1] =  { STARTING_CONSECUTIVE_LOSSES, ... };

methodmap TFGOPlayer
{
	public TFGOPlayer(int client)
	{
		return view_as<TFGOPlayer>(client);
	}
	
	property int Client
	{
		public get()
		{
			return view_as<int>(this);
		}
	}
	
	property int Account
	{
		public get()
		{
			return g_PlayerAccounts[this];
		}
		public set(int val)
		{
			if (val > tfgo_maxmoney.IntValue)
				g_PlayerAccounts[this] = tfgo_maxmoney.IntValue;
			else if (val < 0)
				g_PlayerAccounts[this] = 0;
			else
				g_PlayerAccounts[this] = val;
		}
	}
	
	property int ArmorValue
	{
		public get()
		{
			return g_PlayerArmorValues[this][TF2_GetPlayerClass(this.Client)];
		}
		public set(int val)
		{
			g_PlayerArmorValues[this][TF2_GetPlayerClass(this.Client)] = val;
		}
	}
	
	property bool HasHelmet
	{
		public get()
		{
			return g_PlayerHelmets[this][TF2_GetPlayerClass(this.Client)];
		}
		public set(bool val)
		{
			g_PlayerHelmets[this][TF2_GetPlayerClass(this.Client)] = val;
		}
	}
	
	property bool HasDefuseKit
	{
		public get()
		{
			return g_PlayerDefuseKits[this][TF2_GetPlayerClass(this.Client)];
		}
		public set(bool val)
		{
			g_PlayerDefuseKits[this][TF2_GetPlayerClass(this.Client)] = val;
		}
	}
	
	property Menu ActiveBuyMenu
	{
		public get()
		{
			return g_ActiveBuyMenus[this];
		}
		public set(Menu val)
		{
			g_ActiveBuyMenus[this] = val;
		}
	}
	
	public void AddToAccount(int val, const char[] reason, any...)
	{
		this.Account += val;
		
		char message[PLATFORM_MAX_PATH];
		VFormat(message, sizeof(message), reason, 4);
		
		if (val > 0)
			CPrintToChat(this.Client, "{positive}+$%d{default}: %s", val, message);
		else if (val < 0)
			CPrintToChat(this.Client, "{negative}-$%d{default}: %s", val * -1, message);
		else
			CPrintToChat(this.Client, "{negative}$%d{default}: %s", val, message);
		
		Forward_CashAwarded(this.Client, val);
	}
	
	public BuyResult AttemptToBuyWeapon(int defindex)
	{
		TFClassType class = TF2_GetPlayerClass(this.Client);
		int slot = TF2_GetItemSlot(defindex, class);
		int weapon = GetPlayerWeaponSlot(this.Client, slot);
		
		TFGOWeapon config;
		g_AvailableWeapons.GetWeapon(defindex, config);
		
		if (weapon > -1 && GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == defindex)
		{
			PrintCenterText(this.Client, "%T", "Already_Have_One", LANG_SERVER);
			return BUY_ALREADY_HAVE;
		}
		else if (this.Account < config.price)
		{
			PrintCenterText(this.Client, "%T", "Not_Enough_Money", LANG_SERVER);
			return BUY_CANT_AFFORD;
		}
		else
		{
			if (weapon > -1) // Drop old weapon, if present
			{
				float position[3];
				GetClientEyePosition(this.Client, position);
				float angles[3];
				GetClientEyeAngles(this.Client, angles);
				SDK_CreateDroppedWeapon(weapon, this.Client, position, angles);
			}
			
			TF2_CreateAndEquipWeapon(this.Client, defindex, TFQual_Unique, GetRandomInt(1, 100));
			g_PlayerLoadoutWeaponIndexes[this][class][slot] = defindex;
			this.Account -= config.price;
			return BUY_BOUGHT;
		}
	}
	
	public int GetWeaponFromLoadout(TFClassType class, int slot)
	{
		int defIndex = g_PlayerLoadoutWeaponIndexes[this][class][slot];
		if (defIndex > -1)
			return defIndex;
		else
			return g_DefaultWeaponIndexes[class][slot];
	}
	
	public void ApplyLoadout()
	{
		TFClassType class = TF2_GetPlayerClass(this.Client);
		
		for (int slot = sizeof(g_PlayerLoadoutWeaponIndexes[][]) - 1; slot >= 0; slot--)
		{
			int defIndex = this.GetWeaponFromLoadout(class, slot);
			if (defIndex > -1)
				TF2_CreateAndEquipWeapon(this.Client, defIndex, TFQual_Unique, GetRandomInt(1, 100));
		}
	}
	
	public void AddToLoadout(int defIndex)
	{
		TFClassType class = TF2_GetPlayerClass(this.Client);
		int slot = TF2_GetItemSlot(defIndex, class);
		g_PlayerLoadoutWeaponIndexes[this][class][slot] = defIndex;
	}
	
	public void RemoveAllItems(bool removeArmor)
	{
		for (int i = 0; i < sizeof(g_PlayerLoadoutWeaponIndexes[]); i++)
		{
			for (int j = 0; j < sizeof(g_PlayerLoadoutWeaponIndexes[][]); j++)
			{
				g_PlayerLoadoutWeaponIndexes[this][i][j] = -1;
			}
		}
		
		if (removeArmor)
		{
			for (int i = 0; i < sizeof(g_PlayerHelmets[]); i++)
			{
				g_PlayerHelmets[this][i] = false;
			}
			
			for (int i = 0; i < sizeof(g_PlayerArmorValues[]); i++)
			{
				g_PlayerArmorValues[this][i] = 0;
			}
		}
		
		for (int i = 0; i < sizeof(g_PlayerDefuseKits[]); i++)
		{
			g_PlayerDefuseKits[this][i] = false;
		}
	}
	
	public void Reset()
	{
		this.RemoveAllItems(true);
		this.Account = tfgo_startmoney.IntValue;
	}
	
	public bool IsArmored(int hitgroup)
	{
		switch (hitgroup)
		{
			case HITGROUP_GENERIC, HITGROUP_CHEST, HITGROUP_STOMACH, HITGROUP_LEFTARM, HITGROUP_RIGHTARM:
			{
				return this.ArmorValue > 0;
			}
			case HITGROUP_HEAD:
			{
				return this.ArmorValue > 0 && this.HasHelmet;
			}
			default:
			{
				return false;
			}
		}
	}
	
	public BuyResult AttemptToBuyVest()
	{
		if (tfgo_max_armor.IntValue < 1)
		{
			PrintCenterText(this.Client, "%T", "Cannot_Buy_This", LANG_SERVER);
			return BUY_NOT_ALLOWED;
		}
		if (this.ArmorValue >= TF2_GetMaxHealth(this.Client))
		{
			PrintCenterText(this.Client, "%T", "Already_Have_Kevlar", LANG_SERVER);
			return BUY_ALREADY_HAVE;
		}
		else if (this.Account < KEVLAR_PRICE)
		{
			PrintCenterText(this.Client, "%T", "Not_Enough_Money", LANG_SERVER);
			return BUY_CANT_AFFORD;
		}
		else
		{
			if (this.HasHelmet)
				PrintCenterText(this.Client, "%T", "Already_Have_Helmet_Bought_Kevlar", LANG_SERVER);
			
			this.ArmorValue = TF2_GetMaxHealth(this.Client);
			this.Account -= KEVLAR_PRICE;
			return BUY_BOUGHT;
		}
	}
	
	public BuyResult AttemptToBuyAssaultSuit()
	{
		bool fullArmor = this.ArmorValue >= TF2_GetMaxHealth(this.Client);
		
		bool enoughMoney;
		int price;
		
		if (tfgo_max_armor.IntValue < 2)
		{
			PrintCenterText(this.Client, "%T", "Cannot_Buy_This", LANG_SERVER);
			return BUY_NOT_ALLOWED;
		}
		else if (fullArmor && this.HasHelmet)
		{
			PrintCenterText(this.Client, "%T", "Already_Have_Kevlar_Helmet", LANG_SERVER);
			return BUY_ALREADY_HAVE;
		}
		else if (fullArmor && !this.HasHelmet && this.Account >= HELMET_PRICE)
		{
			enoughMoney = true;
			price = HELMET_PRICE;
			PrintCenterText(this.Client, "%T", "Already_Have_Kevlar_Bought_Helmet", LANG_SERVER);
		}
		else if (!fullArmor && this.HasHelmet && this.Account >= KEVLAR_PRICE)
		{
			enoughMoney = true;
			price = KEVLAR_PRICE;
			PrintCenterText(this.Client, "%T", "Already_Have_Helmet_Bought_Kevlar", LANG_SERVER);
		}
		else if (this.Account >= ASSAULTSUIT_PRICE)
		{
			enoughMoney = true;
			price = ASSAULTSUIT_PRICE;
		}
		
		// Process the result
		if (!enoughMoney)
		{
			PrintCenterText(this.Client, "%T", "Not_Enough_Money", LANG_SERVER);
			return BUY_CANT_AFFORD;
		}
		else
		{
			this.HasHelmet = true;
			this.ArmorValue = TF2_GetMaxHealth(this.Client);
			this.Account -= price;
			return BUY_BOUGHT;
		}
	}
	
	public BuyResult AttemptToBuyDefuseKit()
	{
		if (this.HasDefuseKit)
		{
			PrintCenterText(this.Client, "#Already_Have_One", LANG_SERVER);
			return BUY_ALREADY_HAVE;
		}
		else if (this.Account < DEFUSEKIT_PRICE)
		{
			PrintCenterText(this.Client, "#Not_Enough_Money", LANG_SERVER);
			return BUY_CANT_AFFORD;
		}
		else
		{
			this.HasDefuseKit = true;
			this.Account -= DEFUSEKIT_PRICE;
			return BUY_BOUGHT;
		}
	}
}

methodmap TFGOTeam
{
	public TFGOTeam(TFTeam team)
	{
		return view_as<TFGOTeam>(team);
	}
	
	property TFTeam Team
	{
		public get()
		{
			return view_as<TFTeam>(this);
		}
	}
	
	property int ConsecutiveLosses
	{
		public get()
		{
			return g_TeamConsecutiveLosses[this];
		}
		
		public set(int val)
		{
			if (val > tfgo_consecutive_loss_max.IntValue)
				g_TeamConsecutiveLosses[this] = tfgo_consecutive_loss_max.IntValue;
			else if (val < MIN_CONSECUTIVE_LOSSES)
				g_TeamConsecutiveLosses[this] = MIN_CONSECUTIVE_LOSSES;
			else
				g_TeamConsecutiveLosses[this] = val;
		}
	}
	
	property int LoseIncome
	{
		public get()
		{
			return tfgo_cash_team_loser_bonus.IntValue + tfgo_cash_team_loser_bonus_consecutive_rounds.IntValue * this.ConsecutiveLosses;
		}
	}
	
	public void AddToClientAccounts(int val, const char[] reason, any...)
	{
		char message[PLATFORM_MAX_PATH];
		VFormat(message, sizeof(message), reason, 4);
		
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client) && TF2_GetClientTeam(client) == this.Team)
				TFGOPlayer(client).AddToAccount(val, message);
		}
	}
}
