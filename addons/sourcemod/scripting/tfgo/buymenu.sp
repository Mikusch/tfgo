#include <tf2_stocks> // TODO REMOVE THIS SHIT SOMEHOW
#include <sourcemod>

#define CONFIG_FILE "tfgo.cfg"
#define MAXLEN_CONFIG_VALUE 256

// TF2 Class names, ordered from TFClassType
char g_strClassName[TFClassType][] =  {
	"Unknown", 
	"Scout", 
	"Sniper", 
	"Soldier", 
	"Demoman", 
	"Medic", 
	"Heavy", 
	"Pyro", 
	"Spy", 
	"Engineer", 
};

// TF2 Slot names
char g_strSlotName[][] =  {
	"Primary", 
	"Secondary", 
	"Melee", 
	"PDA1", 
	"PDA2", 
	"Building"
};

methodmap ConfigClass < StringMap
{
	public ConfigClass()
	{
		return view_as<ConfigClass>(new StringMap());
	}
	
	public void LoadSection(KeyValues kv, TFClassType nClass, int iSlot)
	{
		PrintToServer("ahaha %b", kv.JumpToKey("class", false));
		if (kv.JumpToKey("class", false)) //Jump to "class"
		{
			if (kv.JumpToKey(g_strClassName[nClass], false)) //Jump to TF2 class name
			{
				if (kv.JumpToKey(g_strSlotName[iSlot], false)) //Jump to slot name
				{
					if (kv.GotoFirstSubKey(false)) //Go to first subkeys (desp, attrib etc)
					{
						do //Loop through each subkeys from that slot
						{
							char sSubkey[MAXLEN_CONFIG_VALUE], sValue[MAXLEN_CONFIG_VALUE];
							
							kv.GetSectionName(sSubkey, sizeof(sSubkey)); //Subkey (class, attrib etc)
							kv.GetString(NULL_STRING, sValue, sizeof(sValue), ""); //Value of that subkey
											PrintToServer(sValue);
							TrimString(sSubkey);
							TrimString(sValue);
							
							this.SetString(sSubkey, sValue);
						}
						while (kv.GotoNextKey(false));
					}
					kv.GoBack();
				}
				kv.GoBack();
			}
			kv.GoBack();
		}
		kv.GoBack();
	}
	
	//Return clip size class slot should have on spawn, -1 if not specified
	public int GetCost()
	{
		char sValue[MAXLEN_CONFIG_VALUE];
		if (this.GetString("cost", sValue, sizeof(sValue)))
			return StringToInt(sValue);
		
		else return -1;
	}
};

ConfigClass g_ConfigClass[10][5 + 1]; //Double array of StringMap

void Config_Init()
{
	for (int iClass = 1; iClass < sizeof(g_ConfigClass); iClass++)
	for (int iSlot = 0; iSlot < sizeof(g_ConfigClass[]); iSlot++)
	g_ConfigClass[iClass][iSlot] = new ConfigClass();
}

void Config_Refresh()
{
	for (int iClass = 1; iClass < sizeof(g_ConfigClass); iClass++)
		for (int iSlot = 0; iSlot < sizeof(g_ConfigClass[]); iSlot++)
			g_ConfigClass[iClass][iSlot].Clear();
	
	KeyValues kv = new KeyValues("Config");
	kv.ImportFromFile("tfgo/configs/tfgo.cfg");
	if (kv == null)return;
	
	//Load each class and slots
	for (int iClass = 1; iClass < sizeof(g_ConfigClass); iClass++)
		for (int iSlot = 0; iSlot < sizeof(g_ConfigClass[]); iSlot++) 
			g_ConfigClass[iClass][iSlot].LoadSection(kv, view_as<TFClassType>(iClass), iSlot);
	
	delete kv;
} 