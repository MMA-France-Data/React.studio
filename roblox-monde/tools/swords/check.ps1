$ErrorActionPreference = 'Stop'
$taskRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
& luau (Join-Path $PSScriptRoot 'dual-and-wisps.luau')
if ($LASTEXITCODE -ne 0) { throw 'Dual mirror / particle profile checks failed' }
& node (Join-Path $PSScriptRoot 'verify-dual-geometry.cjs')
if ($LASTEXITCODE -ne 0) { throw 'Actual R15 inward hand trajectories failed' }
$taskFixture = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'aura-runtime.template.luau') -Raw
foreach ($taskSource in @(@('WISP','SwordWispProfile'),@('PROFILE','VoidAuraProfile'),@('VOID','VoidBladeAura'),@('AURA','SwordElementalAura'))) {
    $taskCode = Get-Content -LiteralPath (Join-Path $taskRoot "src/client/$($taskSource[1]).luau") -Raw
    $taskFixture = $taskFixture.Replace("--[[$($taskSource[0])_SOURCE]]", $taskCode)
}
$taskFixtureDir = Join-Path ([System.IO.Path]::GetTempPath()) ('sword-aura-contract-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $taskFixtureDir | Out-Null
$taskFixturePath = Join-Path $taskFixtureDir 'contract.luau'
[System.IO.File]::WriteAllText($taskFixturePath, $taskFixture)
& luau $taskFixturePath
if ($LASTEXITCODE -ne 0) { throw 'Aura object lifecycle / mobile contract failed (mock objects, not Studio rendering)' }
& luau-compile --null (Join-Path $PSScriptRoot 'RangerLesEpees.lua') | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Import plugin syntax error' }
foreach ($taskId in @('Fusion', 'Void')) {
    $taskDir = Join-Path $taskRoot "assets/swords-roblox/$taskId"
    $taskInfo = Get-Content -LiteralPath (Join-Path $taskDir 'info.json') -Raw | ConvertFrom-Json
    if ($taskInfo.triangles -gt 19000 -or $taskInfo.triangles -le 0) { throw "Triangle budget: $taskId" }
    if ($taskInfo.gripAt[0] -ne 0 -or $taskInfo.gripAt[1] -ne 0 -or $taskInfo.gripAt[2] -ne 0) { throw 'Handle pivot not at origin' }
    if ($taskInfo.trailTip[2] -ge $taskInfo.trailBase[2] -or $taskInfo.trailBase[2] -ge 0) { throw 'Invalid blade/trail axis' }
    $taskModel = Join-Path $taskDir "Sword_$taskId.fbx"
    $taskImport = Join-Path $taskRoot "assets/swords-roblox/A-IMPORTER/Sword_$taskId.fbx"
    if ((Get-FileHash -LiteralPath $taskModel).Hash -ne (Get-FileHash -LiteralPath $taskImport).Hash) { throw 'Import copy differs from prepared FBX' }
    foreach ($taskMap in @('baseColor','normal','metallic','roughness')) {
        $taskTexture = Join-Path $taskDir "$taskMap.png"
        $taskBundled = Join-Path $taskRoot "assets/swords-roblox/A-IMPORTER/Sword_$taskId.fbm/$taskMap.png"
        if (-not (Test-Path -LiteralPath $taskTexture)) { throw 'Missing PBR map' }
        if ((Get-FileHash -LiteralPath $taskTexture).Hash -ne (Get-FileHash -LiteralPath $taskBundled).Hash) { throw 'Texture copy differs' }
    }
}
& (Join-Path $taskRoot 'tools/combat-v4/check.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Combat regression check failed' }
Write-Output 'SWORD_ADDITIONS_OK (Studio/mobile runtime still required)'
