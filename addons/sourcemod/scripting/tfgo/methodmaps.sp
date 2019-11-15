#define TFGO_MIN_LOSESTREAK				0
#define TFGO_MAX_LOSESTREAK				4
#define TFGO_STARTING_LOSESTREAK		1

// -1 indicates the class should start with no weapon in that slot
int g_defaultWeaponIndexes[][] =  {
	{ -1, -1, -1, -1, -1, -1 },  // Unknown
	{ -1, 23, 30758, -1, -1, -1 },  // Scout
	{ -1, 16, 30758, -1, -1, -1 },  // Sniper
	{ -1, 10, 30758, -1, -1, -1 },  // Soldier
	{ -1, 131, 30758, -1, -1, -1 },  // Demoman
	{ 17, -1, 30758, -1, -1, -1 },  // Medic
	{ -1, 11, 30758, -1, -1, -1 },  // Heavy
	{ -1, 12, 30758, -1, -1, -1 },  // Pyro
	{ -1, 735, 4, -1, 30, -1 },  // Spy
	{ 9, 22, 30758, -1, -1, 28 } // Engineer
};

float g_classViewHeights[] =  { -1.0, 65.0, 75.0, 68.0, 68.0, 75.0, 75.0, 68.0, 75.0, 68.0 };

int g_playerLoadoutWeaponIndexes[TF_MAXPLAYERS + 1][view_as<int>(TFClass_Engineer) + 1][view_as<int>(WeaponSlot_BuilderEngie) + 1];
int g_playerBalances[TF_MAXPLAYERS + 1];

Menu g_activeBuyMenus[TF_MAXPLAYERS + 1];

int g_teamLosingStreaks[view_as<int>(TFTeam_Blue) + 1] =  { TFGO_STARTING_LOSESTREAK, ... };
int g_losingStreakCompensation[TFGO_MAX_LOSESTREAK + 1] =  { 1400, 1900, 2400, 2900, 3400 };


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
			return g_playerBalances[this];
		}
		public set(int val)
		{
			if (val > tfgo_maxmoney.IntValue)
				g_playerBalances[this] = tfgo_maxmoney.IntValue;
			else if (val < 0)
				g_playerBalances[this] = 0;
			else
				g_playerBalances[this] = val;
		}
	}
	
	property Menu ActiveBuyMenu
	{
		public get()
		{
			return g_activeBuyMenus[this];
		}
		public set(Menu val)
		{
			g_activeBuyMenus[this] = val;
		}
	}
	
	public void ShowMoneyHudDisplay(float time)
	{
		SetHudTextParams(-1.0, 0.675, time, 0, 162, 255, 71);
		ShowSyncHudText(this.Client, g_hudSync, "$%d", this.Balance);
	}
	
	public void AddToBalance(int val, const char[] reason = NULL_STRING)
	{
		this.Balance += val;
		if (val > 0)
		{
			if (IsNullString(reason))
				CPrintToChat(this.Client, "{positive}+$%d{default}", val);
			else
				CPrintToChat(this.Client, "{positive}+$%d{default}: %s.", val, reason);
		}
		else if (val < 0)
		{
			val = IntAbs(val);
			if (IsNullString(reason))
				CPrintToChat(this.Client, "{negative}-$%d{default}", val);
			else
				CPrintToChat(this.Client, "{negative}-$%d{default}: %s.", val, reason);
		}
		else
		{
			if (IsNullString(reason))
				CPrintToChat(this.Client, "{negative}$%d{default}", val);
			else
				CPrintToChat(this.Client, "{negative}$%d{default}: %s.", val, reason);
		}
		
		this.ShowMoneyHudDisplay(5.0);
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
			float origin[3];
			GetClientAbsOrigin(this.Client, origin);
			origin[2] += g_classViewHeights[class] / 2;
			float angles[3];
			GetClientAbsAngles(this.Client, angles);
			SDK_CreateDroppedWeapon(currentWeapon, this.Client, origin, angles);
		}
		
		TF2_CreateAndEquipWeapon(this.Client, defindex);
		
		// Save to loadout
		g_playerLoadoutWeaponIndexes[this][class][slot] = defindex;
		
		// Deduct balance from client
		Weapon weapon;
		g_availableWeapons.GetArray(g_availableWeapons.FindValue(defindex, 0), weapon, sizeof(weapon));
		this.Balance -= weapon.cost;
		
		float origin[3];
		GetClientAbsOrigin(this.Client, origin);
		EmitAmbientSound("mvm/mvm_bought_upgrade.wav", origin);
	}
	
	public int GetWeaponFromLoadout(TFClassType class, int slot)
	{
		int defindex = g_playerLoadoutWeaponIndexes[this][class][slot];
		if (defindex <= -1)
			return g_defaultWeaponIndexes[class][slot];
		else
			return defindex;
	}
	
	public void ApplyLoadout()
	{
		TFClassType class = TF2_GetPlayerClass(this.Client);
		
		for (int slot = sizeof(g_playerLoadoutWeaponIndexes[][]) - 1; slot >= 0; slot--)
		{
			int defindex = this.GetWeaponFromLoadout(class, slot);
			if (defindex != TF2_GetItemInSlot(this.Client, slot))
			{
				if (defindex != -1)
					TF2_CreateAndEquipWeapon(this.Client, defindex);
				else
					TF2_RemoveItemInSlot(this.Client, slot);
			}
		}
	}
	
	public void AddToLoadout(int defindex)
	{
		TFClassType class = TF2_GetPlayerClass(this.Client);
		int slot = TF2_GetSlotInItem(defindex, class);
		g_playerLoadoutWeaponIndexes[this.Client][view_as<int>(class)][slot] = defindex;
	}
	
	public void ClearLoadout()
	{
		for (int class = 0; class < sizeof(g_playerLoadoutWeaponIndexes[]); class++)
			for (int slot = 0; slot < sizeof(g_playerLoadoutWeaponIndexes[][]); slot++)
				g_playerLoadoutWeaponIndexes[this.Client][class][slot] = -1;
	}
}

methodmap TFGOTeam
{
	public TFGOTeam(TFTeam team)
	{
		return view_as<TFGOTeam>(view_as<int>(team));
	}
	
	property TFTeam Team
	{
		public get()
		{
			return view_as<TFTeam>(this);
		}
	}
	
	property int LoseStreak
	{
		public get()
		{
			return g_teamLosingStreaks[this];
		}
		
		public set(int val)
		{
			if (val > TFGO_MAX_LOSESTREAK)
				g_teamLosingStreaks[this] = TFGO_MAX_LOSESTREAK;
			else if (val < TFGO_MIN_LOSESTREAK)
				g_teamLosingStreaks[this] = TFGO_MIN_LOSESTREAK;
			else
				g_teamLosingStreaks[this] = val;
		}
	}
	
	property int LoseIncome
	{
		public get()
		{
			return g_losingStreakCompensation[this.LoseStreak];
		}
	}
	
	public void ResetLoseStreak()
	{
		g_teamLosingStreaks[this] = TFGO_STARTING_LOSESTREAK;
	}
	
	public void AddToTeamBalance(int val, const char[] reason = NULL_STRING)
	{
		for (int client = 1; client <= MaxClients; client++)
		if (IsClientInGame(client) && TF2_GetClientTeam(client) == this.Team)
			TFGOPlayer(client).AddToBalance(val, reason);
	}
	
	public int GetHighestBalance()
	{
		int balance = tfgo_startmoney.IntValue;
		for (int client = 1; client <= MaxClients; client++)
		{
			TFGOPlayer player = TFGOPlayer(client);
			if (IsClientInGame(client) && TF2_GetClientTeam(client) == this.Team && player.Balance > balance)
				balance = player.Balance;
		}
		return balance;
	}
}
