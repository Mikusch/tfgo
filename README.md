# Team Fortress: Global Offensive Arena [![Action Status](https://github.com/Mikusch/tfgo/workflows/Package/badge.svg)](https://github.com/Mikusch/tfgo/actions?query=branch%3Amaster)
TF:GO Arena brings the bomb defusal mode from Counter-Strike: Global Offensive to Team Fortress 2.
All players begin the game with basic weapons and can buy new equipment at the start of each round with money earned from neutralizing enemy players or planting the bomb.

The plugin first started development on September 29, 2019 by [Mikusch](https://github.com/Mikusch) and was his first attempt at using SourcePawn.
Many new gameplay features such as universal headshots, armor, and defuse kits have been added since.

## Dependencies
* SourceMod 1.10
* [DHooks with Detour Support](https://github.com/peace-maker/DHooks2/tree/dynhooks)
* [TF2 Econ Data](https://forums.alliedmods.net/showthread.php?t=315011)
* [LoadSoundScript](https://github.com/haxtonsale/LoadSoundScript)
* [More Colors](https://forums.alliedmods.net/showthread.php?t=185016) (recompile only)
* [MemoryPatch](https://github.com/Kenzzer/MemoryPatch) (recompile only)

## Builds
GitHub automatically builds an archive on every push to the repository that contains all files required to run the game mode.
To download this archive head over to [Actions](https://github.com/Mikusch/tfgo/actions?query=workflow%3APackage) and click on the latest "Package" workflow on branch ``master``.

## Maps
Most arena maps should be compatible with this game mode as long as they don't do wacky stuff (like altering the control point after it has been captured).

A `func_respawnroom` entity for each team to define the buy zones is highly recommended but not required.
Additionally, maps with multiple control points are required to give them proper indices, or else they may fail to lock when the bomb is planted.
