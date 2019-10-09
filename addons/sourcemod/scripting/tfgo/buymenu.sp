
public void ShowBuyMenu(int client, int slot)
{
	Menu menu = new Menu(MenuHandler1);
	TFGOPlayer player = TFGOPlayer(client);
	
	menu.SetTitle("Welcome to the buy menu!\nYou currently have $%d.",player.Balance);
	
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
	menu.Display(client, tfgo_buytime.IntValue);
	
}

public int MenuHandler1(Menu menu, MenuAction action, int param1, int param2)
{
	/* If an option was selected, tell the client about the item. */
	if (action == MenuAction_Select)
	{
		char info[32];
		bool found = menu.GetItem(param2, info, sizeof(info));
		PrintToConsole(param1, "You selected item: %d (found? %d info: %s)", param2, found, info);
	}
	/* If the menu was cancelled, print a message to the server about it. */
	else if (action == MenuAction_Cancel)
	{
		PrintToServer("Client %d's menu was cancelled.  Reason: %d", param1, param2);
	}
	/* If the menu has ended, destroy it */
	else if (action == MenuAction_End)
	{
		delete menu;
	}
} 