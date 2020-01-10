#define INFO_EQUIPMENT "EQUIPMENT"
#define INFO_EQUIPMENT_KEVLAR "0"
#define INFO_EQUIPMENT_ASSAULTSUIT "1"

public bool DisplayMainBuyMenu(int client)
{
	Menu menu = new Menu(MenuHandler_MainBuyMenu, MenuAction_Display | MenuAction_Select | MenuAction_Cancel | MenuAction_End | MenuAction_DisplayItem);
	menu.SetTitle("%T\n%T", "BuyMenu_Title", LANG_SERVER, "BuyMenu_SubTitle_Slot", LANG_SERVER);
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
	
	menu.AddItem(INFO_EQUIPMENT, "BuyMenu_Equipment");
	
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
			
			if (StrEqual(info, INFO_EQUIPMENT))
			{
				DisplayEquipmentBuyMenu(param1);
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
						if (strlen(slots[i]) > 0)
							slotList.Push(StringToInt(slots[i]));
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
	menu.SetTitle("%T\n%T", "BuyMenu_Title", LANG_SERVER, "BuyMenu_SubTitle_Weapon", LANG_SERVER);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	
	for (int i = 0; i < g_AvailableWeapons.Length; i++)
	{
		WeaponConfig config;
		g_AvailableWeapons.GetArray(i, config, sizeof(config));
		
		TFClassType class = TF2_GetPlayerClass(client);
		int slot = TF2_GetSlotInItem(config.defIndex, class);
		
		if (slots.FindValue(slot) > -1 && config.price > -1)
		{
			char info[32];
			IntToString(config.defIndex, info, sizeof(info));
			
			char itemName[PLATFORM_MAX_PATH];
			TF2_GetItemName(config.defIndex, itemName, sizeof(itemName));
			
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
			char info[32]; // item def index
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
			char info[32]; // item def index
			menu.GetItem(param2, info, sizeof(info), style);
			
			WeaponConfig config;
			g_AvailableWeapons.GetArray(g_AvailableWeapons.FindValue(StringToInt(info), 0), config, sizeof(config));
			
			TFGOPlayer player = TFGOPlayer(param1);
			TFClassType class = TF2_GetPlayerClass(param1);
			int slot = TF2_GetSlotInItem(config.defIndex, class);
			
			return player.GetWeaponFromLoadout(class, slot) == config.defIndex || config.price > player.Account ? ITEMDRAW_DISABLED : style;
		}
		
		case MenuAction_DisplayItem:
		{
			char info[32]; // item def index
			char display[PLATFORM_MAX_PATH]; // item name
			menu.GetItem(param2, info, sizeof(info), _, display, sizeof(display));
			
			WeaponConfig config;
			g_AvailableWeapons.GetArray(g_AvailableWeapons.FindValue(StringToInt(info), 0), config, sizeof(config));
			
			TFClassType class = TF2_GetPlayerClass(param1);
			int slot = TF2_GetSlotInItem(config.defIndex, class);
			
			TFGOPlayer player = TFGOPlayer(param1);
			if (player.GetWeaponFromLoadout(class, slot) == config.defIndex)
				Format(display, sizeof(display), "%s (%T)", display, "BuyMenu_AlreadyCarrying", LANG_SERVER);
			else
				Format(display, sizeof(display), "%s ($%d)", display, config.price);
			
			return RedrawMenuItem(display);
		}
	}
	
	return 0;
}

public int DisplayEquipmentBuyMenu(int client)
{
	Menu menu = new Menu(MenuHandler_EquipmentBuyMenu, MenuAction_Display | MenuAction_Select | MenuAction_Cancel | MenuAction_End | MenuAction_DrawItem | MenuAction_DisplayItem);
	menu.SetTitle("%T\n%T", "BuyMenu_Title", LANG_SERVER, "BuyMenu_SubTitle_Equipment", LANG_SERVER);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	
	menu.AddItem(INFO_EQUIPMENT_KEVLAR, "BuyMenu_Equipment_Kevlar");
	menu.AddItem(INFO_EQUIPMENT_ASSAULTSUIT, "BuyMenu_Equipment_Kevlar_Helmet");
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_EquipmentBuyMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Display: TFGOPlayer(param1).ActiveBuyMenu = menu;
		
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			
			TFGOPlayer player = TFGOPlayer(param1);
			if (StrEqual(info, INFO_EQUIPMENT_KEVLAR))
				player.AttemptToBuyVest();
			else if (StrEqual(info, INFO_EQUIPMENT_ASSAULTSUIT))
				player.AttemptToBuyAssaultSuit();
			
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
		
		case MenuAction_End: delete menu;
		
		case MenuAction_DrawItem:
		{
			int style;
			char info[32];
			menu.GetItem(param2, info, sizeof(info), style);
			
			TFGOPlayer player = TFGOPlayer(param1);
			
			if (StrEqual(info, INFO_EQUIPMENT_KEVLAR))
			{
				if (player.HasFullArmor() || tfgo_max_armor.IntValue < 1 || player.Account < EQUIPMENT_KEVLAR_PRICE)
					return ITEMDRAW_DISABLED;
			}
			else if (StrEqual(info, INFO_EQUIPMENT_ASSAULTSUIT))
			{
				if (player.HasHelmet || tfgo_max_armor.IntValue < 2)
					return ITEMDRAW_DISABLED;
				else if (player.HasFullArmor() && player.Account < EQUIPMENT_HELMET_PRICE)
					return ITEMDRAW_DISABLED;
				else if (!player.HasFullArmor() && player.Account < EQUIPMENT_ASSAULTSUIT_PRICE)
					return ITEMDRAW_DISABLED;
			}
			
			return style;
		}
		
		case MenuAction_DisplayItem:
		{
			char info[32];
			char display[PLATFORM_MAX_PATH];
			menu.GetItem(param2, info, sizeof(info), _, display, sizeof(display));
			
			TFGOPlayer player = TFGOPlayer(param1);
			if (StrEqual(info, INFO_EQUIPMENT_KEVLAR) && !player.HasFullArmor())
				Format(display, sizeof(display), "%T ($%d)", display, LANG_SERVER, EQUIPMENT_KEVLAR_PRICE);
			else if (StrEqual(info, INFO_EQUIPMENT_ASSAULTSUIT) && !player.HasHelmet)
				Format(display, sizeof(display), "%T ($%d)", display, LANG_SERVER, player.HasFullArmor() ? EQUIPMENT_HELMET_PRICE : EQUIPMENT_ASSAULTSUIT_PRICE);
			else
				Format(display, sizeof(display), "%T (%T)", display, LANG_SERVER, "BuyMenu_AlreadyCarrying", LANG_SERVER);
			
			return RedrawMenuItem(display);
		}
	}
	
	return 0;
}
