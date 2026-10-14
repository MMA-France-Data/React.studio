# Garde l'écran allumé pendant un test automatique (à charger avec « . awake.ps1 » dans run.ps1).
# Sans ça, quand personne ne touche au PC pendant 10 minutes, Windows éteint l'écran, et Studio n'affiche plus
# rien du tout : l'image du jeu fait 1 x 1 pixel, plus aucune image n'est dessinée (RenderStepped s'arrête), les
# captures sont blanches et tous les tests de l'écran ratent (vu le 02/10/2026).
#   Start-KeepAwake : demande à Windows de garder l'écran allumé tant que ce script tourne (rien n'est changé dans
#                     les réglages d'alimentation : la demande s'arrête avec le script), et rallume l'écran s'il
#                     était déjà éteint (un mouvement de souris d'un pixel, aller et retour).
#   Stop-KeepAwake  : rend la main (l'écran s'éteindra de nouveau après le délai habituel).
Add-Type @"
using System; using System.Runtime.InteropServices;
public class TestAwake {
	[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint flags);
	[DllImport("user32.dll")] public static extern void mouse_event(uint flags, int dx, int dy, uint data, UIntPtr extra);
}
"@
function Start-KeepAwake {
	# ES_CONTINUOUS (0x80000000) + ES_SYSTEM_REQUIRED (1) + ES_DISPLAY_REQUIRED (2)
	[TestAwake]::SetThreadExecutionState(2147483651) | Out-Null
	[TestAwake]::mouse_event(1, 1, 0, 0, [UIntPtr]::Zero) # 1 = MOUSEEVENTF_MOVE
	Start-Sleep -Milliseconds 50
	[TestAwake]::mouse_event(1, -1, 0, 0, [UIntPtr]::Zero)
}
function Stop-KeepAwake {
	[TestAwake]::SetThreadExecutionState(2147483648) | Out-Null # ES_CONTINUOUS seul : plus aucune demande
}
