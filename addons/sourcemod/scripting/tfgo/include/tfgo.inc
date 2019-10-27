#if defined _tfgo_included
	#endinput
#endif
#define _tfgo_included

enum Arena_Winreason
{
	Winreason_PointCaptured = 1, 
	Winreason_Elimination, 
	Winreason_AllPointsCaptured = 4, 
	Winreason_Stalemate
};

enum
{
	WeaponSlot_Primary = 0, 
	WeaponSlot_Secondary, 
	WeaponSlot_Melee, 
	WeaponSlot_PDABuild, 
	WeaponSlot_PDADisguise = 3, 
	WeaponSlot_PDADestroy, 
	WeaponSlot_InvisWatch = 4, 
	WeaponSlot_BuilderEngie, 
	WeaponSlot_Unknown1, 
	WeaponSlot_Head, 
	WeaponSlot_Misc1, 
	WeaponSlot_Action, 
	WeaponSlot_Misc2
}; 
