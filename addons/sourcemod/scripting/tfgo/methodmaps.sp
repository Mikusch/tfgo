methodmap TFGOWeapon
{
	public TFGOWeapon(int defindex)
	{
		return view_as<TFGOWeapon>(defindex);
	}
	
	property int DefIndex
	{
		public get()
		{
			return view_as<int>(this);
		}
	}
	
	property int Cost
	{
		public get()
		{
			int index = weaponList.FindValue(this, 0);
			TFGOWeaponEntry weapon;
			weaponList.GetArray(index, weapon, sizeof(weapon));
			return weapon.Cost;
		}
	}
	
	property int KillReward
	{
		public get()
		{
			char key[255];
			TF2Econ_GetItemClassName(this.DefIndex, key, sizeof(key));
			
			int reward;
			killAwardMap.GetValue(key, reward);
			return reward;
		}
	}
	
	public bool IsInBuyMenu()
	{
		return weaponList.FindValue(this, 0) != -1;
	}
}

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
	
	/**
	 * The player's money.
	 */
	property int Balance
	{
		public get()
		{
			return g_iBalance[this];
		}
		public set(int val)
		{
			if (val > TFGO_MAX_BALANCE)
				g_iBalance[this] = TFGO_MAX_BALANCE;
			else if (val < TFGO_MIN_BALANCE)
				g_iBalance[this] = TFGO_MIN_BALANCE;
			else
				g_iBalance[this] = val;
		}
	}

	property Menu ActiveBuyMenu
	{
		public get()
		{
			return g_hActiveBuyMenus[this];
		}
		public set(Menu val)
		{
			g_hActiveBuyMenus[this] = val;
		}
	}

	public void ShowMoneyHudDisplay(float time)
	{
		SetHudTextParams(-1.0, 0.675, time, 0, 133, 67, 140);
		ShowSyncHudText(this.Client, g_hHudSync, "$%d", this.Balance);
	}

	/**
	 * Adds to the balance of this client and displays a chat message notifying them of the amount earned.
	 *
	 * Passing a negative value will remove balance instead.
	 *
	 * @param val		the amount to add
	 * @param reason	(optional) the reason for this operation
	 */
	public void AddToBalance(int val, const char[] reason = "")
	{
		this.Balance += val;
		if (val >= 0)
		{
			if (strlen(reason) > 0)
				CPrintToChat(this.Client, "{money}+$%d{default}: %s.", val, reason);
			else
				CPrintToChat(this.Client, "{money}+$%d{default}", val);
		}
		else
		{
			val = IntAbs(val);
			if (strlen(reason) > 0)
				CPrintToChat(this.Client, "{alert}-$%d{default}: %s.", val, reason);
			else
				CPrintToChat(this.Client, "{alert}-$%d{default}", val);
		}

		this.ShowMoneyHudDisplay(5.0);
	}

	/**
	* Purchases an item for this player and adds it to their loadout.
	**/
	public void PurchaseItem(int defindex)
	{
		// This shouldn't even be possible but better safe than sorry?
		if (!g_bBuyTimeActive)return;

		TFGOWeapon weapon = TFGOWeapon(defindex);
		TFClassType class = TF2_GetPlayerClass(this.Client);
		int slot = TF2Econ_GetItemSlot(defindex, class);

		// Player doesn't own weapon yet, charge them for it and grant it
		if (g_iLoadoutWeaponIndex[this][class][slot] != defindex)
		{
			TF2_CreateAndEquipWeapon(this.Client, defindex);

			g_iLoadoutWeaponIndex[this][class][slot] = defindex; // Save to loadout
			this.Balance -= weapon.Cost;

			char name[255];
			TF2Econ_GetItemName(defindex, name, sizeof(name));
			CPrintToChat(this.Client, "You have bought {normal}%s{default} for {money}$%d{default}.", name, weapon.Cost);

			float pos[3];
			GetClientAbsOrigin(this.Client, pos);
			EmitAmbientSound("mvm/mvm_bought_upgrade.wav", pos);

			this.ShowMoneyHudDisplay(5.0);
		}
		else // Player owns this weapon already, equip it
		{
			TF2_CreateAndEquipWeapon(this.Client, defindex);
		}
	}

	/**
	* Gets a weapon from the player's loadout.
	* If this player has no purchased weapon in their loadout, this function may return the default weapon definition index.
	*
	* @return a valid item definition index or -1 if no weapon for the slot has been found
	**/
	public int GetWeaponFromLoadout(TFClassType class, int slot)
	{
		int defindex = g_iLoadoutWeaponIndex[this][class][slot];
		if (defindex <= -1)
			return g_iDefaultWeaponIndex[class][slot];
		else
			return defindex;
	}

	/**
	* Applies this player's current loadout.
	**/
	public void ApplyLoadout()
	{
		TFClassType class = TF2_GetPlayerClass(this.Client);

		for (int slot = sizeof(g_iLoadoutWeaponIndex[][]) - 1; slot >= 0 ; slot--)
		{
			int defindex = this.GetWeaponFromLoadout(class, slot);
			if (defindex != -1)
				TF2_CreateAndEquipWeapon(this.Client, defindex);
			else
				TF2_RemoveItemInSlot(this.Client, slot);
		}
	}

	/**
    * Adds a weapon to this player's loadout.
    **/
	public void AddToLoadout(int defindex)
	{
		TFClassType class = TF2_GetPlayerClass(this.Client);
		g_iLoadoutWeaponIndex[this.Client][view_as<int>(class)][TF2Econ_GetItemSlot(defindex, class)] = defindex;
	}

	/**
	* Resets this player's loadout.
	**/
	public void ClearLoadout()
	{
		for (int class = 0; class < sizeof(g_iLoadoutWeaponIndex[]); class++)
		    for (int slot = 0; slot < sizeof(g_iLoadoutWeaponIndex[][]); slot++)
		        g_iLoadoutWeaponIndex[this.Client][class][slot] = -1;
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
			return g_iLoseStreak[this];
		}

		public set(int val)
		{
			if (val > TFGO_MAX_LOSESTREAK)
				g_iLoseStreak[this] = TFGO_MAX_LOSESTREAK;
			else if (val < TFGO_MIN_LOSESTREAK)
				g_iLoseStreak[this] = TFGO_MIN_LOSESTREAK;
			else
				g_iLoseStreak[this] = val;
		}
	}

	/**
	 * Adds balance to every client in this team and displays
	 * a chat message notifying them of the amount earned.
	 *
	 * @param val		the amount to add
	 * @param reason	(optional) the reason for this operation
	 */
	public void AddToTeamBalance(int val, const char[] reason = "")
	{
		for (int i = 1; i <= MaxClients; i++)
		    if (IsClientInGame(i) && TF2_GetClientTeam(i) == this.Team)
			    TFGOPlayer(i).AddToBalance(val, reason);
	}
}
