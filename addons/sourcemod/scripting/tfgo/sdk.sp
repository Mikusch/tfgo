static Handle DHookGetCaptureValueForPlayer;
static Handle DHookSetWinningTeam;
static Handle DHookHandleSwitchTeams;
static Handle DHookHandleScrambleTeams;
static Handle DHookGiveNamedItem;
static Handle SDKCallGetEquippedWearableForLoadoutSlot;
static Handle SDKCallGetMaxAmmo;
static Handle SDKCallCreateDroppedWeapon;
static Handle SDKCallInitDroppedWeapon;
static Handle SDKCallSetSwitchTeams;
static Handle SDKCallSetScrambleTeams;
static Handle SDKCallEquipWearable;

static int g_HookIdsGiveNamedItem[TF_MAXPLAYERS + 1] =  { -1, ... };

void SDK_Init()
{
	GameData gamedata = new GameData("tfgo");
	
	SDKCallGetEquippedWearableForLoadoutSlot = PrepSDKCall_GetEquippedWearableForLoadoutSlot(gamedata);
	SDKCallGetMaxAmmo = PrepSDKCall_GetMaxAmmo(gamedata);
	SDKCallCreateDroppedWeapon = PrepSDKCall_CreateDroppedWeapon(gamedata);
	SDKCallInitDroppedWeapon = PrepSDKCall_InitDroppedWeapon(gamedata);
	SDKCallSetSwitchTeams = PrepSDKCall_SetSwitchTeams(gamedata);
	SDKCallSetScrambleTeams = PrepSDKCall_SetScrambleTeams(gamedata);
	SDKCallEquipWearable = PrepSDKCall_EquipWearable(gamedata);
	
	DHookGetCaptureValueForPlayer = DHook_CreateVirtual(gamedata, "CTFGameRules::GetCaptureValueForPlayer");
	DHookSetWinningTeam = DHook_CreateVirtual(gamedata, "CTFGameRules::SetWinningTeam");
	DHookGiveNamedItem = DHook_CreateVirtual(gamedata, "CTFPlayer::GiveNamedItem");
	DHookHandleSwitchTeams = DHook_CreateVirtual(gamedata, "CTFGameRules::HandleSwitchTeams");
	DHookHandleScrambleTeams = DHook_CreateVirtual(gamedata, "CTFGameRules::HandleScrambleTeams");
	
	DHook_CreateDetour(gamedata, "CTFPlayer::PickupWeaponFromOther", Detour_PickupWeaponFromOther);
	
	MemoryPatch.SetGameData(gamedata);
	g_PickupWeaponPatch = new MemoryPatch("Patch_PickupWeaponFromOther");
	if (g_PickupWeaponPatch != null)
		g_PickupWeaponPatch.Enable();
	else
		LogMessage("Failed to create patch: Patch_PickupWeaponFromOther");
	
	delete gamedata;
}

void SDK_HookGamerules()
{
	DHookGamerules(DHookGetCaptureValueForPlayer, true, _, DHook_GetCaptureValueForPlayer);
	DHookGamerules(DHookSetWinningTeam, false, _, DHook_SetWinningTeam);
	DHookGamerules(DHookHandleSwitchTeams, false, _, DHook_HandleSwitchTeams);
	DHookGamerules(DHookHandleScrambleTeams, false, _, DHook_HandleScrambleTeams);
}

void SDK_HookClientEntity(int client)
{
	g_HookIdsGiveNamedItem[client] = DHookEntity(DHookGiveNamedItem, false, client, DHookRemoval_GiveNamedItem, DHook_GiveNamedItem);
}

void SDK_UnhookClientEntity(int client)
{
	if (g_HookIdsGiveNamedItem[client] != -1)
	{
		DHookRemoveHookID(g_HookIdsGiveNamedItem[client]);
		g_HookIdsGiveNamedItem[client] = -1;
	}
}

static Handle DHook_CreateVirtual(GameData gamedata, const char[] name)
{
	Handle hook = DHookCreateFromConf(gamedata, name);
	if (!hook)
		LogError("Failed to create virtual: %s", name);
	
	return hook;
}

static void DHook_CreateDetour(GameData gamedata, const char[] name, DHookCallback preCallback = INVALID_FUNCTION, DHookCallback postCallback = INVALID_FUNCTION)
{
	Handle detour = DHookCreateFromConf(gamedata, name);
	if (!detour)
	{
		LogError("Failed to create detour: %s", name);
	}
	else
	{
		if (preCallback != INVALID_FUNCTION)
			if (!DHookEnableDetour(detour, false, preCallback))
			LogError("Failed to enable pre detour: %s", name);
		
		if (postCallback != INVALID_FUNCTION)
			if (!DHookEnableDetour(detour, true, postCallback))
			LogError("Failed to enable post detour: %s", name);
		
		delete detour;
	}
}

static Handle PrepSDKCall_GetEquippedWearableForLoadoutSlot(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFPlayer::GetEquippedWearableForLoadoutSlot");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create call: CTFPlayer::GetEquippedWearableForLoadoutSlot");
	
	return call;
}

static Handle PrepSDKCall_GetMaxAmmo(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFPlayer::GetMaxAmmo");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create call: CTFPlayer::GetMaxAmmo");
	
	return call;
}

static Handle PrepSDKCall_CreateDroppedWeapon(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFDroppedWeapon::Create");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_QAngle, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create call: CTFDroppedWeapon::Create");
	
	return call;
}

static Handle PrepSDKCall_InitDroppedWeapon(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFDroppedWeapon::InitDroppedWeapon");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create call: CTFDroppedWeapon::InitDroppedWeapon");
	
	return call;
}

static Handle PrepSDKCall_SetSwitchTeams(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_GameRules);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CTFGameRules::SetSwitchTeams");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create call: CTFGameRules::SetSwitchTeams");
	
	return call;
}

static Handle PrepSDKCall_SetScrambleTeams(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_GameRules);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CTFGameRules::SetScrambleTeams");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create call: CTFGameRules::SetScrambleTeams");
	
	return call;
}

static Handle PrepSDKCall_EquipWearable(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CBasePlayer::EquipWearable");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: CBasePlayer::EquipWearable");
	
	return call;
}

public MRESReturn Detour_PickupWeaponFromOther(int client, Handle returnVal, Handle params)
{
	int weapon = DHookGetParam(params, 1); // tf_dropped_weapon
	int defindex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
	TFGOPlayer(client).AddToLoadout(defindex);
	Forward_OnClientPickupWeapon(client, defindex);
}

public MRESReturn DHook_GetCaptureValueForPlayer(Handle returnVal, Handle params)
{
	int client = DHookGetParam(params, 1);
	if (TFGOPlayer(client).HasDefuseKit && g_IsBombPlanted) // Defuse kit only takes effect when the bomb is planted
	{
		DHookSetReturn(returnVal, DHookGetReturn(returnVal) + 1);
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public MRESReturn DHook_SetWinningTeam(Handle params)
{
	TFTeam team = DHookGetParam(params, 1);
	int winReason = DHookGetParam(params, 2);
	
	// Allow planting team to die
	if (g_IsBombPlanted && team != g_BombPlantingTeam && winReason == WinReason_Elimination)
		return MRES_Supercede;
	
	return MRES_Ignored;
}

public MRESReturn DHook_HandleSwitchTeams()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		TFGOPlayer(client).Reset();
	}
	
	for (int team = view_as<int>(TFTeam_Red); team <= view_as<int>(TFTeam_Blue); team++)
	{
		TFGOTeam(view_as<TFTeam>(team)).ConsecutiveLosses = STARTING_CONSECUTIVE_LOSSES;
	}
}

public MRESReturn DHook_HandleScrambleTeams()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		TFGOPlayer(client).Reset();
	}
	
	for (int team = view_as<int>(TFTeam_Red); team <= view_as<int>(TFTeam_Blue); team++)
	{
		TFGOTeam(view_as<TFTeam>(team)).ConsecutiveLosses = STARTING_CONSECUTIVE_LOSSES;
		SetTeamScore(team, 0);
	}
	
	// Arena informs the players of a team switch but not of a scramble, wtf?
	Event alert = CreateEvent("teamplay_alert");
	alert.SetInt("alert_type", 0);
	alert.Fire();
	PrintToChatAll("%T", "TF_TeamsScrambled", LANG_SERVER);
	EmitGameSoundToAll(GAMESOUND_ANNOUNCER_TEAM_SCRAMBLE);
}

public MRESReturn DHook_GiveNamedItem(int client, Handle returnVal, Handle params)
{
	if (DHookIsNullParam(params, 1) || DHookIsNullParam(params, 3))
		return MRES_Ignored;
	
	int defindex = DHookGetParamObjectPtrVar(params, 3, 4, ObjectValueType_Int) & 0xFFFF;
	int slot = TF2_GetItemSlot(defindex, TF2_GetPlayerClass(client));
	TFClassType class = TF2_GetPlayerClass(client);
	
	if (0 <= slot <= WeaponSlot_BuilderEngie && TFGOPlayer(client).GetWeaponFromLoadout(class, slot) != defindex)
	{
		DHookSetReturn(returnVal, 0);
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public void DHookRemoval_GiveNamedItem(int hookId)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (g_HookIdsGiveNamedItem[client] == hookId)
		{
			g_HookIdsGiveNamedItem[client] = -1;
			return;
		}
	}
}

stock void SDK_SetSwitchTeams(bool shouldSwitch)
{
	SDKCall(SDKCallSetSwitchTeams, shouldSwitch);
}

stock void SDK_SetScrambleTeams(bool shouldScramble)
{
	SDKCall(SDKCallSetScrambleTeams, shouldScramble);
}

stock void SDK_EquipWearable(int client, int wearable)
{
	SDKCall(SDKCallEquipWearable, client, wearable);
}

stock int SDK_GetEquippedWearableForLoadoutSlot(int client, int slot)
{
	return SDKCall(SDKCallGetEquippedWearableForLoadoutSlot, client, slot);
}

stock int SDK_GetMaxAmmo(int client, int slot)
{
	return SDKCall(SDKCallGetMaxAmmo, client, slot, -1);
}

stock int SDK_CreateDroppedWeapon(int fromWeapon, int client, const float origin[3], const float angles[3])
{
	char classname[32];
	if (GetEntityNetClass(fromWeapon, classname, sizeof(classname)))
	{
		int itemOffset = FindSendPropInfo(classname, "m_Item");
		if (itemOffset <= -1)
			ThrowError("Failed to find m_Item on: %s", classname);
		
		char model[PLATFORM_MAX_PATH];
		int worldModelIndex = GetEntProp(fromWeapon, Prop_Send, "m_iWorldModelIndex");
		ModelIndexToString(worldModelIndex, model, sizeof(model));
		
		int droppedWeapon = SDKCall(SDKCallCreateDroppedWeapon, client, origin, angles, model, GetEntityAddress(fromWeapon) + view_as<Address>(itemOffset));
		if (droppedWeapon != INVALID_ENT_REFERENCE)
			SDKCall(SDKCallInitDroppedWeapon, droppedWeapon, client, fromWeapon, false, false);
		return droppedWeapon;
	}
	
	return -1;
}
