#define MUSIC_KIT_FILE "configs/tfgo/musickits.cfg"

enum struct SMusicKit
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

void ReadMusicKitConfig(KeyValues kv)
{
	if (kv.GotoFirstSubKey(false))
	{
		do // Loop through each music kit
		{
			SMusicKit kit;
			char name[PLATFORM_MAX_PATH];
			kv.GetSectionName(name, sizeof(name));
			kit.name = name;
			
			if (kv.GotoFirstSubKey(false))
			{
				do // Loop through each music kit
				{
					char title[PLATFORM_MAX_PATH];
					kv.GetSectionName(title, sizeof(title));
					PrintToServer(title);
					
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
						LogError("Found unregonized sound %s", title);
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
