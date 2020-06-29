static int PlayerLoadoutWeaponIndexes[TF_MAXPLAYERS][view_as<int>(TFClass_Engineer) + 1][WeaponSlot_BuilderEngie + 1];
static int PlayerAccounts[TF_MAXPLAYERS];
static int PlayerArmorValues[TF_MAXPLAYERS][view_as<int>(TFClass_Engineer) + 1];
static bool PlayerHelmets[TF_MAXPLAYERS][view_as<int>(TFClass_Engineer) + 1];
static bool PlayerDefuseKits[TF_MAXPLAYERS][view_as<int>(TFClass_Engineer) + 1];
static Menu ActiveBuyMenus[TF_MAXPLAYERS];
static char PlayerMusicKits[TF_MAXPLAYERS][PLATFORM_MAX_PATH];
static char PlayerPreviousMusicKitSounds[TF_MAXPLAYERS][PLATFORM_MAX_PATH];

static int TeamConsecutiveLosses[view_as<int>(TFTeam_Blue) + 1] =  { STARTING_CONSECUTIVE_LOSSES, ... };
static bool IsTeamAttacking[view_as<int>(TFTeam_Blue) + 1];
static bool IsTeamDefending[view_as<int>(TFTeam_Blue) + 1];

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
			return PlayerAccounts[this];
		}
		public set(int val)
		{
			if (val > tfgo_maxmoney.IntValue)
				PlayerAccounts[this] = tfgo_maxmoney.IntValue;
			else if (val < 0)
				PlayerAccounts[this] = 0;
			else
				PlayerAccounts[this] = val;
		}
	}
	
	property int ArmorValue
	{
		public get()
		{
			return PlayerArmorValues[this][TF2_GetPlayerClass(this.Client)];
		}
		public set(int val)
		{
			PlayerArmorValues[this][TF2_GetPlayerClass(this.Client)] = val;
		}
	}
	
	property bool HasHelmet
	{
		public get()
		{
			return PlayerHelmets[this][TF2_GetPlayerClass(this.Client)];
		}
		public set(bool val)
		{
			PlayerHelmets[this][TF2_GetPlayerClass(this.Client)] = val;
		}
	}
	
	property bool HasDefuseKit
	{
		public get()
		{
			return PlayerDefuseKits[this][TF2_GetPlayerClass(this.Client)];
		}
		public set(bool val)
		{
			PlayerDefuseKits[this][TF2_GetPlayerClass(this.Client)] = val;
		}
	}
	
	property Menu ActiveBuyMenu
	{
		public get()
		{
			return ActiveBuyMenus[this];
		}
		public set(Menu val)
		{
			ActiveBuyMenus[this] = val;
		}
	}
	
	public int GetMusicKit(char[] buffer, int maxlen)
	{
		return strcopy(buffer, maxlen, PlayerMusicKits[this]);
	}
	
	public int SetMusicKit(const char[] name)
	{
		return strcopy(PlayerMusicKits[this], sizeof(PlayerMusicKits[]), name);
	}
	
	public int GetPreviousPlayedSound(char[] buffer, int maxlen)
	{
		return strcopy(buffer, maxlen, PlayerPreviousMusicKitSounds[this]);
	}
	
	public int SetPreviousPlayedSound(const char[] sound)
	{
		return strcopy(PlayerPreviousMusicKitSounds[this], sizeof(PlayerPreviousMusicKitSounds[]), sound);
	}
	
	public void AddToAccount(int val, const char[] format = NULL_STRING, any...)
	{
		int temp = val;
		Action action = Forward_OnClientAccountChange(this.Client, temp);
		
		if (action >= Plugin_Changed)
			val = temp;
		
		if (action < Plugin_Handled)
		{
			if (!IsNullString(format))
			{
				SetGlobalTransTarget(this.Client);
				char message[PLATFORM_MAX_PATH];
				VFormat(message, sizeof(message), format, 4);
				CPrintToChat(this.Client, message);
			}
			
			this.Account += val;
			Forward_OnClientAccountChanged(this.Client, val);
		}
	}
	
	public void AddToLoadout(int defindex)
	{
		TFClassType class = TF2_GetPlayerClass(this.Client);
		int slot = TF2_GetItemSlot(defindex, class);
		PlayerLoadoutWeaponIndexes[this][class][slot] = defindex;
	}
	
	public BuyResult AttemptToBuyWeapon(int defindex)
	{
		TFGOWeapon config;
		if (g_AvailableWeapons.GetByDefIndex(defindex, config) > 0)
		{
			TFClassType class = TF2_GetPlayerClass(this.Client);
			int slot = TF2_GetItemSlot(defindex, class);
			int currentWeapon = GetPlayerWeaponSlot(this.Client, slot);
			
			if (currentWeapon > -1 && GetEntProp(currentWeapon, Prop_Send, "m_iItemDefinitionIndex") == defindex)
			{
				PrintCenterText(this.Client, "%t", "Already_Have_One");
				return BUY_ALREADY_HAVE;
			}
			else if (this.Account < config.price)
			{
				PrintCenterText(this.Client, "%t", "Not_Enough_Money");
				return BUY_CANT_AFFORD;
			}
			else
			{
				// Drop current weapon if one exists
				if (currentWeapon > -1)
				{
					float position[3], angles[3];
					GetClientEyePosition(this.Client, position);
					GetClientEyeAngles(this.Client, angles);
					SDKCall_CreateDroppedWeapon(currentWeapon, this.Client, position, angles);
				}
				
				// Buying while taunting causes civilian pose
				TF2_RemoveCondition(this.Client, TFCond_Taunting);
				
				TF2_RemoveItemInSlot(this.Client, slot);
				int weapon = TF2_CreateAndEquipWeapon(this.Client, defindex);
				
				char classname[256];
				TF2Econ_GetItemClassName(defindex, classname, sizeof(classname));
				if (StrContains(classname, "tf_wearable") == 0 || StrContains(classname, "tf_weapon_parachute") == 0)
				{
					if (GetEntPropEnt(this.Client, Prop_Send, "m_hActiveWeapon") <= MaxClients)
					{
						// Looks like player's new active weapon is a wearable, fix that by switching to melee
						int melee = GetPlayerWeaponSlot(this.Client, TFWeaponSlot_Melee);
						if (melee > MaxClients)
							TF2_SetActiveWeapon(this.Client, melee);
					}
				}
				else
				{
					int ammoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
					if (ammoType > -1)
					{
						// Reset ammo before GivePlayerAmmo gives the correct amount
						SetEntProp(this.Client, Prop_Send, "m_iAmmo", 0, _, ammoType);
						GivePlayerAmmo(this.Client, 9999, ammoType, true);
					}
					
					TF2_SetActiveWeapon(this.Client, weapon);
				}
				
				// Reset item charge meter to default value
				SetEntPropFloat(this.Client, Prop_Send, "m_flItemChargeMeter", SDKCall_GetDefaultItemChargeMeterValue(weapon), slot);
				
				// This fixes HUD meters
				Event event = CreateEvent("localplayer_pickup_weapon", true);
				event.FireToClient(this.Client);
				event.Cancel();
				
				// Add health to player if needed
				ArrayList attribs = TF2Econ_GetItemStaticAttributes(defindex);
				int index = attribs.FindValue(ATTRIB_MAX_HEALTH_ADDITIVE_BONUS);
				if (index > -1)
					SetEntityHealth(this.Client, GetClientHealth(this.Client) + RoundFloat(attribs.Get(index, 1)));
				delete attribs;
				
				this.AddToLoadout(defindex);
				this.Account -= config.price;
				return BUY_BOUGHT;
			}
		}
		
		return BUY_INVALID_ITEM;
	}
	
	public int GetWeaponFromLoadout(TFClassType class, int slot)
	{
		int defindex = PlayerLoadoutWeaponIndexes[this][class][slot];
		if (defindex > -1)
			return defindex;
		
		//Find default weapon for this class and slot
		for (int i = 0; i < g_AvailableWeapons.Length; i++)
		{
			TFGOWeapon weapon;
			g_AvailableWeapons.GetArray(i, weapon, sizeof(weapon));
			
			//Is this a default weapon and meant for this slot
			if (weapon.isDefault && TF2_GetItemSlot(weapon.defindex, class) == slot)
			{
				char classname[PLATFORM_MAX_PATH];
				if (TF2Econ_GetItemClassName(weapon.defindex, classname, sizeof(classname)) && TF2Econ_TranslateWeaponEntForClass(classname, sizeof(classname), class))
					return weapon.defindex;
			}
		}
		
		return -1;
	}
	
	public void ApplyLoadout()
	{
		TFClassType class = TF2_GetPlayerClass(this.Client);
		
		for (int slot = sizeof(PlayerLoadoutWeaponIndexes[][]) - 1; slot >= 0; slot--)
		{
			int defindex = this.GetWeaponFromLoadout(class, slot);
			if (defindex > -1 && (GetPlayerWeaponSlot(this.Client, slot) == -1 && SDKCall_GetEquippedWearableForLoadoutSlot(this.Client, slot) == -1))
				TF2_CreateAndEquipWeapon(this.Client, defindex);
		}
	}
	
	public void RemoveAllItems(bool removeArmor)
	{
		for (int i = 0; i < sizeof(PlayerLoadoutWeaponIndexes[]); i++)
		{
			for (int j = 0; j < sizeof(PlayerLoadoutWeaponIndexes[][]); j++)
			{
				PlayerLoadoutWeaponIndexes[this][i][j] = -1;
			}
		}
		
		if (removeArmor)
		{
			for (int i = 0; i < sizeof(PlayerHelmets[]); i++)
			{
				PlayerHelmets[this][i] = false;
			}
			
			for (int i = 0; i < sizeof(PlayerArmorValues[]); i++)
			{
				PlayerArmorValues[this][i] = 0;
			}
		}
		
		for (int i = 0; i < sizeof(PlayerDefuseKits[]); i++)
		{
			PlayerDefuseKits[this][i] = false;
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
			PrintCenterText(this.Client, "%t", "Cannot_Buy_This");
			return BUY_NOT_ALLOWED;
		}
		if (this.ArmorValue >= TF2_GetMaxHealth(this.Client))
		{
			PrintCenterText(this.Client, "%t", "Already_Have_Kevlar");
			return BUY_ALREADY_HAVE;
		}
		else if (this.Account < KEVLAR_PRICE)
		{
			PrintCenterText(this.Client, "%t", "Not_Enough_Money");
			return BUY_CANT_AFFORD;
		}
		else
		{
			if (this.HasHelmet)
				PrintCenterText(this.Client, "%t", "Already_Have_Helmet_Bought_Kevlar");
			
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
			PrintCenterText(this.Client, "%t", "Cannot_Buy_This");
			return BUY_NOT_ALLOWED;
		}
		else if (fullArmor && this.HasHelmet)
		{
			PrintCenterText(this.Client, "%t", "Already_Have_Kevlar_Helmet");
			return BUY_ALREADY_HAVE;
		}
		else if (fullArmor && !this.HasHelmet && this.Account >= HELMET_PRICE)
		{
			enoughMoney = true;
			price = HELMET_PRICE;
			PrintCenterText(this.Client, "%t", "Already_Have_Kevlar_Bought_Helmet");
		}
		else if (!fullArmor && this.HasHelmet && this.Account >= KEVLAR_PRICE)
		{
			enoughMoney = true;
			price = KEVLAR_PRICE;
			PrintCenterText(this.Client, "%t", "Already_Have_Helmet_Bought_Kevlar");
		}
		else if (this.Account >= ASSAULTSUIT_PRICE)
		{
			enoughMoney = true;
			price = ASSAULTSUIT_PRICE;
		}
		
		// Process the result
		if (!enoughMoney)
		{
			PrintCenterText(this.Client, "%t", "Not_Enough_Money");
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
		if (!IsTeamDefending[GetClientTeam(this.Client)])
		{
			PrintCenterText(this.Client, "%t", "Cannot_Buy_This");
			return BUY_NOT_ALLOWED;
		}
		else if (this.HasDefuseKit)
		{
			PrintCenterText(this.Client, "%t", "Already_Have_One");
			return BUY_ALREADY_HAVE;
		}
		else if (this.Account < DEFUSEKIT_PRICE)
		{
			PrintCenterText(this.Client, "%t", "Not_Enough_Money");
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
			return TeamConsecutiveLosses[this];
		}
		
		public set(int val)
		{
			if (val > tfgo_consecutive_loss_max.IntValue)
				TeamConsecutiveLosses[this] = tfgo_consecutive_loss_max.IntValue;
			else if (val < MIN_CONSECUTIVE_LOSSES)
				TeamConsecutiveLosses[this] = MIN_CONSECUTIVE_LOSSES;
			else
				TeamConsecutiveLosses[this] = val;
		}
	}
	
	property int LoseIncome
	{
		public get()
		{
			return tfgo_cash_team_loser_bonus.IntValue + tfgo_cash_team_loser_bonus_consecutive_rounds.IntValue * this.ConsecutiveLosses;
		}
	}
	
	property bool IsAttacking
	{
		public get()
		{
			return IsTeamAttacking[this];
		}
		public set(bool val)
		{
			IsTeamAttacking[this] = val;
		}
	}
	
	property bool IsDefending
	{
		public get()
		{
			return IsTeamDefending[this];
		}
		public set(bool val)
		{
			IsTeamDefending[this] = val;
		}
	}
	
	public void AddToClientAccounts(int val, const char[] format, any...)
	{
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client) && TF2_GetClientTeam(client) == this.Team)
			{
				SetGlobalTransTarget(client);
				char message[PLATFORM_MAX_PATH];
				VFormat(message, sizeof(message), format, 4);
				TFGOPlayer(client).AddToAccount(val, message);
			}
		}
	}
	
	public void PrintToChat(const char[] format, any...)
	{
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client) && TF2_GetClientTeam(client) == this.Team)
			{
				SetGlobalTransTarget(client);
				char message[PLATFORM_MAX_PATH];
				VFormat(message, sizeof(message), format, 3);
				CPrintToChat(client, message);
			}
		}
	}
}
