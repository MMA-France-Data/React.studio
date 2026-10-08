$ErrorActionPreference = 'Stop'
$menuRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$menuOutput = Join-Path ([System.IO.Path]::GetTempPath()) ('monde-menu-ui-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $menuOutput | Out-Null
& node (Join-Path $PSScriptRoot 'check.cjs') $menuRoot $menuOutput
if ($LASTEXITCODE -ne 0) { throw 'Menu behavior / layout checks failed' }
foreach ($menuSource in Get-ChildItem -LiteralPath (Join-Path $menuRoot 'src') -Recurse -Filter '*.luau') {
    & luau-compile --null $menuSource.FullName | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Syntax error: $($menuSource.FullName)" }
}
& rojo build (Join-Path $menuRoot 'default.project.json') -o (Join-Path $menuOutput 'Monde.rbxl')
if ($LASTEXITCODE -ne 0) { throw 'Game build failed' }
Write-Output "MENU_UI_BUILD_OK: $menuOutput (headless mocks, not a Studio renderer test)"
