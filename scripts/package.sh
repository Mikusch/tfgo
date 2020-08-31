# Go to build dir
cd build

# Create package dir
mkdir -p package/addons/sourcemod/plugins
mkdir -p package/addons/sourcemod/configs
mkdir -p package/addons/sourcemod/gamedata
mkdir -p package/addons/sourcemod/translations
mkdir -p package/sound

# Copy all required files to package
cp -r addons/sourcemod/plugins/tfgo.smx package/addons/sourcemod/plugins
cp -r ../configs/tfgo package/addons/sourcemod/configs
cp -r ../gamedata/tfgo.txt package/addons/sourcemod/gamedata
cp -r ../translations package/addons/sourcemod
cp -r ../sound package
cp -r ../LICENSE package