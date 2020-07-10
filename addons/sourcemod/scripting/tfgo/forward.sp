static GlobalForward ForwardBombPlanted;
static GlobalForward ForwardBombDetonated;
static GlobalForward ForwardBombDefused;
static GlobalForward ForwardHalfTimeStarted;
static GlobalForward ForwardHasHalfTimeEnded;
static GlobalForward ForwardClientAccountChange;
static GlobalForward ForwardClientAccountChanged;
static GlobalForward ForwardClientPurchaseWeapon;
static GlobalForward ForwardClientPickupWeapon;
static GlobalForward ForwardClientName;
static GlobalForward ForwardMusicKitName;

void Forward_AskLoad()
{
	ForwardBombPlanted = new GlobalForward("TFGO_OnBombPlanted", ET_Ignore, Param_Cell, Param_Cell);
	ForwardBombDetonated = new GlobalForward("TFGO_OnBombDetonated", ET_Ignore, Param_Cell);
	ForwardBombDefused = new GlobalForward("TFGO_OnBombDefused", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	ForwardHalfTimeStarted = new GlobalForward("TFGO_OnHalfTimeStarted", ET_Ignore);
	ForwardHasHalfTimeEnded = new GlobalForward("TFGO_HasHalfTimeEnded", ET_Single);
	ForwardClientAccountChange = new GlobalForward("TFGO_OnClientAccountChange", ET_Event, Param_Cell, Param_Cell);
	ForwardClientAccountChanged = new GlobalForward("TFGO_OnClientAccountChanged", ET_Ignore, Param_Cell, Param_Cell);
	ForwardClientPurchaseWeapon = new GlobalForward("TFGO_OnClientPurchaseWeapon", ET_Ignore, Param_Cell, Param_Cell);
	ForwardClientPickupWeapon = new GlobalForward("TFGO_OnClientPickupWeapon", ET_Ignore, Param_Cell, Param_Cell);
	ForwardClientName = new GlobalForward("TFGO_GetClientName", ET_Ignore, Param_Cell, Param_String, Param_Cell);
	ForwardMusicKitName = new GlobalForward("TFGO_GetMusicKitName", ET_Ignore, Param_Cell, Param_String, Param_Cell);
}

void Forward_OnBombPlanted(TFTeam team, ArrayList planters)
{
	Call_StartForward(ForwardBombPlanted);
	Call_PushCell(team);
	Call_PushCell(planters);
	Call_Finish();
}

void Forward_OnBombDetonated(TFTeam team)
{
	Call_StartForward(ForwardBombDetonated);
	Call_PushCell(team);
	Call_Finish();
}

void Forward_OnBombDefused(TFTeam team, ArrayList defusers, float timeLeft)
{
	Call_StartForward(ForwardBombDefused);
	Call_PushCell(team);
	Call_PushCell(defusers);
	Call_PushCell(timeLeft);
	Call_Finish();
}

void Forward_OnHalfTimeStarted()
{
	Call_StartForward(ForwardHalfTimeStarted);
	Call_Finish();
}

bool Forward_HasHalfTimeEnded()
{
	bool value;
	
	Call_StartForward(ForwardHasHalfTimeEnded);
	Call_Finish(value);
	
	return value;
}

Action Forward_OnClientAccountChange(int client, int &amount)
{
	Action action;
	
	Call_StartForward(ForwardClientAccountChange);
	Call_PushCell(client);
	Call_PushCell(amount);
	Call_Finish(action);
	
	return action;
}

void Forward_OnClientAccountChanged(int client, int amount)
{
	Call_StartForward(ForwardClientAccountChanged);
	Call_PushCell(client);
	Call_PushCell(amount);
	Call_Finish();
}

void Forward_OnClientPurchaseWeapon(int client, int defindex)
{
	Call_StartForward(ForwardClientPurchaseWeapon);
	Call_PushCell(client);
	Call_PushCell(defindex);
	Call_Finish();
}

void Forward_OnClientPickupWeapon(int client, int defindex)
{
	Call_StartForward(ForwardClientPickupWeapon);
	Call_PushCell(client);
	Call_PushCell(defindex);
	Call_Finish();
}

void Forward_GetClientName(int client, char[] name, int maxlen)
{
	Call_StartForward(ForwardClientName);
	Call_PushCell(client);
	Call_PushStringEx(name, maxlen, SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(maxlen);
	Call_Finish();
}

void Forward_GetMusicKitName(int client, char[] name, int maxlen)
{
	Call_StartForward(ForwardMusicKitName);
	Call_PushCell(client);
	Call_PushStringEx(name, maxlen, SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(maxlen);
	Call_Finish();
}
