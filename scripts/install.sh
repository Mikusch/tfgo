# Create build folder
mkdir build
cd build

# Install SourceMod
wget --input-file=https://sourcemod.net/smdrop/$SM_VERSION/sourcemod-latest-linux
tar -xzf $(cat sourcemod-latest-linux)

# Copy .sp file to build dir
cp -r ../addons/sourcemod/scripting addons/sourcemod
cd addons/sourcemod/scripting

# Install Dependencies
wget "https://raw.githubusercontent.com/peace-maker/DHooks2/dynhooks/sourcemod_files/scripting/include/dhooks.inc" -O include/dhooks.inc
wget "https://raw.githubusercontent.com/nosoop/SM-TFEconData/master/scripting/include/tf_econ_data.inc" -O include/tf_econ_data.inc
wget "https://raw.githubusercontent.com/Kenzzer/MemoryPatch/master/addons/sourcemod/scripting/include/memorypatch.inc" -O include/memorypatch.inc
wget "https://www.doctormckay.com/download/scripting/include/morecolors.inc" -O include/morecolors.inc
wget "https://raw.githubusercontent.com/haxtonsale/LoadSoundScript/master/sourcepawn/loadsoundscript.inc" -O include/loadsoundscript.inc
