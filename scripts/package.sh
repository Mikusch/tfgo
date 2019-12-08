# Go to build dir
cd build

# Create package dir
mkdir -p package/addons/sourcemod/plugins
mkdir -p package/addons/sourcemod/configs
mkdir -p package/addons/sourcemod/gamedata
mkdir -p package/addons/sourcemod/translations

# Copy all required files to package
cp -r addons/sourcemod/plugins/tfgo.smx package/addons/sourcemod/plugins
cp -r ../addons/sourcemod/configs/tfgo package/addons/sourcemod/configs
cp -r ../addons/sourcemod/gamedata/tfgo.txt package/addons/sourcemod/gamedata
cp -r ../addons/sourcemod/translations/tfgo.phrases.txt package/addons/sourcemod/translations
cp -r ../sound package
