static char g_sBombPlantedAnnouncerAlerts[][PLATFORM_MAX_PATH] =  {
	"vo/mvm_bomb_alerts01.mp3", 
	"vo/mvm_bomb_alerts02.mp3"
};

static char g_sBombPlantedEngineerAlerts[][PLATFORM_MAX_PATH] =  {
	"vo/engineer_mvm_bomb_see01.mp3", 
	"vo/engineer_mvm_bomb_see02.mp3", 
	"vo/engineer_mvm_bomb_see03.mp3"
};

static char g_sBombPlantedHeavyAlerts[][PLATFORM_MAX_PATH] =  {
	"vo/heavy_mvm_bomb_see01.mp3"
};

static char g_sBombPlantedMedicAlerts[][PLATFORM_MAX_PATH] =  {
	"vo/medic_mvm_bomb_see01.mp3", 
	"vo/medic_mvm_bomb_see02.mp3", 
	"vo/medic_mvm_bomb_see03.mp3"
};

static char g_sBombPlantedSoldierAlerts[][PLATFORM_MAX_PATH] =  {
	"vo/soldier_mvm_bomb_see01.mp3", 
	"vo/soldier_mvm_bomb_see02.mp3", 
	"vo/soldier_mvm_bomb_see03.mp3", 
};

static char g_sBombDefusedEngineerResponses[][PLATFORM_MAX_PATH] =  {
	"vo/engineer_mvm_bomb_destroyed02.mp3"
};

static char g_sBombDefusedHeavyResponses[][PLATFORM_MAX_PATH] =  {
	"vo/heavy_mvm_bomb_destroyed01.mp3"
};

static char g_sBombDefusedMedicResponses[][PLATFORM_MAX_PATH] =  {
	"vo/medic_mvm_bomb_destroyed01.mp3"
};

static char g_sBombDefusedSoldierResponses[][PLATFORM_MAX_PATH] =  {
	"vo/soldier_mvm_bomb_destroyed02.mp3"
};

stock void PrecacheSounds()
{
	PrecacheSound("mvm/mvm_bomb_warning.wav");
	PrecacheSound("mvm/mvm_bomb_explode.wav");
	PrecacheSound("mvm/mvm_bought_upgrade.wav");
	PrecacheSound("player/cyoa_pda_beep8.wav");
	PrecacheSound("vo/announcer_time_added.mp3");
	// TODO remove this after removing the bandaid
	PrecacheSound("vo/halloween_boo1.mp3");
	PrecacheSound("vo/halloween_boo2.mp3");
	PrecacheSound("vo/halloween_boo3.mp3");
	PrecacheSound("vo/halloween_boo4.mp3");
	PrecacheSound("vo/halloween_boo5.mp3");
	PrecacheSound("vo/halloween_boo6.mp3");
	PrecacheSound("vo/halloween_boo7.mp3");
	
	for (int i = 0; i < sizeof(g_sBombPlantedAnnouncerAlerts); i++)PrecacheSound(g_sBombPlantedAnnouncerAlerts[i]);
	for (int i = 0; i < sizeof(g_sBombPlantedEngineerAlerts); i++)PrecacheSound(g_sBombPlantedEngineerAlerts[i]);
	for (int i = 0; i < sizeof(g_sBombPlantedHeavyAlerts); i++)PrecacheSound(g_sBombPlantedHeavyAlerts[i]);
	for (int i = 0; i < sizeof(g_sBombPlantedMedicAlerts); i++)PrecacheSound(g_sBombPlantedMedicAlerts[i]);
	for (int i = 0; i < sizeof(g_sBombPlantedSoldierAlerts); i++)PrecacheSound(g_sBombPlantedSoldierAlerts[i]);
	for (int i = 0; i < sizeof(g_sBombDefusedEngineerResponses); i++)PrecacheSound(g_sBombDefusedEngineerResponses[i]);
	for (int i = 0; i < sizeof(g_sBombDefusedHeavyResponses); i++)PrecacheSound(g_sBombDefusedHeavyResponses[i]);
	for (int i = 0; i < sizeof(g_sBombDefusedMedicResponses); i++)PrecacheSound(g_sBombDefusedMedicResponses[i]);
	for (int i = 0; i < sizeof(g_sBombDefusedSoldierResponses); i++)PrecacheSound(g_sBombDefusedSoldierResponses[i]);
}

public void PlayAnnouncerBombAlert()
{
	EmitSoundToAll(g_sBombPlantedAnnouncerAlerts[GetRandomInt(0, sizeof(g_sBombPlantedAnnouncerAlerts) - 1)]);
}

public void ShoutBombWarnings()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) != g_bombPlantingTeam)
		{
			switch (TF2_GetPlayerClass(client))
			{
				case TFClass_Engineer:EmitSoundToAll(g_sBombPlantedEngineerAlerts[GetRandomInt(0, sizeof(g_sBombPlantedEngineerAlerts) - 1)], _, SNDCHAN_VOICE);
				case TFClass_Heavy:EmitSoundToAll(g_sBombPlantedHeavyAlerts[GetRandomInt(0, sizeof(g_sBombPlantedHeavyAlerts) - 1)], _, SNDCHAN_VOICE);
				case TFClass_Medic:EmitSoundToAll(g_sBombPlantedMedicAlerts[GetRandomInt(0, sizeof(g_sBombPlantedMedicAlerts) - 1)], _, SNDCHAN_VOICE);
				case TFClass_Soldier:EmitSoundToAll(g_sBombPlantedSoldierAlerts[GetRandomInt(0, sizeof(g_sBombPlantedSoldierAlerts) - 1)], _, SNDCHAN_VOICE);
			}
		}
	}
}

public Action Event_Pre_Teamplay_Broadcast_Audio(Event event, const char[] name, bool dontBroadcast)
{
	// Cancel various sounds that could still be playing here
	g_currentMusicKit.StopMusicForAll(Music_StartRound);
	g_currentMusicKit.StopMusicForAll(Music_StartAction);
	g_currentMusicKit.StopMusicForAll(Music_BombPlanted);
	g_currentMusicKit.StopMusicForAll(Music_RoundTenSecCount);
	g_currentMusicKit.StopMusicForAll(Music_BombTenSecCount);
	
	char sound[PLATFORM_MAX_PATH];
	event.GetString("sound", sound, sizeof(sound));
	TFTeam team = view_as<TFTeam>(event.GetInt("team"));
	
	if (StrEqual(sound, "Game.YourTeamWon"))
	{
		g_currentMusicKit.PlayMusicToTeam(team, Music_WonRound);
		return Plugin_Handled;
	}
	else if (StrEqual(sound, "Game.YourTeamLost") || StrEqual(sound, "Game.Stalemate"))
	{
		g_currentMusicKit.PlayMusicToTeam(team, Music_LostRound);
		return Plugin_Handled;
	}
	else if (StrEqual(sound, "Announcer.AM_RoundStartRandom"))
	{
		g_currentMusicKit.PlayMusicToAll(Music_StartAction);
		return Plugin_Continue;
	}
	
	return Plugin_Continue;
}

stock Action Play10SecondWarning(Handle timer)
{
	g_currentMusicKit.StopMusicForAll(Music_StartAction);
	g_currentMusicKit.PlayMusicToAll(Music_RoundTenSecCount);
	g_10SecondRoundTimer = null;
}

stock void PlayRoundStartMusic()
{
	g_currentMusicKit.StopMusicForAll(Music_WonRound);
	g_currentMusicKit.StopMusicForAll(Music_LostRound);
	g_currentMusicKit.PlayMusicToAll(Music_StartRound);
}
