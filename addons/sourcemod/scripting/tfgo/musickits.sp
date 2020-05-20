static StringMap DefaultMusicKits;
static StringMap CustomMusicKits;

void MusicKit_Init()
{
	DefaultMusicKits = new StringMap();
	CustomMusicKits = new StringMap();
	
	// Default music kits
	MusicKit_RegisterMusicKit("valve_csgo_01", "sound/tfgo/music/valve_csgo_01/game_sounds_music.txt", true);
	MusicKit_RegisterMusicKit("valve_csgo_02", "sound/tfgo/music/valve_csgo_02/game_sounds_music.txt", true);
}

void MusicKit_Precache()
{
	SoundScriptStringMapPrecache(DefaultMusicKits);
	SoundScriptStringMapPrecache(CustomMusicKits);
}

static void SoundScriptStringMapPrecache(StringMap map)
{
	StringMapSnapshot snapshot = map.Snapshot();
	for (int i = 0; i < snapshot.Length; i++)
	{
		int keyBufferSize = snapshot.KeyBufferSize(i);
		char[] key = new char[keyBufferSize];
		snapshot.GetKey(i, key, keyBufferSize);
		
		SoundScript soundScript;
		if (map.GetValue(key, soundScript))
			PrecacheSoundScriptEntries(soundScript);
	}
	delete snapshot;
}

bool MusicKit_RegisterMusicKit(const char[] name, const char[] path, bool isDefault = false, bool precache = false)
{
	SoundScript soundScript = LoadSoundScript(path);
	if (precache)
		PrecacheSoundScriptEntries(soundScript);
	return isDefault ? DefaultMusicKits.SetValue(name, soundScript) : CustomMusicKits.SetValue(name, soundScript);
}

void MusicKit_SetMusicKit(int client, const char[] name)
{
	SoundScript soundScript;
	if (CustomMusicKits.GetValue(name, soundScript) || DefaultMusicKits.GetValue(name, soundScript))
	{
		TFGOPlayer(client).SetMusicKit(name);
	}
	else
	{
		LogError("Invalid music kit %s, falling back to random default kit", name);
		MusicKit_SetRandomDefaultMusicKit(client);
	}
}

void MusicKit_SetRandomDefaultMusicKit(int client)
{
	StringMapSnapshot snapshot = DefaultMusicKits.Snapshot();
	if (snapshot.Length > 0)
	{
		int i = GetRandomInt(0, snapshot.Length - 1);
		int keyBufferSize = snapshot.KeyBufferSize(i);
		char[] key = new char[keyBufferSize];
		snapshot.GetKey(i, key, keyBufferSize);
		TFGOPlayer(client).SetMusicKit(key);
		delete snapshot;
	}
	else
	{
		delete snapshot;
		ThrowError("No default music kits found");
	}
}

void MusicKit_PlayKitsToClients(MusicType type)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		char sound[PLATFORM_MAX_PATH];
		if (BuildGameSound(client, type, sound, sizeof(sound)) > 0)
		{
			TFGOPlayer player = TFGOPlayer(client);
			char previousSound[PLATFORM_MAX_PATH];
			player.GetPreviousPlayedSound(previousSound, sizeof(previousSound));
			StopGameSound(client, previousSound);
			player.SetPreviousPlayedSound(sound);
			EmitGameSoundToClient(client, sound);
		}
	}
}

bool MusicKit_HasCustomMusicKit(int client)
{
	char kit[PLATFORM_MAX_PATH];
	SoundScript soundScript;
	return TFGOPlayer(client).GetMusicKit(kit, sizeof(kit)) > 0 && CustomMusicKits.GetValue(ClientMusicKits[client], soundScript);
}

void MusicKit_PlayMVPAnthem(int mvp)
{
	char sound[PLATFORM_MAX_PATH];
	if (BuildGameSound(mvp, Music_MVPAnthem, sound, sizeof(sound)) > 0)
	{
		char name[MAX_NAME_LENGTH];
		GetClientName(mvp, name, sizeof(name));
		
		for (int client = 1; client <= MaxClients; client++)
		{
			if (mvp == client)
				PrintToChatAll("%T", "Playing_MVP_MusicKit_Yours", LANG_SERVER);
			else
				PrintToChatAll("%T", "Playing_MVP_MusicKit", LANG_SERVER, name);
			
			StopGameSound(client, PreviousPlayedSounds[client]);
			strcopy(PreviousPlayedSounds[client], sizeof(PreviousPlayedSounds[]), sound);
			EmitGameSoundToClient(client, sound);
		}
	}
}

void MusicKit_PlayKitsToTeam(TFTeam team, MusicType type)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && TF2_GetClientTeam(client) == team)
		{
			char sound[PLATFORM_MAX_PATH];
			if (BuildGameSound(client, type, sound, sizeof(sound)) > 0)
			{
				TFGOPlayer player = TFGOPlayer(client);
				char previousSound[PLATFORM_MAX_PATH];
				player.GetPreviousPlayedSound(previousSound, sizeof(previousSound));
				StopGameSound(client, previousSound);
				player.SetPreviousPlayedSound(sound);
				EmitGameSoundToClient(client, sound);
			}
		}
	}
}

stock void PrecacheSoundScriptEntries(SoundScript soundScript)
{
	for (int i = 0; i < soundScript.Count; i++)
	{
		SoundEntry entry = soundScript.GetSound(i);
		char sound[PLATFORM_MAX_PATH];
		entry.GetName(sound, sizeof(sound));
		PrecacheScriptSound(sound);
		AddScriptSoundToDownloadsTable(sound);
	}
}

stock int BuildGameSound(int client, MusicType type, char[] buffer, int maxlen)
{
	char entry[PLATFORM_MAX_PATH];
	if (GetEntryNameForMusicType(type, entry, sizeof(entry)) > 0)
	{
		char kit[PLATFORM_MAX_PATH];
		if (TFGOPlayer(client).GetMusicKit(kit, sizeof(kit)) > 0)
			return Format(buffer, maxlen, "%s.%s", entry, kit);
	}
	
	return 0;
}

stock int GetEntryNameForMusicType(MusicType type, char[] buffer, int maxlen)
{
	switch (type)
	{
		case Music_StartRound: return strcopy(buffer, maxlen, "Music.StartRound");
		case Music_StartAction: return strcopy(buffer, maxlen, "Music.StartAction");
		case Music_BombPlanted: return strcopy(buffer, maxlen, "Music.BombPlanted");
		case Music_BombTenSecCount: return strcopy(buffer, maxlen, "Music.BombTenSecCount");
		case Music_TenSecCount: return strcopy(buffer, maxlen, "Music.TenSecCount");
		case Music_WonRound: return strcopy(buffer, maxlen, "Music.WonRound");
		case Music_LostRound: return strcopy(buffer, maxlen, "Music.LostRound");
		case Music_DeathCam: return strcopy(buffer, maxlen, "Music.DeathCam");
		case Music_MVPAnthem: return strcopy(buffer, maxlen, "Music.MVPAnthem");
		default: return 0;
	}
}
