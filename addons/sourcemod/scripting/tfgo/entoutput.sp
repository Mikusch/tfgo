void EntOutput_Init()
{
	HookEntityOutput("team_round_timer", "On10SecRemain", EntOutput_On10SecRemain);
}

void EntOutput_On10SecRemain(const char[] output, int caller, int activator, float delay)
{
	if (g_IsMainRoundActive)
		MusicKit_PlayKitsToClients(Music_TenSecCount);
}
