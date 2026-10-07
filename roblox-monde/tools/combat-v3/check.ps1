$ErrorActionPreference = 'Stop'
$taskRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
& luau (Join-Path $PSScriptRoot 'alternation.luau')
if ($LASTEXITCODE -ne 0) { throw 'Combat timing / alternation failed' }
foreach ($taskName in @('CombatMotion','CombatVFX','Poses','SwordVisuals','SwordPalette','SwordEffects','SwordGrip','SwordElementalAura')) {
    & luau-compile --null (Join-Path $taskRoot "src/client/$taskName.luau")
    if ($LASTEXITCODE -ne 0) { throw "Syntax error: $taskName" }
}
$taskExports = @(Get-ChildItem -LiteralPath (Join-Path $taskRoot 'assets/combat/personnage-v3/animations') -Filter '*.rbxmx')
if ($taskExports.Count -ne 2) { throw 'Exactly two attacks required' }
foreach ($taskFile in $taskExports) {
    [xml]$taskXml = Get-Content -LiteralPath $taskFile.FullName -Raw
    if ($taskXml.SelectSingleNode('//Item[@class="KeyframeSequence"]/Properties/bool[@name="Loop"]').InnerText -ne 'false') { throw 'Attack must not loop' }
    if ($taskXml.SelectNodes('//Item[@class="Keyframe" and Properties/string[@name="Name"]="Impact"]').Count -ne 1) { throw 'One Impact marker required' }
    if (-not $taskXml.SelectSingleNode('//Item[@class="Pose" and Properties/string[@name="Name"]="HumanoidRootPart"]')) { throw 'R15 root missing' }
    foreach ($taskNode in $taskXml.SelectNodes('//CoordinateFrame/*')) {
        $taskValue = [double]::Parse($taskNode.InnerText, [System.Globalization.CultureInfo]::InvariantCulture)
        if ([double]::IsNaN($taskValue) -or [double]::IsInfinity($taskValue)) { throw 'Non-finite pose' }
    }
}
$taskBuild = Join-Path ([System.IO.Path]::GetTempPath()) ('monde-combat-v3-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $taskBuild | Out-Null
& rojo build (Join-Path $taskRoot 'assets/combat/personnage-v3/gallery.project.json') -o (Join-Path $taskBuild 'Gallery.rbxlx')
if ($LASTEXITCODE -ne 0) { throw 'Gallery build failed' }
& rojo build (Join-Path $taskRoot 'default.project.json') -o (Join-Path $taskBuild 'Monde.rbxlx')
if ($LASTEXITCODE -ne 0) { throw 'Game build failed' }
Write-Output "COMBAT_V3_CHECKS_OK: $taskBuild (Studio runtime not tested)"
