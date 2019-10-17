#define MUSIC_KIT_FILE "configs/tfgo/musickits.cfg"

enum struct MusicKit
{
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
}

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

public void PlayMusicToClient(int client, const char[] name, MusicType type)
{
	char sound[PLATFORM_MAX_PATH];
	GetRandomMusic(sound, sizeof(sound), name, type);
	EmitSoundToClient(client, sound);
}

public void PlayMusicToAll(const char[] name, MusicType type)
{
	char sound[PLATFORM_MAX_PATH];
	GetRandomMusic(sound, sizeof(sound), name, type);
	EmitSoundToAll(sound);
}

public void PlayMusicToTeam(TFTeam team, const char[] name, MusicType type)
{
	char sound[PLATFORM_MAX_PATH];
	GetRandomMusic(sound, sizeof(sound), name, type);
	for (int client = 1; client <= MaxClients; client++)
	if (IsClientInGame(client) && TF2_GetClientTeam(client) == team)
		EmitSoundToClient(client, sound);
}

public void GetRandomMusic(char[] buffer, int maxlength, const char[] name, MusicType type)
{
	MusicKit kit;
	g_hMusicKits.GetArray(name, kit, sizeof(kit));
	
	switch (type)
	{
		case Music_BombPlanted:strcopy(buffer, maxlength, kit.bombplanted);
		case Music_BombTenSecCount:strcopy(buffer, maxlength, kit.bombtenseccount);
		case Music_ChooseTeam:strcopy(buffer, maxlength, kit.chooseteam);
		case Music_LostRound:strcopy(buffer, maxlength, kit.lostround);
		case Music_RoundTenSecCount:strcopy(buffer, maxlength, kit.roundtenseccount);
		case Music_WonRound:strcopy(buffer, maxlength, kit.wonround);
		case Music_StartRound:kit.startround.GetString(GetRandomInt(0, kit.startround.Length - 1), buffer, maxlength);
		case Music_StartAction:kit.startaction.GetString(GetRandomInt(0, kit.startaction.Length - 1), buffer, maxlength);
		case Music_RoundMVPAnthem:kit.roundmvpanthem.GetString(GetRandomInt(0, kit.roundmvpanthem.Length - 1), buffer, maxlength);
	}
}

public void StopMusicForClient(int entity, const char[] name, MusicType type)
{
	MusicKit kit;
	g_hMusicKits.GetArray(name, kit, sizeof(kit));
	
	switch (type)
	{
		case Music_BombPlanted:StopSound(entity, SNDCHAN_AUTO, kit.bombplanted);
		case Music_BombTenSecCount:StopSound(entity, SNDCHAN_AUTO, kit.bombtenseccount);
		case Music_ChooseTeam:StopSound(entity, SNDCHAN_AUTO, kit.chooseteam);
		case Music_LostRound:StopSound(entity, SNDCHAN_AUTO, kit.lostround);
		case Music_RoundTenSecCount:StopSound(entity, SNDCHAN_AUTO, kit.roundtenseccount);
		case Music_WonRound:StopSound(entity, SNDCHAN_AUTO, kit.wonround);
		case Music_StartRound:
		{
			for (int i = 0; i < kit.startround.Length; i++)
			{
				char sound[PLATFORM_MAX_PATH];
				kit.startround.GetString(i, sound, sizeof(sound));
				StopSound(entity, SNDCHAN_AUTO, sound);
			}
		}
		case Music_StartAction:
		{
			for (int i = 0; i < kit.startaction.Length; i++)
			{
				char sound[PLATFORM_MAX_PATH];
				kit.startaction.GetString(i, sound, sizeof(sound));
				StopSound(entity, SNDCHAN_AUTO, sound);
			}
		}
		case Music_RoundMVPAnthem:
		{
			for (int i = 0; i < kit.roundmvpanthem.Length; i++)
			{
				char sound[PLATFORM_MAX_PATH];
				kit.roundmvpanthem.GetString(i, sound, sizeof(sound));
				StopSound(entity, SNDCHAN_AUTO, sound);
			}
		}
	}
}

public void StopMusicForTeam(TFTeam team, const char[] name, MusicType type)
{
	for (int client = 1; client <= MaxClients; client++)
	if (IsClientInGame(client) && TF2_GetClientTeam(client) == team)
		StopMusicForClient(client, name, type);
}

public void StopMusicForAll(const char[] name, MusicType type)
{
	for (int client = 1; client <= MaxClients; client++)
	StopMusicForClient(client, name, type);
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
						ExplodeString(temp, ";", buffers, sizeof(buffers), sizeof(buffers[]));
						for (int i = 0; i < sizeof(buffers); i++)list.PushString(buffers[i]);
						
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
