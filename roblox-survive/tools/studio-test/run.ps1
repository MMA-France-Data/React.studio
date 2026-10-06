# Test automatique du jeu dans Roblox Studio : construit une place de test, l'ouvre dans Studio, lance Play, joue le
# scenario (dossier scenarios), prend une capture a chaque "SHOT:nom" de la Sortie et affiche les resultats.
#
#   powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1             -> tout le jeu (environ 5 min)
#   powershell -ExecutionPolicy Bypass -File tools\studio-test\run.ps1 -Test jump  -> mesure du saut (environ 3 min)
#
# Resultats dans tools\studio-test\out : studio-output.log et les captures. Ne touche pas au PC pendant le test.
# Un Studio deja ouvert n'est PAS touche : le test s'ouvre dans une autre fenetre, fermee a la fin (-KeepOpen : non).
# (Fichier sans accents expres : PowerShell 5.1 lit mal l'UTF-8 sans BOM.)
param(
	[ValidateSet("game", "jump", "hunter", "rocks", "valves", "eggs", "poses")][string]$Test = "game",
	[int]$Seconds = 420,
	[switch]$KeepOpen
)
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$out = Join-Path $root "out"
New-Item -ItemType Directory -Force $out | Out-Null

$others = @(Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })

Add-Type @"
using System; using System.Runtime.InteropServices;
public class TestWindow {
	[DllImport("user32.dll")] public static extern bool IsZoomed(IntPtr h);
	[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
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
# Un test interrompu peut laisser tourner son serveur de journal : il garde le port. On l'arrete.
Get-CimInstance Win32_Process -Filter "Name = 'node.exe'" -ErrorAction SilentlyContinue |
	Where-Object { $_.CommandLine -like "*logserver.cjs*" } |
	ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
$server = Start-Process node -ArgumentList "`"$(Join-Path $root 'logserver.cjs')`"" -WindowStyle Hidden -PassThru
. (Join-Path $root "awake.ps1")
Start-KeepAwake

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
# Le Studio ouvert par CE test : un processus qui n'existait pas avant, avec sa vraie fenetre.
function Get-TestStudio {
	return Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue |
		Where-Object { $others -notcontains $_.Id -and $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -match "- Roblox Studio$" } |
		Select-Object -First 1
}

try {
	explorer.exe $placeFile
	$start = Get-Date
	$shots = @{}
	$maximized = $false
	while ($true) {
		Start-Sleep -Milliseconds 250
		$lines = Read-Log
		foreach ($line in $lines) {
			if ($line -match "SHOT:(\w+)" -and -not $shots.ContainsKey($Matches[1])) {
				$name = $Matches[1]
				$shots[$name] = $true
				$testStudio = Get-TestStudio
				# Une capture ratee (fichier occupe, fenetre cachee) ne doit pas arreter le test.
				if ($testStudio) {
					try { & (Join-Path $root "shot.ps1") (Join-Path $out "$name.png") -ProcessId $testStudio.Id | Out-Null }
					catch { Write-Host "Capture ratee : $name" }
				}
			}
		}
		if (-not $maximized) {
			$studio = Get-TestStudio
			if ($studio) {
				if ([TestWindow]::IsZoomed($studio.MainWindowHandle)) { $maximized = $true }
				else { [TestWindow]::ShowWindow($studio.MainWindowHandle, 3) | Out-Null }
			}
		}
		$all = $lines -join "`n"
		if ($all -match "play mode ended") { break }
		if ($all -match "TEST:done") { Start-Sleep -Seconds 2; break }
		if (((Get-Date) - $start).TotalSeconds -gt ($Seconds + 150)) { Write-Host "Temps depasse"; break }
	}
} finally {
	Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
	Stop-KeepAwake
}
if (-not $KeepOpen) {
	Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | Where-Object { $others -notcontains $_.Id } |
		ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
}

$lines = Read-Log
$lines | Where-Object { $_ -match "\[SURVIVE\]|\[PASS\]|\[FAIL\]|\]\[Error\]|\[MessageError\]|\]\[Warning\]" }
Write-Host ""
Write-Host ("Captures : " + (($shots.Keys | Sort-Object) -join ", "))
$passed = @($lines | Where-Object { $_ -match "\[PASS\]" })
$errors = @($lines | Where-Object { $_ -match "\]\[Error\]|\[MessageError\]|\[FAIL\]" })
Write-Host "Reussis : $($passed.Count)   Erreurs : $($errors.Count)"
