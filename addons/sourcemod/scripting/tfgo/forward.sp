static GlobalForward ForwardBombPlanted;
static GlobalForward ForwardBombDetonated;
static GlobalForward ForwardBombDefused;
static GlobalForward ForwardHalfTime;
static GlobalForward ForwardMaxRounds;
static GlobalForward ForwardClientAccountChange;
static GlobalForward ForwardClientAccountChanged;
static GlobalForward ForwardClientPurchaseWeapon;
static GlobalForward ForwardClientPickupWeapon;

void Forward_AskLoad()
{
	ForwardBombPlanted = new GlobalForward("TFGO_OnBombPlanted", ET_Ignore, Param_Cell, Param_Cell);
	ForwardBombDetonated = new GlobalForward("TFGO_OnBombDetonated", ET_Ignore, Param_Cell);
	ForwardBombDefused = new GlobalForward("TFGO_OnBombDefused", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	ForwardHalfTime = new GlobalForward("TFGO_OnHalfTime", ET_Ignore);
	ForwardMaxRounds = new GlobalForward("TFGO_OnMaxRounds", ET_Ignore);
	ForwardClientAccountChange = new GlobalForward("TFGO_OnClientAccountChange", ET_Event, Param_Cell, Param_Cell);
	ForwardClientAccountChanged = new GlobalForward("TFGO_OnClientAccountChanged", ET_Ignore, Param_Cell, Param_Cell);
	ForwardClientPurchaseWeapon = new GlobalForward("TFGO_OnClientPurchaseWeapon", ET_Ignore, Param_Cell, Param_Cell);
	ForwardClientPickupWeapon = new GlobalForward("TFGO_OnClientPickupWeapon", ET_Ignore, Param_Cell, Param_Cell);
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

void Forward_OnHalfTime()
{
	Call_StartForward(ForwardHalfTime);
	Call_Finish();
}

void Forward_OnMaxRounds()
{
	Call_StartForward(ForwardMaxRounds);
	Call_Finish();
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
