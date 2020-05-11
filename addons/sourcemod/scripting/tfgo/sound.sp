static char MinigunShootCritSounds[][] = {
	")weapons/dragon_gun_motor_loop_crit.wav",
	")weapons/gatling_shoot_crit.wav",
	")weapons/minifun_shoot_crit.wav",
	")weapons/minigun_shoot_crit.wav",
	")weapons/tomislav_shoot_crit.wav"
};

static char EngineerBombSeeGameSounds[][] =  {
	"engineer_mvm_bomb_see01", 
	"engineer_mvm_bomb_see02", 
	"engineer_mvm_bomb_see03"
};

static char HeavyBombSeeGameSounds[][] =  {
	"heavy_mvm_bomb_see01"
};

static char MedicBombSeeGameSounds[][] =  {
	"medic_mvm_bomb_see01", 
	"medic_mvm_bomb_see02", 
	"medic_mvm_bomb_see03"
};

static char SoldierBombSeeGameSounds[][] =  {
	"soldier_mvm_bomb_see01", 
	"soldier_mvm_bomb_see02", 
	"soldier_mvm_bomb_see03"
};

void Sound_Precache()
{
	PrecacheSound(SOUND_BOMB_BEEPING);
	PrecacheSound("mvm/mvm_bomb_explode.wav");
	
	PrecacheScriptSound(GAMESOUND_BOMB_EXPLOSION);
	PrecacheScriptSound(GAMESOUND_BOMB_WARNING);
	PrecacheScriptSound(GAMESOUND_PLAYER_PURCHASE);
	PrecacheScriptSound(GAMESOUND_ANNOUNCER_BOMB_PLANTED);
	PrecacheScriptSound(GAMESOUND_ANNOUNCER_TEAM_SCRAMBLE);
	
	for (int i = 0; i < sizeof(EngineerBombSeeGameSounds); i++) PrecacheScriptSound(EngineerBombSeeGameSounds[i]);
	for (int i = 0; i < sizeof(HeavyBombSeeGameSounds); i++) PrecacheScriptSound(HeavyBombSeeGameSounds[i]);
	for (int i = 0; i < sizeof(MedicBombSeeGameSounds); i++) PrecacheScriptSound(MedicBombSeeGameSounds[i]);
	for (int i = 0; i < sizeof(SoldierBombSeeGameSounds); i++) PrecacheScriptSound(SoldierBombSeeGameSounds[i]);
}

void EmitBombSeeGameSounds()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && IsPlayerAlive(client) && TF2_GetClientTeam(client) != g_BombPlantingTeam)
		{
			switch (TF2_GetPlayerClass(client))
			{
				case TFClass_Engineer: EmitGameSoundToAll(EngineerBombSeeGameSounds[GetRandomInt(0, sizeof(EngineerBombSeeGameSounds) - 1)]);
				case TFClass_Heavy: EmitGameSoundToAll(HeavyBombSeeGameSounds[GetRandomInt(0, sizeof(HeavyBombSeeGameSounds) - 1)]);
				case TFClass_Medic: EmitGameSoundToAll(MedicBombSeeGameSounds[GetRandomInt(0, sizeof(MedicBombSeeGameSounds) - 1)]);
				case TFClass_Soldier: EmitGameSoundToAll(SoldierBombSeeGameSounds[GetRandomInt(0, sizeof(SoldierBombSeeGameSounds) - 1)]);
			}
		}
	}
}

Action NormalSoundHook(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if (strncmp(sample, ")weapons/", 9) == 0)
	{
		// Spatialized minigun crit sounds from headshots loop forever, block them entirely
		for (int i = 0; i < sizeof(MinigunShootCritSounds); i++)
		{
			if (StrEqual(sample, MinigunShootCritSounds[i]))
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
