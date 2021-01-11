/*
 * Copyright (C) 2020  Mikusch
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

enum struct MusicKit
{
	char name[256];
	SoundScript soundScript;
	bool isDefault;
	
	void Precache()
	{
		for (int i = 0; i < this.soundScript.Count; i++)
		{
			SoundEntry entry = this.soundScript.GetSound(i);
			char sound[PLATFORM_MAX_PATH];
			entry.GetName(sound, sizeof(sound));
			PrecacheScriptSound(sound);
			AddScriptSoundToDownloadsTable(sound);
		}
	}
	
	int BuildGameSound(MusicType type, char[] buffer, int maxlen)
	{
		char entry[PLATFORM_MAX_PATH];
		if (MusicKit_GetEntryNameForMusicType(type, entry, sizeof(entry)) > 0)
			return Format(buffer, maxlen, "%s.%s", entry, this.name);
		else
			return 0;
	}
	
	void PlayGameSoundToClient(int client, char[] gameSound, bool stopPrevious = true)
	{
		if (stopPrevious)
		{
			TFGOPlayer player = TFGOPlayer(client);
			char previousSound[PLATFORM_MAX_PATH];
			player.GetPreviousPlayedSound(previousSound, sizeof(previousSound));
			StopGameSound(client, previousSound);
			player.SetPreviousPlayedSound(gameSound);
		}
		
		EmitGameSoundToClient(client, gameSound);
	}
	
	void PlayToClient(int client, MusicType type, bool stopPrevious = true)
	{
		char gameSound[PLATFORM_MAX_PATH];
		if (this.BuildGameSound(type, gameSound, sizeof(gameSound)) > 0)
		{
			this.PlayGameSoundToClient(client, gameSound, stopPrevious);
		}
	}
	
	void PlayToTeam(TFTeam team, MusicType type, bool stopPrevious = true)
	{
		char gameSound[PLATFORM_MAX_PATH];
		if (this.BuildGameSound(type, gameSound, sizeof(gameSound)) > 0)
		{
			for (int client = 1; client <= MaxClients; client++)
			{
				if (IsClientInGame(client) && TF2_GetClientTeam(client) == team)
					this.PlayGameSoundToClient(client, gameSound, stopPrevious);
			}
		}
	}
	
	void PlayToAll(MusicType type, bool stopPrevious = true)
	{
		char gameSound[PLATFORM_MAX_PATH];
		if (this.BuildGameSound(type, gameSound, sizeof(gameSound)) > 0)
		{
			for (int client = 1; client <= MaxClients; client++)
			{
				if (IsClientInGame(client))
					this.PlayGameSoundToClient(client, gameSound, stopPrevious);
			}
		}
	}
}

static ArrayList AllMusicKits;

void MusicKit_Init()
{
	AllMusicKits = new ArrayList(sizeof(MusicKit));
}

ArrayList MusicKit_GetDefaultKits()
{
	ArrayList defaultKits = new ArrayList(sizeof(MusicKit));
	for (int i = 0; i < AllMusicKits.Length; i++)
	{
		if (AllMusicKits.Get(i, MusicKit::isDefault))
		{
			MusicKit defaultKit;
			AllMusicKits.GetArray(i, defaultKit, sizeof(defaultKit));
			defaultKits.PushArray(defaultKit);
		}
	}
	return defaultKits;
}

int MusicKit_GetByName(const char[] name, MusicKit buffer)
{
	int index = AllMusicKits.FindString(name);
	return index != -1 ? AllMusicKits.GetArray(index, buffer, sizeof(buffer)) : 0;
}

int MusicKit_Register(const char[] name, const char[] path, bool isDefault, bool precache)
{
	MusicKit kit;
	strcopy(kit.name, sizeof(kit.name), name);
	kit.soundScript = LoadSoundScript(path);
	kit.isDefault = isDefault;
	
	if (precache)
		kit.Precache();
	
	return AllMusicKits.PushArray(kit);
}

void MusicKit_SetMusicKit(int client, const char[] name)
{
	MusicKit kit;
	if (MusicKit_GetByName(name, kit) > 0)
	{
		TFGOPlayer(client).SetMusicKit(name);
	}
	else
	{
		if (name[0] != '\0')
			LogError("Invalid music kit %s, falling back to random default kit", name);
		
		MusicKit_SetRandomDefaultMusicKit(client);
	}
}

void MusicKit_SetRandomDefaultMusicKit(int client)
{
	ArrayList defaultKits = MusicKit_GetDefaultKits();
	MusicKit defaultKit;
	if (defaultKits.Length > 0 && defaultKits.GetArray(GetRandomInt(0, defaultKits.Length - 1), defaultKit, sizeof(defaultKit)) > 0)
	{
		TFGOPlayer(client).SetMusicKit(defaultKit.name);
		delete defaultKits;
	}
	else
	{
		delete defaultKits;
		ThrowError("No default music kits found");
	}
}

void MusicKit_PlayAllClientMusicKits(MusicType type, bool stopPrevious = true)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
			MusicKit_PlayClientMusicKit(client, type, stopPrevious);
	}
}

void MusicKit_PlayClientMusicKit(int client, MusicType type, bool stopPrevious = true)
{
	char name[PLATFORM_MAX_PATH];
	TFGOPlayer(client).GetMusicKit(name, sizeof(name));
	
	MusicKit kit;
	if (MusicKit_GetByName(name, kit) > 0)
		kit.PlayToClient(client, type, stopPrevious);
}

void MusicKit_PlayTeamMusicKits(TFTeam team, MusicType type, bool stopPrevious = true)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && TF2_GetClientTeam(client) == team)
			MusicKit_PlayClientMusicKit(client, type, stopPrevious);
	}
}

bool MusicKit_HasCustomMusicKit(int client)
{
	char name[PLATFORM_MAX_PATH];
	MusicKit kit;
	return TFGOPlayer(client).GetMusicKit(name, sizeof(name)) > 0 && MusicKit_GetByName(name, kit) > 0 && !kit.isDefault;
}

void MusicKit_PlayMVPAnthem(int mvp)
{
	char name[PLATFORM_MAX_PATH];
	TFGOPlayer(mvp).GetMusicKit(name, sizeof(name));
	
	MusicKit kit;
	if (MusicKit_GetByName(name, kit) > 0)
		kit.PlayToAll(Music_MVPAnthem);
}

int MusicKit_GetEntryNameForMusicType(MusicType type, char[] buffer, int maxlen)
{
	switch (type)
	{
		case Music_HalfTime: return strcopy(buffer, maxlen, "Music.HalfTime");
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
