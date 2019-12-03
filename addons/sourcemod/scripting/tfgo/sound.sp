static char g_BombPlantedAnnouncerAlerts[][PLATFORM_MAX_PATH] =  {
	"vo/mvm_bomb_alerts01.mp3", 
	"vo/mvm_bomb_alerts02.mp3"
};

static char g_BombPlantedEngineerAlerts[][PLATFORM_MAX_PATH] =  {
	"vo/engineer_mvm_bomb_see01.mp3", 
	"vo/engineer_mvm_bomb_see02.mp3", 
	"vo/engineer_mvm_bomb_see03.mp3"
};

static char g_BombPlantedHeavyAlerts[][PLATFORM_MAX_PATH] =  {
	"vo/heavy_mvm_bomb_see01.mp3"
};

static char g_BombPlantedMedicAlerts[][PLATFORM_MAX_PATH] =  {
	"vo/medic_mvm_bomb_see01.mp3", 
	"vo/medic_mvm_bomb_see02.mp3", 
	"vo/medic_mvm_bomb_see03.mp3"
};

static char g_BombPlantedSoldierAlerts[][PLATFORM_MAX_PATH] =  {
	"vo/soldier_mvm_bomb_see01.mp3", 
	"vo/soldier_mvm_bomb_see02.mp3", 
	"vo/soldier_mvm_bomb_see03.mp3"
};

public void PrecacheSounds()
{
	PrecacheSound(BOMB_WARNING_SOUND);
	PrecacheSound(BOMB_EXPLOSION_SOUND);
	PrecacheSound(PLAYER_PURCHASE_SOUND);
	PrecacheSound(BOMB_BEEPING_SOUND);
	
	for (int i = 0; i < sizeof(g_BombPlantedAnnouncerAlerts); i++)PrecacheSound(g_BombPlantedAnnouncerAlerts[i]);
	for (int i = 0; i < sizeof(g_BombPlantedEngineerAlerts); i++)PrecacheSound(g_BombPlantedEngineerAlerts[i]);
	for (int i = 0; i < sizeof(g_BombPlantedHeavyAlerts); i++)PrecacheSound(g_BombPlantedHeavyAlerts[i]);
	for (int i = 0; i < sizeof(g_BombPlantedMedicAlerts); i++)PrecacheSound(g_BombPlantedMedicAlerts[i]);
	for (int i = 0; i < sizeof(g_BombPlantedSoldierAlerts); i++)PrecacheSound(g_BombPlantedSoldierAlerts[i]);
}

public void PlayAnnouncerBombAlert()
{
	EmitSoundToAll(g_BombPlantedAnnouncerAlerts[GetRandomInt(0, sizeof(g_BombPlantedAnnouncerAlerts) - 1)], _, SNDCHAN_VOICE_BASE); // SNDCHAN_VOICE_BASE = CHAN_VOICE2
}

public void ShoutBombWarnings()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && IsPlayerAlive(client) && TF2_GetClientTeam(client) != g_BombPlantingTeam)
		{
			switch (TF2_GetPlayerClass(client))
			{
				case TFClass_Engineer:EmitSoundToAll(g_BombPlantedEngineerAlerts[GetRandomInt(0, sizeof(g_BombPlantedEngineerAlerts) - 1)], _, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
				case TFClass_Heavy:EmitSoundToAll(g_BombPlantedHeavyAlerts[GetRandomInt(0, sizeof(g_BombPlantedHeavyAlerts) - 1)], _, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
				case TFClass_Medic:EmitSoundToAll(g_BombPlantedMedicAlerts[GetRandomInt(0, sizeof(g_BombPlantedMedicAlerts) - 1)], _, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
				case TFClass_Soldier:EmitSoundToAll(g_BombPlantedSoldierAlerts[GetRandomInt(0, sizeof(g_BombPlantedSoldierAlerts) - 1)], _, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
			}
		}
	}
}

public Action Event_Pre_Teamplay_Broadcast_Audio(Event event, const char[] name, bool dontBroadcast)
{
	char sound[PLATFORM_MAX_PATH];
	event.GetString("sound", sound, sizeof(sound));
	TFTeam team = view_as<TFTeam>(event.GetInt("team"));
	
	if (strncmp(sound, "Game.", 5) == 0)
	{
		g_CurrentMusicKit.StopMusicForAll(Music_StartAction);
		g_CurrentMusicKit.StopMusicForAll(Music_BombPlanted);
		g_CurrentMusicKit.StopMusicForAll(Music_RoundTenSecCount);
		g_CurrentMusicKit.StopMusicForAll(Music_BombTenSecCount);
		
		// Playing sound directly instead of rewriting event so we can control when to stop it
		if (StrEqual(sound, "Game.YourTeamWon"))
			g_CurrentMusicKit.PlayMusicToTeam(team, Music_WonRound);
		else if (StrEqual(sound, "Game.YourTeamLost") || StrEqual(sound, "Game.Stalemate"))
			g_CurrentMusicKit.PlayMusicToTeam(team, Music_LostRound);
		
		return Plugin_Handled;
	}
	else if (StrEqual(sound, "Announcer.AM_RoundStartRandom"))
	{
		g_CurrentMusicKit.StopMusicForAll(Music_StartRound);
		g_CurrentMusicKit.PlayMusicToAll(Music_StartAction);
	}
	
	return Plugin_Continue;
}
