# Create build folder
mkdir build
cd build

# Install SourceMod
wget --input-file=http://sourcemod.net/smdrop/$SM_VERSION/sourcemod-latest-linux
tar -xzf $(cat sourcemod-latest-linux)

# Copy .sp file to build dir
cp -r ../addons/sourcemod/scripting addons/sourcemod
cd addons/sourcemod/scripting

# Install Dependencies
wget "https://bitbucket.org/Peace_Maker/dhooks2/raw/dfe13dde99547a5c6c7815d843809726cc92c897/sourcemod/scripting/include/dhooks.inc" -O include/dhooks.inc
wget "https://raw.githubusercontent.com/nosoop/SM-TFEconData/master/scripting/include/tf_econ_data.inc" -O include/tf_econ_data.inc
wget "https://raw.githubusercontent.com/Kenzzer/MemoryPatch/master/addons/sourcemod/scripting/include/memorypatch.inc" -O include/memorypatch.inc
wget "https://www.doctormckay.com/download/scripting/include/morecolors.inc" -O include/morecolors.inc
