$ErrorActionPreference = 'Stop'
$taskRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
& luau (Join-Path $taskRoot 'tools/combat-v3/alternation.luau')
if ($LASTEXITCODE -ne 0) { throw 'Combat timing / alternation failed' }
$taskSources = @(Get-ChildItem -LiteralPath (Join-Path $taskRoot 'src') -Recurse -Filter '*.luau')
$taskSources += Get-Item -LiteralPath (Join-Path $taskRoot 'assets/combat/personnage-v4/Preview.client.luau')
foreach ($taskSource in $taskSources) {
    & luau-compile --null $taskSource.FullName | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Syntax error: $($taskSource.FullName)" }
}
$taskExports = @(Get-ChildItem -LiteralPath (Join-Path $taskRoot 'assets/combat/personnage-v4/animations') -Filter '*.rbxmx')
if ($taskExports.Count -ne 2) { throw 'Exactly two attacks required' }
foreach ($taskFile in $taskExports) {
    [xml]$taskXml = Get-Content -LiteralPath $taskFile.FullName -Raw
    if ($taskXml.SelectSingleNode('//Item[@class="KeyframeSequence"]/Properties/bool[@name="Loop"]').InnerText -ne 'false') { throw 'Attack must not loop' }
    if ($taskXml.SelectNodes('//Item[@class="Keyframe" and Properties/string[@name="Name"]="Impact"]').Count -ne 1) { throw 'One Impact marker required' }
    if (-not $taskXml.SelectSingleNode('//Item[@class="Pose" and Properties/string[@name="Name"]="HumanoidRootPart"]')) { throw 'R15 root missing' }
    $taskMaximum = 0.0
    foreach ($taskNode in $taskXml.SelectNodes('//Item[@class="Keyframe"]/Properties/float[@name="Time"]')) {
        $taskTime = [double]::Parse($taskNode.InnerText, [System.Globalization.CultureInfo]::InvariantCulture)
        $taskMaximum = [Math]::Max($taskMaximum, $taskTime)
    }
    if ([Math]::Abs($taskMaximum - 0.38) -gt 0.00001) { throw 'Visual duration changed' }
    foreach ($taskNode in $taskXml.SelectNodes('//CoordinateFrame/*')) {
        $taskValue = [double]::Parse($taskNode.InnerText, [System.Globalization.CultureInfo]::InvariantCulture)
        if ([double]::IsNaN($taskValue) -or [double]::IsInfinity($taskValue)) { throw 'Non-finite pose' }
    }
}
$taskBuild = Join-Path ([System.IO.Path]::GetTempPath()) ('monde-combat-v4-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $taskBuild | Out-Null
& rojo build (Join-Path $taskRoot 'assets/combat/personnage-v4/gallery.project.json') -o (Join-Path $taskBuild 'ElementalPreview.rbxl')
if ($LASTEXITCODE -ne 0) { throw 'Preview build failed' }
& rojo build (Join-Path $taskRoot 'default.project.json') -o (Join-Path $taskBuild 'Monde.rbxl')
if ($LASTEXITCODE -ne 0) { throw 'Game build failed' }
Write-Output "COMBAT_V4_CHECKS_OK: $($taskSources.Count) Luau files, 89 timing checks, two XML clips, preview + game built. $taskBuild (Studio/mobile runtime not tested)"
