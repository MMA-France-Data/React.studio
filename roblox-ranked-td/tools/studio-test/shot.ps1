# Capture de la fenêtre de Roblox Studio (même si elle est derrière une autre fenêtre).
#   shot.ps1 <fichier.png>                    (le premier Studio trouvé)
#   shot.ps1 <fichier.png> -ProcessId 1234    (ce Studio-là : run.ps1 donne celui qu'il a ouvert)
param([Parameter(Mandatory = $true)][string]$OutFile, [int]$ProcessId = 0)
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public class StudioWindow {
	[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
	[DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
	[DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
	[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
	public struct RECT { public int L, T, R, B; }
}
"@
$process = Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue |
	Where-Object { $_.MainWindowHandle -ne 0 -and ($ProcessId -eq 0 -or $_.Id -eq $ProcessId) } | Select-Object -First 1
if (-not $process) { Write-Host "Studio n'est pas ouvert"; exit 1 }
$handle = $process.MainWindowHandle
if ([StudioWindow]::IsIconic($handle)) { [StudioWindow]::ShowWindow($handle, 4) | Out-Null; Start-Sleep -Milliseconds 500 }
$rect = New-Object StudioWindow+RECT
[StudioWindow]::GetWindowRect($handle, [ref]$rect) | Out-Null
$bitmap = New-Object System.Drawing.Bitmap ($rect.R - $rect.L), ($rect.B - $rect.T)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$hdc = $graphics.GetHdc()
[StudioWindow]::PrintWindow($handle, $hdc, 2) | Out-Null # 2 = PW_RENDERFULLCONTENT (rendu 3D compris)
$graphics.ReleaseHdc($hdc)
$bitmap.Save($OutFile, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host "Capture : $OutFile"
