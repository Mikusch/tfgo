
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
	
};

static char g_sBombPlantedMedicAlerts[][PLATFORM_MAX_PATH] =  {
	
};

static char g_sBombPlantedHeavyAlerts[][PLATFORM_MAX_PATH] =  {
	
};

stock void PrecacheSounds()
{
	PrecacheSound("mvm/mvm_money_pickup.wav");
	PrecacheSound("mvm/mvm_money_vanish.wav");
	PrecacheSound("tfgo/music/valve_csgo_01/wonround.mp3");
	PrecacheSound("tfgo/music/valve_csgo_01/lostround.mp3");
	PrecacheSound("tfgo/music/valve_csgo_01/roundtenseccount.mp3");
	PrecacheSound("tfgo/music/valve_csgo_01/bombtenseccount.mp3");
	PrecacheSound("tfgo/music/valve_csgo_01/chooseteam.mp3");
	PrecacheSound("tfgo/music/valve_csgo_01/bombplanted.mp3");
	//PrecacheSound("mvm/sentrybuster/mvm_sentrybuster_loop.wav");
	PrecacheSound("mvm/mvm_bomb_explode.wav");
	PrecacheSound("mvm/mvm_bought_upgrade.wav");
	PrecacheSound("vo/announcer_time_added.mp3");
	for (int i = 0; i < sizeof(g_sStartRoundMusic); i++)PrecacheSound(g_sStartRoundMusic[i]);
	for (int i = 0; i < sizeof(g_sStartActionMusic); i++)PrecacheSound(g_sStartActionMusic[i]);
	for (int i = 0; i < sizeof(g_sBombPlantedAnnouncerAlerts); i++)PrecacheSound(g_sBombPlantedAnnouncerAlerts[i]);
}

public void PlayAnnouncerBombAlert()
{
	EmitSoundToAll(g_sBombPlantedAnnouncerAlerts[GetRandomInt(0, sizeof(g_sBombPlantedAnnouncerAlerts) - 1)]);
}

stock void EmitSoundToTeam(int iTeam, const char[] sound)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == iTeam)
		{
			EmitSoundToClient(i, sound);
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
