# Headless validation only. Does not launch, focus or control Roblox Studio.
$ErrorActionPreference = 'Stop'
$checkRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
& (Join-Path $checkRoot 'tools/menu-ui/check.ps1')
& (Join-Path $checkRoot 'tools/combat-v4/check.ps1')
