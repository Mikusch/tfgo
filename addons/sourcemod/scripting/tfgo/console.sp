void Console_Init()
{
	AddCommandListener(CommandListener_Build, "build");
	AddCommandListener(CommandListener_Destroy, "destroy");
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
