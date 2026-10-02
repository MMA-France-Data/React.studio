# Test « téléphone » : le jeu affiché dans une fenêtre de Studio réduite à la taille d'un écran de téléphone
# (les autres tests ne font que des calculs avec de fausses tailles). Le scénario scenarios\PhoneClient.luau demande
# une taille par « PHONE:want=645x268;have=... » dans la Sortie : ce script redimensionne la fenêtre de Studio jusqu'à
# ce que l'écran du jeu fasse cette taille, puis le scénario ouvre chaque fenêtre, vérifie que rien ne sort de l'écran
# et demande une capture (« SHOT:nom »).
# Tout au début, le joueur de test est un NOUVEAU joueur : le tuto démarre tout seul comme dans le jeu publié, et le
# scénario regarde ses premières étapes à la taille du téléphone (captures phone_a_newplayer*.png).
#
#   powershell -ExecutionPolicy Bypass -File tools\studio-test\phone.ps1
#
# Résultats dans tools\studio-test\out : studio-output.log et phone_<taille>_<nom>.png (a = le téléphone du
# propriétaire, b = grand téléphone, c = petit). Ne touche pas au PC pendant le test (la fenêtre de Studio bouge).
# À la fin, Studio est fermé (il retrouve sa taille normale à la prochaine ouverture).
#
# Test des NIVEAUX (prototype de la nouvelle formule) : même outil, autre scénario (scenarios\LevelsServer.luau et
# LevelsClient.luau), à la taille normale de Studio puis à la taille d'un téléphone :
#   powershell -ExecutionPolicy Bypass -File tools\studio-test\phone.ps1 -Mode levels
# Captures : levels_<nom>.png.
param(
	[ValidateSet("phone", "levels")][string]$Mode = "phone",
	[int]$Seconds = 0, # 0 = selon le test : téléphone 420 s, niveaux 360 s
	[switch]$CloseStudio,
	[switch]$KeepOpen
)
if ($Seconds -le 0) { $Seconds = if ($Mode -eq "levels") { 360 } else { 420 } }
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$out = Join-Path $root "out"
New-Item -ItemType Directory -Force $out | Out-Null

if (Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue) {
	if (-not $CloseStudio) {
		Write-Host "Roblox Studio est ouvert : ferme-le (sauvegarde ton travail) ou relance avec -CloseStudio."
		exit 1
	}
	Stop-Process -Name RobloxStudioBeta -Force
	Start-Sleep 3
}

Add-Type @"
using System; using System.Runtime.InteropServices;
public class PhoneWindow {
	[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
	[DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int height, bool repaint);
	[DllImport("user32.dll")] public static extern bool IsZoomed(IntPtr h);
	[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
	public struct RECT { public int L, T, R, B; }
}
"@

node (Join-Path $root "mkproj.cjs") $Mode $Seconds
$placeFile = Join-Path $out "$Mode.rbxl"
rojo build (Join-Path $out "$Mode.project.json") -o $placeFile
if ($LASTEXITCODE -ne 0) { exit 1 }

$plugins = Join-Path $env:LOCALAPPDATA "Roblox\Plugins"
New-Item -ItemType Directory -Force $plugins | Out-Null
Copy-Item (Join-Path $root "AutoPlayTest.lua") $plugins -Force

Get-ChildItem $out -Filter "$($Mode)_*.png" -ErrorAction SilentlyContinue | Remove-Item -Force
$log = Join-Path $out "studio-output.log"
[IO.File]::WriteAllText($log, "")
$server = Start-Process node -ArgumentList "`"$(Join-Path $root 'logserver.cjs')`"" -WindowStyle Hidden -PassThru
# Écran gardé allumé pendant le test (éteint, Studio n'affiche plus rien : voir awake.ps1).
. (Join-Path $root "awake.ps1")
Start-KeepAwake

# Lit le journal pendant que logserver.cjs y écrit.
function Read-Log {
	try {
		$stream = [IO.File]::Open($log, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
		$reader = New-Object IO.StreamReader($stream, [Text.Encoding]::UTF8)
		$text = $reader.ReadToEnd()
		$reader.Close()
		return $text -split "`r?`n"
	} catch {
		return @()
	}
}
function Get-StudioWindow {
	$process = Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
	if ($process) { return $process.MainWindowHandle }
	return [IntPtr]::Zero
}

try {
	explorer.exe $placeFile
	$start = Get-Date
	$shots = @{}
	$seen = 0 # lignes « PHONE:want » déjà traitées
	$lastResize = Get-Date
	$lastHave = "" # taille du jeu (« have ») de la dernière correction faite
	while ($true) {
		Start-Sleep -Milliseconds 250
		$lines = Read-Log
		foreach ($line in $lines) {
			if ($line -match "SHOT:(\w+)" -and -not $shots.ContainsKey($Matches[1])) {
				$name = $Matches[1]
				$shots[$name] = $true
				& (Join-Path $root "shot.ps1") (Join-Path $out "$name.png") | Out-Null
			}
		}
		# Dernière demande de taille : une seule correction à la fois, puis 2,5 s d'attente. Le journal arrive avec
		# ~1 s de retard : une ligne écrite AVANT la dernière correction (même taille « have » que celle déjà
		# corrigée) est ignorée pendant 5 s, sinon la même correction serait faite deux fois.
		$wants = @($lines | Where-Object { $_ -match "PHONE:want=(\d+)x(\d+);have=(\d+)x(\d+)" })
		if ($wants.Count -gt $seen -and ((Get-Date) - $lastResize).TotalSeconds -gt 2.5) {
			$seen = $wants.Count
			if ($wants[-1] -match "PHONE:want=(\d+)x(\d+);have=(\d+)x(\d+)") {
				$dx = [int]$Matches[1] - [int]$Matches[3]
				$dy = [int]$Matches[2] - [int]$Matches[4]
				$have = "$($Matches[3])x$($Matches[4])"
				$stale = ($have -eq $lastHave -and ((Get-Date) - $lastResize).TotalSeconds -lt 5)
				$handle = Get-StudioWindow
				if (-not $stale -and $handle -ne [IntPtr]::Zero -and ([Math]::Abs($dx) -gt 2 -or [Math]::Abs($dy) -gt 2)) {
					$lastHave = $have
					if ([PhoneWindow]::IsZoomed($handle)) {
						[PhoneWindow]::ShowWindow($handle, 9) | Out-Null # 9 = SW_RESTORE (plus en plein écran)
						Start-Sleep -Milliseconds 600
					}
					$rect = New-Object PhoneWindow+RECT
					[PhoneWindow]::GetWindowRect($handle, [ref]$rect) | Out-Null
					$width = [Math]::Max(320, ($rect.R - $rect.L) + $dx)
					$height = [Math]::Max(320, ($rect.B - $rect.T) + $dy)
					[PhoneWindow]::MoveWindow($handle, 10, 10, $width, $height, $true) | Out-Null
					Write-Host "Fenêtre de Studio : $width x $height (écran du jeu voulu $($Matches[1]) x $($Matches[2]), obtenu $($Matches[3]) x $($Matches[4]))"
					$lastResize = Get-Date
				}
			}
		}
		$all = $lines -join "`n"
		if ($all -match "play mode ended") { break }
		# Scénario fini avant la fin du Play : inutile d'attendre (la dernière capture est déjà prise).
		if ($all -match "PHONE:done") { Start-Sleep -Seconds 2; break }
		if (((Get-Date) - $start).TotalSeconds -gt ($Seconds + 150)) { Write-Host "Temps dépassé"; break }
	}
} finally {
	Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
	Stop-KeepAwake
}
if (-not $KeepOpen) {
	Stop-Process -Name RobloxStudioBeta -Force -ErrorAction SilentlyContinue
}

$lines = Read-Log
$lines | Where-Object { $_ -match "\[PHONE\]|\[LEVELS\]|\[PASS\]|\[FAIL\]|\]\[Error\]" } | Where-Object { $_ -notmatch "PHONE:want" }
Write-Host ""
Write-Host ("Captures : " + (($shots.Keys | Sort-Object) -join ", "))
$errors = @($lines | Where-Object { $_ -match "\]\[Error\]|\[FAIL\]" })
Write-Host "Erreurs : $($errors.Count)"
