# VIDÉO DE LA PAGE ROBLOX du jeu : 16 s faites de plans de 3 à 4 s (demande du propriétaire, 04/10/2026 : « faut
# refaire une vidéo du jeu avec des rushs de 3/4 s, une vidéo de 16 s »). Pas un test.
#   1. Construit une place avec les scénarios VideoServer / VideoClient (de vraies parties, en anglais), l'ouvre dans
#      Studio, lance Play et pilote OBS (obs.cjs) : repérage de la vue 3D, puis un enregistrement par plan
#      (out\video\r1.mp4 à r5.mp4) ;
#   2. montage.py coupe les plans, les enchaîne avec des transitions (ffmpeg) et pose dessus notre propre musique
#      (musique.py, à la place du son du jeu) : out\video\video-16s.mp4 (et video-16s-titres.mp4, avec des titres
#      en anglais), copiées dans A-PUBLIER.
#   powershell -ExecutionPolicy Bypass -File tools\studio-test\video.ps1
#   powershell -ExecutionPolicy Bypass -File tools\studio-test\video.ps1 -MontageSeulement   (refait seulement le
#                                                  montage, avec les plans déjà filmés)
# OBS doit être fermé : il est lancé sur son profil « Tower 22 » (1920 x 1080, 60 images/s ; jamais le profil du
# propriétaire, avec son chat Twitch), puis refermé, et son profil et ses scènes habituels sont remis à la fin. Un
# Studio déjà ouvert n'est pas touché : le tournage s'ouvre dans une autre fenêtre de Studio, mise devant et en plein
# écran (cachée derrière une autre fenêtre, Studio ne dessine plus sa vue 3D). Ne touche pas au PC pendant le
# tournage (environ 5 minutes).
param(
	[int]$Seconds = 480, # durée maximale du Play
	[switch]$MontageSeulement
)
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$repo = (Resolve-Path (Join-Path $root "..\..")).Path
$out = Join-Path $root "out"
$media = Join-Path $out "video"
New-Item -ItemType Directory -Force $media | Out-Null
$montage = Join-Path $root "montage.py"
$publish = Join-Path $repo "A-PUBLIER"

if (-not $MontageSeulement) {
	if (Get-Process obs64 -ErrorAction SilentlyContinue) {
		Write-Host "OBS est ouvert : ferme-le d'abord (il est relancé sur le profil « Tower 22 », puis remis comme avant)."
		exit 1
	}
	# Studio déjà ouverts avant le tournage (numéros de processus) : jamais touchés.
	$others = @(Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
	if ($others.Count -gt 0) {
		Write-Host "Roblox Studio est déjà ouvert : il n'est pas touché, le tournage s'ouvre dans une autre fenêtre de Studio."
	}

	Add-Type @"
using System; using System.Runtime.InteropServices;
public class VideoWindow {
	[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
	[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
	[DllImport("user32.dll")] public static extern bool IsZoomed(IntPtr h);
	[DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
}
"@
	# Le Studio ouvert par CE tournage : un processus qui n'existait pas avant, avec sa vraie fenêtre.
	function Get-VideoStudio {
		return Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue |
			Where-Object { $others -notcontains $_.Id -and $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -match "- Roblox Studio$" } |
			Select-Object -First 1
	}
	# Met la fenêtre du tournage devant, en plein écran. (Windows ne laisse passer une fenêtre devant que si on vient
	# d'utiliser le clavier : touche Alt appuyée et relâchée.)
	function Show-VideoStudio {
		$process = Get-VideoStudio
		if (-not $process) { return }
		$handle = $process.MainWindowHandle
		[VideoWindow]::ShowWindow($handle, 3) | Out-Null # 3 = SW_MAXIMIZE
		[VideoWindow]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)
		[VideoWindow]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
		[VideoWindow]::SetForegroundWindow($handle) | Out-Null
	}

	# 1. La place du tournage et le plugin de test (il lance Play tout seul et envoie la Sortie à logserver.cjs).
	node (Join-Path $root "mkproj.cjs") video $Seconds
	if ($LASTEXITCODE -ne 0) { exit 1 }
	$placeFile = Join-Path $out "video.rbxl"
	rojo build (Join-Path $out "video.project.json") -o $placeFile
	if ($LASTEXITCODE -ne 0) { exit 1 }
	$plugins = Join-Path $env:LOCALAPPDATA "Roblox\Plugins"
	New-Item -ItemType Directory -Force $plugins | Out-Null
	Copy-Item (Join-Path $root "AutoPlayTest.lua") $plugins -Force
	Get-ChildItem $media -Filter "r*.mp4" -ErrorAction SilentlyContinue | Remove-Item -Force

	# 2. OBS sur son profil « Tower 22 ».
	$obs = Join-Path $root "obs.cjs"
	function Invoke-Obs([string[]]$arguments) {
		$ErrorActionPreference = "Continue"
		& node $obs @arguments 2>&1 | ForEach-Object { Write-Host "  [OBS] $_" }
	}
	Invoke-Obs @("start")
	if ($LASTEXITCODE -ne 0) {
		Write-Host "OBS n'a pas pu démarrer : tournage annulé"
		Stop-Process -Name obs64 -Force -ErrorAction SilentlyContinue
		Start-Sleep -Seconds 1
		Invoke-Obs @("restore")
		exit 1
	}

	# 3. Studio, puis les marqueurs du scénario (lignes complètes de la Sortie seulement).
	$log = Join-Path $out "studio-output.log"
	[IO.File]::WriteAllText($log, "")
	# (un vieux serveur de journal garderait le port : la Sortie partirait dans SON fichier)
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
			return $text
		} catch {
			return $null
		}
	}
	$done = 0
	$clips = @()
	try {
		explorer.exe $placeFile
		$start = Get-Date
		$maximized = $false
		$ended = $false
		while (-not $ended) {
			Start-Sleep -Milliseconds 100
			if (((Get-Date) - $start).TotalSeconds -gt ($Seconds + 150)) { Write-Host "Temps dépassé"; break }
			if (-not $maximized) {
				$studio = Get-VideoStudio
				if ($studio) {
					if ([VideoWindow]::IsZoomed($studio.MainWindowHandle)) { $maximized = $true } else { Show-VideoStudio }
				}
			}
			$text = Read-Log
			if ($null -eq $text) { continue }
			$lines = $text -split "`n"
			$complete = $lines.Count - 1 # (la dernière case est vide si le fichier finit par un retour à la ligne)
			for ($i = $done; $i -lt $complete; $i++) {
				$line = $lines[$i]
				if ($line -match "\] CALIBRATE") {
					Show-VideoStudio
					Start-Sleep -Milliseconds 1500
					Invoke-Obs @("calibrate", "video.rbxl")
				} elseif ($line -match "\] REC:START") {
					Show-VideoStudio
					Invoke-Obs @("rec-start")
				} elseif ($line -match "\] REC:STOP:(\w+)") {
					$file = Join-Path $media "$($Matches[1]).mp4"
					Invoke-Obs @("rec-stop", $file)
					$clips += $file
				} elseif ($line -match "VIDEO:done" -or $line -match "play mode ended") {
					$ended = $true
				}
			}
			$done = [Math]::Max($done, $complete)
		}
	} finally {
		Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
		Stop-KeepAwake
		# Seulement le Studio du tournage (les autres ne sont pas touchés).
		Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | Where-Object { $others -notcontains $_.Id } |
			ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
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
	Get-Content $log -Encoding UTF8 | Where-Object { $_ -match "\[VIDEO\]|\]\[Error\]|\[FAIL\]" }
	Write-Host ""
	Write-Host "Plans filmés :"
	foreach ($file in $clips) {
		if (Test-Path $file) { Write-Host ("  " + $file + "  (" + [Math]::Round((Get-Item $file).Length / 1MB, 1) + " Mo)") }
		else { Write-Host "  MANQUANT : $file" }
	}
}

# 4. Le montage : 16 s pile, avec les plans filmés.
python $montage --plans $media --sortie $publish
exit $LASTEXITCODE
