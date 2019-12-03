static GlobalForward g_ForwardBombPlanted;
static GlobalForward g_ForwardBombDetonated;
static GlobalForward g_ForwardBombDefused;
static GlobalForward g_ForwardCashAwarded;
static GlobalForward g_ForwardWeaponPickup;

void Forward_AskLoad()
{
	g_ForwardBombPlanted = new GlobalForward("TFGO_OnBombPlanted", ET_Ignore, Param_Cell, Param_Cell);
	g_ForwardBombDetonated = new GlobalForward("TFGO_OnBombDetonated", ET_Ignore, Param_Cell);
	g_ForwardBombDefused = new GlobalForward("TFGO_OnBombDefused", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_ForwardCashAwarded = new GlobalForward("TFGO_OnCashAwarded", ET_Ignore, Param_Cell, Param_Cell);
	g_ForwardWeaponPickup = new GlobalForward("TFGO_OnWeaponPickup", ET_Ignore, Param_Cell, Param_Cell);
}

void Forward_BombPlanted(TFTeam team, ArrayList cappers)
{
	Call_StartForward(g_ForwardBombPlanted);
	Call_PushCell(team);
	Call_PushCell(cappers);
	Call_Finish();
}

void Forward_BombDetonated(TFTeam team)
{
	Call_StartForward(g_ForwardBombDetonated);
	Call_PushCell(team);
	Call_Finish();
}

void Forward_BombDefused(TFTeam team, ArrayList cappers, float timeLeft)
{
	Call_StartForward(g_ForwardBombDefused);
	Call_PushCell(team);
	Call_PushCell(cappers);
	Call_PushCell(timeLeft);
	Call_Finish();
}

void Forward_CashAwarded(int client, int amount)
{
	Call_StartForward(g_ForwardCashAwarded);
	Call_PushCell(client);
	Call_PushCell(amount);
	Call_Finish();
}

void Forward_WeaponPickup(int client, int defindex)
{
	Call_StartForward(g_ForwardWeaponPickup);
	Call_PushCell(client);
	Call_PushCell(defindex);
	Call_Finish();
}
