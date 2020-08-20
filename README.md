# Team Fortress: Global Offensive [![Action Status](https://github.com/Mikusch/tfgo/workflows/Package/badge.svg)](https://github.com/Mikusch/tfgo/actions?query=branch%3Amaster)
TF:GO brings the bomb defusal mode from Counter-Strike: Global Offensive to Team Fortress 2 arena.
All players begin the game with basic weapons and can buy new equipment at the start of each round with money earned from neutralizing enemy players or planting the bomb.

The plugin first started development on September 29, 2019 by [Mikusch](https://github.com/Mikusch) and was his first project written in SourcePawn.

## Features
* Similar gameplay to Counter-Strike: Global Offensive's bomb defusal mode
* Support for a wide range of arena maps
* Critical headshots on weapons like pistols, SMGs and revolvers
* Highly configurable using the plugin configuration and convars
* Support for custom music kits
* Support for custom map voting plugins

## Dependencies
* SourceMod 1.10
* [DHooks with Detour Support](https://github.com/peace-maker/DHooks2/tree/dynhooks)
* [TF2 Econ Data](https://forums.alliedmods.net/showthread.php?t=315011)
* [LoadSoundScript](https://github.com/haxtonsale/LoadSoundScript)
* [More Colors](https://forums.alliedmods.net/showthread.php?t=185016) (compile only)
* [MemoryPatch](https://github.com/Kenzzer/MemoryPatch) (compile only)

## Downloads
GitHub automatically builds an archive on every push to the repository that contains all files required to run the game mode.
To download this archive head over to [Actions](https://github.com/Mikusch/tfgo/actions?query=workflow%3APackage) and click on the latest "Package" workflow on branch ``master``.

Alternatively, you may check for the last stable release on the [Releases](https://github.com/Mikusch/tfgo/releases) page.

## Music Kits
The gamemode comes with two default music kits, ``valve_csgo_01`` and ``valve_csgo_02``, which get randomly assigned to each player when they join the server.

To add a new music kit, use the ``TFGO_RegisterMusicKit`` native. Each music kit requires a unique name and a [soundscript](https://developer.valvesoftware.com/wiki/Soundscripts) specifying the sounds for each sound type. 

To assign a newly registered music kit to a client, use the ``TFGO_SetClientMusicKit`` native.

## Maps
While there is no direct map support in the plugin, it should function with almost every arena map that doesn't screw with the control points after the bomb has been planted.

The plugin searches for ``func_respawnroom`` entities to define the buy zones for each team. If none are present in the map, the gamemode will calculate a spherical buy zone based on spawn points.