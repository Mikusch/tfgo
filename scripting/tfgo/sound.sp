#include <sdktools_sound>

#define CSGO_ROUNDTENSECCOUNT_LENGTH	12.7

static char g_EngineerMvmCollectCredits[][PLATFORM_MAX_PATH] = 
{
	"vo/engineer_mvm_collect_credits01.mp3", 
	"vo/engineer_mvm_collect_credits02.mp3", 
	"vo/engineer_mvm_collect_credits03.mp3"
};

static char g_HeavyMvmCollectCredits[][PLATFORM_MAX_PATH] = 
{
	"vo/heavy_mvm_collect_credits01.mp3", 
	"vo/heavy_mvm_collect_credits02.mp3", 
	"vo/heavy_mvm_collect_credits03.mp3", 
	"vo/heavy_mvm_collect_credits04.mp3"
};

static char g_MedicMvmCollectCredits[][PLATFORM_MAX_PATH] = 
{
	"vo/medic_mvm_collect_credits01.mp3", 
	"vo/medic_mvm_collect_credits02.mp3", 
	"vo/medic_mvm_collect_credits03.mp3", 
	"vo/medic_mvm_collect_credits04.mp3"
};

static char g_SoldierMvmCollectCredits[][PLATFORM_MAX_PATH] = 
{
	"vo/soldier_mvm_collect_credits01.mp3", 
	"vo/soldier_mvm_collect_credits02.mp3"
};

static char g_sStartRoundMusic[][PLATFORM_MAX_PATH] =  {
	"valve_csgo_01/startround_01.mp3", 
	"valve_csgo_01/startround_02.mp3", 
	"valve_csgo_01/startround_03.mp3"
};

static char g_sStartActionMusic[][PLATFORM_MAX_PATH] =  {
	"valve_csgo_01/startaction_01.mp3"
};

stock void PrecacheSounds()
{
	PrecacheSound("mvm/mvm_money_vanish.wav");
	PrecacheSound("valve_csgo_01/wonround.mp3");
	PrecacheSound("valve_csgo_01/lostround.mp3");
	PrecacheSound("valve_csgo_01/roundtenseccount.mp3");
	for (int i = 0; i < sizeof(g_sStartRoundMusic); i++)PrecacheSound(g_sStartRoundMusic[i]);
	for (int i = 0; i < sizeof(g_sStartActionMusic); i++)PrecacheSound(g_sStartActionMusic[i]);
	for (int i = 0; i < sizeof(g_EngineerMvmCollectCredits); i++)PrecacheSound(g_EngineerMvmCollectCredits[i]);
	for (int i = 0; i < sizeof(g_HeavyMvmCollectCredits); i++)PrecacheSound(g_HeavyMvmCollectCredits[i]);
	for (int i = 0; i < sizeof(g_MedicMvmCollectCredits); i++)PrecacheSound(g_MedicMvmCollectCredits[i]);
	for (int i = 0; i < sizeof(g_SoldierMvmCollectCredits); i++)PrecacheSound(g_SoldierMvmCollectCredits[i]);
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

public Action Event_Broadcast_Audio(Event event, const char[] name, bool dontBroadcast)
{
	char sound[PLATFORM_MAX_PATH];
	event.GetString("sound", sound, sizeof(sound));
	int iTeam = event.GetInt("team");
	
	if (strcmp(sound, "Game.YourTeamWon") == 0)
	{
		EmitSoundToTeam(iTeam, "valve_csgo_01/wonround.mp3");
		return Plugin_Handled;
	}
	else if (strcmp(sound, "Game.YourTeamLost") == 0 || strcmp(sound, "Game.Stalemate") == 0)
	{
		EmitSoundToTeam(iTeam, "valve_csgo_01/lostround.mp3");
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

stock void PlayCashPickupVoiceLine(int iClient)
{
	switch (TF2_GetPlayerClass(iClient))
	{
		case TFClass_Soldier:
		{
			int iRandom = GetRandomInt(0, sizeof(g_SoldierMvmCollectCredits) - 1);
			EmitSoundToAll(g_SoldierMvmCollectCredits[iRandom], iClient, SNDCHAN_VOICE);
		}
		case TFClass_Engineer:
		{
			int iRandom = GetRandomInt(0, sizeof(g_EngineerMvmCollectCredits) - 1);
			EmitSoundToAll(g_EngineerMvmCollectCredits[iRandom], iClient, SNDCHAN_VOICE);
		}
		case TFClass_Heavy:
		{
			int iRandom = GetRandomInt(0, sizeof(g_HeavyMvmCollectCredits) - 1);
			EmitSoundToAll(g_HeavyMvmCollectCredits[iRandom], iClient, SNDCHAN_VOICE);
		}
		case TFClass_Medic:
		{
			int iRandom = GetRandomInt(0, sizeof(g_MedicMvmCollectCredits) - 1);
			EmitSoundToAll(g_MedicMvmCollectCredits[iRandom], iClient, SNDCHAN_VOICE);
		}
	}
}

stock Action Play10SecondWarning(Handle timer)
{
	EmitSoundToAll("valve_csgo_01/roundtenseccount.mp3");
	g_h10SecondWarningTimer = null;
}

stock void PlayRoundStartMusic()
{
	StopSoundForAll(SNDCHAN_AUTO, "valve_csgo_01/wonround.mp3");
	StopSoundForAll(SNDCHAN_AUTO, "valve_csgo_01/lostround.mp3");
	int iRandom = GetRandomInt(0, sizeof(g_sStartRoundMusic) - 1);
	EmitSoundToAll(g_sStartRoundMusic[iRandom]);
}

stock void PlayRoundActionMusic()
{
	for (int i = 0; i < sizeof(g_sStartRoundMusic); i++)StopSoundForAll(SNDCHAN_AUTO, g_sStartRoundMusic[i]);
	int iRandom = GetRandomInt(0, sizeof(g_sStartActionMusic) - 1);
	EmitSoundToAll(g_sStartActionMusic[iRandom]);
	
	DataPack pack;
	CreateDataTimer(10.0, StopRoundActionMusic, pack);
	pack.WriteString(g_sStartActionMusic[iRandom]);
}

public Action StopRoundActionMusic(Handle timer, DataPack pack)
{
	pack.Reset();
	char sound[PLATFORM_MAX_PATH];
	pack.ReadString(sound, sizeof(sound));
	StopSoundForAll(SNDCHAN_AUTO, sound);
}

stock void StopSoundForAll(int channel, const char[] sound)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i <= MaxClients && IsClientInGame(i))
		{
			StopSound(i, channel, sound);
		}
	}
} 