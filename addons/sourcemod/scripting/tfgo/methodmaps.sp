// -1 indicates the class should start with no weapon in that slot
int g_DefaultWeaponIndexes[][] =  {
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

int g_PlayerLoadoutWeaponIndexes[TF_MAXPLAYERS + 1][view_as<int>(TFClassType)][WeaponSlot_BuilderEngie + 1];
int g_PlayerBalances[TF_MAXPLAYERS + 1];
Menu g_ActiveBuyMenus[TF_MAXPLAYERS + 1];
int g_PlayerArmor[TF_MAXPLAYERS + 1][view_as<int>(TFClassType)];
bool g_PlayerHelmets[TF_MAXPLAYERS + 1][view_as<int>(TFClassType)];

int g_TeamConsecutiveLosses[view_as<int>(TFTeam)] = { STARTING_CONSECUTIVE_LOSSES, ... };


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
	
	property int Balance
	{
		public get()
		{
			return g_PlayerBalances[this];
		}
		public set(int val)
		{
			if (val > tfgo_maxmoney.IntValue)
				g_PlayerBalances[this] = tfgo_maxmoney.IntValue;
			else if (val < 0)
				g_PlayerBalances[this] = 0;
			else
				g_PlayerBalances[this] = val;
		}
	}
	
	property int Armor
	{
		public get()
		{
			return g_PlayerArmor[this.Client][TF2_GetPlayerClass(this.Client)];
		}
		public set(int val)
		{
			g_PlayerArmor[this.Client][TF2_GetPlayerClass(this.Client)] = val;
		}
	}
	
	property bool HasHelmet
	{
		public get()
		{
			return g_PlayerHelmets[this.Client][TF2_GetPlayerClass(this.Client)];
		}
		public set(bool val)
		{
			g_PlayerHelmets[this.Client][TF2_GetPlayerClass(this.Client)] = val;
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
	
	public void AddToBalance(int val, const char[] reason, any...)
	{
		this.Balance += val;
		
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
	
	public void ResetBalance()
	{
		this.Balance = tfgo_startmoney.IntValue;
	}
	
	public void PurchaseItem(int defindex)
	{
		TFClassType class = TF2_GetPlayerClass(this.Client);
		int slot = TF2_GetSlotInItem(defindex, class);
		
		// Drop old weapon, if present
		int currentWeapon = GetPlayerWeaponSlot(this.Client, slot);
		if (currentWeapon > -1)
		{
			float position[3];
			GetClientEyePosition(this.Client, position);
			float angles[3];
			GetClientEyeAngles(this.Client, angles);
			SDK_CreateDroppedWeapon(currentWeapon, this.Client, position, angles);
		}
		
		TF2_CreateAndEquipWeapon(this.Client, defindex, TFQual_Unique, GetRandomInt(1, 100));
		
		// Save to loadout
		g_PlayerLoadoutWeaponIndexes[this][class][slot] = defindex;
		
		// Deduct balance from client
		Weapon weapon;
		g_AvailableWeapons.GetArray(g_AvailableWeapons.FindValue(defindex, 0), weapon, sizeof(weapon));
		this.Balance -= weapon.cost;
		
		float origin[3];
		GetClientAbsOrigin(this.Client, origin);
		EmitAmbientSound(PLAYER_PURCHASE_SOUND, origin);
	}
	
	public int GetWeaponFromLoadout(TFClassType class, int slot)
	{
		int defindex = g_PlayerLoadoutWeaponIndexes[this][class][slot];
		if (defindex > -1)
			return defindex;
		else
			return g_DefaultWeaponIndexes[class][slot];
	}
	
	public void ApplyLoadout()
	{
		TFClassType class = TF2_GetPlayerClass(this.Client);
		
		for (int slot = sizeof(g_PlayerLoadoutWeaponIndexes[][]) - 1; slot >= 0; slot--)
		{
			int defindex = this.GetWeaponFromLoadout(class, slot);
			if (defindex != TF2_GetItemInSlot(this.Client, slot))
			{
				if (defindex > -1)
					TF2_CreateAndEquipWeapon(this.Client, defindex, TFQual_Unique, GetRandomInt(1, 100));
				else
					TF2_RemoveItemInSlot(this.Client, slot);
			}
		}
	}
	
	public void AddToLoadout(int defindex)
	{
		TFClassType class = TF2_GetPlayerClass(this.Client);
		int slot = TF2_GetSlotInItem(defindex, class);
		g_PlayerLoadoutWeaponIndexes[this.Client][class][slot] = defindex;
	}
	
	public void ClearLoadout()
	{
		for (int class = 0; class < sizeof(g_PlayerLoadoutWeaponIndexes[]); class++)
			for (int slot = 0; slot < sizeof(g_PlayerLoadoutWeaponIndexes[][]); slot++)
				g_PlayerLoadoutWeaponIndexes[this.Client][class][slot] = -1;
		
		this.Armor = 0;
		this.HasHelmet = false;
	}
	
	public bool HasFullArmor()
	{
		return this.Armor >= TF2_GetMaxHealth(this.Client);
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
	
	public void AddToClientBalances(int val, const char[] reason, any...)
	{
		char message[PLATFORM_MAX_PATH];
		VFormat(message, sizeof(message), reason, 4);
		
		for (int client = 1; client <= MaxClients; client++)
			if (IsClientInGame(client) && TF2_GetClientTeam(client) == this.Team)
				TFGOPlayer(client).AddToBalance(val, message);
	}
}
