#if defined _tfgo_included
#endinput
#endif
#define _tfgo_included

enum Arena_Winreason
{
	Winreason_PointCaptured = 1, 
	Winreason_Elimination, 
	Winreason_AllPointsCaptured = 4, 
	Winreason_Stalemate
}

/**
 * Forward called when the bomb has been planted.
 *
 * @param team				The team that planted the bomb
 * @param cappers			ArrayList of clients that planted the bomb
 * @noreturn
 */
forward void TFGO_OnBombPlanted(int team, ArrayList cappers);

/**
 * Forward called when the bomb was detonated.
 *
 * @param team				The team that detonated the bomb
 * @noreturn
 */
forward void TFGO_OnBombDetonated(int team);

/**
 * Forward called when the bomb has been defused.
 *
 * @param team				The team that defused the bomb
 * @param cappers			ArrayList of clients that defused the bomb
 * @noreturn
 */
forward void TFGO_OnBombDefused(int team, ArrayList cappers); 
