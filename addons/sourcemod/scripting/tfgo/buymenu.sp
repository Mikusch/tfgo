#define INFO_GEAR "GEAR"
#define INFO_GEAR_KEVLAR "0"
#define INFO_GEAR_KEVLAR_HELMET "1"

public bool DisplayMainBuyMenu(int client)
{
	Menu menu = new Menu(MenuHandler_MainBuyMenu, MenuAction_Display | MenuAction_Select | MenuAction_Cancel | MenuAction_End | MenuAction_DisplayItem);
	menu.SetTitle("%T", "BuyMenu_Title", LANG_SERVER);
	menu.ExitButton = true;
	
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
			menu.AddItem("1", "BuyMenu_Buildings", ITEMDRAW_IGNORE); // Sapper (currently ignored due to client crashes)
		}
		
		default:
		{
			menu.AddItem("0", "BuyMenu_Primaries");
			menu.AddItem("1", "BuyMenu_Secondaries");
			menu.AddItem("2", "BuyMenu_Melees");
		}
	}
	
	menu.AddItem(INFO_GEAR, "BuyMenu_Gear");
	
	return menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_MainBuyMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Display: TFGOPlayer(param1).ActiveBuyMenu = menu;
		
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
				// Convert slot CSV to ArrayList
				char slots[TFWeaponSlot_Building + 1][32];
				if (ExplodeString(info, ";", slots, sizeof(slots), sizeof(slots[])) > 0)
				{
					ArrayList slotList = new ArrayList();
					for (int i = 0; i < sizeof(slots); i++)
					{
						TrimString(slots[i]);
						if (strlen(slots[i]) > 0) slotList.Push(StringToInt(slots[i]));
					}
					
					DisplayWeaponBuyMenu(param1, slotList);
				}
			}
		}
		
		case MenuAction_Cancel: TFGOPlayer(param1).ActiveBuyMenu = null;
		
		case MenuAction_End: delete menu;
		
		case MenuAction_DisplayItem:
		{
			char info[32];
			char display[PLATFORM_MAX_PATH];
			menu.GetItem(param2, info, sizeof(info), _, display, sizeof(display));
			Format(display, sizeof(display), "%T", display, LANG_SERVER);
			return RedrawMenuItem(display);
		}
	}
	
	return 0;
}

public bool DisplayWeaponBuyMenu(int client, ArrayList slots)
{
	Menu menu = new Menu(MenuHandler_WeaponBuyMenu, MenuAction_Display | MenuAction_Select | MenuAction_Cancel | MenuAction_End | MenuAction_DrawItem | MenuAction_DisplayItem);
	menu.SetTitle("%T", "BuyMenu_Title", LANG_SERVER);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	
	for (int i = 0; i < g_AvailableWeapons.Length; i++)
	{
		Weapon weapon;
		g_AvailableWeapons.GetArray(i, weapon, sizeof(weapon));
		
		TFClassType class = TF2_GetPlayerClass(client);
		int slot = TF2_GetSlotInItem(weapon.defindex, class);
		
		if (slots.FindValue(slot) > -1 && weapon.cost > -1)
		{
			char info[32];
			IntToString(weapon.defindex, info, sizeof(info));
			
			char itemName[PLATFORM_MAX_PATH];
			TF2_GetItemName(weapon.defindex, itemName, sizeof(itemName));
			
			menu.AddItem(info, itemName);
		}
	}
	delete slots;
	
	return menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_WeaponBuyMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Display: TFGOPlayer(param1).ActiveBuyMenu = menu;
		
		case MenuAction_Select:
		{
			char info[32]; // item defindex
			menu.GetItem(param2, info, sizeof(info));
			TFGOPlayer(param1).PurchaseItem(StringToInt(info));
			DisplayMainBuyMenu(param1);
		}
		
		case MenuAction_Cancel:
		{
			TFGOPlayer(param1).ActiveBuyMenu = null;
			if (param2 == MenuCancel_ExitBack)
				DisplayMainBuyMenu(param1);
		}
		
		case MenuAction_End: delete menu;
		
		case MenuAction_DrawItem:
		{
			int style;
			char info[32]; // item defindex
			menu.GetItem(param2, info, sizeof(info), style);
			
			Weapon weapon;
			g_AvailableWeapons.GetArray(g_AvailableWeapons.FindValue(StringToInt(info), 0), weapon, sizeof(weapon));
			
			TFGOPlayer player = TFGOPlayer(param1);
			TFClassType class = TF2_GetPlayerClass(param1);
			int slot = TF2_GetSlotInItem(weapon.defindex, class);
			
			return player.GetWeaponFromLoadout(class, slot) == weapon.defindex || weapon.cost > player.Balance ? ITEMDRAW_DISABLED : style;
		}
		
		case MenuAction_DisplayItem:
		{
			char info[32]; // item defindex
			char display[PLATFORM_MAX_PATH]; // item name
			menu.GetItem(param2, info, sizeof(info), _, display, sizeof(display));
			
			Weapon weapon;
			g_AvailableWeapons.GetArray(g_AvailableWeapons.FindValue(StringToInt(info), 0), weapon, sizeof(weapon));
			
			TFClassType class = TF2_GetPlayerClass(param1);
			int slot = TF2_GetSlotInItem(weapon.defindex, class);
			
			TFGOPlayer player = TFGOPlayer(param1);
			if (player.GetWeaponFromLoadout(class, slot) == weapon.defindex)
				Format(display, sizeof(display), "%s (%T)", display, "BuyMenu_AlreadyCarrying", LANG_SERVER);
			else
				Format(display, sizeof(display), "%s ($%d)", display, weapon.cost);
			
			return RedrawMenuItem(display);
		}
	}
	
	return 0;
}

public int DisplayGearMenu(int client)
{
	Menu menu = new Menu(HandleGearMenu, MenuAction_Display | MenuAction_Select | MenuAction_Cancel | MenuAction_End | MenuAction_DrawItem | MenuAction_DisplayItem);
	menu.SetTitle("%T", "BuyMenu_Title", LANG_SERVER, TFGOPlayer(client).Balance);
	
	menu.AddItem(INFO_GEAR_KEVLAR, INFO_GEAR_KEVLAR_HELMET);
	menu.AddItem(INFO_GEAR_KEVLAR_HELMET, INFO_GEAR_KEVLAR_HELMET);
	
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
			
			DisplayMainBuyMenu(param1);
		}
		
		case MenuAction_Cancel:
		{
			TFGOPlayer(param1).ActiveBuyMenu = null;
			if (param2 == MenuCancel_ExitBack)
				DisplayMainBuyMenu(param1);
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
		
		case MenuAction_DisplayItem:
		{
			char info[32];
			char display[PLATFORM_MAX_PATH];
			menu.GetItem(param2, info, sizeof(info), _, display, sizeof(display));
			
			Gear gear;
			g_AvailableGear.GetArray(g_AvailableGear.FindValue(StringToInt(info), 0), gear, sizeof(gear));
			
			Format(display, sizeof(display), "%T", gear.localizedName, LANG_SERVER);
			return RedrawMenuItem(display);
		}
	}
	
	return 0;
}
