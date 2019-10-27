#define MUSIC_KIT_FILE "configs/tfgo/musickits.cfg"
#define SOUND_PATH "sound/"

enum MusicType
{
	Music_BombPlanted, 
	Music_BombTenSecCount, 
	Music_ChooseTeam, 
	Music_LostRound, 
	Music_RoundTenSecCount, 
	Music_WonRound, 
	Music_StartAction, 
	Music_StartRound, 
	Music_RoundMVPAnthem
}

enum struct MusicKit
{
	// Unique identifier of this music kit
	char name[PLATFORM_MAX_PATH];
	
	// Single-value sounds
	char bombPlanted[PLATFORM_MAX_PATH];
	char bombTenSecCount[PLATFORM_MAX_PATH];
	char chooseTeam[PLATFORM_MAX_PATH];
	char lostRound[PLATFORM_MAX_PATH];
	char roundTenSecCount[PLATFORM_MAX_PATH];
	char wonRound[PLATFORM_MAX_PATH];
	
	// Multi-value sounds
	ArrayList startRound;
	ArrayList startAction;
	ArrayList roundMvpAnthem;
	
	void GetRandomMusicFile(char[] buffer, int maxlength, MusicType type)
	{
		switch (type)
		{
			case Music_BombPlanted:strcopy(buffer, maxlength, this.bombPlanted);
			case Music_BombTenSecCount:strcopy(buffer, maxlength, this.bombTenSecCount);
			case Music_ChooseTeam:strcopy(buffer, maxlength, this.chooseTeam);
			case Music_LostRound:strcopy(buffer, maxlength, this.lostRound);
			case Music_RoundTenSecCount:strcopy(buffer, maxlength, this.roundTenSecCount);
			case Music_WonRound:strcopy(buffer, maxlength, this.wonRound);
			case Music_StartRound:this.startRound.GetString(GetRandomInt(0, this.startRound.Length - 1), buffer, maxlength);
			case Music_StartAction:this.startAction.GetString(GetRandomInt(0, this.startAction.Length - 1), buffer, maxlength);
			case Music_RoundMVPAnthem:this.roundMvpAnthem.GetString(GetRandomInt(0, this.roundMvpAnthem.Length - 1), buffer, maxlength);
		}
	}
	
	void PlayMusicToClient(int client, MusicType type)
	{
		char sound[PLATFORM_MAX_PATH];
		this.GetRandomMusicFile(sound, sizeof(sound), type);
		EmitSoundToClient(client, sound, _, SNDCHAN_STATIC);
	}
	
	void PlayMusicToTeam(TFTeam team, MusicType type)
	{
		char sound[PLATFORM_MAX_PATH];
		this.GetRandomMusicFile(sound, sizeof(sound), type);
		for (int client = 1; client <= MaxClients; client++)
		if (IsClientInGame(client) && TF2_GetClientTeam(client) == team)
			EmitSoundToClient(client, sound, _, SNDCHAN_STATIC);
	}
	
	void PlayMusicToAll(MusicType type)
	{
		char sound[PLATFORM_MAX_PATH];
		this.GetRandomMusicFile(sound, sizeof(sound), type);
		EmitSoundToAll(sound, _, SNDCHAN_STATIC);
	}
	
	void StopMusicForClient(int entity, MusicType type)
	{
		char sound[PLATFORM_MAX_PATH];
		switch (type)
		{
			case Music_BombPlanted:StopSound(entity, SNDCHAN_STATIC, this.bombPlanted);
			case Music_BombTenSecCount:StopSound(entity, SNDCHAN_STATIC, this.bombTenSecCount);
			case Music_ChooseTeam:StopSound(entity, SNDCHAN_STATIC, this.chooseTeam);
			case Music_LostRound:StopSound(entity, SNDCHAN_STATIC, this.lostRound);
			case Music_RoundTenSecCount:StopSound(entity, SNDCHAN_STATIC, this.roundTenSecCount);
			case Music_WonRound:StopSound(entity, SNDCHAN_STATIC, this.wonRound);
			case Music_StartRound:
			{
				for (int i = 0; i < this.startRound.Length; i++)
				{
					this.startRound.GetString(i, sound, sizeof(sound));
					StopSound(entity, SNDCHAN_STATIC, sound);
				}
			}
			case Music_StartAction:
			{
				for (int i = 0; i < this.startAction.Length; i++)
				{
					this.startAction.GetString(i, sound, sizeof(sound));
					StopSound(entity, SNDCHAN_STATIC, sound);
				}
			}
			case Music_RoundMVPAnthem:
			{
				for (int i = 0; i < this.roundMvpAnthem.Length; i++)
				{
					this.roundMvpAnthem.GetString(i, sound, sizeof(sound));
					StopSound(entity, SNDCHAN_STATIC, sound);
				}
			}
		}
	}
	
	void StopMusicForTeam(TFTeam team, MusicType type)
	{
		for (int client = 1; client <= MaxClients; client++)
		if (IsClientInGame(client) && TF2_GetClientTeam(client) == team)
			this.StopMusicForClient(client, type);
	}
	
	void StopMusicForAll(MusicType type)
	{
		for (int client = 1; client <= MaxClients; client++)
		this.StopMusicForClient(client, type);
	}
	
	void PrecacheSounds()
	{
		char filename[PLATFORM_MAX_PATH];
		
		filename = SOUND_PATH;
		PrecacheSound(this.bombPlanted);
		StrCat(filename, sizeof(filename), this.bombPlanted);
		AddFileToDownloadsTable(filename);
		
		filename = SOUND_PATH;
		PrecacheSound(this.bombTenSecCount);
		StrCat(filename, sizeof(filename), this.bombTenSecCount);
		AddFileToDownloadsTable(filename);
		
		filename = SOUND_PATH;
		PrecacheSound(this.chooseTeam);
		StrCat(filename, sizeof(filename), this.chooseTeam);
		AddFileToDownloadsTable(filename);
		
		filename = SOUND_PATH;
		PrecacheSound(this.lostRound);
		StrCat(filename, sizeof(filename), this.lostRound);
		AddFileToDownloadsTable(filename);
		
		filename = SOUND_PATH;
		PrecacheSound(this.roundTenSecCount);
		StrCat(filename, sizeof(filename), this.roundTenSecCount);
		AddFileToDownloadsTable(filename);
		
		filename = SOUND_PATH;
		PrecacheSound(this.wonRound);
		StrCat(filename, sizeof(filename), this.wonRound);
		AddFileToDownloadsTable(filename);
		
		char sound[PLATFORM_MAX_PATH];
		for (int i = 0; i < this.startRound.Length; i++)
		{
			this.startRound.GetString(i, sound, sizeof(sound));
			PrecacheSound(sound);
			filename = SOUND_PATH;
			StrCat(filename, sizeof(filename), sound);
			AddFileToDownloadsTable(filename);
		}
		
		for (int i = 0; i < this.startAction.Length; i++)
		{
			this.startAction.GetString(i, sound, sizeof(sound));
			PrecacheSound(sound);
			filename = SOUND_PATH;
			StrCat(filename, sizeof(filename), sound);
			AddFileToDownloadsTable(filename);
		}
		
		for (int i = 0; i < this.roundMvpAnthem.Length; i++)
		{
			this.roundMvpAnthem.GetString(i, sound, sizeof(sound));
			PrecacheSound(sound);
			filename = SOUND_PATH;
			StrCat(filename, sizeof(filename), sound);
			AddFileToDownloadsTable(filename);
		}
	}
}

public void PrecacheMusicKits()
{
	// Precache all music kit sounds
	StringMapSnapshot snapshot = g_availableMusicKits.Snapshot();
	for (int i = 0; i < snapshot.Length; i++)
	{
		char name[PLATFORM_MAX_PATH];
		snapshot.GetKey(i, name, sizeof(name));
		
		MusicKit kit;
		g_availableMusicKits.GetArray(name, kit, sizeof(kit));
		kit.PrecacheSounds();
	}
	delete snapshot;
}

void ReadMusicKitConfig(KeyValues kv)
{
	if (kv.GotoFirstSubKey(false))
	{
		do // Loop through each music kit
		{
			MusicKit kit;
			char name[PLATFORM_MAX_PATH];
			kv.GetSectionName(name, sizeof(name));
			kit.name = name;
			
			if (kv.GotoFirstSubKey(false))
			{
				do // Loop through each music kit
				{
					char title[PLATFORM_MAX_PATH];
					kv.GetSectionName(title, sizeof(title));
					
					// Big array for semicolon-separated multi-value sounds
					char temp[2048];
					
					// Collect all known sounds
					if (StrEqual(title, "bombplanted"))
						kv.GetString(NULL_STRING, kit.bombPlanted, sizeof(kit.bombPlanted));
					else if (StrEqual(title, "bombtenseccount"))
						kv.GetString(NULL_STRING, kit.bombTenSecCount, sizeof(kit.bombTenSecCount));
					else if (StrEqual(title, "chooseteam"))
						kv.GetString(NULL_STRING, kit.chooseTeam, sizeof(kit.chooseTeam));
					else if (StrEqual(title, "lostround"))
						kv.GetString(NULL_STRING, kit.lostRound, sizeof(kit.lostRound));
					else if (StrEqual(title, "roundtenseccount"))
						kv.GetString(NULL_STRING, kit.roundTenSecCount, sizeof(kit.roundTenSecCount));
					else if (StrEqual(title, "wonround"))
						kv.GetString(NULL_STRING, kit.wonRound, sizeof(kit.wonRound));
					else if (StrEqual(title, "startround") || StrEqual(title, "startaction") || StrEqual(title, "roundmvpanthem"))
					{
						ArrayList list = new ArrayList(PLATFORM_MAX_PATH);
						char buffers[32][PLATFORM_MAX_PATH];
						kv.GetString(NULL_STRING, temp, sizeof(temp));
						int count = ExplodeString(temp, ";", buffers, sizeof(buffers), sizeof(buffers[]));
						for (int i = 0; i < count; i++)list.PushString(buffers[i]);
						
						if (StrEqual(title, "startround"))
							kit.startRound = list;
						else if (StrEqual(title, "startaction"))
							kit.startAction = list;
						else if (StrEqual(title, "roundmvpanthem"))
							kit.roundMvpAnthem = list;
					}
					else
						LogError("Found unrecognized sound %s", title);
				}
				while (kv.GotoNextKey(false));
			}
			kv.GoBack();
			
			g_availableMusicKits.SetArray(name, kit, sizeof(kit));
		}
		while (kv.GotoNextKey(false));
		kv.GoBack();
	}
	kv.GoBack();
}

void MusicKit_Init()
{
	if (g_availableMusicKits == null)
		g_availableMusicKits = new StringMap();
	
	// Read config
	KeyValues kv = new KeyValues("MusicKits");
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), MUSIC_KIT_FILE);
	if (kv.ImportFromFile(path))
	{
		ReadMusicKitConfig(kv);
		delete kv;
	}
}