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

enum TFQuality
{
	TFQual_None = -1, 
	TFQual_Normal = 0, 
	TFQual_Genuine, 
	TFQual_Rarity2, 
	TFQual_Vintage, 
	TFQual_Rarity3, 
	TFQual_Unusual, 
	TFQual_Unique, 
	TFQual_Community, 
	TFQual_Developer, 
	TFQual_Selfmade, 
	TFQual_Customized, 
	TFQual_Strange, 
	TFQual_Completed, 
	TFQual_Haunted, 
	TFQual_Collectors, 
	TFQual_Decorated, 
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
 * @param team		The team that planted the bomb
 * @param cappers	ArrayList of clients that planted the bomb
 * @noreturn
 */
forward void TFGO_OnBombPlanted(TFTeam team, ArrayList cappers);

/**
 * Forward called when the bomb was detonated.
 *
 * @param team	The team that detonated the bomb
 * @noreturn
 */
forward void TFGO_OnBombDetonated(TFTeam team);

/**
 * Forward called when the bomb has been defused.
 *
 * @param team		The team that defused the bomb
 * @param cappers	ArrayList of clients that defused the bomb
 * @param timeLeft	Time left on the bomb detonation timer when it was defused
 * @noreturn
 */
forward void TFGO_OnBombDefused(TFTeam team, ArrayList cappers, float timeLeft);

/**
 * Forward called when a player earns cash.
 *
 * @param client	The client that earned the cash
 * @param amount	The amount of money that was earned
 * @noreturn
 */
forward void TFGO_OnCashAwarded(int client, int amount);

/**
 * Forward called when a player picks up a weapon.
 *
 * @param client	The client that picked up the weapon
 * @param defindex	The item definition index of the weapon
 * @noreturn
 */
forward void TFGO_OnWeaponPickup(int client, int defindex);

/**
* Retrieves the cost of a weapon.
*
* @param defindex	The item definition index of the weapon
* @return the cost of the weapon
*/
native int TFGO_GetWeaponCost(int defindex);

public SharedPlugin __pl_tfgo =
{
	name = "tfgo",
	file = "tfgo.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_tfgo_SetNTVOptional()
{
	MarkNativeAsOptional("TFGO_GetWeaponCost");
}
#endif