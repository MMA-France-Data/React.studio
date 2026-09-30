# Mode tournage : images et vidéos du jeu pour la page Roblox (miniatures, vidéo de gameplay).
# Construit une place de test avec les scénarios TournageServer / TournageClient (vraies mécaniques du jeu, seule la
# caméra est pilotée), ouvre Studio, lance Play et pilote OBS (obs.cjs) : repérage de la vue 3D, enregistrement,
# images 1920 x 1080.
#   powershell -ExecutionPolicy Bypass -File tools\studio-test\tournage.ps1
#   powershell -ExecutionPolicy Bypass -File tools\studio-test\tournage.ps1 -SansObs   (captures de la fenêtre de
#                                                  Studio seulement, pour régler les plans sans OBS)
# Résultats dans tools\studio-test\out\tournage : images .png et vidéos .mp4.
# Studio et OBS doivent être fermés. OBS est lancé directement sur son profil « Tower 22 » (jamais celui du
# propriétaire, avec son chat Twitch), puis refermé ; son profil et ses scènes habituels sont remis à la fin.
param(
	[int]$Seconds = 240,
	[switch]$SansObs,
	[int]$Timeout = 0 # ouverture de Studio + Play ($Seconds) + fermeture (0 = $Seconds + 180 s)
)
if ($Timeout -le 0) { $Timeout = $Seconds + 180 }
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$out = Join-Path $root "out"
$media = Join-Path $out "tournage"
New-Item -ItemType Directory -Force $media | Out-Null

if (Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue) {
	Write-Host "Roblox Studio est ouvert : ferme-le d'abord."
	exit 1
}
if (-not $SansObs -and (Get-Process obs64 -ErrorAction SilentlyContinue)) {
	Write-Host "OBS est ouvert : ferme-le d'abord (il est relancé sur le profil « Tower 22 », puis remis comme avant)."
	exit 1
}

# Studio doit rester AU PREMIER PLAN pendant le tournage : caché derrière une autre fenêtre, il ne dessine plus sa vue
# 3D (images blanches ou noires). On le met devant, en plein écran, au moment du repérage, et l'écran reste allumé
# pendant tout le tournage (SetThreadExecutionState).
Add-Type @"
using System; using System.Runtime.InteropServices;
public class TournageWindow {
	[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
	[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
	[DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
	[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint flags);
}
"@
function Show-Studio {
	$process = Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
	if (-not $process) { return }
	$handle = $process.MainWindowHandle
	[TournageWindow]::ShowWindow($handle, 3) | Out-Null # SW_MAXIMIZE
	# Windows ne laisse passer une fenêtre devant que si on vient d'utiliser le clavier : touche Alt appuyée et relâchée.
	[TournageWindow]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)
	[TournageWindow]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
	[TournageWindow]::SetForegroundWindow($handle) | Out-Null
}
[TournageWindow]::SetThreadExecutionState([uint32]"0x80000003") | Out-Null # écran et PC restent allumés

# Lecture de la Sortie pendant que logserver.cjs y écrit : partage en lecture/écriture, et rien (null) si le
# fichier est pris à cet instant (on relit 200 ms plus tard).
function Read-Log([string]$path) {
	try {
		$stream = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
		try {
			$reader = New-Object IO.StreamReader($stream, [Text.Encoding]::UTF8)
			return $reader.ReadToEnd()
		} finally {
			$stream.Dispose()
		}
	} catch {
		return $null
	}
}

# 1. Place de tournage et plugin de test (lance Play tout seul, envoie la Sortie à logserver.cjs)
node (Join-Path $root "mkproj.cjs") tournage $Seconds
$placeFile = Join-Path $out "tournage.rbxl"
rojo build (Join-Path $out "tournage.project.json") -o $placeFile
if ($LASTEXITCODE -ne 0) { exit 1 }
$plugins = Join-Path $env:LOCALAPPDATA "Roblox\Plugins"
New-Item -ItemType Directory -Force $plugins | Out-Null
Copy-Item (Join-Path $root "AutoPlayTest.lua") $plugins -Force

# 2. OBS : profil et scène « Tower 22 »
$obs = Join-Path $root "obs.cjs"
function Invoke-Obs([string[]]$arguments) {
	$ErrorActionPreference = "Continue"
	& node $obs @arguments 2>&1 | ForEach-Object { Write-Host "  [OBS] $_" }
}
if (-not $SansObs) {
	Invoke-Obs @("start")
	if ($LASTEXITCODE -ne 0) {
		Write-Host "OBS n'a pas pu démarrer : tournage annulé"
		Stop-Process -Name obs64 -Force -ErrorAction SilentlyContinue
		Start-Sleep -Seconds 1
		Invoke-Obs @("restore")
		exit 1
	}
}

# 3. Studio, puis les marqueurs du scénario (lignes complètes de la Sortie seulement)
$log = Join-Path $out "studio-output.log"
[IO.File]::WriteAllText($log, "")
$server = Start-Process node -ArgumentList "`"$(Join-Path $root 'logserver.cjs')`"" -WindowStyle Hidden -PassThru
$done = 0
$made = @()
try {
	explorer.exe $placeFile
	$start = Get-Date
	$ended = $false
	while (-not $ended) {
		Start-Sleep -Milliseconds 200
		if (((Get-Date) - $start).TotalSeconds -gt $Timeout) { Write-Host "Temps dépassé"; break }
		$text = Read-Log $log
		if ($null -eq $text) { continue }
		$lines = $text -split "`n"
		$complete = $lines.Count - 1 # la dernière case est vide si le fichier finit par un retour à la ligne
		for ($i = $done; $i -lt $complete; $i++) {
			$line = $lines[$i]
			if ($line -match "\] CALIBRATE") {
				Show-Studio
				Start-Sleep -Milliseconds 1500
				if (-not $SansObs) { Invoke-Obs @("calibrate") }
			} elseif ($line -match "\] REC:START") {
				if (-not $SansObs) { Invoke-Obs @("rec-start") }
			} elseif ($line -match "\] REC:STOP:(\w+)") {
				$file = Join-Path $media "$($Matches[1]).mp4"
				if (-not $SansObs) { Invoke-Obs @("rec-stop", $file); $made += $file }
			} elseif ($line -match "\] IMG:(\w+)") {
				$file = Join-Path $media "$($Matches[1]).png"
				if ($SansObs) { & (Join-Path $root "shot.ps1") $file | Out-Null } else { Invoke-Obs @("shot", $file) }
				$made += $file
			} elseif ($line -match "play mode ended") {
				$ended = $true
			}
		}
		$done = [Math]::Max($done, $complete)
	}
} finally {
	[TournageWindow]::SetThreadExecutionState([uint32]"0x80000000") | Out-Null # l'écran peut de nouveau s'éteindre
	Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
	Stop-Process -Name RobloxStudioBeta -Force -ErrorAction SilentlyContinue
	if (-not $SansObs) {
		# Fin de l'enregistrement, fermeture normale d'OBS (arrêt forcé au bout de 20 s), puis profil et scènes du
		# propriétaire remis.
		Invoke-Obs @("finish")
		$ErrorActionPreference = "Continue"
		taskkill /IM obs64.exe 2>&1 | Out-Null
		$deadline = (Get-Date).AddSeconds(20)
		while ((Get-Process obs64 -ErrorAction SilentlyContinue) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 500 }
		if (Get-Process obs64 -ErrorAction SilentlyContinue) {
			Write-Host "OBS ne se fermait pas : arrêt forcé"
			Stop-Process -Name obs64 -Force -ErrorAction SilentlyContinue
			Start-Sleep -Seconds 1
		}
		Invoke-Obs @("restore")
	}
}

Get-Content $log -Encoding UTF8 | Where-Object { $_ -match "TOURNAGE|Error|FAIL|IMG:|REC:|CALIBRATE" }
Write-Host ""
Write-Host "Fichiers :"
foreach ($file in $made) {
	if (Test-Path $file) { Write-Host ("  " + $file + "  (" + [Math]::Round((Get-Item $file).Length / 1MB, 1) + " Mo)") }
	else { Write-Host "  MANQUANT : $file" }
}
