
// TODO: Proper use of translation files
public void ShowMainBuyMenu(int client)
{
	if (!g_bBuyTimeActive)return;
	TFGOPlayer player = TFGOPlayer(client);
	
	Menu menu = new Menu(HandleBuyMenuFront, MENU_ACTIONS_ALL);
	menu.SetTitle("%T", "#buymenu_title", LANG_SERVER, player.Balance);
	
	switch (TF2_GetPlayerClass(client))
	{
		case TFClass_Engineer:
		{
			menu.AddItem("0", "primary");
			menu.AddItem("1", "secondary");
			menu.AddItem("5", "pda");
		}
		case TFClass_Spy:
		{
			menu.AddItem("0", "Secondary");
			menu.AddItem("2", "Melee");
		}
		default:
		{
			menu.AddItem("0", "primary");
			menu.AddItem("1", "secondary");
		}
	}
	
	menu.ExitButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int HandleBuyMenuFront(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Display:
		{
			TFGOPlayer(param1).ActiveBuyMenu = menu;
		}
		
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			ShowBuyMenu(param1, StringToInt(info));
		}
		
		case MenuAction_Cancel:
		{
			TFGOPlayer(param1).ActiveBuyMenu = null;
		}
		
		case MenuAction_End:
		{
			delete menu;
		}
	}
	
	return 0;
}

public void ShowBuyMenu(int client, int slot)
{
	if (!g_bBuyTimeActive)return;
	TFGOPlayer player = TFGOPlayer(client);
	
	Menu menu = new Menu(HandleBuyMenu, MENU_ACTIONS_ALL);
	menu.SetTitle("%T", "#buymenu_title", LANG_SERVER, player.Balance);
	
	for (int i = 0; i < weaponList.Length; i++)
	{
		TFGOWeaponEntry weapon;
		weaponList.GetArray(i, weapon, sizeof(weapon));
		if (TF2Econ_GetItemSlot(weapon.index, TF2_GetPlayerClass(client)) == slot)
		{
			char info[255];
			IntToString(weapon.index, info, sizeof(info));
			
			char display[255];
			char weaponName[255];
			TF2Econ_GetItemName(weapon.index, weaponName, sizeof(weaponName));
			Format(display, sizeof(display), "%s ($%d)", weaponName, weapon.cost);
			
			menu.AddItem(info, display);
		}
	}
	
	menu.ExitButton = false;
	menu.ExitBackButton = true;
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public int HandleBuyMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Display:
		{
			TFGOPlayer(param1).ActiveBuyMenu = menu;
		}
		
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			TFGOPlayer(param1).PurchaseItem(StringToInt(info));
			ShowMainBuyMenu(param1);
		}
		
		case MenuAction_DrawItem:
		{
			TFGOPlayer player = TFGOPlayer(param1);
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			if (TFGOWeapon(StringToInt(info)).Cost > player.Balance)
			{
				return ITEMDRAW_DISABLED;
			}
			else
			{
				return ITEMDRAW_DEFAULT;
			}
		}
		
		case MenuAction_Cancel:
		{
			TFGOPlayer(param1).ActiveBuyMenu = null;
			if (param2 == MenuCancel_ExitBack)
			{
				ShowMainBuyMenu(param1);
			}
		}
		
		case MenuAction_End:
		{
			delete menu;
		}
	}
	
	return 0;
}
