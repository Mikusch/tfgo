static Handle g_HookGetCaptureValueForPlayer;
static Handle g_HookPickupWeaponFromOther;
static Handle g_HookSetWinningTeam;
static Handle g_HookHandleSwitchTeams;
static Handle g_HookHandleScrambleTeams;
static Handle g_HookGiveNamedItem;
static Handle g_SDKGetEquippedWearableForLoadoutSlot;
static Handle g_SDKGetMaxAmmo;
static Handle g_SDKCreateDroppedWeapon;
static Handle g_SDKInitDroppedWeapon;
static Handle g_SDKSetSwitchTeams;
static Handle g_SDKSetScrambleTeams;
static Handle g_SDKEquipWearable;
static Handle g_SDKRemoveWearable;

static int g_HookIdsGiveNamedItem[TF_MAXPLAYERS + 1] =  { -1, ... };

void SDK_Init()
{
	GameData gameData = new GameData("tfgo");
	
	g_HookPickupWeaponFromOther = DHookCreateFromConf(gameData, "CTFPlayer::PickupWeaponFromOther");
	if (g_HookPickupWeaponFromOther != null)
		DHookEnableDetour(g_HookPickupWeaponFromOther, false, Hook_PickupWeaponFromOther);
	else
		LogMessage("Failed to create hook: CTFPlayer::PickupWeaponFromOther");
	
	int offset = gameData.GetOffset("CTFGameRules::GetCaptureValueForPlayer");
	g_HookGetCaptureValueForPlayer = DHookCreate(offset, HookType_GameRules, ReturnType_Int, ThisPointer_Ignore);
	if (g_HookGetCaptureValueForPlayer == null)
		LogMessage("Failed to create hook: CTFGameRules::GetCaptureValueForPlayer");
	else
		DHookAddParam(g_HookGetCaptureValueForPlayer, HookParamType_CBaseEntity);
	
	offset = gameData.GetOffset("CTFGameRules::SetWinningTeam");
	g_HookSetWinningTeam = DHookCreate(offset, HookType_GameRules, ReturnType_Void, ThisPointer_Ignore);
	if (g_HookSetWinningTeam != null)
	{
		DHookAddParam(g_HookSetWinningTeam, HookParamType_Int);
		DHookAddParam(g_HookSetWinningTeam, HookParamType_Int);
		DHookAddParam(g_HookSetWinningTeam, HookParamType_Bool);
		DHookAddParam(g_HookSetWinningTeam, HookParamType_Bool);
		DHookAddParam(g_HookSetWinningTeam, HookParamType_Bool);
		DHookAddParam(g_HookSetWinningTeam, HookParamType_Bool);
	}
	else
	{
		LogMessage("Failed to create hook: CTFGameRules::SetWinningTeam");
	}
	
	offset = gameData.GetOffset("CTFPlayer::GiveNamedItem");
	g_HookGiveNamedItem = DHookCreate(offset, HookType_Entity, ReturnType_CBaseEntity, ThisPointer_CBaseEntity);
	if (g_HookGiveNamedItem != null)
	{
		DHookAddParam(g_HookGiveNamedItem, HookParamType_CharPtr);
		DHookAddParam(g_HookGiveNamedItem, HookParamType_Int);
		DHookAddParam(g_HookGiveNamedItem, HookParamType_ObjectPtr);
		DHookAddParam(g_HookGiveNamedItem, HookParamType_Bool);
	}
	else
	{
		LogMessage("Failed to create hook: CTFPlayer::GiveNamedItem");
	}
	
	offset = gameData.GetOffset("CTFGameRules::HandleSwitchTeams");
	g_HookHandleSwitchTeams = DHookCreate(offset, HookType_GameRules, ReturnType_Void, ThisPointer_Ignore);
	if (g_HookHandleSwitchTeams == null)
		LogMessage("Failed to create hook: CTFGameRules::HandleSwitchTeams");
	
	offset = gameData.GetOffset("CTFGameRules::HandleScrambleTeams");
	g_HookHandleScrambleTeams = DHookCreate(offset, HookType_GameRules, ReturnType_Void, ThisPointer_Ignore);
	if (g_HookHandleScrambleTeams == null)
		LogMessage("Failed to create hook: CTFGameRules::HandleScrambleTeams");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gameData, SDKConf_Signature, "CTFPlayer::GetEquippedWearableForLoadoutSlot");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	g_SDKGetEquippedWearableForLoadoutSlot = EndPrepSDKCall();
	if (g_SDKGetEquippedWearableForLoadoutSlot == null)
		LogMessage("Failed to create call: CTFPlayer::GetEquippedWearableForLoadoutSlot");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gameData, SDKConf_Signature, "CTFPlayer::GetMaxAmmo");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_SDKGetMaxAmmo = EndPrepSDKCall();
	if (g_SDKGetMaxAmmo == null)
		LogMessage("Failed to create call: CTFPlayer::GetMaxAmmo");
	
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(gameData, SDKConf_Signature, "CTFDroppedWeapon::Create");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_QAngle, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	g_SDKCreateDroppedWeapon = EndPrepSDKCall();
	if (g_SDKCreateDroppedWeapon == null)
		LogMessage("Failed to create call: CTFDroppedWeapon::Create");
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gameData, SDKConf_Signature, "CTFDroppedWeapon::InitDroppedWeapon");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	g_SDKInitDroppedWeapon = EndPrepSDKCall();
	if (g_SDKInitDroppedWeapon == null)
		LogMessage("Failed to create call: CTFDroppedWeapon::InitDroppedWeapon");
	
	StartPrepSDKCall(SDKCall_GameRules);
	PrepSDKCall_SetFromConf(gameData, SDKConf_Virtual, "CTFGameRules::SetSwitchTeams");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	g_SDKSetSwitchTeams = EndPrepSDKCall();
	if (g_SDKSetSwitchTeams == null)
		LogMessage("Failed to create call: CTFGameRules::SetSwitchTeams");
	
	StartPrepSDKCall(SDKCall_GameRules);
	PrepSDKCall_SetFromConf(gameData, SDKConf_Virtual, "CTFGameRules::SetScrambleTeams");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	g_SDKSetScrambleTeams = EndPrepSDKCall();
	if (g_SDKSetScrambleTeams == null)
		LogMessage("Failed to create call: CTFGameRules::SetScrambleTeams");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gameData, SDKConf_Virtual, "CBasePlayer::EquipWearable");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_SDKEquipWearable = EndPrepSDKCall();
	if (g_SDKEquipWearable == null)
		LogMessage("Failed to create call: CBasePlayer::EquipWearable");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gameData, SDKConf_Virtual, "CBasePlayer::RemoveWearable");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_SDKRemoveWearable = EndPrepSDKCall();
	if (g_SDKRemoveWearable == null)
		LogMessage("Failed to create call: CBasePlayer::RemoveWearable");
	
	MemoryPatch.SetGameData(gameData);
	g_PickupWeaponPatch = new MemoryPatch("Patch_PickupWeaponFromOther");
	if (g_PickupWeaponPatch != null)
		g_PickupWeaponPatch.Enable();
	else
		LogMessage("Failed to create patch: Patch_PickupWeaponFromOther");
	
	delete gameData;
}

void SDK_HookGamerules()
{
	DHookGamerules(g_HookGetCaptureValueForPlayer, true, _, Hook_GetCaptureValueForPlayer);
	DHookGamerules(g_HookSetWinningTeam, false, _, Hook_SetWinningTeam);
	DHookGamerules(g_HookHandleSwitchTeams, false, _, Hook_HandleSwitchTeams);
	DHookGamerules(g_HookHandleScrambleTeams, false, _, Hook_HandleScrambleTeams);
}

void SDK_HookClientEntity(int client)
{
	if (g_HookGiveNamedItem)
		g_HookIdsGiveNamedItem[client] = DHookEntity(g_HookGiveNamedItem, false, client, HookRemoval_GiveNamedItem, Hook_GiveNamedItem);
}

void SDK_UnhookClientEntity(int client)
{
	if (g_HookIdsGiveNamedItem[client] != -1)
	{
		DHookRemoveHookID(g_HookIdsGiveNamedItem[client]);
		g_HookIdsGiveNamedItem[client] = -1;
	}
}

public MRESReturn Hook_PickupWeaponFromOther(int client, Handle returnVal, Handle params)
{
	int weapon = DHookGetParam(params, 1); // tf_dropped_weapon
	int defindex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
	TFGOPlayer(client).AddToLoadout(defindex);
	
	Forward_WeaponPickup(client, defindex);
}

public MRESReturn Hook_GetCaptureValueForPlayer(Handle returnVal, Handle params)
{
	int client = DHookGetParam(params, 1);
	if (TFGOPlayer(client).HasDefuseKit && g_IsBombPlanted) // Defuser only comes into effect
	{
		DHookSetReturn(returnVal, DHookGetReturn(returnVal) + 1);
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public MRESReturn Hook_SetWinningTeam(Handle params)
{
	TFTeam team = DHookGetParam(params, 1);
	int winReason = DHookGetParam(params, 2);
	
	// Allow planting team to die
	if (g_IsBombPlanted && team != g_BombPlantingTeam && winReason == WinReason_Elimination)
		return MRES_Supercede;
	
	return MRES_Ignored;
}

public MRESReturn Hook_HandleSwitchTeams()
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

public MRESReturn Hook_HandleScrambleTeams()
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

public MRESReturn Hook_GiveNamedItem(int client, Handle returnVal, Handle params)
{
	if (DHookIsNullParam(params, 1) || DHookIsNullParam(params, 3))
		return MRES_Ignored;
	
	int defIndex = DHookGetParamObjectPtrVar(params, 3, 4, ObjectValueType_Int) & 0xFFFF;
	int slot = TF2_GetSlotInItem(defIndex, TF2_GetPlayerClass(client));
	TFClassType class = TF2_GetPlayerClass(client);
	
	if (0 <= slot <= WeaponSlot_BuilderEngie && TFGOPlayer(client).GetWeaponFromLoadout(class, slot) != defIndex)
	{
		DHookSetReturn(returnVal, 0);
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public void HookRemoval_GiveNamedItem(int hookId)
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
	if (g_SDKSetSwitchTeams != null)
		SDKCall(g_SDKSetSwitchTeams, shouldSwitch);
}

stock void SDK_SetScrambleTeams(bool shouldScramble)
{
	if (g_SDKSetScrambleTeams != null)
		SDKCall(g_SDKSetScrambleTeams, shouldScramble);
}

stock void SDK_EquipWearable(int client, int wearable)
{
	if (g_SDKEquipWearable != null)
		SDKCall(g_SDKEquipWearable, client, wearable);
}

stock void SDK_RemoveWearable(int client, int wearable)
{
	if (g_SDKRemoveWearable != null)
		SDKCall(g_SDKRemoveWearable, client, wearable);
}

stock int SDK_GetEquippedWearableForLoadoutSlot(int client, int slot)
{
	if (g_SDKGetEquippedWearableForLoadoutSlot != null)
		return SDKCall(g_SDKGetEquippedWearableForLoadoutSlot, client, slot);
	else
		return -1;
}

stock int SDK_GetMaxAmmo(int client, int slot)
{
	if (g_SDKGetMaxAmmo != null)
		return SDKCall(g_SDKGetMaxAmmo, client, slot, -1);
	else
		return -1;
}

stock int SDK_CreateDroppedWeapon(int fromWeapon, int client, const float origin[3], const float angles[3])
{
	char clsname[32];
	if (GetEntityNetClass(fromWeapon, clsname, sizeof(clsname)))
	{
		int itemOffset = FindSendPropInfo(clsname, "m_Item");
		if (itemOffset <= -1)
			ThrowError("Failed to find m_Item on %s", clsname);
		
		char model[PLATFORM_MAX_PATH];
		int worldModelIndex = GetEntProp(fromWeapon, Prop_Send, "m_iWorldModelIndex");
		ModelIndexToString(worldModelIndex, model, sizeof(model));
		
		if (g_SDKCreateDroppedWeapon != null)
		{
			int droppedWeapon = SDKCall(g_SDKCreateDroppedWeapon, client, origin, angles, model, GetEntityAddress(fromWeapon) + view_as<Address>(itemOffset));
			if (droppedWeapon != INVALID_ENT_REFERENCE && g_SDKInitDroppedWeapon != null)
				SDKCall(g_SDKInitDroppedWeapon, droppedWeapon, client, fromWeapon, false, false);
			return droppedWeapon;
		}
	}
	
	return -1;
}
