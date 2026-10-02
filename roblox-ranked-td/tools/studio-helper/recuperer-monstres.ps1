# Sort en fichiers .rbxm (assets/EnemyModels) les monstres rangés par le plugin « Rangeur de monstres »
# dans ReplicatedStorage > EnemyModels du jeu enregistré (Jeu.rbxl, Ctrl+S dans Studio).
#   powershell -ExecutionPolicy Bypass -File tools\studio-helper\recuperer-monstres.ps1
#   ... -Remplacer   : remplace aussi les fichiers qui existent déjà (sinon seuls les nouveaux sont ajoutés)
#   ... -Place <fichier.rbxl> : un autre fichier de jeu que Jeu.rbxl (sans -Place : Jeu.rbxl, sinon l'ancien
#                               nom RankedTD.rbxl, à la racine du dossier roblox-ranked-td)
# Ne supprime jamais rien : Rojo syncback écrit dans un dossier temporaire, puis on copie.
param(
	[string]$Place = "",
	[switch]$Remplacer
)
$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if (-not $Place) {
	$Place = Join-Path $repo "Jeu.rbxl"
	if (-not (Test-Path $Place)) { $Place = Join-Path $repo "RankedTD.rbxl" }
}
if (-not (Test-Path $Place)) { Write-Host "Fichier de jeu introuvable : $Place"; exit 1 }
$target = Join-Path $repo "assets\EnemyModels"

$work = Join-Path $env:TEMP "rangeur-monstres"
Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force (Join-Path $work "out") | Out-Null
$project = '{ "name": "Monstres", "tree": { "$className": "DataModel", "ReplicatedStorage": { "$className": "ReplicatedStorage", "EnemyModels": { "$path": "out" } } } }'
[IO.File]::WriteAllText((Join-Path $work "default.project.json"), $project, (New-Object Text.UTF8Encoding $false))

# Rojo écrit sa progression sur la sortie d'erreur : pas une vraie erreur (PowerShell 5.1 la prendrait pour une).
$ErrorActionPreference = "Continue"
rojo syncback --input $Place (Join-Path $work "default.project.json") -y 2>$null | Out-Null
$code = $LASTEXITCODE
$ErrorActionPreference = "Stop"
if ($code -ne 0) { Write-Host "Rojo syncback a échoué (code $code)."; exit 1 }

$added = @(); $replaced = @(); $skipped = @()
foreach ($file in Get-ChildItem (Join-Path $work "out") -File | Where-Object { $_.Extension -in ".rbxm", ".rbxmx" }) {
	$destination = Join-Path $target $file.Name
	if (Test-Path $destination) {
		if ($Remplacer) { Copy-Item $file.FullName $destination -Force; $replaced += $file.BaseName } else { $skipped += $file.BaseName }
	} else {
		Copy-Item $file.FullName $destination
		$added += $file.BaseName
	}
}
Write-Host ("Ajoutés : " + $(if ($added) { $added -join ", " } else { "aucun" }))
if ($replaced) { Write-Host ("Remplacés : " + ($replaced -join ", ")) }
if ($skipped) { Write-Host ("Déjà présents, gardés tels quels (relance avec -Remplacer pour les remplacer) : " + ($skipped -join ", ")) }
