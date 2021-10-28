/*
 * Copyright (C) 2020  Mikusch
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

static int PlayerLoadoutWeaponIndexes[MAXPLAYERS + 1][view_as<int>(TFClass_Engineer) + 1][WeaponSlot_BuilderEngie + 1];
static int PlayerAccounts[MAXPLAYERS + 1];
static int PlayerArmorValues[MAXPLAYERS + 1][view_as<int>(TFClass_Engineer) + 1];
static bool PlayerHelmets[MAXPLAYERS + 1][view_as<int>(TFClass_Engineer) + 1];
static bool PlayerDefuseKits[MAXPLAYERS + 1][view_as<int>(TFClass_Engineer) + 1];
static bool PlayerHasSuicided[MAXPLAYERS + 1];
static bool PlayerIsInBuyZone[MAXPLAYERS + 1];
static Menu PlayerActiveBuyMenus[MAXPLAYERS + 1];
static char PlayerMusicKits[MAXPLAYERS + 1][PLATFORM_MAX_PATH];
static char PlayerPreviousMusicKitSounds[MAXPLAYERS + 1][PLATFORM_MAX_PATH];

static int TeamConsecutiveLosses[view_as<int>(TFTeam_Blue) + 1] = { STARTING_CONSECUTIVE_LOSSES, ... };
static bool TeamIsAttacking[view_as<int>(TFTeam_Blue) + 1];
static bool TeamIsDefending[view_as<int>(TFTeam_Blue) + 1];

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
			return view_as<int>(this)
		}
	}
	
	property int Account
	{
		public get()
		{
			return PlayerAccounts[this.Client];
		}
		public set(int val)
		{
			if (val > tfgo_maxmoney.IntValue)
				PlayerAccounts[this.Client] = tfgo_maxmoney.IntValue;
			else if (val < 0)
				PlayerAccounts[this.Client] = 0;
			else
				PlayerAccounts[this.Client] = val;
		}
	}
	
	property int ArmorValue
	{
		public get()
		{
			return PlayerArmorValues[this.Client][TF2_GetPlayerClass(view_as<int>(this))];
		}
		public set(int val)
		{
			PlayerArmorValues[this.Client][TF2_GetPlayerClass(view_as<int>(this))] = val;
		}
	}
	
	property bool HasHelmet
	{
		public get()
		{
			return PlayerHelmets[this.Client][TF2_GetPlayerClass(view_as<int>(this))];
		}
		public set(bool val)
		{
			PlayerHelmets[this.Client][TF2_GetPlayerClass(view_as<int>(this))] = val;
		}
	}
	
	property bool HasDefuseKit
	{
		public get()
		{
			return PlayerDefuseKits[this.Client][TF2_GetPlayerClass(view_as<int>(this))];
		}
		public set(bool val)
		{
			PlayerDefuseKits[this.Client][TF2_GetPlayerClass(view_as<int>(this))] = val;
		}
	}
	
	property bool HasSuicided
	{
		public get()
		{
			return PlayerHasSuicided[this.Client];
		}
		public set(bool val)
		{
			PlayerHasSuicided[this.Client] = val;
		}
	}
	
	property bool InBuyZone
	{
		public get()
		{
			return PlayerIsInBuyZone[this.Client];
		}
		public set(bool val)
		{
			PlayerIsInBuyZone[this.Client] = val;
		}
	}
	
	property Menu ActiveBuyMenu
	{
		public get()
		{
			return PlayerActiveBuyMenus[this.Client];
		}
		public set(Menu val)
		{
			PlayerActiveBuyMenus[this.Client] = val;
		}
	}
	
	public int GetMusicKit(char[] buffer, int maxlen)
	{
		return strcopy(buffer, maxlen, PlayerMusicKits[this.Client]);
	}
	
	public int SetMusicKit(const char[] name)
	{
		return strcopy(PlayerMusicKits[this.Client], sizeof(PlayerMusicKits[]), name);
	}
	
	public int GetPreviousPlayedSound(char[] buffer, int maxlen)
	{
		return strcopy(buffer, maxlen, PlayerPreviousMusicKitSounds[this.Client]);
	}
	
	public int SetPreviousPlayedSound(const char[] sound)
	{
		return strcopy(PlayerPreviousMusicKitSounds[this.Client], sizeof(PlayerPreviousMusicKitSounds[]), sound);
	}
	
	public void AddToAccount(int val, const char[] format = NULL_STRING, any...)
	{
		int temp = val;
		Action action = Forward_OnClientAccountChange(view_as<int>(this), temp);
		
		if (action >= Plugin_Changed)
			val = temp;
		
		if (action < Plugin_Handled)
		{
			if (!IsNullString(format))
			{
				SetGlobalTransTarget(view_as<int>(this));
				char message[PLATFORM_MAX_PATH];
				VFormat(message, sizeof(message), format, 4);
				CPrintToChat(view_as<int>(this), message);
			}
			
			this.Account += val;
			
			if (val > 0)
			{
				SetHudTextParams(0.05, 0.29, 5.0, 162, 255, 71, 255);
				ShowSyncHudText(view_as<int>(this), g_CashEarnedHudSync, "+$%d", val);
			}
			else if (val < 0)
			{
				SetHudTextParams(0.05, 0.29, 5.0, 234, 65, 65, 255);
				ShowSyncHudText(view_as<int>(this), g_CashEarnedHudSync, "-$%d", val);
			}
			
			Forward_OnClientAccountChanged(view_as<int>(this), val);
		}
	}
	
	public void AddToLoadout(int defindex)
	{
		TFClassType class = TF2_GetPlayerClass(view_as<int>(this));
		int slot = TF2_GetItemWeaponSlot(defindex, class);
		PlayerLoadoutWeaponIndexes[this.Client][class][slot] = defindex;
	}
	
	public BuyResult AttemptToBuyWeapon(int defindex)
	{
		TFGOWeapon config;
		if (g_AvailableWeapons.GetByDefIndex(defindex, config) > 0)
		{
			TFClassType class = TF2_GetPlayerClass(view_as<int>(this));
			int slot = TF2_GetItemWeaponSlot(defindex, class);
			int currentWeapon = GetPlayerWeaponSlot(view_as<int>(this), slot);
			
			if (currentWeapon > -1 && GetEntProp(currentWeapon, Prop_Send, "m_iItemDefinitionIndex") == defindex)
			{
				PrintCenterText(view_as<int>(this), "%t", "Already_Have_One");
				return BUY_ALREADY_HAVE;
			}
			else if (this.Account < config.price)
			{
				PrintCenterText(view_as<int>(this), "%t", "Not_Enough_Money");
				return BUY_CANT_AFFORD;
			}
			else
			{
				// Drop current weapon if one exists
				if (currentWeapon > -1)
				{
					float position[3], angles[3];
					GetClientEyePosition(view_as<int>(this), position);
					GetClientEyeAngles(view_as<int>(this), angles);
					SDKCall_CreateDroppedWeapon(currentWeapon, view_as<int>(this), position, angles);
				}
				
				// Buying while taunting causes civilian pose
				TF2_RemoveCondition(view_as<int>(this), TFCond_Taunting);
				
				TF2_RemoveItemInSlot(view_as<int>(this), slot);
				int weapon = TF2_CreateAndEquipWeapon(view_as<int>(this), defindex);
				
				char classname[256];
				TF2Econ_GetItemClassName(defindex, classname, sizeof(classname));
				if (StrContains(classname, "tf_wearable") == 0 || StrContains(classname, "tf_weapon_parachute") == 0)
				{
					if (GetEntPropEnt(view_as<int>(this), Prop_Send, "m_hActiveWeapon") <= MaxClients)
					{
						// Looks like player's new active weapon is a wearable, fix that by switching to melee
						int melee = GetPlayerWeaponSlot(view_as<int>(this), TFWeaponSlot_Melee);
						if (melee > MaxClients)
							TF2_SetActiveWeapon(view_as<int>(this), melee);
					}
				}
				else
				{
					int ammoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
					if (ammoType > -1)
					{
						// Reset ammo before GivePlayerAmmo gives the correct amount
						SetEntProp(view_as<int>(this), Prop_Send, "m_iAmmo", 0, _, ammoType);
						GivePlayerAmmo(view_as<int>(this), 9999, ammoType, true);
					}
					
					TF2_SetActiveWeapon(view_as<int>(this), weapon);
				}
				
				// Reset item charge meter to default value
				SetEntPropFloat(view_as<int>(this), Prop_Send, "m_flItemChargeMeter", SDKCall_GetDefaultItemChargeMeterValue(weapon), slot);
				
				// This fixes HUD meters
				Event event = CreateEvent("localplayer_pickup_weapon", true);
				event.FireToClient(view_as<int>(this));
				event.Cancel();
				
				// Add health to player if needed
				ArrayList attribs = TF2Econ_GetItemStaticAttributes(defindex);
				int index = attribs.FindValue(ATTRIB_MAX_HEALTH_ADDITIVE_BONUS);
				if (index > -1)
					SetEntityHealth(view_as<int>(this), GetClientHealth(view_as<int>(this)) + RoundFloat(attribs.Get(index, 1)));
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
		int defindex = PlayerLoadoutWeaponIndexes[this.Client][class][slot];
		if (defindex > -1)
			return defindex;
		
		//Find default weapon for this class and slot
		for (int i = 0; i < g_AvailableWeapons.Length; i++)
		{
			TFGOWeapon weapon;
			g_AvailableWeapons.GetArray(i, weapon, sizeof(weapon));
			
			//Is this a default weapon and meant for this slot
			if (weapon.isDefault && TF2_GetItemWeaponSlot(weapon.defindex, class) == slot)
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
		TFClassType class = TF2_GetPlayerClass(view_as<int>(this));
		
		for (int slot = sizeof(PlayerLoadoutWeaponIndexes[][]) - 1; slot >= 0; slot--)
		{
			int defindex = this.GetWeaponFromLoadout(class, slot);
			if (defindex > -1 && (GetPlayerWeaponSlot(view_as<int>(this), slot) == -1 && SDKCall_GetEquippedWearableForLoadoutSlot(view_as<int>(this), slot) == -1))
				TF2_CreateAndEquipWeapon(view_as<int>(this), defindex);
		}
	}
	
	public void RemoveAllItems(bool removeArmor)
	{
		for (int i = 0; i < sizeof(PlayerLoadoutWeaponIndexes[]); i++)
		{
			for (int j = 0; j < sizeof(PlayerLoadoutWeaponIndexes[][]); j++)
			{
				PlayerLoadoutWeaponIndexes[this.Client][i][j] = -1;
			}
		}
		
		if (removeArmor)
		{
			for (int i = 0; i < sizeof(PlayerHelmets[]); i++)
			{
				PlayerHelmets[this.Client][i] = false;
			}
			
			for (int i = 0; i < sizeof(PlayerArmorValues[]); i++)
			{
				PlayerArmorValues[this.Client][i] = 0;
			}
		}
		
		for (int i = 0; i < sizeof(PlayerDefuseKits[]); i++)
		{
			PlayerDefuseKits[this.Client][i] = false;
		}
	}
	
	public void Reset()
	{
		this.RemoveAllItems(true);
		this.Account = tfgo_startmoney.IntValue;
	}
	
	public bool CanDefuse()
	{
		return g_IsBombPlanted && TF2_GetClientTeam(view_as<int>(this)) != g_BombPlantingTeam;
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
			PrintCenterText(view_as<int>(this), "%t", "Cannot_Buy_This");
			return BUY_NOT_ALLOWED;
		}
		if (this.ArmorValue >= TF2_GetMaxHealth(view_as<int>(this)))
		{
			PrintCenterText(view_as<int>(this), "%t", "Already_Have_Kevlar");
			return BUY_ALREADY_HAVE;
		}
		else if (this.Account < KEVLAR_PRICE)
		{
			PrintCenterText(view_as<int>(this), "%t", "Not_Enough_Money");
			return BUY_CANT_AFFORD;
		}
		else
		{
			if (this.HasHelmet)
				PrintCenterText(view_as<int>(this), "%t", "Already_Have_Helmet_Bought_Kevlar");
			
			this.ArmorValue = TF2_GetMaxHealth(view_as<int>(this));
			this.Account -= KEVLAR_PRICE;
			return BUY_BOUGHT;
		}
	}
	
	public BuyResult AttemptToBuyAssaultSuit()
	{
		bool fullArmor = this.ArmorValue >= TF2_GetMaxHealth(view_as<int>(this));
		
		bool enoughMoney;
		int price;
		
		if (tfgo_max_armor.IntValue < 2)
		{
			PrintCenterText(view_as<int>(this), "%t", "Cannot_Buy_This");
			return BUY_NOT_ALLOWED;
		}
		else if (fullArmor && this.HasHelmet)
		{
			PrintCenterText(view_as<int>(this), "%t", "Already_Have_Kevlar_Helmet");
			return BUY_ALREADY_HAVE;
		}
		else if (fullArmor && !this.HasHelmet && this.Account >= HELMET_PRICE)
		{
			enoughMoney = true;
			price = HELMET_PRICE;
			PrintCenterText(view_as<int>(this), "%t", "Already_Have_Kevlar_Bought_Helmet");
		}
		else if (!fullArmor && this.HasHelmet && this.Account >= KEVLAR_PRICE)
		{
			enoughMoney = true;
			price = KEVLAR_PRICE;
			PrintCenterText(view_as<int>(this), "%t", "Already_Have_Helmet_Bought_Kevlar");
		}
		else if (this.Account >= ASSAULTSUIT_PRICE)
		{
			enoughMoney = true;
			price = ASSAULTSUIT_PRICE;
		}
		
		// Process the result
		if (!enoughMoney)
		{
			PrintCenterText(view_as<int>(this), "%t", "Not_Enough_Money");
			return BUY_CANT_AFFORD;
		}
		else
		{
			this.HasHelmet = true;
			this.ArmorValue = TF2_GetMaxHealth(view_as<int>(this));
			this.Account -= price;
			return BUY_BOUGHT;
		}
	}
	
	public BuyResult AttemptToBuyDefuseKit()
	{
		if (!TeamIsDefending[GetClientTeam(view_as<int>(this))])
		{
			PrintCenterText(view_as<int>(this), "%t", "Cannot_Buy_This");
			return BUY_NOT_ALLOWED;
		}
		else if (this.HasDefuseKit)
		{
			PrintCenterText(view_as<int>(this), "%t", "Already_Have_One");
			return BUY_ALREADY_HAVE;
		}
		else if (this.Account < DEFUSEKIT_PRICE)
		{
			PrintCenterText(view_as<int>(this), "%t", "Not_Enough_Money");
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
	
	property int TeamNum
	{
		public get()
		{
			return view_as<int>(this);
		}
	}
	
	property int ConsecutiveLosses
	{
		public get()
		{
			return TeamConsecutiveLosses[this.TeamNum];
		}
		
		public set(int val)
		{
			if (val > tfgo_consecutive_loss_max.IntValue)
				TeamConsecutiveLosses[this.TeamNum] = tfgo_consecutive_loss_max.IntValue;
			else if (val < MIN_CONSECUTIVE_LOSSES)
				TeamConsecutiveLosses[this.TeamNum] = MIN_CONSECUTIVE_LOSSES;
			else
				TeamConsecutiveLosses[this.TeamNum] = val;
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
			return TeamIsAttacking[this.TeamNum];
		}
		public set(bool val)
		{
			TeamIsAttacking[this.TeamNum] = val;
		}
	}
	
	property bool IsDefending
	{
		public get()
		{
			return TeamIsDefending[this.TeamNum];
		}
		public set(bool val)
		{
			TeamIsDefending[this.TeamNum] = val;
		}
	}
	
	public void AddToClientAccounts(int val, const char[] format, any...)
	{
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client) && TF2_GetClientTeam(client) == view_as<TFTeam>(this))
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
			if (IsClientInGame(client) && TF2_GetClientTeam(client) == view_as<TFTeam>(this))
			{
				SetGlobalTransTarget(client);
				char message[PLATFORM_MAX_PATH];
				VFormat(message, sizeof(message), format, 3);
				CPrintToChat(client, message);
			}
		}
	}
}
