
static char g_sStartRoundMusic[][PLATFORM_MAX_PATH] =  {
	"tfgo/music/valve_csgo_01/startround_01.mp3", 
	"tfgo/music/valve_csgo_01/startround_02.mp3", 
	"tfgo/music/valve_csgo_01/startround_03.mp3"
};

static char g_sStartActionMusic[][PLATFORM_MAX_PATH] =  {
	"tfgo/music/valve_csgo_01/startaction_01.mp3"
};

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
	AddFileToDownloadsTable ("sound/tfgo/music/valve_csgo_01/wonround.mp3");
	AddFileToDownloadsTable ("sound/tfgo/music/valve_csgo_01/lostround.mp3");
	AddFileToDownloadsTable ("sound/tfgo/music/valve_csgo_01/roundtenseccount.mp3");
	AddFileToDownloadsTable ("sound/tfgo/music/valve_csgo_01/bombtenseccount.mp3");
	AddFileToDownloadsTable ("sound/tfgo/music/valve_csgo_01/chooseteam.mp3");
	AddFileToDownloadsTable ("sound/tfgo/music/valve_csgo_01/bombplanted.mp3");
	
	PrecacheSound("tfgo/music/valve_csgo_01/wonround.mp3");
	PrecacheSound("tfgo/music/valve_csgo_01/lostround.mp3");
	PrecacheSound("tfgo/music/valve_csgo_01/roundtenseccount.mp3");
	PrecacheSound("tfgo/music/valve_csgo_01/bombtenseccount.mp3");
	PrecacheSound("tfgo/music/valve_csgo_01/chooseteam.mp3");
	PrecacheSound("tfgo/music/valve_csgo_01/bombplanted.mp3");
	PrecacheSound("mvm/mvm_bomb_warning.wav");
	PrecacheSound("mvm/mvm_bomb_explode.wav");
	PrecacheSound("mvm/mvm_bought_upgrade.wav");
	PrecacheSound("vo/announcer_time_added.mp3");
	
	// TODO remove this after removing the bandaid
	PrecacheSound("vo/halloween_boo1.mp3");
	PrecacheSound("vo/halloween_boo2.mp3");
	PrecacheSound("vo/halloween_boo3.mp3");
	PrecacheSound("vo/halloween_boo4.mp3");
	PrecacheSound("vo/halloween_boo5.mp3");
	PrecacheSound("vo/halloween_boo6.mp3");
	PrecacheSound("vo/halloween_boo7.mp3");

	for (int i = 0; i < sizeof(g_sStartRoundMusic); i++)PrecacheSound(g_sStartRoundMusic[i]);
	for (int i = 0; i < sizeof(g_sStartActionMusic); i++)PrecacheSound(g_sStartActionMusic[i]);
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
		if (IsClientInGame(client) && GetClientTeam(client) != g_iBombPlanterTeam)
		{
			switch (TF2_GetPlayerClass(client))
			{
				case TFClass_Engineer:
				{
					EmitSoundToAll(g_sBombPlantedEngineerAlerts[GetRandomInt(0, sizeof(g_sBombPlantedEngineerAlerts) - 1)], _, SNDCHAN_VOICE);
				}
				case TFClass_Heavy:
				{
					EmitSoundToAll(g_sBombPlantedHeavyAlerts[GetRandomInt(0, sizeof(g_sBombPlantedHeavyAlerts) - 1)], _, SNDCHAN_VOICE);
				}
				case TFClass_Medic:
				{
					EmitSoundToAll(g_sBombPlantedMedicAlerts[GetRandomInt(0, sizeof(g_sBombPlantedMedicAlerts) - 1)], _, SNDCHAN_VOICE);
				}
				case TFClass_Soldier:
				{
					EmitSoundToAll(g_sBombPlantedSoldierAlerts[GetRandomInt(0, sizeof(g_sBombPlantedSoldierAlerts) - 1)], _, SNDCHAN_VOICE);
				}
			}
		}
	}
}

stock void EmitSoundToTeam(int team, const char[] sound)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == team)
		{
			EmitSoundToClient(client, sound);
		}
	}
}

public Action Event_Pre_Broadcast_Audio(Event event, const char[] name, bool dontBroadcast)
{
	// Cancel various sounds that could still be playing here
	StopRoundActionMusic();
	StopSoundForAll(SNDCHAN_AUTO, "tfgo/music/valve_csgo_01/bombplanted.mp3");
	StopSoundForAll(SNDCHAN_AUTO, "tfgo/music/valve_csgo_01/roundtenseccount.mp3");
	StopSoundForAll(SNDCHAN_AUTO, "tfgo/music/valve_csgo_01/bombtenseccount.mp3");
	
	char sound[PLATFORM_MAX_PATH];
	event.GetString("sound", sound, sizeof(sound));
	int team = event.GetInt("team");
	
	if (strcmp(sound, "Game.YourTeamWon") == 0)
	{
		EmitSoundToTeam(team, "tfgo/music/valve_csgo_01/wonround.mp3");
		return Plugin_Handled;
	}
	else if (strcmp(sound, "Game.YourTeamLost") == 0 || strcmp(sound, "Game.Stalemate") == 0)
	{
		EmitSoundToTeam(team, "tfgo/music/valve_csgo_01/lostround.mp3");
		return Plugin_Handled;
	}
	else if (strcmp(sound, "Announcer.AM_RoundStartRandom") == 0)
	{
		for (int i = 0; i < sizeof(g_sStartRoundMusic); i++)StopSoundForAll(SNDCHAN_AUTO, g_sStartRoundMusic[i]);
		int iRandom = GetRandomInt(0, sizeof(g_sStartActionMusic) - 1);
		EmitSoundToAll(g_sStartActionMusic[iRandom]);
		return Plugin_Continue;
	}
	
	return Plugin_Continue;
}

stock Action Play10SecondWarning(Handle timer)
{
	StopRoundActionMusic(); // if it is still playing for whatever reason
	EmitSoundToAll("tfgo/music/valve_csgo_01/roundtenseccount.mp3");
	g_h10SecondRoundTimer = null;
}

stock Action Play10SecondBombWarning(Handle timer)
{
	StopSoundForAll(SNDCHAN_AUTO, "tfgo/music/valve_csgo_01/bombplanted.mp3");
	EmitSoundToAll("tfgo/music/valve_csgo_01/bombtenseccount.mp3");
	g_h10SecondBombTimer = null;
}


stock void PlayRoundStartMusic()
{
	StopSoundForAll(SNDCHAN_AUTO, "tfgo/music/valve_csgo_01/wonround.mp3");
	StopSoundForAll(SNDCHAN_AUTO, "tfgo/music/valve_csgo_01/lostround.mp3");
	int iRandom = GetRandomInt(0, sizeof(g_sStartRoundMusic) - 1);
	EmitSoundToAll(g_sStartRoundMusic[iRandom]);
}

stock void StopRoundActionMusic()
{
	for (int i = 0; i < sizeof(g_sStartActionMusic); i++)
	{
		StopSoundForAll(SNDCHAN_AUTO, g_sStartActionMusic[i]);
	}
}

stock void StopSoundForAll(int channel, const char[] sound)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i <= MaxClients && IsClientConnected(i))
		{
			StopSound(i, channel, sound);
		}
	}
}
