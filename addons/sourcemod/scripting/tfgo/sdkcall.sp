static Handle SDKCallGetEquippedWearableForLoadoutSlot;
static Handle SDKCallGetLoadoutItem;
static Handle SDKCallGetBaseEntity;
static Handle SDKCallGiveNamedItem;
static Handle SDKCallCreateDroppedWeapon;
static Handle SDKCallInitDroppedWeapon;
static Handle SDKCallSetSwitchTeams;
static Handle SDKCallSetScrambleTeams;
static Handle SDKCallGetDefaultItemChargeMeterValue;
static Handle SDKCallPickUp;
static Handle SDKCallEquipWearable;

void SDKCall_Init(GameData gamedata)
{
	SDKCallGetEquippedWearableForLoadoutSlot = PrepSDKCall_GetEquippedWearableForLoadoutSlot(gamedata);
	SDKCallGetLoadoutItem = PrepSDKCall_GetLoadoutItem(gamedata);
	SDKCallGetBaseEntity = PrepSDKCall_GetBaseEntity(gamedata);
	SDKCallGiveNamedItem = PrepSDKCall_GiveNamedItem(gamedata);
	SDKCallCreateDroppedWeapon = PrepSDKCall_CreateDroppedWeapon(gamedata);
	SDKCallInitDroppedWeapon = PrepSDKCall_InitDroppedWeapon(gamedata);
	SDKCallSetSwitchTeams = PrepSDKCall_SetSwitchTeams(gamedata);
	SDKCallSetScrambleTeams = PrepSDKCall_SetScrambleTeams(gamedata);
	SDKCallGetDefaultItemChargeMeterValue = PrepSDKCall_GetDefaultItemChargeMeterValue(gamedata);
	SDKCallPickUp = PrepSDKCall_PickUp(gamedata);
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
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CTeamplayRules::SetSwitchTeams");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create call: CTeamplayRules::SetSwitchTeams");
	
	return call;
}

static Handle PrepSDKCall_SetScrambleTeams(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_GameRules);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CTeamplayRules::SetScrambleTeams");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogMessage("Failed to create call: CTeamplayRules::SetScrambleTeams");
	
	return call;
}

static Handle PrepSDKCall_GetDefaultItemChargeMeterValue(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CBaseEntity::GetDefaultItemChargeMeterValue");
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: CBaseEntity::GetDefaultItemChargeMeterValue");
		
	return call;
}

static Handle PrepSDKCall_PickUp(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CCaptureFlag::PickUp");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: CCaptureFlag::PickUp");
	
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

static Handle PrepSDKCall_GetLoadoutItem(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFPlayer::GetLoadoutItem");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_ByValue);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: CTFPlayer::GetLoadoutItem");
		
	return call;
}

static Handle PrepSDKCall_GetBaseEntity(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CBaseEntity::GetBaseEntity");
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: CBaseEntity::GetBaseEntity");
		
	return call;
}

static Handle PrepSDKCall_GiveNamedItem(GameData gamedata)
{
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "CTFPlayer::GiveNamedItem");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_ByValue);
	
	Handle call = EndPrepSDKCall();
	if (!call)
		LogError("Failed to create SDKCall: CTFPlayer::GiveNamedItem");
		
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

stock float SDKCall_GetDefaultItemChargeMeterValue(int weapon)
{
	return SDKCall(SDKCallGetDefaultItemChargeMeterValue, weapon);
}

stock void SDKCall_PickUp(int teamflag, int client)
{
	SDKCall(SDKCallPickUp, teamflag, client, true);
}

stock void SDKCall_EquipWearable(int client, int wearable)
{
	SDKCall(SDKCallEquipWearable, client, wearable);
}

stock int SDKCall_GetEquippedWearableForLoadoutSlot(int client, int slot)
{
	return SDKCall(SDKCallGetEquippedWearableForLoadoutSlot, client, slot);
}

stock Address SDKCall_GiveNamedItem(int client, const char[] classname, int subType, Address item, bool force = false, bool skipHook = true)
{
	g_SkipGiveNamedItemHook = skipHook;
	return SDKCall(SDKCallGiveNamedItem, client, classname, subType, item, force);
}

stock Address SDKCall_GetLoadoutItem(int client, TFClassType class, int slot)
{
	return SDKCall(SDKCallGetLoadoutItem, client, class, slot, false);
}

stock int SDKCall_GetBaseEntity(Address address)
{
	return SDKCall(SDKCallGetBaseEntity, address);
}

stock int SDKCall_CreateDroppedWeapon(int fromWeapon, int client, const float origin[3], const float angles[3])
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
