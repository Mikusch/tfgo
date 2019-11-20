#if defined _tfgo_included
#endinput
#endif
#define _tfgo_included

#include <tf2>

enum
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

/**
 * Forward called when the bomb has been planted.
 *
 * @param team				The team that planted the bomb
 * @param cappers			ArrayList of clients that planted the bomb
 * @noreturn
 */
forward void TFGO_OnBombPlanted(TFTeam team, ArrayList cappers);

/**
 * Forward called when the bomb was detonated.
 *
 * @param team				The team that detonated the bomb
 * @noreturn
 */
forward void TFGO_OnBombDetonated(TFTeam team);

/**
 * Forward called when the bomb has been defused.
 *
 * @param team				The team that defused the bomb
 * @param cappers			ArrayList of clients that defused the bomb
 * @noreturn
 */
forward void TFGO_OnBombDefused(TFTeam team, ArrayList cappers);
