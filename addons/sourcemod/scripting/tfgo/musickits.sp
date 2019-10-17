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
	char bombplanted[PLATFORM_MAX_PATH];
	char bombtenseccount[PLATFORM_MAX_PATH];
	char chooseteam[PLATFORM_MAX_PATH];
	char lostround[PLATFORM_MAX_PATH];
	char roundtenseccount[PLATFORM_MAX_PATH];
	char wonround[PLATFORM_MAX_PATH];
	
	// Multi-value sounds
	ArrayList startaction;
	ArrayList startround;
	ArrayList roundmvpanthem;
	
	void GetRandomMusicFile(char[] buffer, int maxlength, MusicType type)
	{
		switch (type)
		{
			case Music_BombPlanted:strcopy(buffer, maxlength, this.bombplanted);
			case Music_BombTenSecCount:strcopy(buffer, maxlength, this.bombtenseccount);
			case Music_ChooseTeam:strcopy(buffer, maxlength, this.chooseteam);
			case Music_LostRound:strcopy(buffer, maxlength, this.lostround);
			case Music_RoundTenSecCount:strcopy(buffer, maxlength, this.roundtenseccount);
			case Music_WonRound:strcopy(buffer, maxlength, this.wonround);
			case Music_StartRound:this.startround.GetString(GetRandomInt(0, this.startround.Length - 1), buffer, maxlength);
			case Music_StartAction:this.startaction.GetString(GetRandomInt(0, this.startaction.Length - 1), buffer, maxlength);
			case Music_RoundMVPAnthem:this.roundmvpanthem.GetString(GetRandomInt(0, this.roundmvpanthem.Length - 1), buffer, maxlength);
		}
	}
	
	void PlayMusicToClient(int client, MusicType type)
	{
		char sound[PLATFORM_MAX_PATH];
		this.GetRandomMusicFile(sound, sizeof(sound), type);
		EmitSoundToClient(client, sound);
	}
	
	void PlayMusicToTeam(TFTeam team, MusicType type)
	{
		char sound[PLATFORM_MAX_PATH];
		this.GetRandomMusicFile(sound, sizeof(sound), type);
		for (int client = 1; client <= MaxClients; client++)
		if (IsClientInGame(client) && TF2_GetClientTeam(client) == team)
			EmitSoundToClient(client, sound);
	}
	
	void PlayMusicToAll(MusicType type)
	{
		char sound[PLATFORM_MAX_PATH];
		this.GetRandomMusicFile(sound, sizeof(sound), type);
		EmitSoundToAll(sound);
	}
	
	void StopMusicForClient(int entity, MusicType type)
	{
		char sound[PLATFORM_MAX_PATH];
		switch (type)
		{
			case Music_BombPlanted:StopSound(entity, SNDCHAN_AUTO, this.bombplanted);
			case Music_BombTenSecCount:StopSound(entity, SNDCHAN_AUTO, this.bombtenseccount);
			case Music_ChooseTeam:StopSound(entity, SNDCHAN_AUTO, this.chooseteam);
			case Music_LostRound:StopSound(entity, SNDCHAN_AUTO, this.lostround);
			case Music_RoundTenSecCount:StopSound(entity, SNDCHAN_AUTO, this.roundtenseccount);
			case Music_WonRound:StopSound(entity, SNDCHAN_AUTO, this.wonround);
			case Music_StartRound:
			{
				for (int i = 0; i < this.startround.Length; i++)
				{
					this.startround.GetString(i, sound, sizeof(sound));
					StopSound(entity, SNDCHAN_AUTO, sound);
				}
			}
			case Music_StartAction:
			{
				for (int i = 0; i < this.startaction.Length; i++)
				{
					this.startaction.GetString(i, sound, sizeof(sound));
					StopSound(entity, SNDCHAN_AUTO, sound);
				}
			}
			case Music_RoundMVPAnthem:
			{
				for (int i = 0; i < this.roundmvpanthem.Length; i++)
				{
					this.roundmvpanthem.GetString(i, sound, sizeof(sound));
					StopSound(entity, SNDCHAN_AUTO, sound);
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
		PrecacheSound(this.bombplanted);
		StrCat(filename, sizeof(filename), this.bombplanted);
		AddFileToDownloadsTable(filename);
		
		filename = SOUND_PATH;
		PrecacheSound(this.bombtenseccount);
		StrCat(filename, sizeof(filename), this.bombtenseccount);
		AddFileToDownloadsTable(filename);
		
		filename = SOUND_PATH;
		PrecacheSound(this.chooseteam);
		StrCat(filename, sizeof(filename), this.chooseteam);
		AddFileToDownloadsTable(filename);
		
		filename = SOUND_PATH;
		PrecacheSound(this.lostround);
		StrCat(filename, sizeof(filename), this.lostround);
		AddFileToDownloadsTable(filename);
		
		filename = SOUND_PATH;
		PrecacheSound(this.roundtenseccount);
		StrCat(filename, sizeof(filename), this.roundtenseccount);
		AddFileToDownloadsTable(filename);
		
		filename = SOUND_PATH;
		PrecacheSound(this.wonround);
		StrCat(filename, sizeof(filename), this.wonround);
		AddFileToDownloadsTable(filename);
		
		char sound[PLATFORM_MAX_PATH];
		for (int i = 0; i < this.startround.Length; i++)
		{
			this.startround.GetString(i, sound, sizeof(sound));
			PrecacheSound(sound);
			filename = SOUND_PATH;
			StrCat(filename, sizeof(filename), sound);
			AddFileToDownloadsTable(filename);
		}
		
		for (int i = 0; i < this.startaction.Length; i++)
		{
			this.startaction.GetString(i, sound, sizeof(sound));
			PrecacheSound(sound);
			filename = SOUND_PATH;
			StrCat(filename, sizeof(filename), sound);
			AddFileToDownloadsTable(filename);
		}
		
		for (int i = 0; i < this.roundmvpanthem.Length; i++)
		{
			this.roundmvpanthem.GetString(i, sound, sizeof(sound));
			PrecacheSound(sound);
			filename = SOUND_PATH;
			StrCat(filename, sizeof(filename), sound);
			AddFileToDownloadsTable(filename);
		}
	}
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
						kv.GetString(NULL_STRING, kit.bombplanted, sizeof(kit.bombplanted));
					else if (StrEqual(title, "bombtenseccount"))
						kv.GetString(NULL_STRING, kit.bombtenseccount, sizeof(kit.bombtenseccount));
					else if (StrEqual(title, "chooseteam"))
						kv.GetString(NULL_STRING, kit.chooseteam, sizeof(kit.chooseteam));
					else if (StrEqual(title, "lostround"))
						kv.GetString(NULL_STRING, kit.lostround, sizeof(kit.lostround));
					else if (StrEqual(title, "roundtenseccount"))
						kv.GetString(NULL_STRING, kit.roundtenseccount, sizeof(kit.roundtenseccount));
					else if (StrEqual(title, "wonround"))
						kv.GetString(NULL_STRING, kit.wonround, sizeof(kit.wonround));
					else if (StrEqual(title, "startround") || StrEqual(title, "startaction") || StrEqual(title, "roundmvpanthem"))
					{
						ArrayList list = new ArrayList(PLATFORM_MAX_PATH);
						char buffers[32][PLATFORM_MAX_PATH];
						kv.GetString(NULL_STRING, temp, sizeof(temp));
						int count = ExplodeString(temp, ";", buffers, sizeof(buffers), sizeof(buffers[]));
						for (int i = 0; i < count; i++)list.PushString(buffers[i]);
						
						if (StrEqual(title, "startround"))
							kit.startround = list;
						else if (StrEqual(title, "startaction"))
							kit.startaction = list;
						else if (StrEqual(title, "roundmvpanthem"))
							kit.roundmvpanthem = list;
					}
					else
						LogError("Found unrecognized sound %s", title);
				}
				while (kv.GotoNextKey(false));
			}
			kv.GoBack();
			
			g_hMusicKits.SetArray(name, kit, sizeof(kit));
		}
		while (kv.GotoNextKey(false));
		kv.GoBack();
	}
	kv.GoBack();
}

void MusicKit_Init()
{
	if (g_hMusicKits == null)
		g_hMusicKits = new StringMap();
	
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
