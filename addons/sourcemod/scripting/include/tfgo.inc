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
	
	void ReadConfig(KeyValues kv)
	{
		this.defindex = kv.GetNum("defindex", -1);
		this.price = kv.GetNum("price");
		this.killAward = kv.GetNum("kill_award");
		this.armorPenetration = kv.GetFloat("armor_penetration", 1.0);
		this.isDefault = view_as<bool>(kv.GetNum("is_default"));
	}
}

methodmap TFGOWeaponList < ArrayList
{
	public TFGOWeaponList()
	{
		return view_as<TFGOWeaponList>(new ArrayList(sizeof(TFGOWeapon)));
	}
	
	public void ReadConfig(KeyValues kv)
	{
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				TFGOWeapon weapon;
				weapon.ReadConfig(kv);
				this.PushArray(weapon, sizeof(weapon));
			}
			while (kv.GotoNextKey(false));
			kv.GoBack();
		}
		kv.GoBack();
	}
	
	public int GetByDefIndex(int defindex, TFGOWeapon weapon)
	{
		int i = this.FindValue(defindex);
		return i != -1 ? this.GetArray(i, weapon) : 0;
	}
}

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