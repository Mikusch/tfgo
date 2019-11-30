static char g_bombPlantedAnnouncerAlerts[][PLATFORM_MAX_PATH] =  {
	"vo/mvm_bomb_alerts01.mp3", 
	"vo/mvm_bomb_alerts02.mp3"
};

static char g_bombPlantedEngineerAlerts[][PLATFORM_MAX_PATH] =  {
	"vo/engineer_mvm_bomb_see01.mp3", 
	"vo/engineer_mvm_bomb_see02.mp3", 
	"vo/engineer_mvm_bomb_see03.mp3"
};

static char g_bombPlantedHeavyAlerts[][PLATFORM_MAX_PATH] =  {
	"vo/heavy_mvm_bomb_see01.mp3"
};

static char g_bombPlantedMedicAlerts[][PLATFORM_MAX_PATH] =  {
	"vo/medic_mvm_bomb_see01.mp3", 
	"vo/medic_mvm_bomb_see02.mp3", 
	"vo/medic_mvm_bomb_see03.mp3"
};

static char g_bombPlantedSoldierAlerts[][PLATFORM_MAX_PATH] =  {
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
	
	for (int i = 0; i < sizeof(g_bombPlantedAnnouncerAlerts); i++)PrecacheSound(g_bombPlantedAnnouncerAlerts[i]);
	for (int i = 0; i < sizeof(g_bombPlantedEngineerAlerts); i++)PrecacheSound(g_bombPlantedEngineerAlerts[i]);
	for (int i = 0; i < sizeof(g_bombPlantedHeavyAlerts); i++)PrecacheSound(g_bombPlantedHeavyAlerts[i]);
	for (int i = 0; i < sizeof(g_bombPlantedMedicAlerts); i++)PrecacheSound(g_bombPlantedMedicAlerts[i]);
	for (int i = 0; i < sizeof(g_bombPlantedSoldierAlerts); i++)PrecacheSound(g_bombPlantedSoldierAlerts[i]);
}

public void PlayAnnouncerBombAlert()
{
	EmitSoundToAll(g_bombPlantedAnnouncerAlerts[GetRandomInt(0, sizeof(g_bombPlantedAnnouncerAlerts) - 1)], _, SNDCHAN_VOICE_BASE); // SNDCHAN_VOICE_BASE = CHAN_VOICE2
}

public void ShoutBombWarnings()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && IsPlayerAlive(client) && TF2_GetClientTeam(client) != g_bombPlantingTeam)
		{
			switch (TF2_GetPlayerClass(client))
			{
				case TFClass_Engineer:EmitSoundToAll(g_bombPlantedEngineerAlerts[GetRandomInt(0, sizeof(g_bombPlantedEngineerAlerts) - 1)], _, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
				case TFClass_Heavy:EmitSoundToAll(g_bombPlantedHeavyAlerts[GetRandomInt(0, sizeof(g_bombPlantedHeavyAlerts) - 1)], _, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
				case TFClass_Medic:EmitSoundToAll(g_bombPlantedMedicAlerts[GetRandomInt(0, sizeof(g_bombPlantedMedicAlerts) - 1)], _, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
				case TFClass_Soldier:EmitSoundToAll(g_bombPlantedSoldierAlerts[GetRandomInt(0, sizeof(g_bombPlantedSoldierAlerts) - 1)], _, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
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
		g_currentMusicKit.StopMusicForAll(Music_StartAction);
		g_currentMusicKit.StopMusicForAll(Music_BombPlanted);
		g_currentMusicKit.StopMusicForAll(Music_RoundTenSecCount);
		g_currentMusicKit.StopMusicForAll(Music_BombTenSecCount);
		
		// Playing sound directly instead of rewriting event so we can control when to stop it
		if (StrEqual(sound, "Game.YourTeamWon"))
			g_currentMusicKit.PlayMusicToTeam(team, Music_WonRound);
		else if (StrEqual(sound, "Game.YourTeamLost") || StrEqual(sound, "Game.Stalemate"))
			g_currentMusicKit.PlayMusicToTeam(team, Music_LostRound);
		
		return Plugin_Handled;
	}
	else if (StrEqual(sound, "Announcer.AM_RoundStartRandom"))
	{
		g_currentMusicKit.StopMusicForAll(Music_StartRound);
		g_currentMusicKit.PlayMusicToAll(Music_StartAction);
	}
	
	return Plugin_Continue;
}
