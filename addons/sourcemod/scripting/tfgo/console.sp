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

void Console_Init()
{
	AddCommandListener(CommandListener_Build, "build");
	AddCommandListener(CommandListener_Destroy, "destroy");
	
	RegConsoleCmd("buymenu", ConCmd_OpenBuyMenu, "Opens the buy menu");
}

public Action CommandListener_Build(int client, const char[] command, int args)
{
	// Check if player owns Construction PDA
	if (TFGOPlayer(client).GetWeaponFromLoadout(TFClass_Engineer, WeaponSlot_PDABuild) != -1)
		return Plugin_Continue;
	
	// Block build by default
	return Plugin_Handled;
}

public Action CommandListener_Destroy(int client, const char[] command, int args)
{
	// Check if player owns Destruction PDA
	if (TFGOPlayer(client).GetWeaponFromLoadout(TFClass_Engineer, WeaponSlot_PDADestroy) != -1)
		return Plugin_Continue;
	
	// Block destroy by default
	return Plugin_Handled;
}

public Action ConCmd_OpenBuyMenu(int client, int args)
{
	if (client == 0)
	{
		ReplyToCommand(client, "%t", "Command is in-game only");
		return Plugin_Handled;
	}
	
	if (!IsPlayerAlive(client))
	{
		PrintHintText(client, "%t", "BuyMenu_CantBuy");
		return Plugin_Handled;
	}
	
	if (TFGOPlayer(client).InBuyZone)
	{
		if (g_IsBuyTimeActive)
		{
			BuyMenu_DisplayMainBuyMenu(client);
		}
		else
		{
			PrintHintText(client, "%t", "BuyMenu_OutOfTime", tfgo_buytime.IntValue);
		}
	}
	else
	{
		PrintHintText(client, "%t", "BuyMenu_NotInBuyZone");
	}
	
	return Plugin_Handled;
}
