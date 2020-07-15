static char MinigunShootCritSounds[][] = {
	")weapons/dragon_gun_motor_loop_crit.wav",
	")weapons/gatling_shoot_crit.wav",
	")weapons/minifun_shoot_crit.wav",
	")weapons/minigun_shoot_crit.wav",
	")weapons/tomislav_shoot_crit.wav"
};

static char FlameThrowerLoopCritSounds[][] = {
	")weapons/flame_thrower_bb_loop_crit.wav",
	")weapons/flame_thrower_dg_loop_crit.wav",
	")weapons/flame_thrower_loop_crit.wav",
	")weapons/phlog_loop_crit.wav",
};

void Sound_Precache()
{
	PrecacheSound(SOUND_BOMB_BEEPING);
	
	PrecacheScriptSound(GAMESOUND_BOMB_EXPLOSION);
	PrecacheScriptSound(GAMESOUND_BOMB_WARNING);
	PrecacheScriptSound(GAMESOUND_PLAYER_PURCHASE);
	PrecacheScriptSound(GAMESOUND_ANNOUNCER_BOMB_PLANTED);
	PrecacheScriptSound(GAMESOUND_ANNOUNCER_TEAM_SCRAMBLE);
}

Action NormalSoundHook(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	// Spatialized minigun and flame thrower crit sounds from headshots loop forever, block them entirely
	if (strncmp(sample, ")weapons/", 9) == 0)
	{
		for (int i = 0; i < sizeof(MinigunShootCritSounds); i++)
		{
			if (StrEqual(sample, MinigunShootCritSounds[i]))
				return Plugin_Handled;
		}
		
		for (int i = 0; i < sizeof(FlameThrowerLoopCritSounds); i++)
		{
			if (StrEqual(sample, FlameThrowerLoopCritSounds[i]))
				return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

Action Event_Pre_TeamplayBroadcastAudio(Event event, const char[] name, bool dontBroadcast)
{
	char sound[PLATFORM_MAX_PATH];
	event.GetString("sound", sound, sizeof(sound));
	TFTeam team = view_as<TFTeam>(event.GetInt("team"));
	
	if (strncmp(sound, "Game.", 5) == 0)
	{
		if (IsValidClient(g_MVP) && MusicKit_HasCustomMusicKit(g_MVP))
		{
			// MVP Anthem is already playing, just prevent any other sounds
			return Plugin_Handled;
		}
		else
		{
			if (StrEqual(sound, "Game.YourTeamWon"))
				MusicKit_PlayTeamMusicKits(team, Music_WonRound);
			else if (StrEqual(sound, "Game.YourTeamLost") || StrEqual(sound, "Game.Stalemate"))
				MusicKit_PlayTeamMusicKits(team, Music_LostRound);
			
			return Plugin_Handled;
		}
	}
	else if (StrEqual(sound, "Announcer.AM_RoundStartRandom"))
	{
		MusicKit_PlayAllClientMusicKits(Music_StartAction);
	}
	
	return Plugin_Continue;
}
