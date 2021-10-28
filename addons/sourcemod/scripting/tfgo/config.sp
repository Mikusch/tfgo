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

#define CONFIG_FILE	"configs/tfgo/weapons.cfg"

static StringMap WeaponReskins;

void Config_Init()
{
	g_AvailableWeapons = new TFGOWeaponList();
	WeaponReskins = new StringMap();
	
	char path[PLATFORM_MAX_PATH];
	
	// Read weapons from config
	BuildPath(Path_SM, path, sizeof(path), CONFIG_FILE);
	KeyValues kv = new KeyValues("Weapons");
	if (kv.ImportFromFile(path))
	{
		g_AvailableWeapons.ReadConfig(kv);
		g_AvailableWeapons.SortCustom(SortFunc_SortAvailableWeaponsByName);
		kv.GoBack();
	}
	delete kv;
	
	// For easy and fast access later on, we write the reskin defindexes into a separate StringMap
	for (int i = 0; i < g_AvailableWeapons.Length; i++)
	{
		TFGOWeapon weapon;
		g_AvailableWeapons.GetArray(i, weapon, sizeof(weapon));
		
		for (int j = 0; j < weapon.reskins.Length; j++)
		{
			char reskin[8];
			if (IntToString(weapon.reskins.Get(j), reskin, sizeof(reskin)))
				WeaponReskins.SetValue(reskin, weapon.defindex);
		}
	}
}

public int SortFunc_SortAvailableWeaponsByName(int index1, int index2, Handle array, Handle hndl)
{
	ArrayList list = view_as<ArrayList>(array);
	
	TFGOWeapon weapon1, weapon2;
	list.GetArray(index1, weapon1, sizeof(weapon1));
	list.GetArray(index2, weapon2, sizeof(weapon2));
	
	char name1[PLATFORM_MAX_PATH], name2[PLATFORM_MAX_PATH];
	TF2_GetItemName(weapon1.defindex, name1, sizeof(name1));
	TF2_GetItemName(weapon2.defindex, name2, sizeof(name2));
	
	return strcmp(name1, name2);
}

stock int Config_GetOriginalItemDefIndex(int defindex)
{
	int origDefindex;
	
	char defindexString[8];
	IntToString(defindex, defindexString, sizeof(defindexString));
	
	if (WeaponReskins.GetValue(defindexString, origDefindex))
		return origDefindex;
	else
		return defindex;
}
