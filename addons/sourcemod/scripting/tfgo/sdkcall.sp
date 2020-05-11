static Handle SDKCallGetEquippedWearableForLoadoutSlot;
static Handle SDKCallGetMaxAmmo;
static Handle SDKCallCreateDroppedWeapon;
static Handle SDKCallInitDroppedWeapon;
static Handle SDKCallSetSwitchTeams;
static Handle SDKCallSetScrambleTeams;
static Handle SDKCallEquipWearable;

void SDKCall_Init(GameData gamedata)
{
	SDKCallGetEquippedWearableForLoadoutSlot = PrepSDKCall_GetEquippedWearableForLoadoutSlot(gamedata);
	SDKCallGetMaxAmmo = PrepSDKCall_GetMaxAmmo(gamedata);
	SDKCallCreateDroppedWeapon = PrepSDKCall_CreateDroppedWeapon(gamedata);
	SDKCallInitDroppedWeapon = PrepSDKCall_InitDroppedWeapon(gamedata);
	SDKCallSetSwitchTeams = PrepSDKCall_SetSwitchTeams(gamedata);
	SDKCallSetScrambleTeams = PrepSDKCall_SetScrambleTeams(gamedata);
	SDKCallEquipWearable = PrepSDKCall_EquipWearable(gamedata);
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

stock void SDKCall_SetSwitchTeams(bool shouldSwitch)
{
	SDKCall(SDKCallSetSwitchTeams, shouldSwitch);
}

stock void SDKCall_SetScrambleTeams(bool shouldScramble)
{
	SDKCall(SDKCallSetScrambleTeams, shouldScramble);
}

stock void SDKCall_EquipWearable(int client, int wearable)
{
	SDKCall(SDKCallEquipWearable, client, wearable);
}

stock int SDKCall_GetEquippedWearableForLoadoutSlot(int client, int slot)
{
	return SDKCall(SDKCallGetEquippedWearableForLoadoutSlot, client, slot);
}

stock int SDKCall_GetMaxAmmo(int client, int slot)
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
