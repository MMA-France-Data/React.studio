# Test automatique du jeu dans Roblox Studio : construit une place de test, l'ouvre dans Studio, lance Play, joue le
# scénario (dossier scenarios), prend une capture à chaque « SHOT:nom » de la Sortie et affiche les résultats.
#
#   powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1
#       -> le JEU en entier (scenarios\LevelsServer.luau et LevelsClient.luau) : niveaux, camp d'entraînement,
#          boutique, et l'interface à la taille normale de Studio puis à la taille d'un téléphone. Le scénario
#          demande une taille par « PHONE:want=750x332;have=... » : ce script redimensionne la fenêtre de Studio
#          jusqu'à ce que l'écran du jeu fasse cette taille. Captures : levels_<nom>.png.
#   powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1 -Test monsters
#       -> les modèles 3D des monstres (scenarios\MonstersClient.luau) : chaque modèle de assets\EnemyModels, la
#          galerie Studio, un vrai niveau. Captures : monsters_<nom>.png.
#   powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1 -Test tutorial
#       -> le TUTO d'un nouveau joueur (scenarios\TutorialServer.luau et TutorialClient.luau) : la flèche le mène
#          au niveau 1, le guide jusqu'à la victoire, puis lui montre la boutique ; « Passer le tuto » ; à la
#          taille d'un ordinateur puis d'un téléphone. Captures : tutorial_<nom>.png.
#   powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1 -Test english
#       -> la VERSION ANGLAISE (scenarios\EnglishServer.luau et EnglishClient.luau) : le joueur passe en anglais,
#          tous les écrans sont ouverts l'un après l'autre (camp, boutique, niveau, fin de niveau, tuto, panneaux
#          de la parcelle) et chaque texte resté en français est listé. Captures : english_<nom>.png.
#
# Résultats dans tools\studio-test\out : studio-output.log et les captures. Ne touche pas au PC pendant le test (la
# fenêtre de Studio du test bouge).
# Si Studio est déjà ouvert (ton travail), il n'est PAS touché : le test s'ouvre dans une autre fenêtre de Studio, et
# seule cette fenêtre est redimensionnée, photographiée puis fermée à la fin (-KeepOpen : elle reste ouverte).
# -CloseStudio : ferme d'abord tous les Studio ouverts (travail non enregistré perdu).
param(
	[ValidateSet("levels", "monsters", "tutorial", "english")][string]$Test = "levels",
	[int]$Seconds = 0, # durée maximale du Play ; 0 = selon le test : jeu 480 s, monstres 540 s, tuto et anglais 420 s
	[switch]$CloseStudio,
	[switch]$KeepOpen
)
if ($Seconds -le 0) { $Seconds = if ($Test -eq "monsters") { 540 } elseif ($Test -eq "tutorial" -or $Test -eq "english") { 420 } else { 480 } }
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$out = Join-Path $root "out"
New-Item -ItemType Directory -Force $out | Out-Null

# Studio déjà ouverts avant le test (numéros de processus) : jamais touchés, sauf avec -CloseStudio.
$others = @(Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
if ($others.Count -gt 0) {
	if ($CloseStudio) {
		Stop-Process -Name RobloxStudioBeta -Force
		Start-Sleep 3
		$others = @()
	} else {
		Write-Host "Roblox Studio est déjà ouvert : il n'est pas touché, le test s'ouvre dans une autre fenêtre de Studio."
	}
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

node (Join-Path $root "mkproj.cjs") $Test $Seconds
if ($LASTEXITCODE -ne 0) { exit 1 }
$placeFile = Join-Path $out "$Test.rbxl"
rojo build (Join-Path $out "$Test.project.json") -o $placeFile
if ($LASTEXITCODE -ne 0) { exit 1 }

$plugins = Join-Path $env:LOCALAPPDATA "Roblox\Plugins"
New-Item -ItemType Directory -Force $plugins | Out-Null
Copy-Item (Join-Path $root "AutoPlayTest.lua") $plugins -Force

Get-ChildItem $out -Filter "$($Test)_*.png" -ErrorAction SilentlyContinue | Remove-Item -Force
$log = Join-Path $out "studio-output.log"
[IO.File]::WriteAllText($log, "")
# Un test interrompu (ici ou dans une autre copie du dépôt) peut laisser tourner son serveur de journal : il garde
# le port, et la Sortie de ce test partirait dans SON fichier (« Temps dépassé », journal vide). On l'arrête.
Get-CimInstance Win32_Process -Filter "Name = 'node.exe'" -ErrorAction SilentlyContinue |
	Where-Object { $_.CommandLine -like "*logserver.cjs*" } |
	ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
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
# Le Studio ouvert par CE test : un processus qui n'existait pas avant, avec sa vraie fenêtre (pas son écran de
# démarrage : le titre de la vraie fenêtre finit par « - Roblox Studio »).
function Get-TestStudio {
	return Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue |
		Where-Object { $others -notcontains $_.Id -and $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -match "- Roblox Studio$" } |
		Select-Object -First 1
}
function Get-StudioWindow {
	$process = Get-TestStudio
	if ($process) { return $process.MainWindowHandle }
	return [IntPtr]::Zero
}

try {
	explorer.exe $placeFile
	$start = Get-Date
	$shots = @{}
	$seen = 0 # lignes « PHONE:want » déjà traitées
	# Avant la première demande de taille, la fenêtre de Studio est agrandie : la partie « ordinateur » d'un scénario
	# se joue toujours à la même taille, quelle que soit celle où Studio a été fermé la dernière fois.
	$maximized = $false
	$lastResize = Get-Date
	$lastHave = "" # taille du jeu (« have ») de la dernière correction faite
	while ($true) {
		Start-Sleep -Milliseconds 250
		$lines = Read-Log
		foreach ($line in $lines) {
			if ($line -match "SHOT:(\w+)" -and -not $shots.ContainsKey($Matches[1])) {
				$name = $Matches[1]
				$shots[$name] = $true
				$testStudio = Get-TestStudio
				if ($testStudio) { & (Join-Path $root "shot.ps1") (Join-Path $out "$name.png") -ProcessId $testStudio.Id | Out-Null }
			}
		}
		# Dernière demande de taille : une seule correction à la fois, puis 2,5 s d'attente. Le journal arrive avec
		# ~1 s de retard : une ligne écrite AVANT la dernière correction (même taille « have » que celle déjà
		# corrigée) est ignorée pendant 5 s, sinon la même correction serait faite deux fois.
		$wants = @($lines | Where-Object { $_ -match "PHONE:want=(\d+)x(\d+);have=(\d+)x(\d+)" })
		if (-not $maximized) {
			if ($wants.Count -gt 0) {
				$maximized = $true
			} else {
				$studio = Get-TestStudio
				if ($studio) {
					if ([PhoneWindow]::IsZoomed($studio.MainWindowHandle)) {
						$maximized = $true
					} else {
						[PhoneWindow]::ShowWindow($studio.MainWindowHandle, 3) | Out-Null # 3 = SW_MAXIMIZE
					}
				}
			}
		}
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
	# Seulement le Studio ouvert par ce test (les autres ne sont pas touchés).
	Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | Where-Object { $others -notcontains $_.Id } |
		ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
}

$lines = Read-Log
$lines | Where-Object { $_ -match "\[LEVELS\]|\[MONSTERS\]|\[TUTO\]|\[EN\]|\[PASS\]|\[FAIL\]|\]\[Error\]" } | Where-Object { $_ -notmatch "PHONE:want" }
Write-Host ""
Write-Host ("Captures : " + (($shots.Keys | Sort-Object) -join ", "))
$passed = @($lines | Where-Object { $_ -match "\[PASS\]" })
$errors = @($lines | Where-Object { $_ -match "\]\[Error\]|\[FAIL\]" })
Write-Host "Réussis : $($passed.Count)   Erreurs : $($errors.Count)"
