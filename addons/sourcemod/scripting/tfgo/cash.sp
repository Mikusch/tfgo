#define CASH_EXPIRE_TIME 30.0

StringMap g_sCurrencypackPlayerMap;
StringMap g_sCurrencypackValueMap;
StringMap g_iCashToKillerMap;


methodmap Cash
{
	public Cash(int entity)
	{
		return view_as<Cash>(EntIndexToEntRef(entity));
	}
	
	property int Value
	{
		public get()
		{
			char key[32];
			IntToString(view_as<int>(this), key, sizeof(key));
			int owner;
			g_sCurrencypackValueMap.GetValue(key, owner);
			return owner;
		}
		public set(int value)
		{
			char key[32];
			IntToString(view_as<int>(this), key, sizeof(key));
			g_sCurrencypackValueMap.SetValue(key, value);
		}
	}
	
	property int Owner
	{
		public get()
		{
			char key[32];
			IntToString(view_as<int>(this), key, sizeof(key));
			int owner;
			g_iCashToKillerMap.GetValue(key, owner);
			return owner;
		}
		public set(int owner)
		{
			char key[32];
			IntToString(view_as<int>(this), key, sizeof(key));
			g_iCashToKillerMap.SetValue(key, owner);
		}
	}
	
	property int Victim
	{
		public get()
		{
			char key[32];
			IntToString(view_as<int>(this), key, sizeof(key));
			int victim;
			g_sCurrencypackPlayerMap.GetValue(key, victim);
			return victim;
		}
		public set(int attacker)
		{
			char key[32];
			IntToString(view_as<int>(this), key, sizeof(key));
			g_sCurrencypackPlayerMap.SetValue(key, attacker);
		}
	}
}

stock void SpawnCash(int attacker, int victim, int value, bool auto_collect = false) {
	int iCurrencyPack = CreateEntityByName("item_currencypack_medium");
	if (DispatchSpawn(iCurrencyPack))
	{
		Cash cash = Cash(iCurrencyPack);
		cash.Owner = attacker;
		cash.Victim = victim;
		cash.Value = value;
		
		SDKHook(iCurrencyPack, SDKHook_Touch, Cash_OnTouch);
		SDKHook(iCurrencyPack, SDKHook_SpawnPost, Cash_OnSpawnPost);
		
		float origin[3];
		GetClientAbsOrigin(victim, origin);
		TeleportEntity(iCurrencyPack, origin, NULL_VECTOR, NULL_VECTOR);
		
		if (auto_collect)
		{
			PrintToChatAll("autocollect");
			CreateTimer(CASH_EXPIRE_TIME, AutoCollect_CurrencyPack, iCurrencyPack);
		}
		else
		{
			PrintToChatAll("expire");
			CreateTimer(CASH_EXPIRE_TIME, Destroy_CurrencyPack, iCurrencyPack);
		}
	}
}

stock Action Destroy_CurrencyPack(Handle timer, int entity)
{
	if (IsValidEntity(entity)) {
		float vec[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vec);
		EmitAmbientSound("mvm/mvm_money_vanish.wav", vec, entity);
		RemoveEntity(entity);
	}
}

stock Action AutoCollect_CurrencyPack(Handle timer, int entity)
{
	if (IsValidEntity(entity)) {
		Cash cash = Cash(entity);
		float vec[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vec);
		EmitAmbientSound("mvm/mvm_money_pickup.wav", vec, entity);
		RemoveEntity(entity);
		
		AwardCash(cash.Owner, entity);
	}
}

public void Cash_OnSpawnPost(int entity)
{
	// After the 2015 Halloween update, currency packs will not spawn if there's no nav mesh. This allows Cash to spawn on maps without a nav mesh!
	SetEntProp(entity, Prop_Send, "m_bDistributed", true);
}

stock Action Cash_OnTouch(int entity, int activator)
{
	char key[32];
	IntToString(EntIndexToEntRef(entity), key, sizeof(key));
	int victim;
	g_sCurrencypackPlayerMap.GetValue(key, victim);
	
	if (TF2_GetClientTeam(victim) == TF2_GetClientTeam(activator))
	{
		// disallow picking up your own team's cash
		return Plugin_Handled;
	}
	
	
	SetHudTextParams(-1.0, 0.75, 10.0, 0, 133, 67, 140); // 60.0 how long text should stay since last cash update
	ShowSyncHudText(activator, g_hHudSync, "$%d", g_iBalance[activator]);
	
	PlayCashPickupVoiceLine(activator);
	
	RemoveEntity(entity); // fix for money teleporting to world spawn after pickup
	
	AwardCash(activator, entity);
	
	return Plugin_Continue;
}

void AwardCash(int collector, int entity)
{
	Cash cash = Cash(entity);
	
	TFGOPlayer(cash.Owner).AddToBalance(cash.Value, "");
	if (collector != cash.Owner)
	{
		TFGOPlayer(collector).AddToBalance(50, "");
	}
	
	char clientName[32];
	GetClientName(cash.Owner, clientName, sizeof(clientName));
} 