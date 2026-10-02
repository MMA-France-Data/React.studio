# Niveaux (nouvelle formule) hors de Studio : le VRAI moteur des niveaux (src\server\Hub\LevelGame.luau, qui hérite du
# vrai PlotGame.luau) joué par un joueur simulé, en quelques secondes. Sert à régler la difficulté et à vérifier les
# règles sans ouvrir Studio. Depuis le dossier roblox-ranked-td :
#   powershell -ExecutionPolicy Bypass -File tools\levels\run.ps1            (tableau des 10 niveaux, plusieurs joueurs types)
#   powershell -ExecutionPolicy Bypass -File tools\levels\run.ps1 -Tests     (vérifications des règles : tests.luau)
#   powershell -ExecutionPolicy Bypass -File tools\levels\run.ps1 -Lazy      (niveaux joués sans presque rien faire : lazy.luau)
#   powershell -ExecutionPolicy Bypass -File tools\levels\run.ps1 -Tune      (cherche les PV de chaque niveau : tune.luau)
#   powershell -ExecutionPolicy Bypass -File tools\levels\run.ps1 -Curve     (ce qu'un joueur actif peut se payer au fil d'un niveau : curve.luau)
#   powershell -ExecutionPolicy Bypass -File tools\levels\run.ps1 -Regler "Levels.STREAM.RAMP_CURVE=1.2;Levels.DEFINITIONS.1.health=40"
param(
	[switch]$Tests,
	[switch]$Lazy,
	[switch]$Tune,
	[switch]$Curve,
	[string]$Niveaux = "", # avec -Tune : seulement ces niveaux, ex. "1,3,6"
	[string]$Rythme = "", # avec -Tune ou -Curve : secondes entre deux achats du joueur simulé (sinon : le rythme de chaque niveau)
	[string]$Vies = "", # avec -Tune : vies qu'il doit garder (5 par défaut)
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

# Arguments passés aux outils : "nom=valeur" (les vides sont ignorés par l'outil).
$options = @("regler=$Regler", "rythme=$Rythme")

[Console]::OutputEncoding = $utf8
Push-Location $here
try {
	if ($Tests) {
		& luau --codegen -O2 tests.luau
		$code = $LASTEXITCODE
	} elseif ($Tune) {
		# Un niveau par processus, tous en même temps (la recherche prend sinon plusieurs minutes), puis les lignes
		# remises dans l'ordre.
		$levels = if ($Niveaux -ne "") { $Niveaux -split "[,; ]+" | Where-Object { $_ -ne "" } } else { 1..10 }
		$temp = Join-Path $gen "tune"
		New-Item -ItemType Directory -Force $temp | Out-Null
		$luau = (Get-Command luau).Source
		$jobs = @()
		foreach ($level in $levels) {
			$out = Join-Path $temp "niveau-$level.txt"
			$arguments = "--codegen -O2 tune.luau -a `"regler=$Regler`" `"niveaux=$level`" `"rythme=$Rythme`" `"vies=$Vies`""
			$jobs += [pscustomobject]@{
				Level = $level
				Out = $out
				Process = Start-Process -FilePath $luau -ArgumentList $arguments -WorkingDirectory $here -NoNewWindow -PassThru -RedirectStandardOutput $out -RedirectStandardError "$out.err"
			}
		}
		$code = 0
		$first = $true
		$healths = @()
		foreach ($job in $jobs) {
			$job.Process.WaitForExit()
			$lines = [IO.File]::ReadAllLines($job.Out, $utf8)
			$errors = [IO.File]::ReadAllText("$($job.Out).err", $utf8)
			if ($errors.Trim() -ne "") {
				Write-Host "Niveau $($job.Level) : $errors"
				$code = 1
			}
			foreach ($line in $lines) {
				if ($line -match "^\d") {
					Write-Host $line
					$healths += ($line -split "\s+")[1]
				} elseif ($first -and $line -notmatch "^PV trouv" -and $line.Trim() -ne "") {
					Write-Host $line # (réglages essayés, joueur de référence, en-tête : une seule fois)
				}
			}
			$first = $false
		}
		Write-Host ""
		Write-Host ("PV trouvés : " + ($healths -join ", "))
	} elseif ($Curve) {
		& luau --codegen -O2 curve.luau -a @options
		$code = $LASTEXITCODE
	} elseif ($Lazy) {
		& luau --codegen -O2 lazy.luau -a @options
		$code = $LASTEXITCODE
	} else {
		& luau --codegen -O2 sim.luau -a @options
		$code = $LASTEXITCODE
	}
} finally {
	Pop-Location
}
exit $code
