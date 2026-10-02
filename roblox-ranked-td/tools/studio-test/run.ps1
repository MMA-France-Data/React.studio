# Test automatique dans Roblox Studio : construit une place de test, l'ouvre dans Studio, lance Play,
# joue le scénario (dossier scenarios), prend une capture à chaque « SHOT:nom » et affiche la Sortie.
#
#   powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1              (map principale)
#   powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1 -Place match (match ranked + bot)
#
# Résultats dans tools\studio-test\out : studio-output.log et les captures .png.
# Si Studio est déjà ouvert, le script s'arrête pour ne pas te faire perdre ton travail
# (ajoute -CloseStudio pour le fermer quand même). À la fin, il ferme le Studio qu'il a ouvert.
param(
	[ValidateSet("hub", "match")][string]$Place = "hub",
	# Durée du Play en secondes. 0 = selon la place : map principale 280 s (les tests du classé puis du tuto sont à
	# la fin, vers 3 min 50 ; chaque nouveau modèle d'ennemi du dossier assets/EnemyModels ajoute ~3,5 s), match 240 s.
	[int]$Seconds = 0,
	[switch]$CloseStudio,
	[switch]$KeepOpen,
	[int]$Timeout = 0 # ouverture de Studio + Play ($Seconds) + fermeture (0 = $Seconds + 150 s)
)
if ($Seconds -le 0) { $Seconds = if ($Place -eq "match") { 240 } else { 420 } }
if ($Timeout -le 0) { $Timeout = $Seconds + 150 }
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$repo = (Resolve-Path (Join-Path $root "..\..")).Path
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

# 1. Place de test (en mode match : copie de Shared avec STUDIO_FORCE_MODE = "Match")
if ($Place -eq "match") {
	$sharedMatch = Join-Path $out "shared_match"
	Remove-Item -Recurse -Force $sharedMatch -ErrorAction SilentlyContinue
	Copy-Item -Recurse (Join-Path $repo "src\shared") $sharedMatch
	$config = Join-Path $sharedMatch "Config.luau"
	$text = [IO.File]::ReadAllText($config).Replace('Config.STUDIO_FORCE_MODE = "Auto"', 'Config.STUDIO_FORCE_MODE = "Match"')
	[IO.File]::WriteAllText($config, $text, (New-Object Text.UTF8Encoding $false))
}
node (Join-Path $root "mkproj.cjs") $Place $Seconds
$placeFile = Join-Path $out "$Place.rbxl"
rojo build (Join-Path $out "$Place.project.json") -o $placeFile
if ($LASTEXITCODE -ne 0) { exit 1 }

# 2. Plugin (toujours la version du dépôt)
$plugins = Join-Path $env:LOCALAPPDATA "Roblox\Plugins"
New-Item -ItemType Directory -Force $plugins | Out-Null
Copy-Item (Join-Path $root "AutoPlayTest.lua") $plugins -Force

# 3. Serveur qui reçoit la Sortie, puis Studio (ouvert comme par un double-clic : lancé
#    directement depuis un terminal, Studio peut ne pas réussir à se connecter à Roblox)
$log = Join-Path $out "studio-output.log"
[IO.File]::WriteAllText($log, "")
$server = Start-Process node -ArgumentList "`"$(Join-Path $root 'logserver.cjs')`"" -WindowStyle Hidden -PassThru
# Écran gardé allumé pendant le test (éteint, Studio n'affiche plus rien : voir awake.ps1).
. (Join-Path $root "awake.ps1")
Start-KeepAwake
try {
	explorer.exe $placeFile
	$start = Get-Date
	$shots = @{}
	while ($true) {
		Start-Sleep -Milliseconds 250
		$lines = Get-Content $log -Encoding UTF8
		foreach ($line in $lines) {
			if ($line -match "SHOT:(\w+)" -and -not $shots.ContainsKey($Matches[1])) {
				$name = $Matches[1]
				$shots[$name] = $true
				& (Join-Path $root "shot.ps1") (Join-Path $out "$name.png") | Out-Null
			}
		}
		if (($lines -join "`n") -match "play mode ended") { break }
		if (((Get-Date) - $start).TotalSeconds -gt $Timeout) { Write-Host "Temps dépassé"; break }
	}
} finally {
	Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
	Stop-KeepAwake
}
if (-not $KeepOpen) {
	Stop-Process -Name RobloxStudioBeta -Force -ErrorAction SilentlyContinue
}

Get-Content $log -Encoding UTF8
Write-Host ""
Write-Host ("Captures : " + (($shots.Keys | Sort-Object) -join ", "))
$errors = @(Get-Content $log -Encoding UTF8 | Where-Object { $_ -match "\]\[Error\]|\[FAIL\]" })
Write-Host "Erreurs : $($errors.Count)"
