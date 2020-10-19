void Console_Init()
{
	AddCommandListener(CommandListener_Build, "build");
	AddCommandListener(CommandListener_Destroy, "destroy");
	
	RegConsoleCmd("buymenu", ConCmd_OpenBuyMenu, "Opens the buy menu");
}

Action CommandListener_Build(int client, const char[] command, int args)
{
	// Check if player owns Construction PDA
	if (TFGOPlayer(client).GetWeaponFromLoadout(TFClass_Engineer, WeaponSlot_PDABuild) != -1)
		return Plugin_Continue;
	
	// Block build by default
	return Plugin_Handled;
}

Action CommandListener_Destroy(int client, const char[] command, int args)
{
	// Check if player owns Destruction PDA
	if (TFGOPlayer(client).GetWeaponFromLoadout(TFClass_Engineer, WeaponSlot_PDADestroy) != -1)
		return Plugin_Continue;
	
	// Block destroy by default
	return Plugin_Handled;
}

Action ConCmd_OpenBuyMenu(int client, int args)
{
	if (client == 0)
	{
		PrintHintText(client, "Command is in-game only");
		return Plugin_Handled;
	}
	
	if (!IsPlayerAlive(client))
	{
		PrintHintText(client, "BuyMenu_CantBuy");
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
