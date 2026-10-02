# Niveaux (nouvelle formule) hors de Studio : le VRAI moteur des niveaux (src\server\Hub\LevelGame.luau, qui hérite du
# vrai PlotGame.luau) joué par un joueur simulé, en quelques secondes. Sert à régler la difficulté et à vérifier les
# règles sans ouvrir Studio. Depuis le dossier roblox-ranked-td :
#   powershell -ExecutionPolicy Bypass -File tools\levels\run.ps1            (tableau des 10 niveaux, plusieurs joueurs types)
#   powershell -ExecutionPolicy Bypass -File tools\levels\run.ps1 -Tests     (vérifications des règles : tests.luau)
#   powershell -ExecutionPolicy Bypass -File tools\levels\run.ps1 -Lazy      (premiers niveaux joués sans presque rien faire : lazy.luau)
#   powershell -ExecutionPolicy Bypass -File tools\levels\run.ps1 -Regler "Levels.RAMP_END=1.4;Levels.DEFINITIONS.1.health=10"
param(
	[switch]$Tests,
	[switch]$Lazy,
	[string]$Regler = "" # essais de réglages sans toucher à src : "Levels.CHAMP=valeur;Levels.Autre.champ=valeur"
)
$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
$repo = (Resolve-Path (Join-Path $here "..\..")).Path
$shared = Join-Path $repo "src\shared"
$gen = Join-Path $here "gen"
$genShared = Join-Path $gen "shared"
$genServer = Join-Path $gen "server"
$genHub = Join-Path $genServer "Hub"
New-Item -ItemType Directory -Force $genShared | Out-Null
New-Item -ItemType Directory -Force $genHub | Out-Null

if (-not (Get-Command luau -ErrorAction SilentlyContinue)) {
	Write-Host "La commande luau est introuvable : installe Luau (https://github.com/luau-lang/luau/releases) et ajoute-la au PATH."
	exit 1
}

# Copie des vrais modules dans gen\, avec les imitations de Roblox ajoutées au début de la première ligne (les
# numéros de ligne des erreurs ne bougent pas).
$utf8 = New-Object System.Text.UTF8Encoding($false)
$preludeShared = 'local __shim = require("../../../balance/idle/shim"); local Vector3, Color3, CFrame, script = __shim.Vector3, __shim.Color3, __shim.CFrame, __shim.script; '
foreach ($file in Get-ChildItem $shared -Filter *.luau) {
	if ($file.Name -ne "Remotes.luau") {
		$source = [IO.File]::ReadAllText($file.FullName, $utf8)
		[IO.File]::WriteAllText((Join-Path $genShared $file.Name), $preludeShared + $source, $utf8)
	}
}
$stubs = Join-Path $here "stubs"
Copy-Item (Join-Path $stubs "Remotes.luau") (Join-Path $genShared "Remotes.luau") -Force
Copy-Item (Join-Path $stubs "PlayerData.luau") (Join-Path $genServer "PlayerData.luau") -Force
Copy-Item (Join-Path $stubs "HubMap.luau") (Join-Path $genHub "HubMap.luau") -Force
Copy-Item (Join-Path $stubs "IdleTowerModel.luau") (Join-Path $genHub "IdleTowerModel.luau") -Force
$preludeServer = 'local __shim = require("../../../../balance/idle/shim"); local __env = require("../../../env"); local Vector3, Color3, CFrame, script, game, workspace, Random, Instance, task = __shim.Vector3, __shim.Color3, __shim.CFrame, __env.serverScript, __env.game, __env.workspace, __env.Random, __env.Instance, __env.task; '
foreach ($name in "PlotGame.luau", "LevelGame.luau") {
	$source = [IO.File]::ReadAllText((Join-Path $repo "src\server\Hub\$name"), $utf8)
	[IO.File]::WriteAllText((Join-Path $genHub $name), $preludeServer + $source, $utf8)
}

[Console]::OutputEncoding = $utf8
Push-Location $here
try {
	if ($Tests) {
		& luau tests.luau
	} elseif ($Lazy -and $Regler -ne "") {
		& luau --codegen -O2 lazy.luau -a "regler=$Regler"
	} elseif ($Lazy) {
		& luau --codegen -O2 lazy.luau
	} elseif ($Regler -ne "") {
		& luau --codegen -O2 sim.luau -a "regler=$Regler"
	} else {
		& luau --codegen -O2 sim.luau
	}
	$code = $LASTEXITCODE
} finally {
	Pop-Location
}
exit $code
