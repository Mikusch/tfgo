#if defined _tfgo_included
#endinput
#endif
#define _tfgo_included

#include <adt_array>
#include <tf2>

enum struct TFGOWeapon
{
	int defindex;
	int price;
	int killAward;
	float armorPenetration;
	bool isDefault;
	bool canHeadshot;
	ArrayList reskins;
	
	void ReadConfig(KeyValues kv)
	{
		char defindex[8];
		if (kv.GetSectionName(defindex, sizeof(defindex)))
		{
			this.defindex = StringToInt(defindex);
			this.price = kv.GetNum("price");
			this.killAward = kv.GetNum("kill_award");
			this.armorPenetration = kv.GetFloat("armor_penetration", 1.0);
			this.isDefault = view_as<bool>(kv.GetNum("is_default"));
			this.canHeadshot = view_as<bool>(kv.GetNum("can_headshot"));
			
			delete this.reskins;
			this.reskins = new ArrayList();
			
			char reskins[PLATFORM_MAX_PATH];
			kv.GetString("reskins", reskins, sizeof(reskins));
			
			if (reskins[0] != '\0')
			{
				char defindexes[64][32];
				int count = ExplodeString(reskins, ";", defindexes, sizeof(defindexes), sizeof(defindexes[]));
				for (int i = 0; i < count; i++)
				{
					TrimString(defindexes[i]);
					this.reskins.Push(StringToInt(defindexes[i]));
				}
			}
		}
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
 * Intended to be used with map voting plugins to allow a vote to start.
 *
 * @note This forward does not get called if tfgo_halftime is set to 0.
 */
forward void TFGO_OnHalfTimeStarted();

/**
 * Called repeatedly when the game is about to leave half-time.
 * Intended to be used with map voting plugins, this forward should return false if a vote is still in progress.
 *
 * @note This forward does not get called until the initial half-time duration (tfgo_halftime_duration) has elapsed.
 * @note This forward does not get called if tfgo_halftime is set to 0.
 *
 * @return	true if the half-time should end, false if it shouldn't end and call this forward again.
 */
forward bool TFGO_HasHalfTimeEnded();

/**
 * Called when the game is about to switch or scramble the teams after half-time.
 * 
 * @note This forward gets called regardless of the current value of the tfgo_halftime_scramble convar.
 *
 * @return	true if the teams should be switched or scrambled, false if not.
 */
forward bool TFGO_ShouldSwitchTeams();

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
 * Called when the plugin needs to display the name of a client.
 * Subplugins can style the name using morecolors.inc syntax.
 *
 * @param client	Client index.
 * @param name		Buffer to store the name in.
 * @param length	Maximum length of the buffer.
 */
forward void TFGO_GetClientName(int client, char[] name, int maxlen);

/**
 * Called when the plugin needs to display the name of a music kit.
 * Subplugins can style the name using morecolors.inc syntax.
 *
 * @param client	Client index.
 * @param name		Buffer to store the name in.
 * @param length	Maximum length of the buffer.
 */
forward void TFGO_GetMusicKitName(int client, char[] name, int maxlen);

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

/**
 * Registers a new music kit with the specified name and soundscript.
 *
 * @param name		Name of the music kit.
 * @param path		Path to the soundscript text file.
 * @param isDefault	Whether this music kit can be randomly assigned to players as a default kit.
 * @param precache	Whether to precache the sounds in this music kit. All music kit sounds are automatically precached on map start.
 */
native void TFGO_RegisterMusicKit(const char[] name, const char[] path, bool isDefault = false, bool precache = false);

/**
 * Sets the active music kit for a client.
 * The music kit passed must be registered prior using TFGO_RegisterMusicKit.
 *
 * @param client	Client index.
 * @param name		Name of the music kit.
 */
native void TFGO_SetClientMusicKit(int client, const char[] name);

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
	MarkNativeAsOptional("TFGO_RegisterMusicKit");
	MarkNativeAsOptional("TFGO_SetClientMusicKit");
}
#endif
