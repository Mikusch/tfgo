
// TODO: Proper use of translation files
public void ShowMainBuyMenu(int client)
{
	Menu menu = new Menu(HandleBuyMenuFront, MENU_ACTIONS_ALL);
	menu.SetTitle("%T", "#buymenu_title", LANG_SERVER, TFGOPlayer(client).Balance);
	
	// Reminder: These are TF2Econ slots
	switch (TF2_GetPlayerClass(client))
	{
		case TFClass_Engineer:
		{
			menu.AddItem("0", "Primary Weapon");
			menu.AddItem("1", "Secondary Weapon");
			menu.AddItem("2", "Melee Weapon");
			menu.AddItem("5;6", "PDA");
		}
		
		case TFClass_Spy:
		{
			menu.AddItem("1", "Secondary Weapon"); // Revolvers
			menu.AddItem("2", "Melee Weapon"); // Revolvers
			menu.AddItem("3;6", "PDA"); // Disguise Kit/Invis Watch
			menu.AddItem("4", "Sapper");
		}
		
		default:
		{
			menu.AddItem("0", "Primary Weapon");
			menu.AddItem("1", "Secondary Weapon");
			menu.AddItem("2", "Melee Weapon");
		}
	}
	
	menu.ExitButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int HandleBuyMenuFront(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Display:TFGOPlayer(param1).ActiveBuyMenu = menu;
		
		case MenuAction_Select:
		{
			char info[8];
			menu.GetItem(param2, info, sizeof(info));
			
			char slotStrings[TFWeaponSlot_Building + 1][8];
			if (ExplodeString(info, ";", slotStrings, sizeof(slotStrings), sizeof(slotStrings[])) >= 1)
			{
				ArrayList slots = new ArrayList();
				for (int i = 0; i < sizeof(slotStrings); i++)
				{
					if (strlen(slotStrings[i]) > 0)
						slots.Push(StringToInt(slotStrings[i]));
				}
				ShowBuyMenu(param1, slots);
			}
		}
		
		case MenuAction_Cancel:TFGOPlayer(param1).ActiveBuyMenu = null;
		
		case MenuAction_End:delete menu;
	}
	
	return 0;
}

public void ShowBuyMenu(int client, ArrayList slots)
{
	Menu menu = new Menu(HandleBuyMenu, MENU_ACTIONS_ALL);
	menu.SetTitle("%T", "#buymenu_title", LANG_SERVER, TFGOPlayer(client).Balance);
	
	for (int i = 0; i < g_availableWeapons.Length; i++)
	{
		Weapon weapon;
		g_availableWeapons.GetArray(i, weapon, sizeof(weapon));
		
		if (slots.FindValue(TF2Econ_GetItemSlot(weapon.defindex, TF2_GetPlayerClass(client))) > -1)
		{
			char info[8];
			IntToString(weapon.defindex, info, sizeof(info));
			
			char display[255];
			char weaponName[255];
			TF2_GetItemName(weapon.defindex, weaponName, sizeof(weaponName));
			Format(display, sizeof(display), "%s ($%d)", weaponName, weapon.cost);
			
			menu.AddItem(info, display);
		}
	}
	delete slots;
	
	menu.ExitButton = false;
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
			ShowMainBuyMenu(param1);
		}
		
		case MenuAction_DrawItem:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			
			Weapon weapon;
			g_availableWeapons.GetArray(g_availableWeapons.FindValue(StringToInt(info), 0), weapon, sizeof(weapon));
			
			if (weapon.cost > TFGOPlayer(param1).Balance)
				return ITEMDRAW_DISABLED;
			else
				return ITEMDRAW_DEFAULT;
		}
		
		case MenuAction_Cancel:
		{
			TFGOPlayer(param1).ActiveBuyMenu = null;
			if (param2 == MenuCancel_ExitBack)
				ShowMainBuyMenu(param1);
		}
		
		case MenuAction_End:delete menu;
	}
	
	return 0;
}
