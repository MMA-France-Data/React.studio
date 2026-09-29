# Simulateur du mode infini (voir tools\balance\README.md).
# Depuis le dossier roblox-ranked-td :
#   powershell -ExecutionPolicy Bypass -File tools\balance\idle\run.ps1
#   powershell -ExecutionPolicy Bypass -File tools\balance\idle\run.ps1 -Rapide
#   powershell -ExecutionPolicy Bypass -File tools\balance\idle\run.ps1 -Graines 3 -Heures 20 -Scenarios base
#   powershell -ExecutionPolicy Bypass -File tools\balance\idle\run.ps1 -Regler "IdleConfig.HEALTH_GROWTH=1.2;IdleConfig.UPGRADE_DAMAGE=1.45"
#   powershell -ExecutionPolicy Bypass -File tools\balance\idle\run.ps1 -Verifier   (le moteur joue-t-il comme PlotGame.luau ?)
# Résultats dans tools\balance\idle\out\ : rapport.txt, timeline.csv, heures.csv (et journal.txt avec -Journal)
param(
	[int]$Graines = 3,            # nombre de parties simulées par scénario (tirages de la machine à tours différents)
	[double]$Heures = 100,        # durée de jeu simulée par partie
	[string]$Scenarios = "base,forge,renaissance,renaissance-seule,sans-sorcier",
	[double]$Pas = 0.05,          # pas de temps de la simulation (secondes)
	[string]$Regler = "",         # essais de réglages sans toucher à src : "Module.CHAMP=valeur;Module.Autre.champ=valeur"
	[switch]$Journal,             # écrit aussi out\journal.txt : tout ce que fait le joueur simulé (1re partie)
	[switch]$Rapide,              # essai rapide : 3 graines, 40 h, scénario base seulement
	[switch]$Verifier,            # compare le moteur au vrai PlotGame.luau (quelques secondes), sans simulation
	# Parties jouées en même temps (une par cœur du processeur par défaut ; 1 = une après l'autre, comme avant).
	# Le rapport est le même dans les deux cas (voir idle\Dump.luau).
	[int]$Paralleles = 0
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

# -Verifier : le vrai PlotGame.luau (serveur) et ses modules dans gen\verif\, avec des imitations de Roblox
# (verif\extra.luau, verif\stubs\), puis verif\parity.luau fait jouer les mêmes vagues au jeu et au moteur.
if ($Verifier) {
	$verifGen = Join-Path $here "gen\verif"
	$verifShared = Join-Path $verifGen "shared"
	$verifHub = Join-Path $verifGen "server\Hub"
	New-Item -ItemType Directory -Force $verifShared | Out-Null
	New-Item -ItemType Directory -Force $verifHub | Out-Null
	$preludeShared = 'local __shim = require("../../../shim"); local Vector3, Color3, CFrame, script = __shim.Vector3, __shim.Color3, __shim.CFrame, __shim.script; '
	foreach ($file in Get-ChildItem $shared -Filter *.luau) {
		if ($file.Name -ne "Remotes.luau") {
			$source = [IO.File]::ReadAllText($file.FullName, $utf8)
			[IO.File]::WriteAllText((Join-Path $verifShared $file.Name), $preludeShared + $source, $utf8)
		}
	}
	$stubs = Join-Path $here "verif\stubs"
	Copy-Item (Join-Path $stubs "Remotes.luau") (Join-Path $verifShared "Remotes.luau") -Force
	Copy-Item (Join-Path $stubs "PlayerData.luau") (Join-Path $verifGen "server\PlayerData.luau") -Force
	Copy-Item (Join-Path $stubs "HubMap.luau") (Join-Path $verifHub "HubMap.luau") -Force
	Copy-Item (Join-Path $stubs "IdleTowerModel.luau") (Join-Path $verifHub "IdleTowerModel.luau") -Force
	$preludeServer = 'local __shim = require("../../../../shim"); local __extra = require("../../../../verif/extra"); local Vector3, Color3, CFrame, script, game, workspace, Random, Instance, task = __shim.Vector3, __shim.Color3, __shim.CFrame, __extra.serverScript, __extra.game, __extra.workspace, __extra.Random, __extra.Instance, __extra.task; '
	$plotGame = [IO.File]::ReadAllText((Join-Path $repo "src\server\Hub\PlotGame.luau"), $utf8)
	[IO.File]::WriteAllText((Join-Path $verifHub "PlotGame.luau"), $preludeServer + $plotGame, $utf8)
	[Console]::OutputEncoding = $utf8
	Push-Location (Join-Path $here "verif")
	try {
		& luau --codegen -O2 parity.luau
		$code = $LASTEXITCODE
	} finally {
		Pop-Location
	}
	exit $code
}

# 2. Simulation. Chaque ligne commence par un préfixe qui dit où elle va :
#    "CSV|" -> timeline.csv, "HEURES|" -> heures.csv, "JOURNAL|" -> journal.txt, "PROGRES|" -> écran seulement,
#    le reste est le rapport.
[Console]::OutputEncoding = $utf8
# Lignes d'un fichier de sortie d'une partie (gen\runs\*.out). Juste après la fin d'un processus luau, Windows
# peut encore garder le fichier ouvert un court instant (« en cours d'utilisation par un autre processus » :
# arrivé une fois, tout le calcul s'arrêtait et les parties lancées continuaient seules). On l'ouvre en
# laissant les autres l'ouvrir aussi, et on réessaie toutes les 0,2 s, $essais fois au plus (50 = 10 s).
function Read-JobLines([string]$path, [int]$essais = 50) {
	for ($try = 1; ; $try++) {
		try {
			$stream = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
			$reader = New-Object IO.StreamReader($stream, $utf8)
			try {
				$lines = New-Object System.Collections.Generic.List[string]
				while ($null -ne ($line = $reader.ReadLine())) { $lines.Add($line) }
				return ,$lines.ToArray()
			} finally {
				$reader.Dispose()
			}
		} catch {
			if ($try -ge $essais) { throw }
			Start-Sleep -Milliseconds 200
		}
	}
}
$report = New-Object System.Collections.Generic.List[string]
$csv = New-Object System.Collections.Generic.List[string]
$hours = New-Object System.Collections.Generic.List[string]
$log = New-Object System.Collections.Generic.List[string]
$started = Get-Date
$arguments = @("graines=$Graines", "heures=$Heures", "scenarios=$Scenarios", "pas=$Pas")
if ($Regler -ne "") { $arguments += "regler=$Regler" }
$scenarioList = @($Scenarios.Split(",") | Where-Object { $_ -ne "" })
if ($Paralleles -le 0) { $Paralleles = [Environment]::ProcessorCount }
$Paralleles = [math]::Min($Paralleles, $scenarioList.Count * $Graines)
if ($Paralleles -gt 1) {
	# Calcul en parallèle : chaque partie (scénario, graine) dans son propre processus luau ("travail=1"), qui
	# écrit la partie terminée sur une ligne "PARTIE|..." ; run.ps1 en fait un module gen\runs\<nom>.luau, puis
	# un dernier processus ("assembler=...") relit toutes les parties et écrit le rapport (voir Dump.luau).
	Write-Host "Simulation en cours ($Graines graine(s) x $Heures h, scénarios : $Scenarios ; $Paralleles parties en même temps)..."
	$luau = (Get-Command luau).Source
	$runsDir = Join-Path $here "gen\runs"
	New-Item -ItemType Directory -Force $runsDir | Out-Null
	Get-ChildItem $runsDir -File | Remove-Item
	$jobs = New-Object System.Collections.Generic.List[object]
	foreach ($scenario in $scenarioList) {
		for ($seed = 1; $seed -le $Graines; $seed++) {
			$name = "{0}_{1}" -f $scenario, $seed
			$jobArgs = @("--codegen", "-O2", "main.luau", "-a", "travail=1", "graines=1", "debut=$seed", "heures=$Heures", "scenarios=$scenario", "pas=$Pas")
			if ($Regler -ne "") { $jobArgs += "`"regler=$Regler`"" }
			if ($Journal -and $jobs.Count -eq 0) { $jobArgs += "journal=1" }
			$jobs.Add([pscustomobject]@{ Name = $name; Args = $jobArgs; Process = $null; Out = (Join-Path $runsDir "$name.out"); Err = (Join-Path $runsDir "$name.err"); Shown = $false })
		}
	}
	# Lance les parties (au plus $Paralleles à la fois) et affiche la progression quand une partie se termine.
	$next = 0
	while ($true) {
		$running = 0
		foreach ($job in $jobs) {
			if ($job.Process -ne $null) {
				if ($job.Process.HasExited) {
					if (-not $job.Shown) {
						# Progression seulement : un seul essai ; si le fichier est encore bloqué, on réessaie au
						# tour suivant (0,5 s plus tard).
						try {
							foreach ($line in (Read-JobLines $job.Out 1)) {
								if ($line.StartsWith("PROGRES|")) { Write-Host $line.Substring(8) }
							}
							$job.Shown = $true
						} catch { }
					}
				} else {
					$running++
				}
			}
		}
		if ($next -ge $jobs.Count -and $running -eq 0) { break }
		while ($next -lt $jobs.Count -and $running -lt $Paralleles) {
			$job = $jobs[$next]
			$job.Process = Start-Process -FilePath $luau -ArgumentList $job.Args -WorkingDirectory $here -RedirectStandardOutput $job.Out -RedirectStandardError $job.Err -NoNewWindow -PassThru
			$null = $job.Process.Handle # garde le code de sortie lisible après la fin du processus
			$next++
			$running++
		}
		Start-Sleep -Milliseconds 500
	}
	$modules = New-Object System.Collections.Generic.List[string]
	foreach ($job in $jobs) {
		$job.Process.WaitForExit()
		if ($job.Process.ExitCode -ne 0) {
			Get-Content $job.Out -Tail 20 | ForEach-Object { Write-Host $_ }
			Get-Content $job.Err | ForEach-Object { Write-Host $_ }
			Write-Host "La partie $($job.Name) s'est arrêtée sur une erreur (voir ci-dessus)."
			exit 1
		}
		foreach ($line in (Read-JobLines $job.Out)) {
			if ($line.StartsWith("CSV|")) { $csv.Add($line.Substring(4)) }
			elseif ($line.StartsWith("HEURES|")) { $hours.Add($line.Substring(7)) }
			elseif ($line.StartsWith("JOURNAL|")) { $log.Add($line.Substring(8)) }
			elseif ($line.StartsWith("PARTIE|")) {
				[IO.File]::WriteAllText((Join-Path $runsDir "$($job.Name).luau"), "return " + $line.Substring(7), $utf8)
				$modules.Add("./gen/runs/$($job.Name)")
			}
		}
	}
	$assembleArgs = @("--codegen", "-O2", "main.luau", "-a", ("assembler=" + ($modules -join ","))) + $arguments
	$header = New-Object System.Collections.Generic.List[string]
	$hoursHeader = New-Object System.Collections.Generic.List[string]
	Push-Location $here
	try {
		& $luau @assembleArgs | ForEach-Object {
			if ($_.StartsWith("CSV|")) { $header.Add($_.Substring(4)) }
			elseif ($_.StartsWith("HEURES|")) { $hoursHeader.Add($_.Substring(7)) }
			elseif ($_.StartsWith("PROGRES|")) { Write-Host $_.Substring(8) }
			elseif (-not $_.StartsWith("JOURNAL|")) { $report.Add($_) }
		}
		$code = $LASTEXITCODE
	} finally {
		Pop-Location
	}
	$csv.InsertRange(0, $header)
	$hours.InsertRange(0, $hoursHeader)
} else {
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
