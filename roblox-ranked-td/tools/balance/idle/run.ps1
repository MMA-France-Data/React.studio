# Simulateur du mode infini (voir tools\balance\README.md).
# Depuis le dossier roblox-ranked-td :
#   powershell -ExecutionPolicy Bypass -File tools\balance\idle\run.ps1
#   powershell -ExecutionPolicy Bypass -File tools\balance\idle\run.ps1 -Rapide
#   powershell -ExecutionPolicy Bypass -File tools\balance\idle\run.ps1 -Graines 3 -Heures 20 -Scenarios base
#   powershell -ExecutionPolicy Bypass -File tools\balance\idle\run.ps1 -Regler "IdleConfig.HEALTH_GROWTH=1.2;IdleConfig.UPGRADE_DAMAGE=1.45"
# Résultats dans tools\balance\idle\out\ : rapport.txt, timeline.csv, heures.csv (et journal.txt avec -Journal)
param(
	[int]$Graines = 3,            # nombre de parties simulées par scénario (tirages de la machine à tours différents)
	[double]$Heures = 100,        # durée de jeu simulée par partie
	[string]$Scenarios = "base,forge,renaissance,renaissance-seule",
	[double]$Pas = 0.05,          # pas de temps de la simulation (secondes)
	[string]$Regler = "",         # essais de réglages sans toucher à src : "Module.CHAMP=valeur;Module.Autre.champ=valeur"
	[switch]$Journal,             # écrit aussi out\journal.txt : tout ce que fait le joueur simulé (1re partie)
	[switch]$Rapide               # essai rapide : 3 graines, 40 h, scénario base seulement
)
$ErrorActionPreference = "Stop"
if ($Rapide) {
	if (-not $PSBoundParameters.ContainsKey("Graines")) { $Graines = 3 }
	if (-not $PSBoundParameters.ContainsKey("Heures")) { $Heures = 40 }
	if (-not $PSBoundParameters.ContainsKey("Scenarios")) { $Scenarios = "base" }
}
$here = $PSScriptRoot
$repo = (Resolve-Path (Join-Path $here "..\..\..")).Path
$shared = Join-Path $repo "src\shared"
$gen = Join-Path $here "gen\shared"
$out = Join-Path $here "out"
New-Item -ItemType Directory -Force $gen | Out-Null
New-Item -ItemType Directory -Force $out | Out-Null

if (-not (Get-Command luau -ErrorAction SilentlyContinue)) {
	Write-Host "La commande luau est introuvable : installe Luau (https://github.com/luau-lang/luau/releases) et ajoute-la au PATH."
	exit 1
}

# 1. Copie des vrais modules de src\shared dans gen\shared, avec les imitations de Roblox (shim.luau)
#    ajoutées au début de la première ligne : les numéros de ligne des erreurs ne bougent pas.
$utf8 = New-Object System.Text.UTF8Encoding($false)
$prelude = 'local __shim = require("../../shim"); local Vector3, Color3, CFrame, script = __shim.Vector3, __shim.Color3, __shim.CFrame, __shim.script; '
Get-ChildItem $gen -Filter *.luau | Remove-Item
foreach ($file in Get-ChildItem $shared -Filter *.luau) {
	$source = [IO.File]::ReadAllText($file.FullName, $utf8)
	[IO.File]::WriteAllText((Join-Path $gen $file.Name), $prelude + $source, $utf8)
}

# 2. Simulation. Chaque ligne commence par un préfixe qui dit où elle va :
#    "CSV|" -> timeline.csv, "HEURES|" -> heures.csv, "JOURNAL|" -> journal.txt, "PROGRES|" -> écran seulement,
#    le reste est le rapport.
[Console]::OutputEncoding = $utf8
$report = New-Object System.Collections.Generic.List[string]
$csv = New-Object System.Collections.Generic.List[string]
$hours = New-Object System.Collections.Generic.List[string]
$log = New-Object System.Collections.Generic.List[string]
$started = Get-Date
$arguments = @("graines=$Graines", "heures=$Heures", "scenarios=$Scenarios", "pas=$Pas")
if ($Regler -ne "") { $arguments += "regler=$Regler" }
if ($Journal) { $arguments += "journal=1" }
Write-Host "Simulation en cours ($Graines graine(s) x $Heures h, scénarios : $Scenarios)..."
Push-Location $here
try {
	& luau --codegen -O2 main.luau -a @arguments | ForEach-Object {
		if ($_.StartsWith("CSV|")) { $csv.Add($_.Substring(4)) }
		elseif ($_.StartsWith("HEURES|")) { $hours.Add($_.Substring(7)) }
		elseif ($_.StartsWith("JOURNAL|")) { $log.Add($_.Substring(8)) }
		elseif ($_.StartsWith("PROGRES|")) { Write-Host $_.Substring(8) }
		else { $report.Add($_) }
	}
	$code = $LASTEXITCODE
} finally {
	Pop-Location
}
if ($code -ne 0) {
	$report | ForEach-Object { Write-Host $_ }
	Write-Host "Le simulateur s'est arrêté sur une erreur (voir ci-dessus)."
	exit 1
}

[IO.File]::WriteAllLines((Join-Path $out "rapport.txt"), $report, $utf8)
[IO.File]::WriteAllLines((Join-Path $out "timeline.csv"), $csv, $utf8)
[IO.File]::WriteAllLines((Join-Path $out "heures.csv"), $hours, $utf8)
if ($Journal) { [IO.File]::WriteAllLines((Join-Path $out "journal.txt"), $log, $utf8) }
$report | ForEach-Object { Write-Host $_ }
$minutes = [math]::Round(((Get-Date) - $started).TotalMinutes, 1)
Write-Host ""
Write-Host "Terminé en $minutes min. Rapport : $out\rapport.txt  -  Tableaux : timeline.csv et heures.csv"
if ($Journal) { Write-Host "Journal du joueur simulé : $out\journal.txt" }
