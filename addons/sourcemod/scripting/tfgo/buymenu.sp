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

#define INFO_EQUIPMENT "EQUIPMENT"
#define INFO_KEVLAR "KEVLAR"
#define INFO_ASSAULTSUIT "ASSAULTSUIT"
#define INFO_DEFUSEKIT "DEFUSEKIT"

bool BuyMenu_DisplayMainBuyMenu(int client)
{
	Menu menu = new Menu(MenuHandler_MainBuyMenu, MenuAction_Display | MenuAction_Select | MenuAction_Cancel | MenuAction_End | MenuAction_DisplayItem);
	menu.SetTitle("%T\n%T", "BuyMenu_Title", client, "BuyMenu_SelectSlot", client);
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
			menu.AddItem("1;3;4", "BuyMenu_PDAs"); // Sapper/Disguise Kit/Invis Watch
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

bool BuyMenu_DisplayWeaponBuyMenu(int client, ArrayList slots)
{
	Menu menu = new Menu(MenuHandler_WeaponBuyMenu, MenuAction_Display | MenuAction_Select | MenuAction_Cancel | MenuAction_End | MenuAction_DrawItem | MenuAction_DisplayItem);
	menu.SetTitle("%T\n%T", "BuyMenu_Title", client, "BuyMenu_SelectWeapon", client);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	
	for (int i = 0; i < g_AvailableWeapons.Length; i++)
	{
		TFGOWeapon weapon;
		g_AvailableWeapons.GetArray(i, weapon, sizeof(weapon));
		
		TFClassType class = TF2_GetPlayerClass(client);
		int slot = TF2_GetItemWeaponSlot(weapon.defindex, class);
		
		if (slots.FindValue(slot) != -1 && weapon.price != 0)
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

bool BuyMenu_DisplayEquipmentBuyMenu(int client)
{
	Menu menu = new Menu(MenuHandler_EquipmentBuyMenu, MenuAction_Display | MenuAction_Select | MenuAction_Cancel | MenuAction_End | MenuAction_DrawItem | MenuAction_DisplayItem);
	menu.SetTitle("%T\n%T", "BuyMenu_Title", client, "BuyMenu_SelectEquipment", client);
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	
	menu.AddItem(INFO_KEVLAR, "Kevlar");
	menu.AddItem(INFO_ASSAULTSUIT, "AssaultSuit");
	menu.AddItem(INFO_DEFUSEKIT, "DefuseKit");
	
	return menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_MainBuyMenu(Menu menu, MenuAction action, int param1, int param2)
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
			
			if (StrEqual(info, INFO_EQUIPMENT))
			{
				BuyMenu_DisplayEquipmentBuyMenu(param1);
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
					
					BuyMenu_DisplayWeaponBuyMenu(param1, slotList);
				}
			}
		}
		
		case MenuAction_Cancel:
		{
			TFGOPlayer(param1).ActiveBuyMenu = null;
		}
		
		case MenuAction_End:
		{
			delete menu;
		}
		
		case MenuAction_DisplayItem:
		{
			char info[32];
			char display[PLATFORM_MAX_PATH];
			menu.GetItem(param2, info, sizeof(info), _, display, sizeof(display));
			Format(display, sizeof(display), "%T", display, param1);
			return RedrawMenuItem(display);
		}
	}
	
	return 0;
}

public int MenuHandler_WeaponBuyMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Display:
		{
			TFGOPlayer(param1).ActiveBuyMenu = menu;
		}
		
		case MenuAction_Select:
		{
			char info[32]; // item def index
			menu.GetItem(param2, info, sizeof(info));
			int defindex = StringToInt(info);
			
			if (TFGOPlayer(param1).AttemptToBuyWeapon(defindex) == BUY_BOUGHT)
			{
				EmitGameSoundToAll(GAMESOUND_PLAYER_PURCHASE, param1);
				BuyMenu_DisplayMainBuyMenu(param1);
				Forward_OnClientPurchaseWeapon(param1, defindex);
			}
		}
		
		case MenuAction_Cancel:
		{
			TFGOPlayer(param1).ActiveBuyMenu = null;
			if (param2 == MenuCancel_ExitBack)
				BuyMenu_DisplayMainBuyMenu(param1);
		}
		
		case MenuAction_End:
		{
			delete menu;
		}
		
		case MenuAction_DrawItem:
		{
			int style;
			char info[32]; // item def index
			menu.GetItem(param2, info, sizeof(info), style);
			
			TFGOWeapon weapon;
			if (g_AvailableWeapons.GetByDefIndex(StringToInt(info), weapon) > 0)
			{
				TFGOPlayer player = TFGOPlayer(param1);
				TFClassType class = TF2_GetPlayerClass(param1);
				int slot = TF2_GetItemWeaponSlot(weapon.defindex, class);
				
				if (player.GetWeaponFromLoadout(class, slot) == weapon.defindex || weapon.price > player.Account)
					return ITEMDRAW_DISABLED;
			}
			
			return style;
		}
		
		case MenuAction_DisplayItem:
		{
			char info[32]; // item def index
			char display[PLATFORM_MAX_PATH]; // item name
			menu.GetItem(param2, info, sizeof(info), _, display, sizeof(display));
			
			TFGOWeapon weapon;
			if (g_AvailableWeapons.GetByDefIndex(StringToInt(info), weapon) > 0)
			{
				TFGOPlayer player = TFGOPlayer(param1);
				TFClassType class = TF2_GetPlayerClass(param1);
				int slot = TF2_GetItemWeaponSlot(weapon.defindex, class);
				
				SetGlobalTransTarget(param1);
				
				if (player.GetWeaponFromLoadout(class, slot) == weapon.defindex)
					Format(display, sizeof(display), "%s (%t)", display, "BuyMenu_AlreadyCarrying");
				else
					Format(display, sizeof(display), "%s ($%d)", display, weapon.price);
				
				return RedrawMenuItem(display);
			}
			
			return 0;
		}
	}
	
	return 0;
}

public int MenuHandler_EquipmentBuyMenu(Menu menu, MenuAction action, int param1, int param2)
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
			
			TFGOPlayer player = TFGOPlayer(param1);
			
			BuyResult result;
			if (StrEqual(info, INFO_KEVLAR))
				result = player.AttemptToBuyVest();
			else if (StrEqual(info, INFO_ASSAULTSUIT))
				result = player.AttemptToBuyAssaultSuit();
			else if (StrEqual(info, INFO_DEFUSEKIT))
				result = player.AttemptToBuyDefuseKit();
			
			if (result == BUY_BOUGHT)
			{
				EmitGameSoundToAll(GAMESOUND_PLAYER_PURCHASE, param1);
				BuyMenu_DisplayMainBuyMenu(param1);
			}
		}
		
		case MenuAction_Cancel:
		{
			TFGOPlayer(param1).ActiveBuyMenu = null;
			if (param2 == MenuCancel_ExitBack)
				BuyMenu_DisplayMainBuyMenu(param1);
		}
		
		case MenuAction_End:
		{
			delete menu;
		}
		
		case MenuAction_DrawItem:
		{
			int style;
			char info[32];
			menu.GetItem(param2, info, sizeof(info), style);
			
			TFGOPlayer player = TFGOPlayer(param1);
			bool fullArmor = player.ArmorValue >= TF2_GetMaxHealth(param1);
			
			if (StrEqual(info, INFO_KEVLAR))
			{
				if (tfgo_max_armor.IntValue < 1 || fullArmor || player.Account < KEVLAR_PRICE)
					return ITEMDRAW_DISABLED;
			}
			else if (StrEqual(info, INFO_ASSAULTSUIT))
			{
				if (tfgo_max_armor.IntValue < 2 || player.HasHelmet || fullArmor && player.Account < HELMET_PRICE || !fullArmor && player.Account < ASSAULTSUIT_PRICE)
					return ITEMDRAW_DISABLED;
			}
			else if (StrEqual(info, INFO_DEFUSEKIT))
			{
				if (!TFGOTeam(TF2_GetClientTeam(param1)).IsDefending)
					return ITEMDRAW_IGNORE;
				else if (player.HasDefuseKit || player.Account < DEFUSEKIT_PRICE)
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
			bool fullArmor = player.ArmorValue >= TF2_GetMaxHealth(param1);
			
			SetGlobalTransTarget(param1);
			
			if (StrEqual(info, INFO_KEVLAR))
			{
				if (fullArmor)
					Format(display, sizeof(display), "%t (%t)", display, "BuyMenu_AlreadyCarrying");
				else
					Format(display, sizeof(display), "%t ($%d)", display, KEVLAR_PRICE);
			}
			else if (StrEqual(info, INFO_ASSAULTSUIT))
			{
				if (player.HasHelmet)
					Format(display, sizeof(display), "%t (%t)", display, "BuyMenu_AlreadyCarrying");
				else if (fullArmor)
					Format(display, sizeof(display), "%t ($%d)", display, HELMET_PRICE);
				else
					Format(display, sizeof(display), "%t ($%d)", display, ASSAULTSUIT_PRICE);
			}
			else if (StrEqual(info, INFO_DEFUSEKIT))
			{
				if (player.HasDefuseKit)
					Format(display, sizeof(display), "%t (%t)", display, "BuyMenu_AlreadyCarrying");
				else
					Format(display, sizeof(display), "%t ($%d)", display, DEFUSEKIT_PRICE);
			}
			
			return RedrawMenuItem(display);
		}
	}
	
	return 0;
}
