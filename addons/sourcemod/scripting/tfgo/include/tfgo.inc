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
