char g_EngineerMvmCollectCredits[][PLATFORM_MAX_PATH] = 
{
	"vo/engineer_mvm_collect_credits01.mp3", 
	"vo/engineer_mvm_collect_credits02.mp3", 
	"vo/engineer_mvm_collect_credits03.mp3"
};

char g_HeavyMvmCollectCredits[][PLATFORM_MAX_PATH] = 
{
	"vo/heavy_mvm_collect_credits01.mp3", 
	"vo/heavy_mvm_collect_credits02.mp3", 
	"vo/heavy_mvm_collect_credits03.mp3", 
	"vo/heavy_mvm_collect_credits04.mp3"
};

char g_MedicMvmCollectCredits[][PLATFORM_MAX_PATH] = 
{
	"vo/medic_mvm_collect_credits01.mp3", 
	"vo/medic_mvm_collect_credits02.mp3", 
	"vo/medic_mvm_collect_credits03.mp3", 
	"vo/medic_mvm_collect_credits04.mp3"
};

char g_SoldierMvmCollectCredits[][PLATFORM_MAX_PATH] = 
{
	"vo/soldier_mvm_collect_credits01.mp3", 
	"vo/soldier_mvm_collect_credits02.mp3"
};

stock void PrecacheSounds()
{
	PrecacheSound("mvm/mvm_money_vanish.wav");
	PrecacheSound("valve_csgo_01/wonround.mp3");
	PrecacheSound("valve_csgo_01/lostround.mp3");
	for (int i = 0; i < sizeof(g_EngineerMvmCollectCredits); i++)PrecacheSound(g_EngineerMvmCollectCredits[i]);
	for (int i = 0; i < sizeof(g_HeavyMvmCollectCredits); i++)PrecacheSound(g_HeavyMvmCollectCredits[i]);
	for (int i = 0; i < sizeof(g_MedicMvmCollectCredits); i++)PrecacheSound(g_MedicMvmCollectCredits[i]);
	for (int i = 0; i < sizeof(g_SoldierMvmCollectCredits); i++)PrecacheSound(g_SoldierMvmCollectCredits[i]);
}

stock void EmitSoundToTeam(int iTeam, const char[] strSound)
{
    for(int i=1; i<=MaxClients; i++)
        if(IsClientInGame(i) && GetClientTeam(i) == iTeam)
            EmitSoundToClient(i, strSound, _, _, SNDLEVEL_ROCKET );
}