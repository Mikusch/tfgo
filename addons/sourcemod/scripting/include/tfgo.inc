#if defined _tfgo_included
#endinput
#endif
#define _tfgo_included

#include <tf2>

enum struct TFGOWeapon
{
	int defindex;
	int price;
	int killAward;
	float armorPenetration;
	bool isDefault;
	bool canHeadshot;
	
	void ReadConfig(KeyValues kv)
	{
		char defindex[8];
		kv.GetSectionName(defindex, sizeof(defindex));
		this.defindex = StringToInt(defindex);
		this.price = kv.GetNum("price");
		this.killAward = kv.GetNum("kill_award");
		this.armorPenetration = kv.GetFloat("armor_penetration", 1.0);
		this.isDefault = view_as<bool>(kv.GetNum("is_default"));
		this.canHeadshot = view_as<bool>(kv.GetNum("can_headshot"));
	}
}

/**
 * Called when the bomb has been planted.
 *
 * @param team		TFTeam that planted the bomb.
 * @param planters	ArrayList containing client indices that planted the bomb.
 */
forward void TFGO_OnBombPlanted(TFTeam team, ArrayList planters);

/**
 * Called when the bomb was detonated.
 *
 * @param team	TFTeam that detonated the bomb.
 */
forward void TFGO_OnBombDetonated(TFTeam team);

/**
 * Called when the bomb has been defused.
 *
 * @param team		TFTeam that defused the bomb.
 * @param defusers	ArrayList containing client indices that defused the bomb.
 * @param timeLeft	Time left on the bomb timer.
 */
forward void TFGO_OnBombDefused(TFTeam team, ArrayList defusers, float timeLeft);

/**
 * Called when the game has entered half-time.
 *
 * @note This will not call if tfgo_halftime has been set to 0.
 */
forward void TFGO_OnHalfTime();

/**
 * Called when all rounds have been played.
 */
forward void TFGO_OnMaxRounds();

/**
 * Called when a client's account changes due to them earning or losing money.
 *
 * @note This forward does not get called for weapon purchases, see TFGO_OnClientPurchaseWeapon instead.
 * 
 * @param client	Client index.
 * @param amount	Amount of money added, may be negative.
 * @return			Plugin_Continue to continue with the original action.
 * @return			Plugin_Changed to override the amount.
 * @return			Plugin_Handled to prevent the account change.
 */
forward Action TFGO_OnClientAccountChange(int client, int amount);

/**
 * Called when a client's account has changed due to them earning or losing money.
 *
 * @note This forward does not get called for weapon purchases, see TFGO_OnClientPurchaseWeapon instead.
 * 
 * @param client	Client index.
 * @param amount	Amount of money added, may be negative.
 */
forward void TFGO_OnClientAccountChanged(int client, int amount);

/**
 * Called when a client purchases a weapon.
 * 
 * @param client	Client index.
 * @param defindex	Item definition index of the weapon.
 */
forward void TFGO_OnClientPurchaseWeapon(int client, int defindex);

/**
 * Called when a client picks up a weapon.
 *
 * @param client	Client index.
 * @param defindex	Item definition index of the weapon.
 */
forward void TFGO_OnClientPickupWeapon(int client, int defindex);

/**
* Retrieves weapon information for a given item definition index.
*
* @note This forward assumes the passed in array is a TFGOWeapon enum struct.
*
* @param defindex	Item definition index of the weapon.
* @param buffer		Buffer to store weapon information in.
* @return			Number of cells copied.
*/
native int TFGO_GetWeapon(int defindex, any[] buffer);

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
	MarkNativeAsOptional("TFGO_GetWeapon");
}
#endif
