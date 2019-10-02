#define TF_MAXPLAYERS 32

stock int g_iBalance[TF_MAXPLAYERS + 1];
stock Handle g_hCurrencyPackDestroyTimer;
stock StringMap g_sCurrencypackPlayerMap;

Handle g_hHudSync;

stock void CreateDeathCash(int iClient) {
	int iCurrencyPack = EntIndexToEntRef(CreateEntityByName("item_currencypack_medium"));
	if (DispatchSpawn(iCurrencyPack))
	{
		char key[32];
		IntToString(iCurrencyPack, key, sizeof(key));
		g_sCurrencypackPlayerMap.SetValue(key, iClient);
		SDKHook(iCurrencyPack, SDKHook_Touch, Cash_OnTouch);
		SDKHook(iCurrencyPack, SDKHook_SpawnPost, Cash_OnSpawnPost);
		float origin[3];
		GetClientAbsOrigin(iClient, origin);
		TeleportEntity(iCurrencyPack, origin, NULL_VECTOR, NULL_VECTOR);
		CreateTimer(30.0, Destroy_Currency_Pack, iCurrencyPack);
	}
}

stock Action Destroy_Currency_Pack(Handle timer, int entity)
{
	if (IsValidEntity(entity)) {
		float vec[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vec);
		EmitAmbientSound("mvm/mvm_money_vanish.wav", vec, entity);
		RemoveEntity(entity);
	}
}

public void Cash_OnSpawnPost(int entity)
{
	// After the 2015 Halloween update, currency packs will not spawn if there's no nav mesh. This allows Cash to spawn on maps without a nav mesh!
	SetEntProp(entity, Prop_Send, "m_bDistributed", true);
}

stock Action Cash_OnTouch(int entity, int iClient)
{
	char key[32];
	IntToString(EntIndexToEntRef(entity), key, sizeof(key));
	int iCashOwner;
	g_sCurrencypackPlayerMap.GetValue(key, iCashOwner);
	
	
	if (TF2_GetClientTeam(iCashOwner) == TF2_GetClientTeam(iClient))
	{
		// disallow picking up your own team's cash
		return Plugin_Handled;
	}
	
	g_iBalance[iClient] += 100;
	
	SetHudTextParams(-1.0, 0.75, 10.0, 0, 133, 67, 140); // 60.0 how long text should stay since last cash update
	ShowSyncHudText(iClient, g_hHudSync, "$%d", g_iBalance[iClient]);
	
	switch (TF2_GetPlayerClass(iClient))
	{
		case TFClass_Soldier:
		{
			int iRandom = GetRandomInt(0, sizeof(g_SoldierMvmCollectCredits) - 1);
			EmitSoundToAll(g_SoldierMvmCollectCredits[iRandom], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
		}
		case TFClass_Engineer:
		{
			int iRandom = GetRandomInt(0, sizeof(g_EngineerMvmCollectCredits) - 1);
			EmitSoundToAll(g_EngineerMvmCollectCredits[iRandom], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
		}
		case TFClass_Heavy:
		{
			int iRandom = GetRandomInt(0, sizeof(g_HeavyMvmCollectCredits) - 1);
			EmitSoundToAll(g_HeavyMvmCollectCredits[iRandom], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
		}
		case TFClass_Medic:
		{
			int iRandom = GetRandomInt(0, sizeof(g_MedicMvmCollectCredits) - 1);
			EmitSoundToAll(g_MedicMvmCollectCredits[iRandom], iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
		}
	}
	
	RemoveEntity(entity); // fix for money teleporting to world spawn after pickup
	
	PrintToChat(client, "You have picked up $%d and now have $%d!", 100, g_balance[client]);
	return Plugin_Continue;
}
