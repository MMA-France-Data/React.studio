# Installe le plugin Studio « Rangeur de monstres » (bouton « Monstres » de l'onglet Plugins).
#   powershell -ExecutionPolicy Bypass -File tools\studio-helper\install.ps1
# Studio charge les plugins au démarrage : le relancer après l'installation.
$ErrorActionPreference = "Stop"
$plugins = Join-Path $env:LOCALAPPDATA "Roblox\Plugins"
New-Item -ItemType Directory -Force $plugins | Out-Null
Copy-Item (Join-Path $PSScriptRoot "RangeurMonstres.lua") $plugins -Force
Write-Host "Plugin installé dans $plugins (relance Studio pour le voir : onglet Plugins > Monstres)."
