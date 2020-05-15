void EntOutput_Init()
{
	HookEntityOutput("team_round_timer", "On10SecRemain", EntOutput_On10SecRemain);
}

void EntOutput_On10SecRemain(const char[] output, int caller, int activator, float delay)
{
	if (g_IsMainRoundActive)
	{
		g_CurrentMusicKit.StopMusicForAll(Music_StartAction);
		g_CurrentMusicKit.PlayMusicToAll(Music_RoundTenSecCount);
	}
}
