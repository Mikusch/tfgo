
public void ShowMainBuyMenu(int client)
{
	TFGOPlayer player = TFGOPlayer(client);
	if (!g_bBuyTimeActive || !player.InBuyZone)return;
	
	Menu menu = new Menu(HandleBuyMenuFront);
	menu.SetTitle("%T", "#buymenu_title", LANG_SERVER, player.Balance);
	
	switch (TF2_GetPlayerClass(client))
	{
		case TFClass_Engineer:
		{
			menu.AddItem("0", "#buymenu_item_primary");
			menu.AddItem("1", "#buymenu_item_secondary");
			menu.AddItem("3", "#buymenu_item_pda");
		}
		case TFClass_Spy:
		{
			menu.AddItem("0", "#buymenu_item_secondary");
			menu.AddItem("1", "#buymenu_item_building_spy");
			menu.AddItem("4", "#buymenu_item_pda2_spy");
		}
		default:
		{
			menu.AddItem("0", "#buymenu_item_primary");
			menu.AddItem("1", "#buymenu_item_secondary");
		}
	}
	
	menu.ExitButton = false;
	
	menu.Display(client, -1);
	player.ActiveBuymenu = menu;
}

public int HandleBuyMenuFront(Menu menu, MenuAction action, int param1, int pos)
{
	switch (action)
	{
		case MenuAction_Display:
		{
			char buffer[255];
			Format(buffer, sizeof(buffer), "%T", "Vote Nextmap", param1);
			
			Panel panel = view_as<Panel>(pos);
			panel.SetTitle(buffer);
			PrintToServer("Client %d was sent menu with panel %x", param1, pos);
		}
		
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(pos, info, sizeof(info));
			ShowBuyMenu(param1, StringToInt(info));
		}
		
		case MenuAction_DisplayItem:
		{
			char display[64];
			
			Format(display, sizeof(display), "%T");
			return RedrawMenuItem(display);
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
	TFGOPlayer player = TFGOPlayer(client);
	if (!g_bBuyTimeActive || !player.InBuyZone)return;
	
	Menu menu = new Menu(HandleBuyMenu);
	menu.SetTitle("%T", "#buymenu_title", LANG_SERVER, player.Balance);
	
	for (int i = 0; i < weaponList.Length; i++)
	{
		TFGOWeaponEntry weapon;
		weaponList.GetArray(i, weapon, sizeof(weapon));
		if (TF2Econ_GetItemSlot(weapon.index, TF2_GetPlayerClass(client)) == slot) // primary
		{
			char info[255];
			IntToString(weapon.index, info, sizeof(info));
			
			char display[255];
			char weaponName[255];
			TF2Econ_GetItemName(weapon.index, weaponName, sizeof(weaponName));
			Format(display, sizeof(display), "%s ($%d)", weaponName, weapon.cost);
			
			
			if (weapon.cost > player.Balance)
			{
				menu.AddItem(info, display, ITEMDRAW_DISABLED);
			}
			else
			{
				menu.AddItem(info, display);
			}
		}
	}
	
	menu.ExitButton = false;
	menu.ExitBackButton = true;
	
	player.ActiveBuymenu = menu;
	menu.Display(client, -1);
}

public int HandleBuyMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			TFGOPlayer(param1).PurchaseItem(StringToInt(info));
			ShowMainBuyMenu(param1);
		}
		
		case MenuAction_Cancel:
		{
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
}
