# Vérification rapide sans ouvrir Studio : syntaxe de tous les scripts (luau-compile, si installé)
# et construction de la place (rojo build).
#   powershell -ExecutionPolicy Bypass -File tools\studio-test\check.ps1
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$out = Join-Path $PSScriptRoot "out"
New-Item -ItemType Directory -Force $out | Out-Null
$failed = $false

if (Get-Command luau-compile -ErrorAction SilentlyContinue) {
	foreach ($file in Get-ChildItem (Join-Path $repo "src") -Recurse -Filter *.luau) {
		# luau-compile écrit les erreurs de syntaxe sur la sortie d'erreur
		$errors = cmd /c "luau-compile --text `"$($file.FullName)`" 2>&1 1>NUL"
		if ($errors) { $errors; $failed = $true }
	}
} else {
	Write-Host "luau-compile absent : syntaxe non vérifiée (https://github.com/luau-lang/luau/releases)"
}

rojo build (Join-Path $repo "default.project.json") -o (Join-Path $out "check.rbxl") | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Host "rojo build a échoué"; $failed = $true }

if ($failed) { exit 1 }
Write-Host "OK : syntaxe valide et place construite"
