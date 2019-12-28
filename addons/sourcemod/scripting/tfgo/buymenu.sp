#define INFO_GEAR "GEAR"
#define INFO_GEAR_KEVLAR "KEVLAR"
#define INFO_GEAR_KEVLAR_HELMET "KEVLAR_HELMET"

public void DisplaySlotSelectionMenu(int client)
{
	Menu menu = new Menu(HandleSlotSelectionMenu, MenuAction_Display | MenuAction_Select | MenuAction_Cancel | MenuAction_End | MenuAction_DisplayItem);
	menu.SetTitle("%T", "BuyMenu_Title", LANG_SERVER);
	
	switch (TF2_GetPlayerClass(client))
	{
		case TFClass_Engineer:
		{
			menu.AddItem("0", "BuyMenu_Primaries");
			menu.AddItem("1", "BuyMenu_Secondaries");
			menu.AddItem("2", "BuyMenu_Melees");
			menu.AddItem("3;4", "BuyMenu_PDAs");
		}
		
		case TFClass_Spy:
		{
			menu.AddItem("0", "BuyMenu_Secondaries"); // Revolver
			menu.AddItem("2", "BuyMenu_Melees"); // Knife
			menu.AddItem("3;4", "BuyMenu_PDAs"); // Disguise Kit/Invis Watch
			//menu.AddItem("1", "BuyMenu_Buildings"); // Sapper (Currently crashes the game)
		}
		
		default:
		{
			menu.AddItem("0", "BuyMenu_Primaries");
			menu.AddItem("1", "BuyMenu_Secondaries");
			menu.AddItem("2", "BuyMenu_Melees");
		}
	}
	
	menu.AddItem(INFO_GEAR, "BuyMenu_Gear");
	
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int HandleSlotSelectionMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Display:TFGOPlayer(param1).ActiveBuyMenu = menu;
		
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			
			if (StrEqual(info, INFO_GEAR))
			{
				DisplayGearMenu(param1);
			}
			else
			{
				char slotStrings[TFWeaponSlot_Building + 1][32];
				if (ExplodeString(info, ";", slotStrings, sizeof(slotStrings), sizeof(slotStrings[])) >= 1)
				{
					ArrayList slots = new ArrayList();
					for (int i = 0; i < sizeof(slotStrings); i++)
					{
						TrimString(slotStrings[i]);
						if (strlen(slotStrings[i]) > 0)
							slots.Push(StringToInt(slotStrings[i]));
					}
					DisplayBuyMenu(param1, slots);
				}
			}
		}
		
		case MenuAction_Cancel:TFGOPlayer(param1).ActiveBuyMenu = null;
		
		case MenuAction_End:delete menu;
		
		case MenuAction_DisplayItem:
		{
			char info[32];
			char display[64];
			menu.GetItem(param2, info, sizeof(info), _, display, sizeof(display));
			Format(display, sizeof(display), "%T", display, LANG_SERVER);
			return RedrawMenuItem(display);
		}
	}
	
	return 0;
}

public void DisplayBuyMenu(int client, ArrayList slots)
{
	Menu menu = new Menu(HandleBuyMenu, MenuAction_Display | MenuAction_Select | MenuAction_Cancel | MenuAction_End | MenuAction_DrawItem);
	menu.SetTitle("%T", "BuyMenu_Title", LANG_SERVER);
	
	for (int i = 0; i < g_AvailableWeapons.Length; i++)
	{
		Weapon weapon;
		g_AvailableWeapons.GetArray(i, weapon, sizeof(weapon));
		
		TFGOPlayer player = TFGOPlayer(client);
		TFClassType class = TF2_GetPlayerClass(client);
		int slot = TF2_GetSlotInItem(weapon.defindex, class);
		
		int slotIndex = slots.FindValue(slot);
		if (slotIndex > -1 && weapon.cost > -1)
		{
			char info[32];
			IntToString(weapon.defindex, info, sizeof(info));
			
			char display[PLATFORM_MAX_PATH];
			char weaponName[PLATFORM_MAX_PATH];
			TF2_GetItemName(weapon.defindex, weaponName, sizeof(weaponName));
			
			if (player.GetWeaponFromLoadout(class, slot) != weapon.defindex)
			{
				Format(display, sizeof(display), "%s ($%d)", weaponName, weapon.cost);
			}
			else
			{
				char alreadyCarryingTag[PLATFORM_MAX_PATH];
				Format(alreadyCarryingTag, sizeof(alreadyCarryingTag), "%T", "BuyMenu_AlreadyCarrying", LANG_SERVER);
				Format(display, sizeof(display), "%s (%s)", weaponName, alreadyCarryingTag);
			}
			
			menu.AddItem(info, display);
		}
	}
	delete slots;
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public int HandleBuyMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Display:TFGOPlayer(param1).ActiveBuyMenu = menu;
		
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			TFGOPlayer(param1).PurchaseItem(StringToInt(info));
			DisplaySlotSelectionMenu(param1);
		}
		
		case MenuAction_Cancel:
		{
			TFGOPlayer(param1).ActiveBuyMenu = null;
			if (param2 == MenuCancel_ExitBack)
				DisplaySlotSelectionMenu(param1);
		}
		
		case MenuAction_End:delete menu;
		
		case MenuAction_DrawItem:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			
			Weapon weapon;
			g_AvailableWeapons.GetArray(g_AvailableWeapons.FindValue(StringToInt(info), 0), weapon, sizeof(weapon));
			
			TFGOPlayer player = TFGOPlayer(param1);
			TFClassType class = TF2_GetPlayerClass(param1);
			int slot = TF2_GetSlotInItem(weapon.defindex, class);
			
			if (player.GetWeaponFromLoadout(class, slot) == weapon.defindex || weapon.cost > TFGOPlayer(param1).Balance)
				return ITEMDRAW_DISABLED;
			else
				return ITEMDRAW_DEFAULT;
		}
	}
	
	return 0;
}

public int DisplayGearMenu(int client)
{
	Menu menu = new Menu(HandleGearMenu, MenuAction_Display | MenuAction_Select | MenuAction_Cancel | MenuAction_End | MenuAction_DisplayItem);
	menu.SetTitle("%T", "BuyMenu_Title", LANG_SERVER, TFGOPlayer(client).Balance);
	
	menu.AddItem(INFO_GEAR_KEVLAR, "BuyMenu_Gear_Kevlar");
	menu.AddItem(INFO_GEAR_KEVLAR_HELMET, "BuyMenu_Gear_Kevlar_Helmet");
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public int HandleGearMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Display:TFGOPlayer(param1).ActiveBuyMenu = menu;
		
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			
			if (StrEqual(info, INFO_GEAR_KEVLAR))
			{
				// TODO actually purchase kevlar
			}
			else if (StrEqual(info, INFO_GEAR_KEVLAR_HELMET))
			{
				// TODO actually purchase kevlar and helmet
			}
			
			float origin[3];
			GetClientAbsOrigin(param1, origin);
			EmitAmbientSound(PLAYER_PURCHASE_SOUND, origin);
			
			DisplaySlotSelectionMenu(param1);
		}
		
		case MenuAction_Cancel:
		{
			TFGOPlayer(param1).ActiveBuyMenu = null;
			if (param2 == MenuCancel_ExitBack)
				DisplaySlotSelectionMenu(param1);
		}
		
		case MenuAction_End:delete menu;
		
		case MenuAction_DrawItem:
		{
			TFGOPlayer player = TFGOPlayer(param1);
			
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			
			if (StrEqual(info, INFO_GEAR_KEVLAR))
				return player.Armor >= TF2_GetMaxHealth(param1) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT;
			else if (StrEqual(info, INFO_GEAR_KEVLAR_HELMET))
				return player.HasHelmet ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT;
			
			return ITEMDRAW_DEFAULT;
		}
	}
	
	return 0;
}
